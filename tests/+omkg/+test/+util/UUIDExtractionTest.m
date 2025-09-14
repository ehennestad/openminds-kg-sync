classdef UUIDExtractionTest < matlab.unittest.TestCase
% UUIDExtractionTest - Tests for UUID extraction utility functions
%
% This test class covers:
% - UUID extraction from bare identifiers
% - UUID extraction from prefixed identifiers
% - Edge cases and error handling

    properties
        TestUUID
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TestUUID = "550e8400-e29b-41d4-a716-446655440000";
        end
    end
    
    methods (Test)
        
        function testUUIDExtractionFromBareUUID(testCase)
            % Test extraction from bare UUID (should return same)
            
            extracted = omkg.util.getIdentifierUUID(testCase.TestUUID);
            testCase.verifyEqual(extracted, testCase.TestUUID, ...
                'Should return same UUID when no prefix');
        end
        
        function testUUIDExtractionFromPrefixedUUID(testCase)
            % Test extraction from KG-prefixed UUID
            
            kgPrefix = omkg.constants.KgInstanceIRIPrefix;
            prefixedUUID = kgPrefix + "/" + testCase.TestUUID;
            extracted = omkg.util.getIdentifierUUID(prefixedUUID);
            testCase.verifyEqual(extracted, testCase.TestUUID, ...
                'Should extract UUID from prefixed identifier');
        end
        
        function testUUIDExtractionEdgeCases(testCase)
            % Test edge cases for UUID extraction
            
            % Test with different UUID formats
            testUUIDs = {
                "6ba7b810-9dad-11d1-80b4-00c04fd430c8", ...
                "6ba7b811-9dad-11d1-80b4-00c04fd430c9"
            };
            
            kgPrefix = omkg.constants.KgInstanceIRIPrefix;
            
            for i = 1:length(testUUIDs)
                uuid = testUUIDs{i};
                prefixed = kgPrefix + "/" + uuid;
                extracted = omkg.util.getIdentifierUUID(prefixed);
                testCase.verifyEqual(extracted, uuid, ...
                    sprintf('Should extract UUID %d correctly', i));
            end
        end
    end
end
