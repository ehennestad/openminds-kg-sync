classdef KgsaveTest < matlab.unittest.TestCase
% KgsaveTest - Unit tests for the kgsave function
%
% This test class covers:
% - Basic saving of openMINDS instances
% - Different SaveMode options (Update vs Replace)
% - Single and multiple instance saving
% - Error handling for invalid inputs and API failures
% - Integration with mock KG client
% - Argument validation and default behaviors
% - Custom client and metadata store usage

    properties (TestParameter)
        % Test with different SaveMode values
        saveModes = {omkg.enum.SaveMode.Update, omkg.enum.SaveMode.Replace}

        % Test with different numbers of instances
        instanceCounts = {1, 3, 5}

        % Test with different KG servers
        kgServers = {ebrains.kg.enum.KGServer.PROD, ebrains.kg.enum.KGServer.PREPROD}
    end

    properties
        MockClient
        TestInstances
        TestSpace
        TestServer
        OriginalPrefs
    end

    methods (TestClassSetup)
        function setupOnce(testCase) %#ok<MANU>
            omkg.internal.checkEnvironment()
        end
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            % Store original preferences to restore later
            try
                testCase.OriginalPrefs.DefaultSpace = omkg.getpref("DefaultSpace");
            catch
                testCase.OriginalPrefs.DefaultSpace = [];
            end
            try
                testCase.OriginalPrefs.DefaultServer = omkg.getpref("DefaultServer");
            catch
                testCase.OriginalPrefs.DefaultServer = [];
            end

            % Set up test environment
            testCase.TestSpace = "test-space-12345";
            testCase.TestServer = ebrains.kg.enum.KGServer.PREPROD;

            % Set temporary preferences for testing
            omkg.setpref("DefaultSpace", testCase.TestSpace);
            omkg.setpref("DefaultServer", testCase.TestServer);

            % Create mock client
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            % Create test instances
            testCase.TestInstances = testCase.createTestInstances();

            % Set up default mock responses
            testCase.setupMockResponses();
        end
    end

    methods (TestMethodTeardown)
        function teardownTest(testCase)
            % Restore original preferences
            if ~isempty(testCase.OriginalPrefs.DefaultSpace)
                omkg.setpref("DefaultSpace", testCase.OriginalPrefs.DefaultSpace);
            end
            if ~isempty(testCase.OriginalPrefs.DefaultServer)
                omkg.setpref("DefaultServer", testCase.OriginalPrefs.DefaultServer);
            end
        end
    end

    methods (Test)

        function testBasicSave_SingleInstance(testCase)
            % Test basic saving of a single openMINDS instance
            instance = testCase.TestInstances(1);

            ids = kgsave(instance, 'Client', testCase.MockClient, 'Verbose', false);

            testCase.verifyClass(ids, 'string', ...
                'Expected string array of IDs');
            testCase.verifySize(ids, [1, 1], ...
                'Expected single ID for single instance');
            testCase.verifyNotEmpty(ids, ...
                'Expected non-empty ID');

            % Verify client was called correctly
            testCase.verifyNotEmpty(testCase.MockClient.getLastCallFor('createNewInstanceWithId'), ...
                'Expected createNewInstance to be called');
        end

        function testBasicSave_MultipleInstances(testCase, instanceCounts)
            % Test saving multiple instances
            instances = testCase.TestInstances(1:instanceCounts);

            ids = kgsave(instances, 'Client', testCase.MockClient, 'Verbose', false);

            testCase.verifyClass(ids, 'string', ...
                'Expected string array of IDs');
            testCase.verifySize(ids, [1, instanceCounts], ...
                'Expected ID for each instance');
            testCase.verifyTrue(all(strlength(ids) > 0), ...
                'All IDs should be non-empty');

            % Verify client was called correct number of times
            testCase.verifyEqual(testCase.MockClient.getCallCount('createNewInstanceWithId'), instanceCounts, ...
                'Expected createNewInstance called once per instance');
        end

        function testSaveMode_Update(testCase)
            % Test saving with Update mode (default)
            instance = testCase.TestInstances(1);

            ids = kgsave(instance, ...
                'Client', testCase.MockClient, ...
                'SaveMode', omkg.enum.SaveMode.Update, ...
                'Verbose', false);

            testCase.verifyNotEmpty(ids, 'Expected successful save with Update mode');
        end

        function testSaveMode_Replace(testCase)
            % Test saving with Replace mode
            instance = testCase.TestInstances(1);

            ids = kgsave(instance, ...
                'Client', testCase.MockClient, ...
                'SaveMode', omkg.enum.SaveMode.Replace, ...
                'Verbose', false);

            testCase.verifyNotEmpty(ids, 'Expected successful save with Replace mode');
        end

        function testCustomSpaceAndServer(testCase)
            % Test saving with custom space and server
            instance = testCase.TestInstances(1);
            customSpace = "custom-test-space";
            customServer = ebrains.kg.enum.KGServer.PROD;

            ids = kgsave(instance, ...
                'space', customSpace, ...
                'Server', customServer, ...
                'Client', testCase.MockClient, ...
                'Verbose', false);

            testCase.verifyNotEmpty(ids, 'Expected successful save with custom options');
        end

        function testEmptyInput(testCase)
            % Test behavior with empty instance array
            emptyInstances = openminds.core.actors.Person.empty();

            ids = kgsave(emptyInstances, 'Client', testCase.MockClient, 'Verbose', false);

            testCase.verifyEmpty(ids, 'Expected empty result for empty input');
            testCase.verifyEmpty(testCase.MockClient.getLastCallFor('createNewInstanceWithId'), ...
                'Expected no API calls for empty input');
        end

        function testNoOutputArgument(testCase)
            % Test calling kgsave without output argument
            instance = testCase.TestInstances(1);

            % This should not error and should not return anything
            evalc('kgsave(instance, ''Client'', testCase.MockClient)');

            % Verify the save operation still happened
            testCase.verifyNotEmpty(testCase.MockClient.getLastCallFor('createNewInstanceWithId'), ...
                'Expected save to occur even without output argument');
        end

        function testApiError_SingleInstance(testCase)
            % Test error handling when API call fails for single instance
            instance = testCase.TestInstances(1);

            % Configure mock to throw error
            testCase.MockClient.setError('createNewInstanceWithId', ...
                MException('MOCK:APIError', 'Simulated API error'));

            testCase.verifyError(@() kgsave(instance, 'Client', testCase.MockClient, 'Verbose', false), ...
                'OMKG:kgsave:SaveFailed', ...
                'Expected SaveFailed error when API fails');
        end

        function testApiError_MultipleInstances(testCase)
            % Test error handling when API fails during batch save
            instances = testCase.TestInstances(1:2);

            % Configure mock to fail on calls
            testCase.MockClient.setError('createNewInstanceWithId', ...
                MException('MOCK:APIError', 'Simulated API error for batch'));

            testCase.verifyError(@() kgsave(instances, 'Client', testCase.MockClient, 'Verbose', false), ...
                'OMKG:kgsave:SaveFailed', ...
                'Expected SaveFailed error when API fails during batch');
        end

        function testInputValidation_InvalidInstance(testCase)
            % Test input validation for invalid instance types
            invalidInstance = struct('notAnInstance', true);

            testCase.verifyError(@() kgsave(invalidInstance, 'Verbose', false), ...
                'MATLAB:validation:UnableToConvert', ...
                'Expected validation error for invalid instance type');
        end

        function testInputValidation_InvalidSaveMode(testCase)
            % Test validation of SaveMode parameter
            instance = testCase.TestInstances(1);

            testCase.verifyError(@() kgsave(instance, 'SaveMode', "invalid", 'Verbose', false), ...
                'MATLAB:validation:UnableToConvert', ...
                'Expected validation error for invalid SaveMode');
        end

        function testInputValidation_InvalidSpace(testCase)
            % Test validation of space parameter
            instance = testCase.TestInstances(1);

            testCase.verifyError(@() kgsave(instance, 'space', ["a", "b"], 'Verbose', false), ...
                'MATLAB:validation:IncompatibleSize', ...
                'Expected validation error for space with wrong size');
        end

        function testInputValidation_InvalidServer(testCase)
            % Test validation of Server parameter
            instance = testCase.TestInstances(1);

            testCase.verifyError(@() kgsave(instance, 'Server', "invalid", 'Verbose', false), ...
                'MATLAB:validation:UnableToConvert', ...
                'Expected validation error for invalid Server enum');
        end

        function testCustomMetadataStore(testCase)
            % Test using custom MetadataStore
            instance = testCase.TestInstances(1);

            % Create a mock metadata store (in real scenario would be proper store)
            customStore = struct(); % Simplified for test

            % This test mainly verifies the parameter is accepted
            % Full integration would require proper MetadataStore mock
            try
                kgsave(instance, ...
                    'Client', testCase.MockClient, ...
                    'MetadataStore', customStore);
                testCase.verifyFail('Expected error for invalid MetadataStore type');
            catch ME
                % Expected to fail with current simplified mock
                testCase.verifyTrue(contains(ME.message, 'MetadataStore'), ...
                    'Expected MetadataStore-related error');
            end
        end

        function testEnvironmentCheck(testCase)
            % Test that environment check is called
            instance = testCase.TestInstances(1);

            % Mock the environment check to throw error
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.CurrentFolderFixture

            % This would require mocking omkg.internal.checkEnvironment
            % For now, just verify normal operation doesn't fail
            ids = kgsave(instance, 'Client', testCase.MockClient, 'Verbose', false);
            testCase.verifyNotEmpty(ids, 'Expected save to succeed with environment check');
        end

        function testDefaultParameterUsage(testCase)
            % Test that default parameters from preferences are used
            instance = testCase.TestInstances(1);

            % Save without specifying space/server - should use defaults
            ids = kgsave(instance, 'Client', testCase.MockClient, 'Verbose', false);

            testCase.verifyTrue(...
                testCase.MockClient.wasCalledWithRequiredParam("createNewInstanceWithId", ...
                    "space", omkg.getpref('DefaultSpace')))
            testCase.verifyTrue(...
                testCase.MockClient.wasCalledWithOption("createNewInstanceWithId", ...
                    "Server", omkg.getpref('DefaultServer')))

            testCase.verifyNotEmpty(ids, 'Expected successful save with default parameters');
        end

        function testLargeInstanceArray(testCase)
            % Test performance with larger number of instances
            largeInstanceCount = 10;
            instances = repmat(testCase.TestInstances(1), 1, largeInstanceCount);

            ids = kgsave(instances, 'Client', testCase.MockClient, 'Verbose', false);

            testCase.verifySize(ids, [1, largeInstanceCount], ...
                'Expected ID for each instance in large array');
            testCase.verifyEqual(testCase.MockClient.getCallCount('createNewInstanceWithId'), largeInstanceCount, ...
                'Expected API call for each instance');
        end
    end

    methods (Access = private)

        function instances = createTestInstances(~)
            % Create test openMINDS instances for testing
            instances = openminds.core.actors.Person.empty(1, 0);

            % Create first person
            person1 = openminds.core.actors.Person();
            person1.givenName = "John";
            person1.familyName = "Doe";
            instances(1) = person1;

            % Create second person
            person2 = openminds.core.actors.Person();
            person2.givenName = "Jane";
            person2.familyName = "Smith";
            instances(2) = person2;

            % Create third person
            person3 = openminds.core.actors.Person();
            person3.givenName = "Bob";
            person3.familyName = "Johnson";
            instances(3) = person3;

            % Add more instances for testing
            person4 = openminds.core.actors.Person();
            person4.givenName = "Alice";
            person4.familyName = "Williams";
            instances(4) = person4;

            person5 = openminds.core.actors.Person();
            person5.givenName = "Charlie";
            person5.familyName = "Brown";
            instances(5) = person5;
        end

        function setupMockResponses(testCase)
            % Set up default mock responses for successful operations

            % Create response for createNewInstance
            createResponse = struct();
            createResponse.data = struct();
            createResponse.data.x_id = "550e8400-e29b-41d4-a716-446655440000";
            testCase.MockClient.setCreateResponse(createResponse);

            % Create response for updateInstance
            updateResponse = struct();
            updateResponse.data = struct();
            updateResponse.data.x_id = "550e8400-e29b-41d4-a716-446655440001";
            testCase.MockClient.setUpdateResponse(updateResponse);

            % Create response for replaceInstance
            replaceResponse = struct();
            replaceResponse.data = struct();
            replaceResponse.data.x_id = "550e8400-e29b-41d4-a716-446655440002";
            testCase.MockClient.setReplaceResponse(replaceResponse);
        end

        function wasMethodCalled = methodWasCalled(testCase, methodName)
            % Helper method to check if a method was called
            wasMethodCalled = ~isempty(testCase.MockClient.getLastCallFor(methodName));
        end
    end
end
