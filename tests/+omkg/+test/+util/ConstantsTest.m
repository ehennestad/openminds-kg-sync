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
            testCase.verifyTrue(contains(omNamespace, "openminds.ebrains.eu"), ...
                'OpenMINDSNamespaceIRI should reference openMINDS');

            testCase.verifyClass(omPrefix, 'string', ...
                'OpenMINDSInstanceIRIPrefix should be a string');
            testCase.verifyTrue(contains(omPrefix, "openminds.ebrains.eu"), ...
                'OpenMINDSInstanceIRIPrefix should reference openMINDS');
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
