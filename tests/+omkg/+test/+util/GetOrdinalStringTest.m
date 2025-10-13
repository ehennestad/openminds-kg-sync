classdef GetOrdinalStringTest < matlab.unittest.TestCase
    % GetOrdinalStringTest - Unit tests for omkg.util.getOrdinalNumberString

    methods (Test)
        function testFirst(testCase)
            result = omkg.util.getOrdinalNumberString(1);
            testCase.verifyEqual(result, '1st');
        end

        function testSecond(testCase)
            result = omkg.util.getOrdinalNumberString(2);
            testCase.verifyEqual(result, '2nd');
        end

        function testThird(testCase)
            result = omkg.util.getOrdinalNumberString(3);
            testCase.verifyEqual(result, '3rd');
        end

        function testFourthAndBeyond(testCase)
            testCase.verifyEqual(omkg.util.getOrdinalNumberString(4), '4th');
            testCase.verifyEqual(omkg.util.getOrdinalNumberString(10), '10th');
            testCase.verifyEqual(omkg.util.getOrdinalNumberString(100), '100th');
        end
    end
end
