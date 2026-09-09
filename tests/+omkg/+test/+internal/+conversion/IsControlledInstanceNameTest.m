classdef IsControlledInstanceNameTest < matlab.unittest.TestCase
% IsControlledInstanceNameTest - Unit tests for isControlledInstanceName
%
%   The function under test answers whether the active openMINDS version
%   declares the instance an IRI names. Its contract is defined against
%   the generated CONTROLLED_INSTANCES constants, so these tests run with a
%   pinned openMINDS version and use names taken from those constants.

    properties (Constant, Access = private)
        InstancePrefix = "https://openminds.om-i.org/instances/"
        LegacyInstancePrefix = "https://openminds.ebrains.eu/instances/"
    end

    properties (Access = private)
        OriginalOpenMindsVersion
    end

    methods (TestClassSetup)
        function pinOpenMindsVersion(testCase)
            testCase.OriginalOpenMindsVersion = openminds.version();
            openminds.version("v4.0");
            testCase.addTeardown(@() ...
                openminds.version(testCase.OriginalOpenMindsVersion));
        end
    end

    methods (Test)
        function testDeclaredNameIsRecognised(testCase)
            iri = testCase.InstancePrefix + "biologicalSex/male";

            testCase.verifyTrue(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testUndeclaredNameIsNotRecognised(testCase)
            iri = testCase.InstancePrefix + "biologicalSex/notAnInstanceInTheLibrary";

            testCase.verifyFalse(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testNameIsMatchedExactly(testCase)
            % openMINDS resolves names without regard to case, but the
            % Knowledge Graph lists case variants of one name as aliases of
            % a single instance, and only an exact match can tell which of
            % them is the library's spelling.
            iri = testCase.InstancePrefix + "molecularEntity/Halothane";

            testCase.verifyFalse(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testSchemaVersionOfIriDoesNotMatter(testCase)
            % A name is declared for its type, not for a namespace: the
            % Knowledge Graph may still hand out an IRI of another version.
            iri = testCase.LegacyInstancePrefix + "biologicalSex/male";

            testCase.verifyTrue(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testUnknownTypeIsNotRecognised(testCase)
            % A type absent from the active openMINDS version must not throw.
            iri = testCase.InstancePrefix + "notAType/male";

            testCase.verifyFalse(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testIriThatNamesNoInstanceIsNotRecognised(testCase)
            iri = "https://openminds.om-i.org/types/BiologicalSex";

            testCase.verifyFalse(omkg.internal.conversion.isControlledInstanceName(iri))
        end

        function testAnswersPerIri(testCase)
            iris = testCase.InstancePrefix + [ ...
                "biologicalSex/male", ...
                "biologicalSex/notAnInstanceInTheLibrary", ...
                "biologicalSex/female"];

            tf = omkg.internal.conversion.isControlledInstanceName(iris);

            testCase.verifyEqual(tf, [true, false, true])
        end
    end
end
