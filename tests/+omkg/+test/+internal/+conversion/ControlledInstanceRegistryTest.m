classdef ControlledInstanceRegistryTest < matlab.unittest.TestCase
    % ControlledInstanceRegistryTest - Comprehensive unit tests for ControlledInstanceIdentifierRegistry
    %
    % This test suite uses mock API clients to test all registry functionality
    % without requiring connection to the EBRAINS Knowledge Graph.
    %
    % Test Coverage:
    %   - Singleton pattern behavior
    %   - Identifier lookup methods (bidirectional)
    %   - Mapping retrieval and consistency
    %   - Update mechanisms (full and incremental)
    %   - Cache persistence and loading
    %   - API interaction patterns
    %   - Performance and efficiency
    %   - Data consistency
    %   - Error handling

    properties (TestParameter)
        % Test data for parameterized tests
        validKgIds = {"123e4567-e89b-12d3-a456-426614174000", ...
                      "987e6543-e21b-45c3-d654-321456987000"}
        validOmIds = {"https://openminds.ebrains.eu/controlledTerms/Species1", ...
                      "https://openminds.ebrains.eu/controlledTerms/Technique2"}
    end

    properties
        TestDataDir
        OriginalCacheFile
        OriginalSeedFile
    end

    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Set up test environment - backup existing cache if present
            toolboxDir = omkg.toolboxdir();
            testCase.TestDataDir = fullfile(toolboxDir, 'userdata');
            testCase.OriginalCacheFile = fullfile(testCase.TestDataDir, ...
                'kg2om_identifier_loopkup.json');
            testCase.OriginalSeedFile = fullfile(toolboxDir, ...
                'omkg', '+omkg', '+internal', 'resources', ...
                'kg2om_identifier_loopkup.json');
            % Backup existing cache file if it exists
            if isfile(testCase.OriginalCacheFile)
                copyfile(testCase.OriginalCacheFile, ...
                    [testCase.OriginalCacheFile '.backup']);
            end

            if isfile(testCase.OriginalSeedFile)
                movefile(testCase.OriginalSeedFile, ...
                    [testCase.OriginalSeedFile '.backup']);
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
                % Clean up test cache if no backup existed
                delete(testCase.OriginalCacheFile);
            end

            backupFile = [testCase.OriginalSeedFile '.backup'];
            if isfile(backupFile)
                movefile(backupFile, testCase.OriginalSeedFile);
            end
        end
    end

    methods (TestMethodSetup)
        function clearSingletonForTest(testCase)
            % Clear singleton instance before each test
            % This ensures each test starts with a fresh registry
            if isfile(testCase.OriginalCacheFile)
                delete(testCase.OriginalCacheFile)
            end

            mockClient = testCase.createMockClient();

            omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'ApiClient', mockClient, 'Verbose', false);
        end
    end

    %% Singleton Pattern Tests
    methods (Test)
        function testSingletonPattern(testCase)
            % Test that instance() returns the same object
            mockClient = testCase.createMockClient();

            registry1 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance("ApiClient", mockClient, 'Verbose', false);
            registry2 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance();

            testCase.verifyEqual(registry1, registry2, ...
                'Singleton should return the same instance');
        end

        function testSingletonPersistsAcrossCalls(testCase)
            % Test that singleton persists even without explicit storage
            mockClient = testCase.createMockClient();

            registry1 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);
            kgId1 = registry1.getKgId("https://openminds.ebrains.eu/controlledTerms/Species");

            % Get instance again without storing
            kgId2 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance().getKgId(...
                "https://openminds.ebrains.eu/controlledTerms/Species");

            testCase.verifyEqual(kgId1, kgId2, ...
                'Singleton should maintain state across calls');
        end
    end

    %% Lookup Methods Tests
    methods (Test)
        function testGetKgIdFound(testCase)
            % Test successful KG ID lookup
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            omId = "https://openminds.ebrains.eu/controlledTerms/Species";
            kgId = registry.getKgId(omId);

            testCase.verifyNotEqual(kgId, "", 'Should return a valid KG ID');
            testCase.verifyTrue(strlength(kgId) > 0, 'KG ID should not be empty');
        end

        function testGetKgIdNotFound(testCase)
            % Test KG ID lookup for non-existent openMINDS ID
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            omId = "https://openminds.ebrains.eu/controlledTerms/NonExistent";

            testCase.verifyError(...
                @() registry.getKgId(omId), ...
                'OMKG:ControlledInstanceRegistry:IdNotFound')
        end

        function testGetOpenMindsIdFound(testCase)
            % Test successful openMINDS ID lookup
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            % Get a known KG ID from the mock data
            testKgId = "550e8400-e29b-41d4-a716-446655440000";
            omId = registry.getOpenMindsId(testKgId);

            testCase.verifyNotEqual(omId, "", 'Should return a valid openMINDS ID');
            testCase.verifyTrue(startsWith(omId, "https://openminds.ebrains.eu/"), ...
                'Should be a valid openMINDS identifier');
        end

        function testGetOpenMindsIdNotFound(testCase)
            % Test openMINDS ID lookup for non-existent KG ID
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            kgId = "00000000-0000-0000-0000-000000000000";
            testCase.verifyError(...
                @() registry.getOpenMindsId(kgId), ...
                'OMKG:ControlledInstanceRegistry:IdNotFound')
        end

        function testBidirectionalLookup(testCase)
            % Test that lookups are bidirectional
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            omId = "https://openminds.ebrains.eu/controlledTerms/Species";
            kgId = registry.getKgId(omId);
            omIdReverse = registry.getOpenMindsId(kgId);

            testCase.verifyEqual(omIdReverse, omId, ...
                'Bidirectional lookup should return original ID');
        end
    end

    %% Mapping Tests
    methods (Test)
        function testGetMappingDefault(testCase)
            % Test getting mapping in default direction (KG -> openMINDS)
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            map = registry.KgToOmMap;

            testCase.verifyTrue(isa(map, 'dictionary') || isa(map, 'containers.Map'), ...
                'Should return dictionary or containers.Map');
            testCase.verifyGreaterThan(getMapCount(map), 0, ...
                'Map should contain entries');
        end

        function testGetMappingReverse(testCase)
            % Test getting mapping in reverse direction (openMINDS -> KG)
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            map = registry.OmToKgMap;

            testCase.verifyTrue(isa(map, 'dictionary') || isa(map, 'containers.Map'), ...
                'Should return dictionary or containers.Map');
            testCase.verifyGreaterThan(getMapCount(map), 0, ...
                'Map should contain entries');
        end

        function testMappingConsistency(testCase)
            % Test that forward and reverse mappings are consistent
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            forwardMap = registry.KgToOmMap;
            reverseMap = registry.OmToKgMap;

            % Both should have the same number of entries
            testCase.verifyEqual(numel(forwardMap), numel(reverseMap), ...
                'Forward and reverse maps should have same number of entries');
        end
    end

    %% Update and Download Tests
    methods (Test)
        function testNeedsUpdateAfterFreshDownload(testCase)
            % Test that needsUpdate returns false after fresh download
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Verbose', false);

            % Simulate fresh download by calling downloadAll
            registry.downloadAll();

            testCase.verifyFalse(registry.needsUpdate(), ...
                'Should not need update immediately after download');
        end

        function testDownloadAllUsesRetrievalFunctions(testCase)
            % Test that downloadAll properly calls retrieval functions
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);

            % Download all should succeed
            registry.downloadAll();

            % Verify calls were made
            testCase.verifyGreaterThan(mockClient.getCallCount('listTypes'), 0, ...
                'Should call listTypes');
            testCase.verifyGreaterThan(mockClient.getCallCount('listInstances'), 0, ...
                'Should call listInstances');
        end

        function testIncrementalUpdate(testCase)
            % Test incremental update mechanism
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance( ...
                'ApiClient', mockClient, 'Verbose', false);

            % Perform incremental update
            registry.update(false);

            % Verify registry still has data
            map = registry.KgToOmMap;
            testCase.verifyGreaterThan(getMapCount(map), 0, ...
                'Registry should have data after incremental update');
        end

        function testIncrementalUpdateIsEfficient(testCase)
            % Test that incremental updates don't refetch everything
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
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

        function testFullUpdate(testCase)
            % Test complete update mechanism
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Verbose', false);

            % Perform full update
            registry.update(true);

            % Verify registry has data
            map = registry.KgToOmMap;
            testCase.verifyGreaterThan(getMapCount(map), 0, ...
                'Registry should have data after full update');
        end

        function testNewTypeDetectionFlow(testCase)
            % Test the complete flow of detecting and processing a new type
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);

            % Initial download
            registry.downloadAll();

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

        function testDataConsistencyAcrossUpdates(testCase)
            % Test that data remains consistent across updates
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
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
    end

    %% Persistence and Caching Tests
    methods (Test)
        function testSaveToFile(testCase)
            % Test that data is saved to file
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Verbose', false);

            % Trigger download which saves
            registry.downloadAll();

            % Verify file exists
            testCase.verifyTrue(isfile(testCase.OriginalCacheFile), ...
                'Cache file should be created');
        end

        function testLoadFromFile(testCase)
            % Test that data is loaded from file
            mockClient = testCase.createMockClient();

            % First instance: create and populate
            registry1 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance( ...
                'ApiClient', mockClient, 'Verbose', false);
            registry1.downloadAll();
            omId = "https://openminds.ebrains.eu/controlledTerms/Species";
            kgId1 = registry1.getKgId(omId);

            % Clear singleton
            clear omkg.internal.conversion.ControlledInstanceIdentifierRegistry

            % Second instance: should load from file
            registry2 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance( ...
                'ApiClient', mockClient, 'Verbose', false);
            kgId2 = registry2.getKgId(omId);

            testCase.verifyEqual(kgId1, kgId2, ...
                'Loaded data should match saved data');
        end

        function testCachingReducesAPICalls(testCase)
            % Test that caching reduces API calls on subsequent initializations
            mockClient = testCase.createConfiguredMockClient();

            % First initialization with download
            registry1 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry1.downloadAll();
            firstCallCount = mockClient.getCallCount();

            % Clear singleton and reinitialize (should load from cache)
            mockClient.clearCalls();

            registry2 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            % Just accessing should use cache
            map = registry2.KgToOmMap;
            secondCallCount = mockClient.getCallCount();

            testCase.verifyLessThan(secondCallCount, firstCallCount, ...
                'Second initialization should use cache and make fewer calls');
            testCase.verifyGreaterThan(numel(map), 0, ...
                'Should still have data from cache');
        end

        function testFileFormatWithMetadata(testCase)
            % Test that file format includes metadata
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Verbose', false);
            registry.downloadAll();

            % Read and verify file format
            data = jsondecode(fileread(testCase.OriginalCacheFile));

            testCase.verifyTrue(isfield(data, 'identifiers'), ...
                'File should contain identifiers field');
            testCase.verifyTrue(isfield(data, 'lastUpdateTime'), ...
                'File should contain lastUpdateTime field');
            testCase.verifyTrue(isfield(data, 'typeUpdateOrder'), ...
                'File should contain typeUpdateOrder field');
            testCase.verifyTrue(isfield(data, 'lastTypeUpdated'), ...
                'File should contain lastTypeUpdated field');
        end
    end

    %% Data Integrity Tests
    methods (Test)
        function testNoDuplicateIdentifiers(testCase)
            % Test that registry doesn't create duplicate entries
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
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

    %% Error Handling Tests
    methods (Test)
        function testHandlesEmptyResponse(testCase)
            % Test handling of empty API response

            if isfile(testCase.OriginalCacheFile)
                delete(testCase.OriginalCacheFile)
            end

            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'ApiClient', mockClient, 'Verbose', false);

            % Should handle gracefully
            map = registry.KgToOmMap;
            testCase.verifyEqual(getMapCount(map), 0, ...
                'Should handle empty response gracefully');
        end

        function testHandlesInvalidIdentifier(testCase)
            % Test handling of invalid identifier formats
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            % Test with various invalid formats
            testCase.verifyError(...
                @() registry.getKgId(""), ...
                'OMKG:ControlledInstanceRegistry:IdNotFound')
            testCase.verifyError( ...
                @() registry.getKgId("invalid"), ...
                'OMKG:ControlledInstanceRegistry:IdNotFound')
        end
    end

    %% Helper Methods
    methods (Access = private)
        function mockClient = createMockClient(~)
            % Create a simple mock API client with basic test data
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            % Configure mock to return controlled types
            typeResponse = {
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Technique')
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Sex')
            };
            mockClient.setListTypesResponse(typeResponse);

            % Configure mock to return instance data
            instanceResponse = [
                struct('x_id', '550e8400-e29b-41d4-a716-446655440000', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/controlledTerms/Species'}})
                struct('x_id', '6ba7b810-9dad-11d1-80b4-00c04fd430c8', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/controlledTerms/Technique'}})
                struct('x_id', '7c9e4567-e89b-12d3-a456-426614174001', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/controlledTerms/Sex'}})
            ];
            mockClient.setListResponse(instanceResponse);
            mockClient.setBulkResponse(instanceResponse);
        end

        function mockClient = createConfiguredMockClient(~)
            % Create a configured mock client with call tracking for integration tests
            % Uses helper to create more comprehensive test data
            mockClient = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.createConfiguredMock(3, 5);
        end
    end
end

function count = getMapCount(map)
    if isa(map, 'dictionary')
        count = map.numEntries();
    elseif isa(map, 'containers.Map')
        count = double(map.Count);
    end
end
