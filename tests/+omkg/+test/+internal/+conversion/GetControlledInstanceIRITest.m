classdef GetControlledInstanceIRITest < matlab.unittest.TestCase
% GetControlledInstanceIRITest - Unit tests for getControlledInstanceIRI
%
%   The function reads the openMINDS IRI a Knowledge Graph node carries in
%   schema:identifier. That field also holds the KG's own IRI for the node
%   and, for some instances, more than one openMINDS IRI. Choosing among
%   several is defined against openMINDS itself, so those tests run with
%   the model version the KG serves.

    properties (Constant, Access = private)
        KgIri = "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        OmIri = "https://openminds.om-i.org/instances/species/musMusculus"
    end

    methods (TestClassSetup)
        function pinOpenMindsVersion(testCase)
            originalVersion = openminds.version();
            openminds.version("v4.0");
            testCase.addTeardown(@() openminds.version(originalVersion));
        end
    end

    methods (Test)
        function testReturnsTheOpenMindsIri(testCase)
            node = testCase.createNode({char(testCase.OmIri), char(testCase.KgIri)});

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, testCase.OmIri)
        end

        function testOrderOfIdentifiersDoesNotMatter(testCase)
            node = testCase.createNode({char(testCase.KgIri), char(testCase.OmIri)});

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, testCase.OmIri)
        end

        function testReturnsEmptyWithoutIdentifierField(testCase)
            node = struct('at_id', char(testCase.KgIri));

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, "")
        end

        function testReturnsEmptyWhenOnlyTheKgIriIsListed(testCase)
            % Every node lists its own KG IRI; on its own that is not an
            % openMINDS identity.
            node = testCase.createNode({char(testCase.KgIri)});

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, "")
        end

        function testIgnoresMalformedOpenMindsIri(testCase)
            node = testCase.createNode({...
                'https://openminds.om-i.org/controlledTerms/programmingLanguage/AMPL', ...
                char(testCase.KgIri)});

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, "")
        end

        function testAcceptsScalarCharIdentifier(testCase)
            % jsondecode yields a char rather than a cell for a single value
            node = testCase.createNode(char(testCase.OmIri));

            iri = omkg.internal.conversion.getControlledInstanceIRI(node);

            testCase.verifyEqual(iri, testCase.OmIri)
        end

        function testChoosesTheSpellingOpenMindsKnowsAmongAliases(testCase)
            % A corrected spelling is kept next to the superseded one on the
            % same node; the one in CONTROLLED_INSTANCES wins, whichever
            % order the KG lists them in.
            aliases = {...
                'https://openminds.om-i.org/instances/contributionType/dataManagment', ...
                'https://openminds.om-i.org/instances/contributionType/dataManagement'};

            for order = {aliases, fliplr(aliases)}
                node = testCase.createNode(order{1});
                iri = omkg.internal.conversion.getControlledInstanceIRI(node);
                testCase.verifyEqual(iri, ...
                    "https://openminds.om-i.org/instances/contributionType/dataManagement")
            end
        end
    end

    methods (Access = private)
        function node = createNode(testCase, identifiers)
            node = struct(...
                'at_id', char(testCase.KgIri), ...
                'at_type', 'https://openminds.om-i.org/types/Species', ...
                'http___schema_org_identifier', {identifiers});
        end
    end
end
