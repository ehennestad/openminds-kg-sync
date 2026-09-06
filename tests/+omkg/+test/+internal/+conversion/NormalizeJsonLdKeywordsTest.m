classdef NormalizeJsonLdKeywordsTest < matlab.unittest.TestCase
% NormalizeJsonLdKeywordsTest - Unit tests for normalizeJsonLdKeywords
%
%   Covers renaming of jsondecode's x_-form JSON-LD keyword fields to the
%   at_ form used by openMINDS_MATLAB, including nested and array payloads.

    methods (Test)
        function testRenamesTopLevelKeywords(testCase)
            node = struct('x_id', 'id-1', 'x_type', 'Type', 'name', 'value');

            result = omkg.internal.conversion.normalizeJsonLdKeywords(node);

            testCase.verifyEqual(fieldnames(result), {'at_id'; 'at_type'; 'name'})
            testCase.verifyEqual(result.at_id, 'id-1')
            testCase.verifyEqual(result.at_type, 'Type')
            testCase.verifyEqual(result.name, 'value')
        end

        function testRenamesNestedKeywords(testCase)
            node = struct(...
                'x_id', 'parent', ...
                'linked', struct('x_id', 'child'), ...
                'embedded', struct('x_type', 'Embedded', 'inner', struct('x_id', 'grandchild')));

            result = omkg.internal.conversion.normalizeJsonLdKeywords(node);

            testCase.verifyEqual(result.linked.at_id, 'child')
            testCase.verifyEqual(result.embedded.at_type, 'Embedded')
            testCase.verifyEqual(result.embedded.inner.at_id, 'grandchild')
        end

        function testPreservesStructArrayShape(testCase)
            nodes = struct('x_id', {'a', 'b', 'c'}, 'value', {1, 2, 3});

            result = omkg.internal.conversion.normalizeJsonLdKeywords(nodes);

            testCase.verifySize(result, [1, 3])
            testCase.verifyEqual({result.at_id}, {'a', 'b', 'c'})
            testCase.verifyEqual([result.value], [1, 2, 3])
        end

        function testRenamesWithinCellArrays(testCase)
            nodes = {struct('x_id', 'a'), struct('x_type', 'T', 'x_id', 'b')};

            result = omkg.internal.conversion.normalizeJsonLdKeywords(nodes);

            testCase.verifyClass(result, 'cell')
            testCase.verifyEqual(result{1}.at_id, 'a')
            testCase.verifyEqual(result{2}.at_type, 'T')
            testCase.verifyEqual(result{2}.at_id, 'b')
        end

        function testAtFormInputIsUnchanged(testCase)
            node = struct('at_id', 'id-1', 'at_type', 'Type', 'linked', struct('at_id', 'x'));

            result = omkg.internal.conversion.normalizeJsonLdKeywords(node);

            testCase.verifyEqual(result, node)
        end

        function testNonKeywordFieldsAreUntouched(testCase)
            % Only JSON-LD keywords are renamed, not arbitrary x_-prefixed names
            node = struct('x_id', 'id-1', 'x_custom', 'keep', 'https___openminds_ebrains_eu_vocab_name', 'n');

            result = omkg.internal.conversion.normalizeJsonLdKeywords(node);

            testCase.verifyTrue(isfield(result, 'x_custom'))
            testCase.verifyTrue(isfield(result, 'https___openminds_ebrains_eu_vocab_name'))
            testCase.verifyFalse(isfield(result, 'x_id'))
        end

        function testNonStructValuesPassThrough(testCase)
            testCase.verifyEqual(omkg.internal.conversion.normalizeJsonLdKeywords(42), 42)
            testCase.verifyEqual(omkg.internal.conversion.normalizeJsonLdKeywords('text'), 'text')
            testCase.verifyEqual(omkg.internal.conversion.normalizeJsonLdKeywords([]), [])
        end

        function testEmptyStructArrayKeepsRenamedFields(testCase)
            nodes = struct('x_id', {});

            result = omkg.internal.conversion.normalizeJsonLdKeywords(nodes);

            testCase.verifyEmpty(result)
            testCase.verifyEqual(fieldnames(result), {'at_id'})
        end
    end
end
