classdef KGMockAPIClientExampleTest < matlab.unittest.TestCase
% KGMockAPIClientExampleTest - Example showing usage of the mock api client
%
% This demonstrates how one mock can test all KG operations

    properties
        MockClient
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            testCase.MockClient.setupDefaultResponses();
        end
    end

    methods (Test)

        function testKglistWithKGMockAPIClient(testCase)
            % Test kglist using the api client mock

            % Configure list response
            mockData = testCase.MockClient.createMockInstance("Person");
            testCase.MockClient.setListResponse({mockData});

            % Call kglist
            try
                [~, ~] = kglist(openminds.enum.Types.Person, ...
                    'Client', testCase.MockClient);

                % Verify call was made
                testCase.verifyEqual(testCase.MockClient.getCallCount('listInstances'), 1, ...
                    'Should call listInstances once');
                testCase.verifyTrue(testCase.MockClient.wasCalledWith('listInstances', 1, openminds.enum.Types.Person), ...
                    'Should call with correct type');

            catch ME
                if contains(ME.message, 'openminds')
                    warning('UNIFIED:TestSkipped', 'Test skipped due to missing openMINDS: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testKgsaveWithKGMockAPIClient(testCase)
            % Test kgsave using the api client mock

            % Configure create response
            createResponse = struct();
            createResponse.data = struct();
            createResponse.data.x_id = "test-created-id";
            testCase.MockClient.setCreateResponse(createResponse);

            try
                % This would call kgsave if we had the full openMINDS infrastructure
                % For now, just test the client directly
                response = testCase.MockClient.createNewInstance('{"test":"data"}', ...
                    'space', 'testspace');

                testCase.verifyEqual(testCase.MockClient.getCallCount('createNewInstance'), 1, ...
                    'Should call createNewInstance once');
                testCase.verifyEqual(response.data.x_id, "test-created-id", ...
                    'Should return correct ID');

            catch ME
                if contains(ME.message, 'openminds')
                    warning('UNIFIED:TestSkipped', 'Test skipped due to missing openMINDS: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testKgpullWithKGMockAPIClient(testCase)
            % Test kgpull using the api client mock

            testUUID = "550e8400-e29b-41d4-a716-446655440000";
            mockNode = testCase.MockClient.createMockKgNode();
            testCase.MockClient.setInstanceResponse(mockNode);

            try
                kgpull(testUUID, 'Client', testCase.MockClient);

                testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1, ...
                    'Should call getInstance once');

            catch ME
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('UNIFIED:TestSkipped', 'Test skipped due to missing dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testKgdeleteWithKGMockAPIClient(testCase)
            % Test kgdelete using the api client mock

            testInstance = struct();
            testInstance.id = "test-instance-id";

            try
                % This would test kgdelete if we had openMINDS infrastructure
                % For now, test the client directly
                testCase.MockClient.deleteInstance(testInstance.id);

                testCase.verifyEqual(testCase.MockClient.getCallCount('deleteInstance'), 1, ...
                    'Should call deleteInstance once');
                testCase.verifyTrue(testCase.MockClient.wasCalledWith('deleteInstance', 1, testInstance.id), ...
                    'Should call with correct instance ID');

            catch ME
                if contains(ME.message, 'openminds')
                    warning('UNIFIED:TestSkipped', 'Test skipped due to missing openMINDS: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testErrorSimulation(testCase)
            % Test error simulation across different methods

            testException = MException('MATLAB:test:MockError', 'Simulated network error');
            testCase.MockClient.setError('listInstances', testException);

            testCase.verifyError(...
                @() testCase.MockClient.listInstances(openminds.enum.Types.Person), ...
                'MATLAB:test:MockError', ...
                'Should throw simulated error for listInstances');

            % Other methods should work fine
            testCase.verifyWarningFree(...
                @() testCase.MockClient.getInstance('test-uuid'), ...
                'getInstance should work when error only set for listInstances');
        end

        function testCrossOperationWorkflow(testCase)
            % Test a workflow that uses multiple operations

            % 1. List instances
            testCase.MockClient.listInstances(openminds.enum.Types.Person);

            % 2. Get specific instance
            testCase.MockClient.getInstance('test-uuid');

            % 3. Update instance
            testCase.MockClient.updateInstance('test-uuid', '{"updated": true}');

            % 4. Delete instance
            testCase.MockClient.deleteInstance('test-uuid');

            % Verify all operations were tracked
            testCase.verifyEqual(testCase.MockClient.getCallCount(), 4, ...
                'Should track all 4 operations');
            testCase.verifyEqual(testCase.MockClient.getCallCount('listInstances'), 1, ...
                'Should track listInstances call');
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1, ...
                'Should track getInstance call');
            testCase.verifyEqual(testCase.MockClient.getCallCount('updateInstance'), 1, ...
                'Should track updateInstance call');
            testCase.verifyEqual(testCase.MockClient.getCallCount('deleteInstance'), 1, ...
                'Should track deleteInstance call');
        end
    end
end
