classdef GetPropertyValuesTest < matlab.unittest.TestCase
% GetPropertyValuesTest - Unit tests for omkg.internal.getPropertyValues
%
%   The function decides which of an instance's properties carry a value
%   worth copying onto another instance. The cases below are the shapes an
%   unset openMINDS property takes, and the one that isempty gets wrong.

    methods (TestClassSetup)
        function setupEnvironment(~)
            omkg.internal.checkEnvironment()
        end
    end

    methods (Test)
        function testUnsetScalarStringIsLeftOut(testCase)
            % An unset (1,1) string property holds "", which is a 1-by-1
            % string: isempty reports false for it. It must still count as
            % holding no value.
            term = openminds.controlledterms.Species();
            term.name = "Mus musculus";

            [names, values] = omkg.internal.getPropertyValues(term);

            testCase.verifyEqual(names, {'name'})
            testCase.verifyEqual(values, {"Mus musculus"})
        end

        function testUnsetListIsLeftOut(testCase)
            % An unset (1,:) string property is string.empty, which
            % isempty does report. Covered so the two shapes stay aligned.
            term = openminds.controlledterms.Species();
            term.name = "Mus musculus";

            names = omkg.internal.getPropertyValues(term);

            testCase.verifyFalse(any(strcmp(names, 'synonym')))
        end

        function testPopulatedListIsKept(testCase)
            term = openminds.controlledterms.Species();
            term.name = "Mus musculus";
            term.synonym = ["mouse", "house mouse"];

            [names, values] = omkg.internal.getPropertyValues(term);

            testCase.verifyEqual(sort(names), sort({'name', 'synonym'}))
            testCase.verifyEqual(values{strcmp(names, 'synonym')}, ["mouse", "house mouse"])
        end

        function testMissingStringIsLeftOut(testCase)
            term = openminds.controlledterms.Species();
            term.name = "Mus musculus";
            term.definition = string(missing);

            names = omkg.internal.getPropertyValues(term);

            testCase.verifyFalse(any(strcmp(names, 'definition')))
        end
    end
end
