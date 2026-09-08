classdef DownloadControlledInstancesTest < matlab.unittest.TestCase
% DownloadControlledInstancesTest - Tests for omkg.downloadControlledInstances
%
%   Uses the mock API client. The mock returns the same list for every
%   listInstances call regardless of paging parameters, so multi-page
%   behaviour can not be exercised here; what is checked is that the
%   request is paged at all, that only controlled term types are asked
%   for, and that the openMINDS IRIs of the returned nodes end up cached.

    properties (Access = private)
        MockClient omkg.test.helper.mock.KGIntancesAPIMockClient
        CacheFile (1,1) string
    end

    methods (TestMethodSetup)
        function isolate(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.CacheFile = fullfile(tempFolder.Folder, "cache.json");
            omkg.internal.ControlledInstanceCache.instance('Reset', true, 'File', testCase.CacheFile);
            testCase.addTeardown(@() ...
                omkg.internal.ControlledInstanceCache.instance('Reset', true));

            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            testCase.MockClient.setListResponse({testCase.createSpeciesKgNode()});
        end
    end

    methods (Test)
        function testErrorsUnderKgIdentityPolicy(testCase)
            % Under "kg" identity the lookup is never consulted, so there is
            % nothing to fill and the download is refused up front.
            omkg.setpref("ControlledInstanceIdentity", "kg");

            testCase.verifyError(...
                @() omkg.downloadControlledInstances('Client', testCase.MockClient, 'Verbose', false), ...
                'OMKG:DownloadControlledInstances:CacheDisabled')
            testCase.verifyEqual(testCase.MockClient.getCallCount('listInstances'), 0, ...
                'Nothing should be downloaded when there is no lookup to fill')
        end

        function testRequestsOnlyControlledTermTypes(testCase)
            % The types come from openminds.enum.Types, not from the KG, so
            % other types held in the same KG space (atlas annotations,
            % thousands of them) are never requested.
            omkg.setpref("ControlledInstanceIdentity", "openminds");

            omkg.downloadControlledInstances('Client', testCase.MockClient, 'Verbose', false);

            calls = testCase.MockClient.getCallsFor('listInstances');
            requestedTypes = string(cellfun(@(args) args{1}, {calls.args}, 'UniformOutput', false));
            testCase.assertNotEmpty(requestedTypes)

            for typeIRI = requestedTypes
                typeEnum = openminds.enum.Types.fromAtType(typeIRI);
                testCase.verifyTrue(startsWith(typeEnum.ClassName, "openminds.controlledterms."), ...
                    sprintf('"%s" is not a controlled term type', typeIRI))
            end
            testCase.verifyFalse(any(contains(requestedTypes, "AtlasAnnotation")))
        end

        function testRequestsArePaged(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");

            omkg.downloadControlledInstances('Client', testCase.MockClient, ...
                'Verbose', false, 'PageSize', 250);

            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'size', uint64(250)), ...
                'Each request should carry the page size')
            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'from', uint64(0)), ...
                'Each request should carry the offset')
        end

        function testCachesTheOpenMindsIriOfEachInstance(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            node = testCase.createSpeciesKgNode();

            omkg.downloadControlledInstances('Client', testCase.MockClient, 'Verbose', false);

            cache = omkg.internal.ControlledInstanceCache.instance();
            testCase.verifyTrue(cache.isKnown(string(node.x_id)))
            testCase.verifyEqual(cache.lookup(string(node.x_id)), ...
                "https://openminds.om-i.org/instances/species/musMusculus")
        end
    end

    methods (Static, Access = private)
        function kgNode = createSpeciesKgNode()
            kgNode = struct();
            kgNode.x_id = 'https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8';
            kgNode.x_type = 'https://openminds.om-i.org/types/Species';
            kgNode.http___schema_org_identifier = { ...
                'https://openminds.om-i.org/instances/species/musMusculus', ...
                'https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8'};
            kgNode.https___openminds_ebrains_eu_vocab_name = 'Mus musculus';
        end
    end
end
