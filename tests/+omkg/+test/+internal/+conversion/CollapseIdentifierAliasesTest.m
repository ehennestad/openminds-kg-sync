classdef CollapseIdentifierAliasesTest < matlab.unittest.TestCase
% CollapseIdentifierAliasesTest - Unit tests for collapseIdentifierAliases
%
%   Grouping the flat identifier pairs into one record per Knowledge Graph
%   instance is where the canonical identifier is chosen, so these tests
%   run with a pinned openMINDS version.

    properties (Constant, Access = private)
        InstancePrefix = "https://openminds.ebrains.eu/instances/"
    end

    methods (TestClassSetup)
        function pinOpenMindsVersion(testCase)
            originalVersion = openminds.version();
            openminds.version("v3.0");
            testCase.addTeardown(@() openminds.version(originalVersion));
        end
    end

    methods (Test)
        function testOneRecordPerKnowledgeGraphInstance(testCase)
            pairs = testCase.makePairs( ...
                ["kg:1", "kg:1", "kg:2"], ...
                testCase.InstancePrefix + [ ...
                    "contributionType/dataManagment", ...
                    "contributionType/dataManagement", ...
                    "biologicalSex/male"]);

            records = omkg.internal.conversion.collapseIdentifierAliases(pairs);

            testCase.verifyNumElements(records, 2)
            testCase.verifyEqual(sort(string({records.kg})), ["kg:1", "kg:2"])
        end

        function testCanonicalIsTheSpellingKnownToOpenMinds(testCase)
            pairs = testCase.makePairs(["kg:1", "kg:1"], ...
                testCase.InstancePrefix + [ ...
                    "contributionType/dataManagment", ...
                    "contributionType/dataManagement"]);

            records = omkg.internal.conversion.collapseIdentifierAliases(pairs);

            testCase.verifyEqual(records.om, ...
                testCase.InstancePrefix + "contributionType/dataManagement")
            testCase.verifyEqual(records.aliases, ...
                testCase.InstancePrefix + "contributionType/dataManagment")
        end

        function testChoiceIsIndependentOfInputOrder(testCase)
            omIds = testCase.InstancePrefix + [ ...
                "contributionType/dataManagment", "contributionType/dataManagement"];

            forward = omkg.internal.conversion.collapseIdentifierAliases(...
                testCase.makePairs(["kg:1", "kg:1"], omIds));
            reversed = omkg.internal.conversion.collapseIdentifierAliases(...
                testCase.makePairs(["kg:1", "kg:1"], flip(omIds)));

            testCase.verifyEqual(forward.om, reversed.om)
            testCase.verifyEqual(forward.aliases, reversed.aliases)
        end

        function testRecordWithoutAliasesHasEmptyAliasList(testCase)
            pairs = testCase.makePairs("kg:1", ...
                testCase.InstancePrefix + "biologicalSex/male");

            records = omkg.internal.conversion.collapseIdentifierAliases(pairs);

            testCase.verifyEmpty(records.aliases)
            testCase.verifyClass(records.aliases, 'string')
        end

        function testRepeatedIdentifierIsNotAnAlias(testCase)
            % The same instance is returned once per controlled type it is
            % listed under, which is a repeat rather than a second identifier.
            omId = testCase.InstancePrefix + "biologicalSex/male";
            pairs = testCase.makePairs(["kg:1", "kg:1", "kg:1"], [omId, omId, omId]);

            records = omkg.internal.conversion.collapseIdentifierAliases(pairs);

            testCase.verifyNumElements(records, 1)
            testCase.verifyEqual(records.om, omId)
            testCase.verifyEmpty(records.aliases)
        end

        function testWarnsWhenOpenMindsCannotDisambiguate(testCase)
            pairs = testCase.makePairs(["kg:1", "kg:1"], ...
                testCase.InstancePrefix + [ ...
                    "contributionType/zzzUnknown", "contributionType/aaaUnknown"]);

            testCase.verifyWarning(...
                @() omkg.internal.conversion.collapseIdentifierAliases(pairs), ...
                'OMKG:ControlledInstanceRegistry:AmbiguousIdentifiers')
        end

        function testDoesNotWarnWhenOpenMindsDecides(testCase)
            pairs = testCase.makePairs(["kg:1", "kg:1"], ...
                testCase.InstancePrefix + [ ...
                    "contributionType/dataManagment", ...
                    "contributionType/dataManagement"]);

            testCase.verifyWarningFree(...
                @() omkg.internal.conversion.collapseIdentifierAliases(pairs))
        end

        function testHandlesEmptyInput(testCase)
            records = omkg.internal.conversion.collapseIdentifierAliases(...
                struct('kg', {}, 'om', {}));

            testCase.verifyEmpty(records)
            testCase.verifyEqual(sort(string(fieldnames(records)))', ...
                ["aliases", "kg", "om"])
        end
    end

    methods (Test) % Against the resource shipped with the toolbox
        function testShippedResourceCollapsesToOneRecordPerInstance(testCase)
            seedPath = fullfile(omkg.toolboxdir(), 'omkg', '+omkg', '+internal', ...
                'resources', 'kg2om_identifier_lookup_v3.json');
            pairs = omkg.internal.conversion.removeInvalidIdentifierPairs(...
                jsondecode(fileread(seedPath)));

            records = omkg.internal.conversion.collapseIdentifierAliases(pairs);

            kgIds = string({records.kg});
            testCase.verifyEqual(numel(kgIds), numel(unique(kgIds)), ...
                'Each Knowledge Graph instance should appear exactly once')
            testCase.verifyLessThan(numel(records), numel(pairs), ...
                'Aliased instances should have been grouped')
        end
    end

    methods (Access = private)
        function pairs = makePairs(~, kgIds, omIds)
            pairs = struct('kg', num2cell(string(kgIds)), ...
                'om', num2cell(string(omIds)));
        end
    end
end
