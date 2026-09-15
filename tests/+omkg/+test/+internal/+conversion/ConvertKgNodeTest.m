classdef ConvertKgNodeTest < matlab.unittest.TestCase
    % ConvertKgNodeTest - Unit tests for convertKgNode function
    %
    % This test suite covers the conversion of Knowledge Graph nodes to
    % openMINDS format, including edge cases and error handling.

    methods (TestClassSetup)
        function setupTestEnvironment(testCase) %#ok<MANU>
            % Ensure openMINDS environment is available
            omkg.internal.checkEnvironment();
        end
    end

    %% Basic Conversion Tests
    methods (Test)
        function testConvertSimpleNode(testCase)
            % Test conversion of a simple node with basic properties
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                'https___openminds_ebrains_eu_vocab_givenName', 'John', ...
                'https___openminds_ebrains_eu_vocab_familyName', 'Doe');

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Converted node should be an openMINDS schema object');
            testCase.verifyTrue(strcmp(omNode.id, kgNode.x_id), ...
                'ID should be preserved');
        end

        function testConvertMultipleNodes(testCase)
            % Test conversion of multiple nodes in one call
            kgNodes = [...
                struct('x_id', 'https://kg.ebrains.eu/api/instances/test-1', ...
                       'x_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                       'https___openminds_ebrains_eu_vocab_givenName', 'John'), ...
                struct('x_id', 'https://kg.ebrains.eu/api/instances/test-2', ...
                       'x_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                       'https___openminds_ebrains_eu_vocab_givenName', 'Jane')];

            omNodes = omkg.internal.conversion.convertKgNode(kgNodes);

            testCase.verifyEqual(numel(omNodes), 2, ...
                'Should return same number of nodes');
        end

        function testConvertNodeWithUnsupportedProperty(testCase)
            % Test that unsupported properties trigger warnings
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___openminds_ebrains_eu_vocab_givenName', 'John', ...
                'https___openminds_ebrains_eu_vocab_unsupportedProperty', 'value');

            testCase.verifyWarning(...
                @() omkg.internal.conversion.convertKgNode(kgNode), ...
                'OMKG:ConvertKgNode:UnsupportedProperty', ...
                'Unsupported properties should trigger warning');
        end

        function testConvertNodeWithAtFormKeywords(testCase)
            % Test that nodes with at_-form keywords (at_id, at_type) convert
            % identically to nodes with jsondecode's x_-form keywords
            linkedNode = struct('at_id', 'https://kg.ebrains.eu/api/instances/linked-123');
            kgNode = struct(...
                'at_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'at_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                'https___openminds_ebrains_eu_vocab_givenName', 'John', ...
                'https___openminds_ebrains_eu_vocab_contactInformation', linkedNode);

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyClass(omNode, 'openminds.core.Person')
            testCase.verifyEqual(string(omNode.id), string(kgNode.at_id))
            testCase.verifyEqual(omNode.givenName, "John")
            testCase.verifyEqual(string(omNode.contactInformation.id), string(linkedNode.at_id), ...
                'Linked node should become an unresolved reference with the given id');
        end
    end

    %% Error Handling Tests
    methods (Test)
        function testConvertInvalidNodeType(testCase)
            % Test conversion with invalid node type
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://invalid.type/DoesNotExist');

            testCase.verifyError(...
                @() omkg.internal.conversion.convertKgNode(kgNode), ...
                'OPENMINDS_MATLAB:Validators:InvalidOpenMINDSIRI', ...
                'Should error on invalid type');
        end

        function testConvertWithWrongReferenceNodeType(testCase)
            % Test that providing wrong reference node type throws error
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', 'John');

            % Create a reference node of different type
            wrongReferenceNode = openminds.core.Organization(...
                'id', 'https://kg.ebrains.eu/api/instances/org-123');

            testCase.verifyError(...
                @() omkg.internal.conversion.convertKgNode(kgNode, wrongReferenceNode), ...
                'OMKG:ConvertKgNode:ReferenceNodeWrongType', ...
                'Should error when reference node type does not match');
        end

        function testConvertWithEmbeddedNodeError(testCase)
            % Test error handling when converting embedded nodes
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/parent-123', ...
                'x_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                'https___openminds_ebrains_eu_vocab_givenName', 'John', ...
                'https___openminds_ebrains_eu_vocab_affiliation', struct(...
                    'x_type', 'https://openminds.ebrains.eu/core/Affiliation', ...
                    'https___openminds_ebrains_eu_vocab_memberOf', 'Test'));
            testCase.verifyError(...
                @() omkg.internal.conversion.convertKgNode(kgNode), ...
                'OMKG:ConvertKGNode:ConversionFailed', ...
                'Should error with proper message for embedded node failures');
        end
    end

    %% Linked Node Tests
    methods (Test)
        function testConvertWithLinkedNode(testCase)
            % Test conversion of node with linked references
            linkedNode = struct('x_id', 'https://kg.ebrains.eu/api/instances/linked-123');

            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', {{'https://openminds.ebrains.eu/core/Person'}}, ...
                'https___openminds_ebrains_eu_vocab_givenName', 'John', ...
                'https___openminds_ebrains_eu_vocab_contactInformation', linkedNode);

            % Should create unresolved node reference
            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should create valid node even with unresolved links');

            linkedInstance = omNode.contactInformation;
            testCase.verifyEqual(string(linkedInstance.id), string(linkedNode.x_id))
            testCase.verifyTrue(linkedInstance.isReference(), ...
                'A linked node must be an explicit reference so it is resolved later and never saved as an empty node');
            testCase.verifyEqual(string(omNode.getUnresolvedLinkIdentifiers()), string(linkedNode.x_id), ...
                'The linked node should be reported as an unresolved link');
        end

        function testConvertLinksMixingControlledAndUnknownInstances(testCase)
            % A property such as studyTarget can hold a controlled term next
            % to an instance that exists only in the Knowledge Graph. Each
            % link is decided on its own: the controlled term becomes the
            % library instance, the other a reference. A link resolver may
            % not change the identifier of a reference, so this is the
            % only point where the controlled term can take its openMINDS
            % identity.
            epilepsyModelKgIri = 'https://kg.ebrains.eu/api/instances/ec1d39f3-411e-4a19-846b-e7a6d5a13306';
            unknownKgIri = 'https://kg.ebrains.eu/api/instances/00000000-0000-4000-8000-000000000001';
            cache = testCase.useOpenMindsIdentityWithTemporaryCache();
            cache.record(string(epilepsyModelKgIri), ...
                "https://openminds.om-i.org/instances/diseaseModel/epilepsyModel");
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/DatasetVersion', ...
                'https___openminds_ebrains_eu_vocab_studyTarget', ...
                    [struct('x_id', epilepsyModelKgIri), struct('x_id', unknownKgIri)]);

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            studyTargets = omNode.studyTarget;
            testCase.verifyEqual(numel(studyTargets), 2)

            controlledTerm = studyTargets(1).Instance;
            testCase.verifyClass(controlledTerm, 'openminds.controlledterms.DiseaseModel')
            testCase.verifyFalse(controlledTerm.isReference(), ...
                'A controlled term known to the identifier map should be the library instance')
            testCase.verifyTrue(endsWith(string(controlledTerm.id), "/diseaseModel/epilepsyModel"), ...
                'The library instance carries its openMINDS identifier')

            unknownInstance = studyTargets(2).Instance;
            testCase.verifyTrue(unknownInstance.isReference(), ...
                'A link not known to the identifier map stays a reference')
            testCase.verifyEqual(string(unknownInstance.id), string(unknownKgIri))

            testCase.verifyEqual(string(omNode.getUnresolvedLinkIdentifiers()), string(unknownKgIri), ...
                'Only the unknown link should remain unresolved')
        end

        function testControlledTermMissingFromLibraryStaysAReference(testCase)
            % The Knowledge Graph can hold a controlled term the local
            % library does not. Rather than fail the parent, the link
            % keeps its KG identifier and is resolved by download.
            kgIri = 'https://kg.ebrains.eu/api/instances/00000000-0000-4000-8000-00000000abcd';
            cache = testCase.useOpenMindsIdentityWithTemporaryCache();
            cache.record(string(kgIri), ...
                "https://openminds.om-i.org/instances/species/notAnInstanceInTheLibrary");
            kgNode = testCase.createSubjectKgNode(kgIri);

            omNode = testCase.verifyWarning(...
                @() omkg.internal.conversion.convertKgNode(kgNode), ...
                'OMKG:ConvertKgNode:ControlledInstanceNotInLibrary');

            testCase.verifyEqual(string(omNode.getUnresolvedLinkIdentifiers()), string(kgIri))
        end

        function testUnderKgIdentityPolicyLinksStayReferences(testCase)
            % Under "kg" identity the lookup is never consulted, even for a
            % term it holds, so every link keeps its KG identifier.
            kgIri = 'https://kg.ebrains.eu/api/instances/species-uuid';
            cache = testCase.useOpenMindsIdentityWithTemporaryCache();
            cache.record(string(kgIri), "https://openminds.om-i.org/instances/species/musMusculus");
            omkg.setpref("ControlledInstanceIdentity", "kg");

            omNode = omkg.internal.conversion.convertKgNode(testCase.createSubjectKgNode(kgIri));

            testCase.verifyEqual(string(omNode.getUnresolvedLinkIdentifiers()), string(kgIri))
        end

        function testConvertWithEmbeddedNode(testCase)
            % Test conversion of node with embedded child nodes
            embeddedNode = struct(...
                'x_type', 'https://openminds.ebrains.eu/core/Affiliation', ...
                'https___schema_org_memberOf', struct(...
                    'x_id', 'https://kg.ebrains.eu/api/instances/org-123'));

            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', 'John', ...
                'https___schema_org_affiliation', embeddedNode);

            % Should recursively convert embedded nodes
            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should handle embedded nodes');
        end

        function testConvertWithCellArrayOfLinkedNodes(testCase)
            % Test conversion with multiple linked nodes
            linkedNodes = {
                struct('x_id', 'https://kg.ebrains.eu/api/instances/linked-1')
                struct('x_id', 'https://kg.ebrains.eu/api/instances/linked-2')
            };

            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', 'John', ...
                'https___schema_org_affiliation', {linkedNodes});

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should handle arrays of linked nodes');
        end
    end

    %% Property Type Conversion Tests
    methods (Test)
        function testConvertCharProperty(testCase)
            % Test conversion of char properties
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', char('John'));

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should handle char properties');
        end

        function testConvertCharWithConversionPreference(testCase)
            % Test char to string conversion when preference is set
            originalPref = getpref('omkg', 'ConvertChar', false);
            setpref('omkg', 'ConvertChar', true);

            cleanupObj = onCleanup(@() setpref('omkg', 'ConvertChar', originalPref));

            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', char('John'));

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should convert char to string when preference is set');
        end

        function testConvertNumericProperty(testCase)
            % Test conversion of numeric properties
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/QuantitativeValue', ...
                'https___schema_org_value', 42.5);

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should handle numeric properties');
        end
    end

    %% Reference Node Tests
    methods (Test)
        function testConvertWithValidReferenceNode(testCase)
            % Test updating an existing node via reference
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', 'John', ...
                'https___schema_org_familyName', 'Doe');

            % Create reference node first
            referenceNode = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/test-123');

            omNode = omkg.internal.conversion.convertKgNode(kgNode, referenceNode);

            testCase.verifyEqual(omNode, referenceNode, ...
                'Should return the same reference node');
            testCase.verifyTrue(isa(omNode, 'openminds.core.Person'), ...
                'Should maintain correct type');
        end
    end

    %% Edge Cases
    methods (Test)
        function testConvertWithEmptyCellArray(testCase)
            % Test conversion with empty cell array properties
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/test-123', ...
                'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                'https___schema_org_givenName', 'John', ...
                'https___schema_org_affiliation', {{}});

            omNode = omkg.internal.conversion.convertKgNode(kgNode);

            testCase.verifyTrue(isa(omNode, 'openminds.Node'), ...
                'Should handle empty cell arrays');
        end

        function testConvertCellArrayOfNodes(testCase)
            % Test that cell array input is handled correctly
            kgNodes = {
                struct('x_id', 'https://kg.ebrains.eu/api/instances/test-1', ...
                       'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                       'https___schema_org_givenName', 'John')
                struct('x_id', 'https://kg.ebrains.eu/api/instances/test-2', ...
                       'x_type', 'https://openminds.ebrains.eu/core/Person', ...
                       'https___schema_org_givenName', 'Jane')
            };

            omNodes = omkg.internal.conversion.convertKgNode(kgNodes);

            testCase.verifyGreaterThanOrEqual(numel(omNodes), 2, ...
                'Should convert all nodes from cell array');
        end

        function testConvertWithParentNodeContext(testCase)
            % Test error message includes parent context
            parentNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/parent-123', ...
                'x_type', {{'https://openminds.ebrains.eu/core/Person'}});

            embeddedNode = struct(...
                'x_type', 'https://openminds.ebrains.eu/core/Affiliation', ...
                'https___openminds_ebrains_eu_vocab_memberOf', 'Test');

            try
                omkg.internal.conversion.convertKgNode(embeddedNode, ...
                    'ParentNode', parentNode);
                testCase.verifyFail('Should have thrown an error');
            catch ME
                testCase.verifyTrue(contains(ME.message, 'parent-123') || ...
                    contains(ME.message, 'Failed to create'), ...
                    'Error message should mention parent context');
            end
        end
    end

    methods (Access = private)
        function cache = useOpenMindsIdentityWithTemporaryCache(testCase)
            % Select the "openminds" identity policy against a temporary
            % cache file, with the user's real preferences restored after.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            cache = omkg.internal.ControlledInstanceCache.instance(...
                'Reset', true, 'File', fullfile(tempFolder.Folder, "cache.json"));
            testCase.addTeardown(@() ...
                omkg.internal.ControlledInstanceCache.instance('Reset', true));
        end
    end

    methods (Static, Access = private)
        function kgNode = createSubjectKgNode(speciesKgIri)
            kgNode = struct(...
                'x_id', 'https://kg.ebrains.eu/api/instances/subject-1', ...
                'x_type', {{'https://openminds.om-i.org/types/Subject'}}, ...
                'https___openminds_ebrains_eu_vocab_lookupLabel', 'mouse1', ...
                'https___openminds_ebrains_eu_vocab_species', struct('x_id', char(speciesKgIri)));
        end
    end
end
