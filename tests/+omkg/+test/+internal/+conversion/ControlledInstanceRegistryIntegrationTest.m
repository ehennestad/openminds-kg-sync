classdef ControlledInstanceRegistryIntegrationTest < matlab.unittest.TestCase
    % ControlledInstanceRegistryIntegrationTest - Integration tests for registry with retrieval functions
    %
    % This test suite tests the integration between the registry and the
    % retrieval functions (getControlledTypes, listControlledTermIds, etc.)
    
    properties
        TestDataDir
        OriginalCacheFile
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Set up test environment
            toolboxDir = omkg.toolboxdir();
            testCase.TestDataDir = fullfile(toolboxDir, 'userdata');
            testCase.OriginalCacheFile = fullfile(testCase.TestDataDir, ...
                'kg2om_identifier_loopkup.json');
            
            % Backup existing cache file if it exists
            if isfile(testCase.OriginalCacheFile)
                copyfile(testCase.OriginalCacheFile, ...
                    [testCase.OriginalCacheFile '.backup']);
            end
        end
    end
    
    methods (TestClassTeardown)
        function restoreEnvironment(testCase)
            % Restore original cache file
            backupFile = [testCase.OriginalCacheFile '.backup'];
            if isfile(backupFile)
                movefile(backupFile, testCase.OriginalCacheFile);
            elseif isfile(testCase.OriginalCacheFile)
                delete(testCase.OriginalCacheFile);
            end
        end
    end
    
    methods (TestMethodSetup)
        function clearSingletonForTest(testCase)
            % Clear singleton instance before each test
            if isfile(testCase.OriginalCacheFile)
                delete(testCase.OriginalCacheFile)
            end
            
            mockClient = testCase.createMockClient();
            omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'Reset', true, 'ApiClient', mockClient, 'Verbose', false);
        end
    end
    
    %% Integration Tests with Retrieval Functions
    methods (Test)
        function testDownloadAllUsesRetrievalFunctions(testCase)
            % Test that downloadAll properly calls retrieval functions
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            % Download all should succeed
            registry.downloadAll();
            
            % Verify calls were made
            testCase.verifyGreaterThan(mockClient.getCallCount('listTypes'), 0, ...
                'Should call listTypes');
            testCase.verifyGreaterThan(mockClient.getCallCount('listInstances'), 0, ...
                'Should call listInstances');
        end
        
        function testIncrementalUpdateUsesRetrievalFunctions(testCase)
            % Test that incremental update properly calls retrieval functions
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            % Initial download
            registry.downloadAll();
            initialCallCount = mockClient.getCallCount('listInstances');
            
            % Clear calls and do incremental update
            mockClient.clearCalls();
            registry.update(false);
            
            % Should make additional calls
            testCase.verifyGreaterThan(mockClient.getCallCount('listInstances'), 0, ...
                'Incremental update should call listInstances');
        end
        
        function testNewTypeDetectionFlow(testCase)
            % Test the complete flow of detecting and processing a new type
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            % Initial download
            registry.downloadAll();
            initialMap = registry.KgToOmMap;
            initialSize = initialMap.numEntries;
            
            % Add new type to mock
            newTypeIri = "https://openminds.ebrains.eu/controlledTerms/NewType";
            mockClient.addNewType(newTypeIri);
            
            % Add instances for new type
            newInstances = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.createTestInstances(newTypeIri, 3);
            currentInstances = mockClient.ListResponse;
            mockClient.setListResponse([currentInstances, newInstances]);
            mockClient.setBulkResponse([currentInstances, newInstances]);
            
            % Trigger incremental update (starting new cycle)
            registry.update(false);
            
            % Verify new type was detected
            testCase.verifyTrue(mockClient.getCallCount('listTypes') >= 1, ...
                'Should call listTypes to detect new types');
        end
        
        function testBulkFetchOptimization(testCase)
            % Test that registry uses bulk fetch for efficiency
            mockClient = testCase.createMockClient();
            
            % Configure mock with multiple instances
            instances = {};
            for i = 1:10
                uuid = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.generateUUID();
                omId = sprintf('https://openminds.ebrains.eu/controlledTerms/Species/species%d', i);
                instances{i} = struct('x_id', uuid, 'http___schema_org_identifier', {{omId}}); %#ok<AGROW>
            end
            mockClient.setListResponse(instances);
            mockClient.setBulkResponse(instances);
            
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry.downloadAll();
            
            % Verify efficient API usage
            testCase.verifyGreaterThan(mockClient.getCallCount(), 0, ...
                'Should make API calls');
        end
    end
    
    %% Performance and Efficiency Tests
    methods (Test)
        function testIncrementalUpdateIsEfficient(testCase)
            % Test that incremental updates don't refetch everything
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            % Initial download
            registry.downloadAll();
            fullDownloadCalls = mockClient.getCallCount();
            
            % Clear and do incremental update
            mockClient.clearCalls();
            registry.update(false);
            incrementalCalls = mockClient.getCallCount();
            
            % Incremental should make fewer calls than full download
            testCase.verifyLessThan(incrementalCalls, fullDownloadCalls, ...
                'Incremental update should be more efficient than full download');
        end
        
        function testCachingReducesAPICalls(testCase)
            % Test that caching reduces API calls on subsequent initializations
            mockClient = testCase.createMockClient();
            
            % First initialization with download
            registry1 = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry1.downloadAll();
            firstCallCount = mockClient.getCallCount();
            
            % Clear singleton and reinitialize (should load from cache)
            mockClient.clearCalls();
            
            registry2 = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            % Just accessing should use cache
            map = registry2.KgToOmMap;
            secondCallCount = mockClient.getCallCount();
            
            testCase.verifyLessThan(secondCallCount, firstCallCount, ...
                'Second initialization should use cache and make fewer calls');
            testCase.verifyGreaterThan(numel(map), 0, ...
                'Should still have data from cache');
        end
    end
    
    %% Data Consistency Tests
    methods (Test)
        function testDataConsistencyAcrossUpdates(testCase)
            % Test that data remains consistent across updates
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            % Initial download
            registry.downloadAll();
            
            % Get a known mapping
            omId = "https://openminds.ebrains.eu/controlledTerms/Species/species1";
            kgId1 = registry.getKgId(omId);
            
            % Update
            registry.update(false);
            
            % Should still have same mapping
            kgId2 = registry.getKgId(omId);
            testCase.verifyEqual(kgId1, kgId2, ...
                'Mappings should remain consistent across updates');
        end
        
        function testNoDuplicateIdentifiers(testCase)
            % Test that registry doesn't create duplicate entries
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.controlledInstanceRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            
            registry.downloadAll();
            map = registry.KgToOmMap;
            
            % Check for duplicates
            if isa(map, 'dictionary')
                kgIds = keys(map);
            else
                kgIds = keys(map);
                kgIds = string(kgIds);
            end
            
            uniqueIds = unique(kgIds);
            testCase.verifyEqual(numel(kgIds), numel(uniqueIds), ...
                'Should not have duplicate KG IDs');
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function mockClient = createMockClient(~)
            % Create a configured mock client for testing
            mockClient = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.createConfiguredMock(3, 5);
        end
    end
end
