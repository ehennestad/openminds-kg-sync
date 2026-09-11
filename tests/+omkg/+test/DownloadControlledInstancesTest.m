classdef DownloadControlledInstancesTest < matlab.unittest.TestCase
% DownloadControlledInstancesTest - Tests for omkg.downloadControlledInstances
%
%   Uses the mock API client in its paged mode, where the configured list
%   stands for every instance of a type and each request gets the slice
%   it asks for. Checked here: only controlled term types are asked for,
%   the listing is paged until a page comes back empty and copes with a
%   server that caps the page size, and the openMINDS IRIs of the returned
%   nodes end up cached.

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
            testCase.MockClient.setPagedListResponse({testCase.createSpeciesKgNode()});
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

        function testPagingContinuesUntilAnEmptyPage(testCase)
            % The client hands back only the data of a page, not a total,
            % so the listing has to run until a page is empty.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            testCase.MockClient.setPagedListResponse(testCase.createSpeciesKgNodes(3));

            omkg.downloadControlledInstances('Client', testCase.MockClient, ...
                'Verbose', false, 'PageSize', 2);

            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'from', uint64(2)), ...
                'The second page should start where the first ended')
            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'from', uint64(3)), ...
                'The listing should ask for one more page and find it empty')
            testCase.verifyEqual(omkg.internal.ControlledInstanceCache.instance().numEntries(), 3)
        end

        function testShortPageDoesNotEndTheListing(testCase)
            % A server may cap the page size below what was asked for. A
            % page shorter than requested is then not the last one, and the
            % offset has to advance by what the page actually held.
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            testCase.MockClient.setPagedListResponse(testCase.createSpeciesKgNodes(3), 'PageSizeCap', 1);

            omkg.downloadControlledInstances('Client', testCase.MockClient, ...
                'Verbose', false, 'PageSize', 500);

            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'from', uint64(1)))
            testCase.verifyTrue(testCase.MockClient.wasCalledWithOptionalParam('listInstances', 'from', uint64(2)))
            testCase.verifyEqual(omkg.internal.ControlledInstanceCache.instance().numEntries(), 3, ...
                'Every instance should be cached even though each page held one')
        end

        function testRequestsGoToTheGivenServer(testCase)
            omkg.setpref("ControlledInstanceIdentity", "openminds");

            omkg.downloadControlledInstances('Client', testCase.MockClient, ...
                'Verbose', false, 'Server', "preprod");

            testCase.verifyTrue(testCase.MockClient.wasCalledWithOption('listInstances', 'Server', ...
                ebrains.kg.enum.KGServer.PREPROD))
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
        function kgNode = createSpeciesKgNode(instanceName)
            arguments
                instanceName (1,1) string = "musMusculus"
            end
            kgIri = "https://kg.ebrains.eu/api/instances/species-" + instanceName;
            kgNode = struct();
            kgNode.x_id = char(kgIri);
            kgNode.x_type = 'https://openminds.om-i.org/types/Species';
            kgNode.http___schema_org_identifier = { ...
                char("https://openminds.om-i.org/instances/species/" + instanceName), ...
                char(kgIri)};
            kgNode.https___openminds_ebrains_eu_vocab_name = char(instanceName);
        end

        function kgNodes = createSpeciesKgNodes(numNodes)
            kgNodes = arrayfun(@(i) ...
                omkg.test.DownloadControlledInstancesTest.createSpeciesKgNode("species" + i), ...
                1:numNodes, 'UniformOutput', false);
        end
    end
end
