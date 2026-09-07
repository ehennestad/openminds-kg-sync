classdef IdentifierCacheLocationTest < matlab.unittest.TestCase
% IdentifierCacheLocationTest - Where the identifier map is cached and seeded
%
%   The cached map is keyed by openMINDS version, because an openMINDS
%   instance IRI carries a version specific namespace: a v3 IRI does not
%   resolve under v4, where openminds.constant.BaseIRI covers om-i.org
%   only. Sharing one cache across versions would hand the resolver
%   identifiers it cannot resolve.

    methods (TestMethodSetup)
        function isolatePreferences(testCase)
            % KgOpenMINDSVersion is a real user preference, so snapshot it
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
        end
    end

    methods (TestMethodTeardown)
        function resetSingleton(~)
            omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'Verbose', false);
        end
    end

    methods (Test)
        function testCacheFileIsKeyedByOpenMindsVersion(testCase)
            v3Path = testCase.cacheFilePathForVersion(3);
            v4Path = testCase.cacheFilePathForVersion(4);

            testCase.verifyNotEqual(v3Path, v4Path, ...
                'Each openMINDS version needs its own cache file')
            testCase.verifyTrue(contains(v3Path, "v3"), ...
                'The v3 cache file should be identifiable as such')
            testCase.verifyTrue(contains(v4Path, "v4"), ...
                'The v4 cache file should be identifiable as such')
        end

        function testCacheIsWrittenOutsideTheToolbox(testCase)
            % An installed toolbox folder is read-only, so the cache has to
            % live with the other user scoped state in prefdir.
            cachePath = testCase.cacheFilePathForVersion(4);

            testCase.verifyTrue(startsWith(cachePath, prefdir), ...
                'The cache should be written under prefdir')
            testCase.verifyFalse(startsWith(cachePath, omkg.toolboxdir()), ...
                'The cache should not be written inside the toolbox')
        end

        function testFileOptionOverridesTheCachePath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            expectedPath = fullfile(tempFolder.Folder, "identifiers.json");

            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'Verbose', false, 'File', expectedPath);

            testCase.verifyEqual(string(registry.getFilePath()), string(expectedPath))
        end
    end

    methods (Test) % The resource shipped with the toolbox
        function testShippedResourceExistsForV3Only(testCase)
            % The shipped map holds v3 namespace IRIs, so it must not be
            % used to seed another openMINDS version.
            testCase.verifyTrue(isfile(testCase.seedFilePathForVersion(3)), ...
                'A v3 resource is expected to ship with the toolbox')
            testCase.verifyFalse(isfile(testCase.seedFilePathForVersion(4)), ...
                'No v4 resource ships, so v4 starts from an empty map')
        end

        function testShippedResourceCarriesOnlyItsOwnNamespace(testCase)
            pairs = jsondecode(fileread(testCase.seedFilePathForVersion(3)));
            pairs = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            omIds = string({pairs.om});

            testCase.verifyNotEmpty(omIds)
            testCase.verifyTrue(all(startsWith(omIds, "https://openminds.ebrains.eu/")), ...
                'The v3 resource should hold v3 namespace identifiers only')
        end
    end

    methods (Access = private)
        function filepath = cacheFilePathForVersion(~, openMindsVersion)
            omkg.setpref("KgOpenMINDSVersion", openMindsVersion);
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'Verbose', false);
            filepath = string(registry.getFilePath());
        end

        function filepath = seedFilePathForVersion(~, openMindsVersion)
            omkg.setpref("KgOpenMINDSVersion", openMindsVersion);
            registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance(...
                'Reset', true, 'Verbose', false);
            filepath = string(registry.getSeedFilePath());
        end
    end
end
