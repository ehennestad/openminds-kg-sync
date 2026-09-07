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
    %   - Update mechanism
    %   - Cache persistence and loading
    %   - API interaction patterns
    %   - Performance and efficiency
    %   - Data consistency
    %   - Error handling

    properties (TestParameter)
        % Test data for parameterized tests
        validKgIds = {"123e4567-e89b-12d3-a456-426614174000", ...
                      "987e6543-e21b-45c3-d654-321456987000"}
        validOmIds = {"https://openminds.ebrains.eu/instances/species/species1", ...
                      "https://openminds.ebrains.eu/instances/technique/technique1"}
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
            kgId1 = registry1.getKgId("https://openminds.ebrains.eu/instances/species/species1");

            % Get instance again without storing
            kgId2 = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance().getKgId(...
                "https://openminds.ebrains.eu/instances/species/species1");

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

            omId = "https://openminds.ebrains.eu/instances/species/species1";
            kgId = registry.getKgId(omId);

            testCase.verifyNotEqual(kgId, "", 'Should return a valid KG ID');
            testCase.verifyTrue(strlength(kgId) > 0, 'KG ID should not be empty');
        end

        function testGetKgIdNotFound(testCase)
            % Test KG ID lookup for non-existent openMINDS ID
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance('ApiClient', mockClient);

            omId = "https://openminds.ebrains.eu/instances/species/nonExistent";

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

            omId = "https://openminds.ebrains.eu/instances/species/species1";
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

            registry.update();

            testCase.verifyFalse(registry.needsUpdate(), ...
                'Should not need update immediately after download');
        end

        function testUpdateUsesRetrievalFunctions(testCase)
            % Test that update properly calls retrieval functions
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);

            registry.update();

            % Verify calls were made
            testCase.verifyGreaterThan(mockClient.getCallCount('listTypes'), 0, ...
                'Should call listTypes');
            testCase.verifyGreaterThan(mockClient.getCallCount('listInstances'), 0, ...
                'Should call listInstances');
        end

        function testUpdateRepopulatesMap(testCase)
            % Test that update leaves the registry populated
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Verbose', false);

            registry.update();

            % Verify registry has data
            map = registry.KgToOmMap;
            testCase.verifyGreaterThan(getMapCount(map), 0, ...
                'Registry should have data after full update');
        end

        function testUpdateDropsIdentifiersRemovedFromKnowledgeGraph(testCase)
            % A refresh replaces the mapping, so instances that disappear
            % from the Knowledge Graph must disappear from the map too. The
            % per-type incremental refresh this replaced could only ever add.
            mockClient = testCase.createMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry.update();

            retiredKgId = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
            testCase.assumeTrue(isKey(registry.KgToOmMap, retiredKgId), ...
                'Precondition: the identifier is present before the update')

            remainingInstances = mockClient.ListResponse;
            remainingInstances(strcmp({remainingInstances.x_id}, retiredKgId)) = [];
            mockClient.setListResponse(remainingInstances);

            registry.update();

            testCase.verifyFalse(isKey(registry.KgToOmMap, retiredKgId), ...
                'A removed instance should no longer be in the map')
        end

        function testNewTypeDetectionFlow(testCase)
            % Test the complete flow of detecting and processing a new type
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);

            % Initial download
            registry.update();

            % Add new type to mock
            newTypeIri = "https://openminds.ebrains.eu/controlledTerms/NewType";
            mockClient.addNewType(newTypeIri);

            % Add instances for new type
            newInstances = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.createTestInstances(newTypeIri, 3);
            currentInstances = mockClient.ListResponse;
            mockClient.setListResponse([currentInstances, newInstances]);
            mockClient.setBulkResponse([currentInstances, newInstances]);

            % A refresh re-reads the type list, so the new type is picked up
            registry.update();

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
            registry.update();

            % Get a known mapping
            omId = "https://openminds.ebrains.eu/instances/species/species1";
            kgId1 = registry.getKgId(omId);

            % Update
            registry.update();

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
            registry.update();

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
            registry1.update();
            omId = "https://openminds.ebrains.eu/instances/species/species1";
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
            registry1.update();
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
            registry.update();

            % Read and verify file format
            data = jsondecode(fileread(testCase.OriginalCacheFile));

            testCase.verifyTrue(isfield(data, 'identifiers'), ...
                'File should contain identifiers field');
            testCase.verifyTrue(isfield(data, 'lastUpdateTime'), ...
                'File should contain lastUpdateTime field');
        end
    end

    %% Data Integrity Tests
    methods (Test)
        function testNoDuplicateIdentifiers(testCase)
            % Test that registry doesn't create duplicate entries
            mockClient = testCase.createConfiguredMockClient();
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);

            registry.update();
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

    %% Data Integrity Tests - unresolvable and aliased identifiers
    methods (Test)
        function testDiscardsUnresolvableIdentifiersOnDownload(testCase)
            % Instances without an openMINDS identifier, and identifiers
            % that are not openMINDS instance IRIs, must not reach the maps.
            mockClient = testCase.createMockClient();
            mockClient.setListResponse([
                struct('x_id', 'https://kg.ebrains.eu/api/instances/valid', ...
                    'http___schema_org_identifier', ...
                    {{'https://openminds.ebrains.eu/instances/biologicalSex/male'}})
                struct('x_id', 'https://kg.ebrains.eu/api/instances/noOpenMindsId', ...
                    'http___schema_org_identifier', ...
                    {{'https://example.org/some/other/identifier'}})
                struct('x_id', 'https://kg.ebrains.eu/api/instances/typeIriNotInstance', ...
                    'http___schema_org_identifier', ...
                    {{'https://openminds.ebrains.eu/controlledTerms/programmingLanguage/AMPL'}})
            ]);

            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry.update();

            kgToOmMap = registry.KgToOmMap;
            testCase.verifyTrue(...
                isKey(kgToOmMap, "https://kg.ebrains.eu/api/instances/valid"), ...
                'The resolvable identifier should be kept')
            testCase.verifyFalse(...
                isKey(kgToOmMap, "https://kg.ebrains.eu/api/instances/noOpenMindsId"), ...
                'An instance without an openMINDS identifier should be dropped')
            testCase.verifyFalse(...
                isKey(kgToOmMap, "https://kg.ebrains.eu/api/instances/typeIriNotInstance"), ...
                'A non-instance openMINDS IRI should be dropped')
        end

        function testEmptyOpenMindsIdentifierIsNotAKey(testCase)
            % An instance carrying no openMINDS identifier used to add an
            % empty key to the reverse map, so getKgId("") returned a hit.
            mockClient = testCase.createMockClient();
            mockClient.setListResponse(...
                struct('x_id', 'https://kg.ebrains.eu/api/instances/noOpenMindsId', ...
                    'http___schema_org_identifier', ...
                    {{'https://example.org/some/other/identifier'}}));

            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry.update();

            testCase.verifyError(...
                @() registry.getKgId(""), ...
                'OMKG:ControlledInstanceRegistry:IdNotFound')
        end

        function testAliasedIdentifiersResolveToSpellingKnownToOpenMinds(testCase)
            % The Knowledge Graph lists a legacy misspelling alongside the
            % corrected spelling for some instances. Both arrive under one
            % KG id, and the map must keep the one openMINDS can resolve
            % regardless of the order the Knowledge Graph returned them in.
            aliasedKgId = "https://kg.ebrains.eu/api/instances/aliased";
            aliases = {
                'https://openminds.ebrains.eu/instances/contributionType/metadataManagment'
                'https://openminds.ebrains.eu/instances/contributionType/metadataManagement'
            };

            for aliasOrder = {aliases, flip(aliases)}
                mockClient = testCase.createMockClient();
                mockClient.setListResponse(...
                    struct('x_id', char(aliasedKgId), ...
                        'http___schema_org_identifier', aliasOrder(1)));

                registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                    'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
                registry.update();

                testCase.verifyEqual(registry.getOpenMindsId(aliasedKgId), ...
                    "https://openminds.ebrains.eu/instances/contributionType/metadataManagement", ...
                    'Should keep the spelling openMINDS resolves')
            end
        end

        function testAliasedIdentifiersRemainLookupableInReverse(testCase)
            % Aliases are ambiguous only in the KG -> openMINDS direction.
            % Each alias still identifies one KG instance, so both must
            % remain usable for the reverse lookup.
            aliasedKgId = "https://kg.ebrains.eu/api/instances/aliased";
            mockClient = testCase.createMockClient();
            mockClient.setListResponse(...
                struct('x_id', char(aliasedKgId), ...
                    'http___schema_org_identifier', {{
                        'https://openminds.ebrains.eu/instances/contributionType/metadataManagment'
                        'https://openminds.ebrains.eu/instances/contributionType/metadataManagement'
                    }}));

            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'ApiClient', mockClient, 'Reset', true, 'Verbose', false);
            registry.update();

            testCase.verifyEqual(registry.getKgId(...
                "https://openminds.ebrains.eu/instances/contributionType/metadataManagment"), ...
                aliasedKgId)
            testCase.verifyEqual(registry.getKgId(...
                "https://openminds.ebrains.eu/instances/contributionType/metadataManagement"), ...
                aliasedKgId)
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

            % Configure mock to return instance data. Controlled instances
            % are identified by an IRI under the "instances" segment; the
            % "controlledTerms" IRIs above name the types, not instances.
            instanceResponse = [
                struct('x_id', '550e8400-e29b-41d4-a716-446655440000', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/instances/species/species1'}})
                struct('x_id', '6ba7b810-9dad-11d1-80b4-00c04fd430c8', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/instances/technique/technique1'}})
                struct('x_id', '7c9e4567-e89b-12d3-a456-426614174001', ...
                    'http___schema_org_identifier', {{'https://openminds.ebrains.eu/instances/sex/sex1'}})
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
