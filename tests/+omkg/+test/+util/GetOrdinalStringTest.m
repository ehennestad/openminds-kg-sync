classdef GetOrdinalStringTest < matlab.unittest.TestCase
    % GetOrdinalStringTest - Unit tests for omkg.util.getOrdinalString
    
    methods (Test)
        function testFirst(testCase)
            result = omkg.util.getOrdinalString(1);
            testCase.verifyEqual(result, '1st');
        end
        
        function testSecond(testCase)
            result = omkg.util.getOrdinalString(2);
            testCase.verifyEqual(result, '2nd');
        end
        
        function testThird(testCase)
            result = omkg.util.getOrdinalString(3);
            testCase.verifyEqual(result, '3rd');
        end
        
        function testFourthAndBeyond(testCase)
            testCase.verifyEqual(omkg.util.getOrdinalString(4), '4th');
            testCase.verifyEqual(omkg.util.getOrdinalString(10), '10th');
            testCase.verifyEqual(omkg.util.getOrdinalString(100), '100th');
        end
    end
end
