classdef ConstantsTest < matlab.unittest.TestCase
% ConstantsTest - Tests for toolbox constants
%
% This test class covers:
% - Availability of required constants
% - Correct format of constant values
% - Integration with external dependencies

    methods (Test)

        function testKgInstanceIRIPrefix(testCase)
            % Test KG instance IRI prefix constant

            prefix = omkg.constants.KgInstanceIRIPrefix;

            testCase.verifyClass(prefix, 'string', ...
                'KgInstanceIRIPrefix should be a string');
            testCase.verifyTrue(strlength(prefix) > 0, ...
                'KgInstanceIRIPrefix should not be empty');
            testCase.verifyTrue(startsWith(prefix, "https://"), ...
                'KgInstanceIRIPrefix should be a valid HTTPS URL');
            testCase.verifyTrue(contains(prefix, "kg.ebrains.eu"), ...
                'KgInstanceIRIPrefix should reference EBRAINS KG');
        end

        function testKgNamespaceIRI(testCase)
            % Test KG namespace IRI constant

            namespace = omkg.constants.KgNamespaceIRI;

            testCase.verifyClass(namespace, 'string', ...
                'KgNamespaceIRI should be a string');
            testCase.verifyTrue(strlength(namespace) > 0, ...
                'KgNamespaceIRI should not be empty');
            testCase.verifyTrue(startsWith(namespace, "https://"), ...
                'KgNamespaceIRI should be a valid HTTPS URL');
        end

        function testOpenMINDSConstants(testCase)
            % Test OpenMINDS-specific constants

            omNamespace = omkg.constants.OpenMINDSNamespaceIRI;
            omPrefix = omkg.constants.OpenMINDSInstanceIRIPrefix;

            testCase.verifyClass(omNamespace, 'string', ...
                'OpenMINDSNamespaceIRI should be a string');
            testCase.verifyTrue(any(contains(omNamespace, "openminds.ebrains.eu")), ...
                'OpenMINDSNamespaceIRI should include the v3-and-below namespace');
            testCase.verifyTrue(any(contains(omNamespace, "openminds.om-i.org")), ...
                'OpenMINDSNamespaceIRI should include the v4-and-above namespace');

            testCase.verifyClass(omPrefix, 'string', ...
                'OpenMINDSInstanceIRIPrefix should be a string');
            testCase.verifyTrue(any(contains(omPrefix, "openminds.ebrains.eu")), ...
                'OpenMINDSInstanceIRIPrefix should include the v3-and-below namespace');
            testCase.verifyTrue(any(contains(omPrefix, "openminds.om-i.org")), ...
                'OpenMINDSInstanceIRIPrefix should include the v4-and-above namespace');
        end

        function testOpenMINDSTypeIRIPrefix(testCase)
            % Test the type (@type) IRI prefix constant
            %
            % v3-and-below uses distinct "controlledTerms/" and "core/"
            % segments; v4-and-above collapses both into "types/".

            typePrefix = omkg.constants.OpenMINDSTypeIRIPrefix;

            testCase.verifyClass(typePrefix, 'string', ...
                'OpenMINDSTypeIRIPrefix should be a string');
            testCase.verifyTrue(any(strcmp(typePrefix, "https://openminds.ebrains.eu/controlledTerms/")), ...
                'OpenMINDSTypeIRIPrefix should include the v3-and-below controlledTerms namespace');
            testCase.verifyTrue(any(strcmp(typePrefix, "https://openminds.om-i.org/types/")), ...
                'OpenMINDSTypeIRIPrefix should include the v4-and-above types namespace');
        end

        function testConstantRelationships(testCase)
            % Test relationships between constants

            kgNamespace = omkg.constants.KgNamespaceIRI;
            kgPrefix = omkg.constants.KgInstanceIRIPrefix;

            % KG instance prefix should be based on KG namespace
            testCase.verifyTrue(startsWith(kgPrefix, kgNamespace), ...
                'KgInstanceIRIPrefix should start with KgNamespaceIRI');
        end
    end
end
