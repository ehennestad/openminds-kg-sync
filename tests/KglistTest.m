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
            testCase.MockClient = KglistTest.createMockClient();
        end
    end
    
    methods (Test)
        
        function testBasicListing(testCase)
            % Test basic listing without any filters
            type = openminds.enum.Types.Person;
            
            [instances, pager] = kglist(type, 'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(instances, 'Should return non-empty instances');
            testCase.verifyClass(pager, 'function_handle', 'Should return a pager function');
            testCase.verifyClass(instances, type.ClassName, 'Should return instances of correct type');
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
            validProperty = KglistTest.getValidPropertyForType(type);
            
            testCase.verifyError(...
                @() kglist(type, 'filterProperty', validProperty, 'Client', testCase.MockClient), ...
                "OMKG:kglist:validator:FilterValueMissing");
        end
        
        function testFilterPropertyWithValue(testCase)
            % Test filtering with valid property and value
            type = openminds.enum.Types.Person;
            validProperty = KglistTest.getValidPropertyForType(type);
            
            [instances, ~] = kglist(type, ...
                'filterProperty', validProperty, ...
                'filterValue', 'testValue', ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(instances, 'Should return filtered instances');
            
            % Verify that the client was called with the correct filter
            expectedProperty = sprintf("%s%s", openminds.constant.PropertyIRIPrefix, validProperty);
            testCase.verifyTrue(testCase.MockClient.wasCalledWith('listInstances', 'filterProperty', expectedProperty));
            testCase.verifyTrue(testCase.MockClient.wasCalledWith('listInstances', 'filterValue', 'testValue'));
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
            emptyClient = KglistTest.createMockClientWithEmptyResponse();
            
            [instances, pager] = kglist(type, 'Client', emptyClient);
            
            testCase.verifyEmpty(instances, 'Should return empty array for empty response');
            testCase.verifyClass(pager, 'function_handle', 'Should still return pager function');
        end
        
        function testSingleInstanceResponse(testCase)
            % Test handling when API returns single instance (not cell array)
            type = openminds.enum.Types.Person;
            singleClient = KglistTest.createMockClientWithSingleResponse();
            
            [instances, ~] = kglist(type, 'Client', singleClient);
            
            testCase.verifyNumElements(instances, 1, 'Should return single instance');
            testCase.verifyClass(instances, type.ClassName, 'Should be correct type');
        end
        
        function testMultipleInstancesResponse(testCase)
            % Test handling of multiple instances
            type = openminds.enum.Types.Person;
            multiClient = KglistTest.createMockClientWithMultipleResponse(3);
            
            [instances, ~] = kglist(type, 'Client', multiClient);
            
            testCase.verifyNumElements(instances, 3, 'Should return three instances');
            testCase.verifyClass(instances, type.ClassName, 'Should be correct type');
        end
        
        function testParameterizedTypes(testCase, validTypes)
            % Parameterized test for different valid types
            [instances, pager] = kglist(validTypes, 'Client', testCase.MockClient);
            
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
            mockClient = MockInstancesClient();
            
            % Configure default behavior - return sample data
            sampleData = KglistTest.createSampleKgData(2);
            mockClient.setResponse(sampleData);
        end
        
        function mockClient = createMockClientWithEmptyResponse()
            % Create mock client that returns empty data
            mockClient = MockInstancesClient();
            mockClient.setResponse([]);
        end
        
        function mockClient = createMockClientWithSingleResponse()
            % Create mock client that returns single instance
            mockClient = MockInstancesClient();
            sampleData = KglistTest.createSampleKgData(1);
            mockClient.setResponse(sampleData{1}); % Return struct, not cell
        end
        
        function mockClient = createMockClientWithMultipleResponse(numInstances)
            % Create mock client that returns specified number of instances
            mockClient = MockInstancesClient();
            sampleData = KglistTest.createSampleKgData(numInstances);
            mockClient.setResponse(sampleData);
        end
        
        function sampleData = createSampleKgData(numInstances)
            % Create sample KG data for testing
            sampleData = cell(1, numInstances);
            for i = 1:numInstances
                sampleData{i} = struct(...
                    'x_id', sprintf('test-id-%d', i), ...
                    'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                    'givenName', sprintf('TestPerson%d', i), ...
                    'familyName', 'TestFamily');
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
