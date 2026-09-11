classdef GetControlledInstanceTest < matlab.unittest.TestCase
% GetControlledInstanceTest - Unit tests for omkg.internal.conversion.getControlledInstance

    properties (Constant)
        V3Iri = "https://openminds.ebrains.eu/instances/species/musMusculus"
        V4Iri = "https://openminds.om-i.org/instances/species/musMusculus"
    end

    methods (TestClassSetup)
        function setupEnvironment(~)
            omkg.internal.checkEnvironment()
        end
    end

    methods (Test)
        function testReturnsLibraryInstanceForEitherNamespace(testCase)
            % The identifier map may hold IRIs of the v3 or the v4
            % namespace. Both name the same library instance, which is
            % identified in the namespace of the active model version.
            fromV3 = omkg.internal.conversion.getControlledInstance(testCase.V3Iri);
            fromV4 = omkg.internal.conversion.getControlledInstance(testCase.V4Iri);

            testCase.verifyClass(fromV3, 'openminds.controlledterms.Species')
            testCase.verifyEqual(fromV3.name, "Mus musculus")
            testCase.verifyEqual(string(fromV3.id), string(fromV4.id))
            testCase.verifyTrue(startsWith(string(fromV3.id), openminds.constant.BaseIRI()), ...
                'The instance should be identified in the namespace of the active model version')
        end
    end
end
