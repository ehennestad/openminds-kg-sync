classdef HasControlledInstanceTest < matlab.unittest.TestCase
% HasControlledInstanceTest - Unit tests for omkg.internal.conversion.hasControlledInstance

    properties (Constant)
        V3SpeciesIri = "https://openminds.ebrains.eu/instances/species/musMusculus"
        V4SpeciesIri = "https://openminds.om-i.org/instances/species/musMusculus"
    end

    methods (TestClassSetup)
        function setupEnvironment(~)
            omkg.internal.checkEnvironment()
        end
    end

    methods (Test)
        function testTrueForLibraryInstanceInEitherNamespace(testCase)
            testCase.verifyTrue( ...
                omkg.internal.conversion.hasControlledInstance(testCase.V3SpeciesIri))
            testCase.verifyTrue( ...
                omkg.internal.conversion.hasControlledInstance(testCase.V4SpeciesIri))
        end

        function testFalseForTypeWithoutLibraryInstances(testCase)
            % The KG links to a viewer specification's display colour by an
            % IRI in the openMINDS instance namespace. SingleColor is a
            % regular type with no entries in the instance library.
            colorIri = "https://openminds.ebrains.eu/instances/singleColor/#FF909F";
            testCase.verifyFalse( ...
                omkg.internal.conversion.hasControlledInstance(colorIri))
        end

        function testFalseForUnknownInstanceOfLibraryType(testCase)
            unknownSpeciesIri = "https://openminds.om-i.org/instances/species/notASpecies";
            testCase.verifyFalse( ...
                omkg.internal.conversion.hasControlledInstance(unknownSpeciesIri))
        end

        function testFalseForUnknownTypeSegment(testCase)
            unknownTypeIri = "https://openminds.om-i.org/instances/notAType/someName";
            testCase.verifyFalse( ...
                omkg.internal.conversion.hasControlledInstance(unknownTypeIri))
        end

        function testFalseForKgIdentifier(testCase)
            kgIri = "https://kg.ebrains.eu/api/instances/00000000-0000-4000-8000-000000000001";
            testCase.verifyFalse( ...
                omkg.internal.conversion.hasControlledInstance(kgIri))
        end
    end
end
