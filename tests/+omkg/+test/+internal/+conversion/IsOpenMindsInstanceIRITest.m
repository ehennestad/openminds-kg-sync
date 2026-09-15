classdef IsOpenMindsInstanceIRITest < matlab.unittest.TestCase
% IsOpenMindsInstanceIRITest - Unit tests for isOpenMindsInstanceIRI
%
%   The function under test decides purely on the shape of an IRI, which
%   is the shape openminds.utility.parseInstanceIRI accepts. The rejected
%   shapes below are the ones found in the map that used to ship with the
%   toolbox; each of them throws once it reaches openminds.instanceFromIRI.

    methods (Test)
        function testAcceptsWellFormedIri(testCase)
            tf = omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://openminds.om-i.org/instances/biologicalSex/male");

            testCase.verifyTrue(tf)
        end

        function testAcceptsEitherNamespace(testCase)
            tf = omkg.internal.conversion.isOpenMindsInstanceIRI([...
                "https://openminds.ebrains.eu/instances/biologicalSex/male", ...
                "https://openminds.om-i.org/instances/biologicalSex/male"]);

            testCase.verifyEqual(tf, [true true])
        end

        function testAcceptsTypeAbsentFromOpenMinds(testCase)
            % Whether the type exists is version dependent and not this
            % function's concern; only the shape is checked.
            tf = omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://openminds.om-i.org/instances/notAType/notAnInstance");

            testCase.verifyTrue(tf)
        end

        function testRejectsEmptyIri(testCase)
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(""))
        end

        function testRejectsIriOutsideOpenMindsNamespace(testCase)
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://example.org/instances/biologicalSex/male"))
        end

        function testRejectsKnowledgeGraphIri(testCase)
            % schema:identifier lists the KG's own IRI next to the openMINDS
            % one; it must never be taken for an openMINDS identity.
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
        end

        function testRejectsIriWithoutInstancesSegment(testCase)
            % A type path where an instance path belongs; parseInstanceIRI
            % asserts on it.
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://openminds.ebrains.eu/controlledTerms/programmingLanguage/AMPL"))
        end

        function testRejectsInstanceNameContainingSlash(testCase)
            % The KG does not escape "/" in instance names, so this can not
            % be split into a type and a name unambiguously.
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://openminds.ebrains.eu/instances/molecularEntity/GABA-A/BZ"))
        end

        function testRejectsTypeIri(testCase)
            testCase.verifyFalse(omkg.internal.conversion.isOpenMindsInstanceIRI(...
                "https://openminds.om-i.org/types/Species"))
        end

        function testReturnsRowForAnyShape(testCase)
            iris = [...
                "https://openminds.om-i.org/instances/biologicalSex/male"
                ""
                "https://openminds.om-i.org/instances/biologicalSex/female"];

            tf = omkg.internal.conversion.isOpenMindsInstanceIRI(iris);

            testCase.verifyEqual(tf, [true false true])
        end

        function testHandlesEmptyInput(testCase)
            tf = omkg.internal.conversion.isOpenMindsInstanceIRI(string.empty);

            testCase.verifyEmpty(tf)
            testCase.verifyClass(tf, 'logical')
        end
    end
end
