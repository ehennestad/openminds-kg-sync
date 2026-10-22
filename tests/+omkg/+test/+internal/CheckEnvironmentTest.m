classdef CheckEnvironmentTest < matlab.unittest.TestCase
% CheckEnvironmentTest - Unit tests for omkg.internal.checkEnvironment
%
%   The class fixture activates the openMINDS version the preference is
%   pinned to, so the active version is known whatever the session started
%   on (a fresh openMINDS_MATLAB session reports "latest"). A mismatch is
%   then produced by pinning the preference to another version, which
%   exercises the check without switching the model version again.

    methods (TestClassSetup)
        function activatePinnedVersion(testCase)
            testCase.applyFixture(omkg.test.fixtures.KgOpenMindsVersionFixture());
        end
    end

    methods (TestMethodSetup)
        function isolatePreferences(testCase)
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
        end
    end

    methods (Test)
        function testPassesWhenActiveVersionIsPinned(testCase)
            testCase.verifyWarningFree(@() omkg.internal.checkEnvironment())
        end

        function testErrorsInsteadOfSwitchingVersion(testCase)
            activeVersion = openminds.version();
            omkg.setpref("KgOpenMINDSVersion", omkg.getpref("KgOpenMINDSVersion") + 1);

            testCase.verifyError(@() omkg.internal.checkEnvironment(), ...
                'OMKG:checkEnvironment:OpenMindsVersionMismatch')
            testCase.verifyEqual(openminds.version(), activeVersion, ...
                'checkEnvironment must not switch the openMINDS version')
        end

        function testErrorNamesBothVersionsAndTheSwitchCall(testCase)
            activeVersion = openminds.version();
            pinnedVersion = omkg.getpref("KgOpenMINDSVersion") + 1;
            omkg.setpref("KgOpenMINDSVersion", pinnedVersion);

            try
                omkg.internal.checkEnvironment()
                checkError = MException.empty();
            catch checkError
                % Inspected below
            end

            testCase.assertNotEmpty(checkError, 'Expected checkEnvironment to error')
            testCase.verifyEqual(string(checkError.identifier), ...
                "OMKG:checkEnvironment:OpenMindsVersionMismatch")
            testCase.verifySubstring(checkError.message, sprintf("v%d.0", pinnedVersion))
            testCase.verifySubstring(checkError.message, activeVersion)
            testCase.verifySubstring(checkError.message, sprintf("openminds.version(%d)", pinnedVersion))
            testCase.verifySubstring(checkError.message, "clear")
        end
    end
end
