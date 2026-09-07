classdef GetControlledTypesTest < matlab.unittest.TestCase
    % GetControlledTypesTest - Unit tests for omkg.internal.retrieval.getControlledTypes
    %
    % Covers the namespace filter that recognizes controlled term types
    % across both the v3-and-below namespace (openminds.ebrains.eu) and the
    % v4-and-above namespace (openminds.om-i.org), since the KG can serve
    % types tagged with either. Namespace shapes are taken from
    % openMINDS_MATLAB's code/resources/.vocab/types.json, which lists the
    % real @type IRI for each schema version.

    methods (Test)
        function testMatchesLegacyEbrainsEuNamespace(testCase)
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Technique')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.ebrains.eu/controlledTerms/Species", ...
                "https://openminds.ebrains.eu/controlledTerms/Technique"]));
        end

        function testExcludesLegacyCoreNamespace(testCase)
            % In v3-and-below, controlled term types (controlledTerms/)
            % and core schema types (core/) are distinct namespace
            % segments, so a core type should still be excluded.
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/core/Person')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(typeNames, "https://openminds.ebrains.eu/controlledTerms/Species");
        end

        function testMatchesCurrentOmiOrgNamespace(testCase)
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/types/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/types/Technique')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.om-i.org/types/Species", ...
                "https://openminds.om-i.org/types/Technique"]));
        end

        function testCannotExcludeCurrentCoreNamespace(testCase)
            % Known limitation: v4-and-above collapses controlled term
            % types and core schema types into the same "types/" segment
            % (Species and Person are both "openminds.om-i.org/types/..."),
            % so this namespace filter can no longer tell them apart for
            % v4 data. A core type therefore is NOT excluded here;
            % correctness for v4 responses relies entirely on the API
            % call already scoping the request to the "controlled" space.
            % This test documents that limitation so it is not silently
            % lost or silently "fixed" without a deliberate decision.
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/types/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/types/Person')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.om-i.org/types/Species", ...
                "https://openminds.om-i.org/types/Person"]));
        end

        function testMatchesMixOfLegacyAndCurrentControlledTypes(testCase)
            % The KG can serve a mix of legacy and current controlled
            % types simultaneously ("mixed mode").
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/types/Technique')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.ebrains.eu/controlledTerms/Species", ...
                "https://openminds.om-i.org/types/Technique"]));
        end
    end
end
