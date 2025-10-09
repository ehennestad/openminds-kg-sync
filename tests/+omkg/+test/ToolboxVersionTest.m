classdef ToolboxVersionTest < matlab.unittest.TestCase
    % ToolboxVersionTest - Unit tests for omkg.toolboxversion

    methods (Test)
        function testReturnsNonEmptyString(testCase)
            versionStr = omkg.toolboxversion();
            testCase.verifyNotEmpty(versionStr);
        end

        function testReturnsCharArray(testCase)
            versionStr = omkg.toolboxversion();
            testCase.verifyClass(versionStr, 'char');
        end

        function testVersionFormatValid(testCase)
            versionStr = omkg.toolboxversion();

            % Should match "Version X.Y.Z" or "Version X.Y.Z.W"
            testCase.verifyTrue(startsWith(versionStr, 'Version '), ...
                'Version string should start with "Version "');

            % Extract numeric part
            numericPart = extractAfter(versionStr, 'Version ');

            % Should have at least X.Y.Z format
            parts = split(numericPart, '.');
            testCase.verifyGreaterThanOrEqual(numel(parts), 3, ...
                'Version should have at least major.minor.patch format');
        end
    end
end
