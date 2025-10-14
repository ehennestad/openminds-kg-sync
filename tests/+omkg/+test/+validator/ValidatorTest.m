classdef ValidatorTest < matlab.unittest.TestCase
% ValidatorTest - Tests for validation functions
%
% This test class covers:
% - KG identifier validation
% - UUID format validation
% - Prefixed identifier validation
% - Error handling for invalid inputs

    methods (Test)

        function testValidUUIDs(testCase)
            % Test that valid UUIDs are accepted

            validUUIDs = [
                "550e8400-e29b-41d4-a716-446655440000";
                "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
                "12345678-1234-5678-9abc-123456789012"
            ];

            for i = 1:length(validUUIDs)
                testCase.verifyWarningFree(...
                    @() omkg.validator.mustBeValidKGIdentifier(validUUIDs(i)), ...
                    sprintf('Should accept valid UUID: %s', validUUIDs(i)));
            end
        end

        function testInvalidUUIDs(testCase)
            % Test that invalid UUIDs are rejected

            invalidUUIDs = ["not-a-uuid"; "123"; ""];

            for i = 1:length(invalidUUIDs)
                testCase.verifyError(...
                    @() omkg.validator.mustBeValidKGIdentifier(invalidUUIDs(i)), ...
                    "OMKG:validator:InvalidUUID", ...
                    sprintf('Should reject invalid UUID: %s', invalidUUIDs(i)));
            end
        end

        function testPrefixedIdentifiers(testCase)
            % Test validation of KG-prefixed identifiers

            baseUUID = "550e8400-e29b-41d4-a716-446655440000";
            kgPrefix = omkg.constants.KgInstanceIRIPrefix;
            prefixedUUID = kgPrefix + "/" + baseUUID;

            % Both forms should be valid
            testCase.verifyWarningFree(...
                @() omkg.validator.mustBeValidKGIdentifier(baseUUID), ...
                'Should accept bare UUID');

            testCase.verifyWarningFree(...
                @() omkg.validator.mustBeValidKGIdentifier(prefixedUUID), ...
                'Should accept KG-prefixed UUID');
        end

        function testEdgeCases(testCase)
            % Test edge cases for validator

            % Test different valid UUID formats
            edgeCaseUUIDs = [
                "00000000-0000-0000-0000-000000000000";  % All zeros
                "ffffffff-ffff-ffff-ffff-ffffffffffff";  % All f's
                "12345678-9abc-def0-1234-56789abcdef0"   % Mixed case
            ];

            for i = 1:length(edgeCaseUUIDs)
                testCase.verifyWarningFree(...
                    @() omkg.validator.mustBeValidKGIdentifier(edgeCaseUUIDs(i)), ...
                    sprintf('Should accept edge case UUID: %s', edgeCaseUUIDs(i)));
            end
        end
    end
end
