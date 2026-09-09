classdef ControlledInstanceCacheTest < matlab.unittest.TestCase
% ControlledInstanceCacheTest - Unit tests for omkg.internal.ControlledInstanceCache
%
%   The cache follows the ControlledInstanceIdentity preference and lives
%   in the user's own folder, so every test isolates the real preferences
%   and points the singleton at a temporary file. The singleton is
%   discarded on teardown so no later test inherits a temporary path.

    properties (Constant, Access = private)
        KgIri = "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        OmIri = "https://openminds.om-i.org/instances/species/musMusculus"
    end

    properties (Access = private)
        CacheFile (1,1) string
    end

    methods (TestMethodSetup)
        function isolate(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.CacheFile = fullfile(tempFolder.Folder, "cache.json");
            testCase.addTeardown(@() ...
                omkg.internal.ControlledInstanceCache.instance('Reset', true));
        end
    end

    methods (Test) % Under the "kg" identity policy
        function testRecordIsANoOpWhileDisabled(testCase)
            omkg.setpref("ControlledInstanceIdentity", "kg");
            cache = testCase.createCache();

            cache.record(testCase.KgIri, testCase.OmIri);

            testCase.verifyFalse(cache.isKnown(testCase.KgIri))
            testCase.verifyFalse(isfile(testCase.CacheFile), ...
                'Nothing should be written while the cache is off')
        end

        function testIsKnownIsFalseWhileDisabled(testCase)
            % Even an entry that exists on disk is ignored while off
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            testCase.createCache().record(testCase.KgIri, testCase.OmIri);

            omkg.setpref("ControlledInstanceIdentity", "kg");

            testCase.verifyFalse(testCase.createCache().isKnown(testCase.KgIri))
        end
    end

    methods (Test) % Enabled
        function testRecordThenLookup(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();

            cache.record(testCase.KgIri, testCase.OmIri);

            testCase.verifyTrue(cache.isKnown(testCase.KgIri))
            testCase.verifyEqual(cache.lookup(testCase.KgIri), testCase.OmIri)
        end

        function testLookupOfUnknownIriErrors(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();

            testCase.verifyError(@() cache.lookup("https://kg.ebrains.eu/api/instances/unknown"), ...
                'OMKG:ControlledInstanceCache:NotCached')
        end

        function testIsKnownIsVectorised(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();
            cache.record(testCase.KgIri, testCase.OmIri);

            tf = cache.isKnown([testCase.KgIri, "https://kg.ebrains.eu/api/instances/other"]);

            testCase.verifyEqual(tf, [true false])
        end

        function testEntriesSurviveANewInstance(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            testCase.createCache().record(testCase.KgIri, testCase.OmIri);

            reloaded = testCase.createCache();

            testCase.verifyTrue(reloaded.isKnown(testCase.KgIri))
            testCase.verifyEqual(reloaded.lookup(testCase.KgIri), testCase.OmIri)
        end

        function testRecordingTheSameEntryAgainDoesNotRewriteTheFile(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();
            cache.record(testCase.KgIri, testCase.OmIri);
            firstWrite = dir(testCase.CacheFile).datenum;

            cache.record(testCase.KgIri, testCase.OmIri);

            testCase.verifyEqual(dir(testCase.CacheFile).datenum, firstWrite)
        end

        function testRecordMixesNewAndKnownEntries(testCase)
            % A bulk record typically repeats entries already held next to
            % new ones, and may list the same key more than once.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();
            cache.record(testCase.KgIri, testCase.OmIri);
            otherKg = "https://kg.ebrains.eu/api/instances/other";
            otherOm = "https://openminds.om-i.org/instances/species/rattusNorvegicus";

            cache.record([testCase.KgIri, otherKg, testCase.KgIri], ...
                         [testCase.OmIri, otherOm, testCase.OmIri]);

            testCase.verifyEqual(cache.numEntries(), 2)
            testCase.verifyEqual(cache.lookup(otherKg), otherOm)
        end

        function testRecordUpdatesAChangedEntry(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();
            cache.record(testCase.KgIri, testCase.OmIri);
            corrected = "https://openminds.om-i.org/instances/species/musMusculusCorrected";

            cache.record(testCase.KgIri, corrected);

            testCase.verifyEqual(cache.lookup(testCase.KgIri), corrected)
            testCase.verifyEqual(testCase.createCache().lookup(testCase.KgIri), corrected, ...
                'The change should have been written to disk')
        end

        function testClearForgetsEntriesAndRemovesFile(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            cache = testCase.createCache();
            cache.record(testCase.KgIri, testCase.OmIri);

            cache.clear();

            testCase.verifyFalse(cache.isKnown(testCase.KgIri))
            testCase.verifyFalse(isfile(testCase.CacheFile))
        end
    end

    methods (Test) % File format
        function testFileRecordsOpenMindsVersion(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            omkg.setpref("KgOpenMINDSVersion", 4);
            testCase.createCache().record(testCase.KgIri, testCase.OmIri);

            data = jsondecode(fileread(testCase.CacheFile));

            testCase.verifyEqual(string(data.openmindsVersion), "v4.0")
            testCase.verifyTrue(isfield(data, 'generatedAt'))
            testCase.verifyTrue(isfield(data, 'schemaVersion'))
        end

        function testFileRecordsKnowledgeGraphScope(testCase)
            % The space and stage a fill requested are recorded for
            % provenance. Not the server: preprod mirrors prod, so a UUID
            % names the same instance regardless of which was queried.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            testCase.createCache().record(testCase.KgIri, testCase.OmIri);

            data = jsondecode(fileread(testCase.CacheFile));

            testCase.verifyEqual(string(data.kg.space), "controlled")
            testCase.verifyEqual(string(data.kg.stage), "RELEASED")
        end

        function testMalformedEntriesAreDroppedOnLoad(testCase)
            % The three shapes found in the old shipped map: no openMINDS
            % identifier, a type path instead of an instance path, and a
            % slash inside the instance name. None can be resolved.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            omkg.setpref("KgOpenMINDSVersion", 4);
            data = struct(...
                'schemaVersion', "1.0", ...
                'openmindsVersion', "v4.0", ...
                'kg', struct('space', "controlled", 'stage', "RELEASED"), ...
                'generatedAt', "2026-09-08T00:00:00Z", ...
                'entries', struct('kg', ...
                    {testCase.KgIri, ...
                     "https://kg.ebrains.eu/api/instances/empty", ...
                     "https://kg.ebrains.eu/api/instances/typepath", ...
                     "https://kg.ebrains.eu/api/instances/slash"}, ...
                    'om', ...
                    {testCase.OmIri, ...
                     "", ...
                     "https://openminds.om-i.org/types/programmingLanguage/AMPL", ...
                     "https://openminds.om-i.org/instances/molecularEntity/GABA-A/BZ"}));
            fid = fopen(testCase.CacheFile, "wt"); fwrite(fid, jsonencode(data)); fclose(fid);

            cache = testCase.createCache();

            testCase.verifyWarning(@() cache.numEntries(), ...
                'OMKG:ControlledInstanceCache:InvalidEntries')
            testCase.verifyEqual(cache.numEntries(), 1)
            testCase.verifyTrue(cache.isKnown(testCase.KgIri))
        end

        function testFileBuiltForAnotherVersionIsIgnored(testCase)
            % An openMINDS IRI carries a version specific namespace, so a
            % cache built for one version must not be used under another.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            omkg.setpref("KgOpenMINDSVersion", 4);
            testCase.createCache().record(testCase.KgIri, testCase.OmIri);

            omkg.setpref("KgOpenMINDSVersion", 3);
            cache = testCase.createCache();

            testCase.verifyWarning(@() cache.isKnown(testCase.KgIri), ...
                'OMKG:ControlledInstanceCache:VersionMismatch')
            testCase.verifyFalse(cache.isKnown(testCase.KgIri))
        end
    end

    methods (Test) % Location
        function testDefaultLocationIsUnderUserpath(testCase)
            % Not prefdir: the cache is user data, kept where the user can
            % see it.
            omkg.setpref("ControlledInstanceCacheFolder", "");
            omkg.setpref("KgOpenMINDSVersion", 4);
            cache = omkg.internal.ControlledInstanceCache.instance('Reset', true);

            filePath = cache.getFilePath();

            testCase.verifyTrue(startsWith(filePath, string(userpath)))
            testCase.verifyTrue(contains(filePath, "v4"))
            testCase.verifyFalse(startsWith(filePath, string(prefdir)))
        end

        function testFileIsNotKeyedByServer(testCase)
            % preprod is a daily-refreshed mirror of prod, so the cache
            % file for a given openMINDS version is shared across servers.
            omkg.setpref("ControlledInstanceCacheFolder", "");
            omkg.setpref("DefaultServer", ebrains.kg.enum.KGServer.PROD);
            prodPath = omkg.internal.ControlledInstanceCache.instance('Reset', true).getFilePath();

            omkg.setpref("DefaultServer", ebrains.kg.enum.KGServer.PREPROD);
            preprodPath = omkg.internal.ControlledInstanceCache.instance('Reset', true).getFilePath();

            testCase.verifyEqual(prodPath, preprodPath)
        end

        function testFolderPreferenceIsHonoured(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            omkg.setpref("ControlledInstanceCacheFolder", folder);
            cache = omkg.internal.ControlledInstanceCache.instance('Reset', true);

            testCase.verifyTrue(startsWith(cache.getFilePath(), string(folder)))
        end

        function testChangingTheFolderPreferenceReloads(testCase)
            % The singleton follows the preference rather than holding on to
            % the file it first loaded.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            folderA = testCase.applyFixture(TemporaryFolderFixture).Folder;
            folderB = testCase.applyFixture(TemporaryFolderFixture).Folder;
            cache = omkg.internal.ControlledInstanceCache.instance('Reset', true);

            omkg.setpref("ControlledInstanceCacheFolder", folderA);
            cache.record(testCase.KgIri, testCase.OmIri);

            omkg.setpref("ControlledInstanceCacheFolder", folderB);
            testCase.verifyFalse(cache.isKnown(testCase.KgIri), ...
                'Entries of the previous folder should not leak into the new one')

            omkg.setpref("ControlledInstanceCacheFolder", folderA);
            testCase.verifyTrue(cache.isKnown(testCase.KgIri))
        end
    end

    methods (Access = private)
        function cache = createCache(testCase)
            cache = omkg.internal.ControlledInstanceCache.instance(...
                'Reset', true, 'File', testCase.CacheFile);
        end
    end
end
