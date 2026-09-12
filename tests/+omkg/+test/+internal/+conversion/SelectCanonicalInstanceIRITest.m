classdef SelectCanonicalInstanceIRITest < matlab.unittest.TestCase
% SelectCanonicalInstanceIRITest - Unit tests for selectCanonicalInstanceIRI
%
%   The function under test decides which of several openMINDS schema
%   identifiers the Knowledge Graph lists for one instance should be used.
%   Its contract is defined against openMINDS itself, so these tests run
%   with a pinned openMINDS version and use instance names taken from the
%   generated CONTROLLED_INSTANCES constants.

    properties (Constant, Access = private)
        InstancePrefix = "https://openminds.om-i.org/instances/"
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
        function testReturnsSoleCandidateUnchanged(testCase)
            iri = testCase.InstancePrefix + "biologicalSex/male";

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(iri);

            testCase.verifyEqual(canonicalIRI, iri)
            testCase.verifyTrue(isResolved)
        end

        function testPrefersSpellingKnownToOpenMinds(testCase)
            % "metadataManagment" is a legacy misspelling that the Knowledge
            % Graph still carries. openMINDS resolves it to an empty
            % instance with only a warning, so picking it fails silently.
            candidates = testCase.InstancePrefix + [ ...
                "contributionType/metadataManagment", ...
                "contributionType/metadataManagement"];

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);

            testCase.verifyEqual(canonicalIRI, ...
                testCase.InstancePrefix + "contributionType/metadataManagement")
            testCase.verifyTrue(isResolved)
        end

        function testPrefersCaseKnownToOpenMinds(testCase)
            candidates = testCase.InstancePrefix + [ ...
                "molecularEntity/Halothane", "molecularEntity/halothane"];

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);

            testCase.verifyEqual(canonicalIRI, ...
                testCase.InstancePrefix + "molecularEntity/halothane")
            testCase.verifyTrue(isResolved)
        end

        function testChoiceIsIndependentOfInputOrder(testCase)
            candidates = testCase.InstancePrefix + [ ...
                "contributionType/dataManagment", "contributionType/dataManagement"];

            forwardChoice = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);
            reversedChoice = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(flip(candidates));

            testCase.verifyEqual(forwardChoice, reversedChoice)
        end
    end

    methods (Test) % Fallback behaviour
        function testFallsBackWhenNoCandidateIsKnown(testCase)
            candidates = testCase.InstancePrefix + [ ...
                "contributionType/zzzUnknown", "contributionType/aaaUnknown"];

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);

            testCase.verifyFalse(isResolved)
            testCase.verifyEqual(canonicalIRI, ...
                testCase.InstancePrefix + "contributionType/aaaUnknown", ...
                'Should fall back to the alphabetically first candidate')
        end

        function testFallsBackWhenSeveralCandidatesAreKnown(testCase)
            % Two names openMINDS recognises give no basis for a choice.
            candidates = testCase.InstancePrefix + [ ...
                "contributionType/dataManagement", "contributionType/dataCollection"];

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);

            testCase.verifyFalse(isResolved)
            testCase.verifyEqual(canonicalIRI, ...
                testCase.InstancePrefix + "contributionType/dataCollection")
        end

        function testFallsBackWhenTypeIsUnknownToOpenMinds(testCase)
            % Types absent from the active openMINDS version must not throw.
            candidates = testCase.InstancePrefix + [ ...
                "notAType/second", "notAType/first"];

            [canonicalIRI, isResolved] = ...
                omkg.internal.conversion.selectCanonicalInstanceIRI(candidates);

            testCase.verifyFalse(isResolved)
            testCase.verifyEqual(canonicalIRI, ...
                testCase.InstancePrefix + "notAType/first")
        end
    end
end
