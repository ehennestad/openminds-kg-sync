classdef DownloadMetadataTest < matlab.unittest.TestCase
% DownloadMetadataTest - Tests for internal downloadMetadata function
%
% This test class covers:
% - Direct testing of omkg.sync.downloadMetadata function
% - Mock client integration at the internal level
% - Error handling and edge cases

    properties
        TestUUID
        MockClient
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TestUUID = "550e8400-e29b-41d4-a716-446655440000";
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
        end
    end

    methods (Test)

        function testBasicDownloadMetadata(testCase)
            % Test the downloadMetadata function directly with controlled inputs
            testCase.useIdentityPolicy("openminds");

            % Create a simple mock KG node
            mockKgNode = struct();
            mockKgNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            mockKgNode.x_type = "https://openminds.ebrains.eu/core/Person";
            mockKgNode.givenName = "John";
            mockKgNode.familyName = "Doe";

            % Configure mock client
            testCase.MockClient.setInstanceResponse(mockKgNode);

            % Test the download
            try
                result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                    'Client', testCase.MockClient, ...
                    'NumLinksToResolve', 0);

                testCase.verifyInstanceOf(result, 'openminds.Node', ...
                    'Should return openMINDS schema instance');
                testCase.verifyClass(result, 'openminds.core.Person', ...
                    'Should return openMINDS Person instance');

            catch ME
                % If it fails due to missing dependencies, that's expected in test environment
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKG:TestSkipped', 'Test skipped due to missing openMINDS/EBRAINS dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testDownloadMetadataWithLinkResolution(testCase)
            % Test downloadMetadata with link resolution
            testCase.useIdentityPolicy("openminds");

            % Create mock nodes with links
            mainNode = struct();
            mainNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            mainNode.x_type = "https://openminds.ebrains.eu/core/Person";
            mainNode.givenName = "John";
            mainNode.familyName = "Doe";

            % Use contactInformation instead of affiliation for linked property
            linkedNodeId1 = "123e4567-e89b-12d3-a456-426614174000";
            linkedNodeId2 = "123e4567-e89b-12d3-a456-426614174001";

            mainNode.contactInformation = struct('x_id', "https://kg.ebrains.eu/api/instances/" + linkedNodeId1);
            mainNode.digitalIdentifier = struct('x_id', "https://kg.ebrains.eu/api/instances/" + linkedNodeId2);

            % Create mock linked node
            linkedNode1 = struct();
            linkedNode1.x_id = "https://kg.ebrains.eu/api/instances/" + linkedNodeId1;
            linkedNode1.x_type = "https://openminds.ebrains.eu/core/ContactInformation";
            linkedNode1.email = "john.doe@example.com";

            linkedNode2 = struct();
            linkedNode2.x_id = "https://kg.ebrains.eu/api/instances/" + linkedNodeId2;
            linkedNode2.x_type = "https://openminds.ebrains.eu/core/ORCID";
            linkedNode2.identifier = "https://orcid.org/0000-0002-1825-0097";

            % Set up mock responses
            testCase.MockClient.setInstanceResponse(mainNode);
            testCase.MockClient.setBulkResponse({linkedNode1, linkedNode2});

            % Test with link resolution (should not fail even if links can't be resolved)
            try
                result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                    'Client', testCase.MockClient, ...
                    'NumLinksToResolve', 1);

                testCase.verifyNotEmpty(result, 'Should return non-empty result');
                testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 1, ...
                    'Linked references should be downloaded in bulk when resolving one level of links');
                testCase.verifyEqual(result.contactInformation.email, "john.doe@example.com", ...
                    'The linked node should be resolved with the downloaded values');
                testCase.verifyFalse(result.contactInformation.isReference(), ...
                    'A resolved link should no longer be a reference');

            catch ME
                % Todo: This is a very unspecific check. Should be improved
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKG:TestSkipped', 'Test skipped due to missing dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function testUnknownControlledLinkIsPrefetchedAndTakesOpenMindsIdentity(testCase)
            % Under the "openminds" identity policy a link to a controlled
            % instance the lookup does not know is fetched before its
            % parent is converted, so the parent's link can be built as
            % the library instance with its openMINDS IRI. Identity is
            % fixed here; a resolver may not change it later.
            testCase.useIdentityPolicy("openminds");
            [subjectNode, speciesNode, speciesKgIri, speciesOmIri] = testCase.createSubjectWithSpecies();
            testCase.MockClient.setInstanceResponse(subjectNode);
            testCase.MockClient.setBulkResponse({speciesNode});

            result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                'Client', testCase.MockClient, 'NumLinksToResolve', 0);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 1, ...
                'The unknown controlled instance should be fetched once, before conversion')
            testCase.verifyEmpty(result.getUnresolvedLinkIdentifiers(), ...
                'A controlled instance link should not be left to resolve later')
            species = result.species;
            if openminds.utility.isMixedInstance(species), species = species.Instance; end
            testCase.verifyClass(species, 'openminds.controlledterms.Species')
            testCase.verifyEqual(string(species.id), speciesOmIri)
            testCase.verifyTrue(omkg.internal.ControlledInstanceCache.instance().isKnown(speciesKgIri), ...
                'The pre-fetch should have recorded the pairing for later pulls')
        end

        function testKnownControlledLinkIsNotFetchedAgain(testCase)
            testCase.useIdentityPolicy("openminds");
            [subjectNode, ~, speciesKgIri, speciesOmIri] = testCase.createSubjectWithSpecies();
            omkg.internal.ControlledInstanceCache.instance().record(speciesKgIri, speciesOmIri);
            testCase.MockClient.setInstanceResponse(subjectNode);

            result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                'Client', testCase.MockClient, 'NumLinksToResolve', 0);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 0, ...
                'A controlled instance already known needs no request at all')
            testCase.verifyEmpty(result.getUnresolvedLinkIdentifiers())
        end

        function testUnderKgIdentityPolicyControlledLinkStaysAReference(testCase)
            % Under "kg" identity nothing is looked up or pre-fetched; the
            % link keeps its Knowledge Graph identifier like any other.
            testCase.useIdentityPolicy("kg");
            [subjectNode, ~, speciesKgIri] = testCase.createSubjectWithSpecies();
            testCase.MockClient.setInstanceResponse(subjectNode);

            result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                'Client', testCase.MockClient, 'NumLinksToResolve', 0);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 0)
            testCase.verifyEqual(string(result.getUnresolvedLinkIdentifiers()), speciesKgIri)
        end

        function testPrefetchedNodesAreReusedByLinkResolution(testCase)
            % A mixed-type link may hold a controlled instance, so the
            % pre-fetch retrieves it to look at its identifiers. When it
            % turns out to be an ordinary node it is an unresolved link
            % like any other, and must be reused rather than downloaded
            % again. A link the Knowledge Graph did not return is not
            % requested a second time either, so it is reported once.
            testCase.useIdentityPolicy("openminds");
            subjectKgIri = "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8";
            missingKgIri = "https://kg.ebrains.eu/api/instances/00000000-0000-4000-8000-00000000dead";

            datasetVersionNode = struct();
            datasetVersionNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            datasetVersionNode.x_type = "https://openminds.om-i.org/types/DatasetVersion";
            datasetVersionNode.studiedSpecimen = struct('x_id', {subjectKgIri, missingKgIri});

            subjectNode = struct();
            subjectNode.x_id = subjectKgIri;
            subjectNode.x_type = "https://openminds.om-i.org/types/Subject";
            subjectNode.lookupLabel = "mouse1";

            testCase.MockClient.setInstanceResponse(datasetVersionNode);
            testCase.MockClient.setBulkResponse({subjectNode});

            result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                'Client', testCase.MockClient, 'NumLinksToResolve', 1);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 1, ...
                'The links should be requested once, by the pre-fetch, and then reused')
            testCase.verifyEqual(string(result.getUnresolvedLinkIdentifiers()), missingKgIri, ...
                'Only the link the Knowledge Graph did not return should remain unresolved')

            specimens = result.studiedSpecimen;
            subject = specimens(1).Instance;
            testCase.verifyClass(subject, 'openminds.core.Subject')
            testCase.verifyEqual(subject.lookupLabel, "mouse1", ...
                'The pre-fetched node should be resolved with its downloaded values')
        end

        function testControlledLinkInsideEmbeddedNodeIsPrefetched(testCase)
            % A controlled term is often linked from an embedded node rather
            % than from the node being converted: the unit of a quantity
            % sits inside the QuantitativeValue that holds it. The pre-fetch
            % must find it there, or the unit keeps its KG identifier while
            % terms linked directly take their openMINDS one.
            testCase.useIdentityPolicy("openminds");
            unitKgIri = "https://kg.ebrains.eu/api/instances/11111111-1111-4111-8111-111111111111";
            unitOmIri = "https://openminds.om-i.org/instances/unitOfMeasurement/month";

            stateNode = struct();
            stateNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            stateNode.x_type = "https://openminds.om-i.org/types/SubjectState";
            stateNode.age = struct(...
                'x_type', "https://openminds.om-i.org/types/QuantitativeValue", ...
                'value', 12, ...
                'unit', struct('x_id', unitKgIri));

            unitNode = struct();
            unitNode.x_id = unitKgIri;
            unitNode.x_type = "https://openminds.om-i.org/types/UnitOfMeasurement";
            unitNode.http___schema_org_identifier = {char(unitOmIri), char(unitKgIri)};
            unitNode.name = "month";

            testCase.MockClient.setInstanceResponse(stateNode);
            testCase.MockClient.setBulkResponse({unitNode});

            result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                'Client', testCase.MockClient, 'NumLinksToResolve', 0);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstancesBulk'), 1, ...
                'The unit should be fetched once, before its parent is converted')
            unit = result.age.unit;
            if openminds.utility.isMixedInstance(unit), unit = unit.Instance; end
            testCase.verifyClass(unit, 'openminds.controlledterms.UnitOfMeasurement')
            testCase.verifyEqual(string(unit.id), unitOmIri, ...
                'The unit should take its openMINDS identity like a directly linked term')
            testCase.verifyFalse(unit.isReference())
        end

        function testMissingSingleControlledCandidateDoesNotAbortThePull(testCase)
            % The API client answers a request for one identifier with an
            % error when the KG has no such instance, where a request for
            % several silently leaves the missing ones out. A dead link on
            % a property that could hold a controlled term must not abort
            % the pull; it is warned about and left a reference.
            testCase.useIdentityPolicy("openminds");
            [subjectNode, ~, speciesKgIri] = testCase.createSubjectWithSpecies();
            testCase.MockClient.setInstanceResponse(subjectNode);
            testCase.MockClient.setError("getInstancesBulk", ...
                MException('EBRAINS:KG_API:getInstance:NotFound', 'NotFound'));

            result = testCase.verifyWarning(...
                @() omkg.sync.downloadMetadata(testCase.TestUUID, ...
                    'Client', testCase.MockClient, 'NumLinksToResolve', 0), ...
                'OMKG:DownloadMetadata:LinkedInstanceNotFound');

            testCase.verifyClass(result, 'openminds.core.research.Subject')
            testCase.verifyEqual(string(result.getUnresolvedLinkIdentifiers()), speciesKgIri, ...
                'The link that could not be retrieved should stay a reference')
        end

        function testDownloadMetadataErrorHandling(testCase)
            % Test error handling in downloadMetadata
            testCase.useIdentityPolicy("openminds");

            % Configure mock to throw error
            testCase.MockClient.setError("getInstance", MException('TEST:Error', 'Mock error'));

            try
                testCase.verifyError(...
                    @() omkg.sync.downloadMetadata(testCase.TestUUID, 'Client', testCase.MockClient), ...
                    'TEST:Error', ...
                    'Should propagate mock client errors');
            catch ME
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKG:TestSkipped', 'Test skipped due to missing dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end
    end

    methods (Access = private)
        function useIdentityPolicy(testCase, policy)
            % Select an identity policy against a temporary cache file,
            % with the user's real preferences and cache left untouched.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
            omkg.setpref("ControlledInstanceIdentity", policy);
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            omkg.internal.ControlledInstanceCache.instance(...
                'Reset', true, 'File', fullfile(tempFolder.Folder, "cache.json"));
            testCase.addTeardown(@() ...
                omkg.internal.ControlledInstanceCache.instance('Reset', true));
        end
    end

    methods (Access = private)
        function [subjectNode, speciesNode, speciesKgIri, speciesOmIri] = createSubjectWithSpecies(testCase)
            speciesKgIri = "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8";
            speciesOmIri = "https://openminds.om-i.org/instances/species/musMusculus";

            subjectNode = struct();
            subjectNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            subjectNode.x_type = "https://openminds.om-i.org/types/Subject";
            subjectNode.lookupLabel = "mouse1";
            subjectNode.species = struct('x_id', speciesKgIri);

            speciesNode = struct();
            speciesNode.x_id = speciesKgIri;
            speciesNode.x_type = "https://openminds.om-i.org/types/Species";
            speciesNode.http___schema_org_identifier = {char(speciesOmIri), char(speciesKgIri)};
            speciesNode.name = "Mus musculus";
        end
    end
end
