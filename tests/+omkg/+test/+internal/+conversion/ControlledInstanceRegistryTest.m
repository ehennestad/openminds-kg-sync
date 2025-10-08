classdef ControlledInstanceRegistryTest < matlab.unittest.TestCase
    % ControlledInstanceRegistryTest - Unit tests for controlledInstanceRegistry
    %
    % This test class demonstrates how to test the registry without
    % connecting to the EBRAINS Knowledge Graph by using a mock API client.
    
    methods (Test)
        function testSingletonPattern(testCase)
            % Test that instance() returns the same object
            registry1 = omkg.internal.conversion.controlledInstanceRegistry.instance();
            registry2 = omkg.internal.conversion.controlledInstanceRegistry.instance();
            
            testCase.verifyEqual(registry1, registry2, ...
                'Singleton should return the same instance');
        end
        
        function testGetKgIdWithMockData(testCase)
            % Test ID lookup with mock API client
            
            % Create mock API client
            mockClient = omkg.test.helper.mock.MockKgApiClient();
            
            % Inject mock client
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(mockClient);
            
            % Test lookup (assumes mock returns known test data)
            % You would need to implement MockKgApiClient with test data
            omId = "https://openminds.ebrains.eu/controlledTerms/TestTerm";
            
            % This test would pass if MockKgApiClient returns appropriate test data
            % kgId = registry.getKgId(omId);
            % testCase.verifyNotEqual(kgId, "", 'Should return a KG ID');
        end
        
        function testGetOpenMindsIdWithMockData(testCase)
            % Test reverse lookup with mock API client
            
            mockClient = omkg.test.helper.mock.MockKgApiClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(mockClient);
            
            % Test reverse lookup
            % kgId = "test-uuid-123";
            % omId = registry.getOpenMindsId(kgId);
            % testCase.verifyNotEqual(omId, "", 'Should return an openMINDS ID');
        end
        
        function testNeedsUpdate(testCase)
            % Test update timing logic
            
            mockClient = omkg.test.helper.mock.MockKgApiClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(mockClient);
            
            % After a fresh download, should not need update immediately
            % This depends on implementation details
            needsUpdate = registry.needsUpdate();
            testCase.verifyTrue(islogical(needsUpdate), ...
                'needsUpdate should return a logical value');
        end
    end
end
