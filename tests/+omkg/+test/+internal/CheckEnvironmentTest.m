classdef CheckEnvironmentTest < matlab.unittest.TestCase
% CheckEnvironmentTest - Unit tests for omkg.internal.checkEnvironment
%
%   The active openMINDS version is never changed by these tests: a
%   mismatch is produced by pinning the preference to a version other than
%   the active one, which exercises the check without touching the host
%   session's model version.

    methods (TestMethodSetup)
        function isolatePreferences(testCase)
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
        end
    end

    methods (Test)
        function testPassesWhenActiveVersionIsPinned(testCase)
            omkg.setpref("KgOpenMINDSVersion", activeMajorVersion());

            testCase.verifyWarningFree(@() omkg.internal.checkEnvironment())
        end

        function testErrorsInsteadOfSwitchingVersion(testCase)
            activeVersion = openminds.version();
            omkg.setpref("KgOpenMINDSVersion", activeMajorVersion() + 1);

            testCase.verifyError(@() omkg.internal.checkEnvironment(), ...
                'OMKG:checkEnvironment:OpenMindsVersionMismatch')
            testCase.verifyEqual(openminds.version(), activeVersion, ...
                'checkEnvironment must not switch the openMINDS version')
        end

        function testErrorNamesBothVersionsAndTheSwitchCall(testCase)
            pinnedVersion = activeMajorVersion() + 1;
            omkg.setpref("KgOpenMINDSVersion", pinnedVersion);

            ME = testCase.verifyError(@() omkg.internal.checkEnvironment(), ...
                'OMKG:checkEnvironment:OpenMindsVersionMismatch');

            testCase.verifySubstring(ME.message, sprintf("v%d.0", pinnedVersion))
            testCase.verifySubstring(ME.message, openminds.version())
            testCase.verifySubstring(ME.message, sprintf("openminds.version(%d)", pinnedVersion))
            testCase.verifySubstring(ME.message, "clear")
        end
    end
end

function major = activeMajorVersion()
    major = str2double(extractBetween(openminds.version(), "v", "."));
end
