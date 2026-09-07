classdef GetControlledTypesTest < matlab.unittest.TestCase
    % GetControlledTypesTest - Unit tests for omkg.internal.retrieval.getControlledTypes
    %
    % Covers the namespace filter that recognizes controlled term types
    % across both the v3-and-below namespace (openminds.ebrains.eu) and the
    % v4-and-above namespace (openminds.om-i.org), since the KG can serve
    % types tagged with either.

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

        function testMatchesCurrentOmiOrgNamespace(testCase)
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/controlledTerms/Technique')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.om-i.org/controlledTerms/Species", ...
                "https://openminds.om-i.org/controlledTerms/Technique"]));
        end

        function testMatchesBothNamespacesAndExcludesUnrelatedTypes(testCase)
            % The KG can serve a mix of legacy and current controlled
            % types simultaneously ("mixed mode"), and non-controlled
            % types should still be excluded regardless of namespace.
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setListTypesResponse({
                struct('http___schema_org_identifier', ...
                    'https://openminds.ebrains.eu/controlledTerms/Species')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/controlledTerms/Technique')
                struct('http___schema_org_identifier', ...
                    'https://openminds.om-i.org/core/Person')
            });

            typeNames = omkg.internal.retrieval.getControlledTypes('ApiClient', mockClient);

            testCase.verifyEqual(sort(typeNames), sort([...
                "https://openminds.ebrains.eu/controlledTerms/Species", ...
                "https://openminds.om-i.org/controlledTerms/Technique"]));
        end
    end
end
