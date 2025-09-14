classdef KglistTest < matlab.unittest.TestCase
% KglistTest - Unit tests for the kglist function
%
% This test class covers:
% - Basic functionality with different types
% - Filter property validation and usage
% - Pagination functionality
% - Error handling for invalid inputs
% - Edge cases (empty responses, single instances)

    properties (TestParameter)
        % Test with different openMINDS types (assuming these exist)
        validTypes = {openminds.enum.Types.Person, openminds.enum.Types.Dataset}
        paginationSizes = {uint64(5), uint64(10), uint64(50)}
    end
    
    properties
        MockClient
        OriginalCheckEnvironment
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            % Create a mock client for testing
            testCase.MockClient = testCase.createMockClient();
        end
    end
    
    methods (Test)
        
        function testBasicListInstances(testCase)
            % Test basic instance listing functionality
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockResponse = struct('data', {{}}, 'total', 0);
            % todo: finish this
        end
        
        function testFilterPropertyValidation(testCase)
            % Test that invalid filter properties are rejected
            type = openminds.enum.Types.Person;
            
            % This should throw an error for invalid property
            testCase.verifyError(...
                @() kglist(type, 'filterProperty', 'invalidProperty', 'filterValue', 'test'), ...
                "OMKG:kglist:validator:InvalidPropertyName");
        end
        
        function testFilterPropertyWithoutValue(testCase)
            % Test that providing filterProperty without filterValue throws error
            type = openminds.enum.Types.Person;
            validProperty = omkg.test.api.KglistTest.getValidPropertyForType(type);
            
            testCase.verifyError(...
                @() kglist(type, 'filterProperty', validProperty, 'Client', testCase.MockClient), ...
                "OMKG:kglist:validator:FilterValueMissing");
        end
        
        function testFilterPropertyWithValue(testCase)
            % Test filtering with valid property and value
            type = openminds.enum.Types.Person;
            validProperty = omkg.test.api.KglistTest.getValidPropertyForType(type);
            
            [instances, ~] = kglist(type, ...
                'filterProperty', validProperty, ...
                'filterValue', 'testValue', ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(instances, 'Should return filtered instances');
            
            % Verify that the client was called with the correct filter
            expectedProperty = sprintf("%s%s", openminds.constant.PropertyIRIPrefix, validProperty);
            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'filterProperty', expectedProperty));
            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'filterValue', 'testValue'));
        end
        
        function testPaginationWithFromAndSize(testCase)
            % Test pagination functionality
            type = openminds.enum.Types.Person;
            fromValue = uint64(10);
            sizeValue = uint64(5);
            
            [instances, pager] = kglist(type, ...
                'from', fromValue, ...
                'size', sizeValue, ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(instances, 'Should return instances');
            testCase.verifyClass(pager, 'function_handle', 'Should return pager function');
            
            % Test that pager function works
            nextPageInstances = pager();
            testCase.verifyNotEmpty(nextPageInstances, 'Pager should return next page');
        end
        
        function testPaginationWithoutFrom(testCase)
            % Test that pager returns empty function when 'from' is not specified
            type = openminds.enum.Types.Person;
            
            [~, pager] = kglist(type, 'size', uint64(10), 'Client', testCase.MockClient);
            
            result = pager();
            testCase.verifyEmpty(result, 'Pager should return empty when from is not specified');
        end
        
        function testEmptyResponse(testCase)
            % Test handling of empty response from API
            type = openminds.enum.Types.Person;
            emptyClient = omkg.test.api.KglistTest.createMockClientWithEmptyResponse();
            
            [instances, pager] = kglist(type, 'Client', emptyClient);
            
            testCase.verifyEmpty(instances, 'Should return empty array for empty response');
            testCase.verifyClass(pager, 'function_handle', 'Should still return pager function');
        end
        
        function testSingleInstanceResponse(testCase)
            % Test handling when API returns single instance (not cell array)
            type = openminds.enum.Types.Person;
            singleClient = omkg.test.api.KglistTest.createMockClientWithSingleResponse();
            
            [instances, ~] = kglist(type, 'Client', singleClient);
            
            testCase.verifyNumElements(instances, 1, 'Should return single instance');
            testCase.verifyClass(instances, type.ClassName, 'Should be correct type');
        end
        
        function testMultipleInstancesResponse(testCase)
            % Test handling of multiple instances
            type = openminds.enum.Types.Person;
            multiClient = omkg.test.api.KglistTest.createMockClientWithMultipleResponse(3);
            
            [instances, ~] = kglist(type, 'Client', multiClient);
            
            testCase.verifyNumElements(instances, 3, 'Should return three instances');
            testCase.verifyClass(instances, type.ClassName, 'Should be correct type');
        end
        
        function testParameterizedTypes(testCase, validTypes)
            % Parameterized test for different valid types
            % Create type-specific mock client for this test
            typeSpecificClient = omkg.test.api.KglistTest.createMockClientForType(validTypes);
            
            [instances, pager] = kglist(validTypes, 'Client', typeSpecificClient);
            
            testCase.verifyNotEmpty(instances, 'Should return instances for any valid type');
            testCase.verifyClass(pager, 'function_handle', 'Should return pager function');
            testCase.verifyClass(instances, validTypes.ClassName, 'Should match expected type');
        end
        
        function testParameterizedPagination(testCase, paginationSizes)
            % Parameterized test for different pagination sizes
            type = openminds.enum.Types.Person;
            
            [instances, pager] = kglist(type, ...
                'from', uint64(0), ...
                'size', paginationSizes, ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(instances, 'Should return instances');
            testCase.verifyClass(pager, 'function_handle', 'Should return pager function');
        end
    end
    
    methods (Static)
        
        function mockClient = createMockClient()
            % Create a mock client that simulates the InstancesClient behavior
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            
            % Configure default behavior - return sample data
            sampleData = omkg.test.api.KglistTest.createSampleKgData(2);
            mockClient.setListResponse(sampleData);
        end
        
        function mockClient = createMockClientForType(type)
            % Create a mock client that returns data for specific type
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            
            % Create type-specific sample data
            sampleData = omkg.test.api.KglistTest.createSampleKgDataForType(type, 2);
            mockClient.setListResponse(sampleData);
        end
        
        function mockClient = createMockClientWithEmptyResponse()
            % Create mock client that returns empty data
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListResponse([]);
        end
        
        function mockClient = createMockClientWithSingleResponse()
            % Create mock client that returns single instance
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            sampleData = omkg.test.api.KglistTest.createSampleKgData(1);
            mockClient.setListResponse(sampleData{1}); % Return struct, not cell
        end
        
        function mockClient = createMockClientWithMultipleResponse(numInstances)
            % Create mock client that returns specified number of instances
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            sampleData = omkg.test.api.KglistTest.createSampleKgData(numInstances);
            mockClient.setListResponse(sampleData);
        end
        
        function sampleData = createSampleKgData(numInstances)
            % Create sample KG data for testing (Person type by default)
            sampleData = omkg.test.api.KglistTest.createSampleKgDataForType(openminds.enum.Types.Person, numInstances);
        end
        
        function sampleData = createSampleKgDataForType(type, numInstances)
            % Create sample KG data for specific type
            sampleData = cell(1, numInstances);
            
            % Get type-specific information
            typeInfo = omkg.test.api.KglistTest.getTypeInfo(type);
            
            for i = 1:numInstances
                sampleData{i} = struct(...
                    'x_id', sprintf('test-%s-id-%d', lower(typeInfo.name), i), ...
                    'x_type', typeInfo.iri, ...
                    typeInfo.sampleFields{:});
            end
        end
        
        function typeInfo = getTypeInfo(type)
            % Get type-specific information for creating mock data
            switch type
                case openminds.enum.Types.Person
                    typeInfo = struct(...
                        'name', 'person', ...
                        'iri', 'https://openminds.ebrains.eu/core/Person', ...
                        'sampleFields', {{'givenName', sprintf('TestPerson%d', randi(100)), ...
                                        'familyName', 'TestFamily'}});
                case openminds.enum.Types.Dataset
                    typeInfo = struct(...
                        'name', 'dataset', ...
                        'iri', 'https://openminds.ebrains.eu/core/Dataset', ...
                        'sampleFields', {{'fullName', sprintf('TestDataset%d', randi(100)), ...
                                        'description', 'A test dataset for unit testing'}});
                otherwise
                    % Todo: this is invalid
                    % Fallback for unknown types
                    typeInfo = struct(...
                        'name', 'unknown', ...
                        'iri', sprintf('https://openminds.ebrains.eu/core/%s', type.ClassName), ...
                        'sampleFields', {{'name', sprintf('Test%s%d', type.ClassName, randi(100))}});
            end
        end
        
        function validProperty = getValidPropertyForType(type)
            % Get a valid property name for the given type
            % This is a helper to avoid hardcoding property names
            instanceProps = properties(feval(type.ClassName));
            if ~isempty(instanceProps)
                validProperty = string(instanceProps{1});
            else
                validProperty = "givenName"; % Fallback
            end
        end
    end
end
