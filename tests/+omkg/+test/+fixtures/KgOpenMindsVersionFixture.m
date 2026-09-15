classdef KgOpenMindsVersionFixture < matlab.unittest.fixtures.Fixture
% KgOpenMindsVersionFixture - Activate the openMINDS version the KG is pinned to
%
%   omkg.internal.checkEnvironment refuses to run unless the active
%   openMINDS_MATLAB model version matches the KgOpenMINDSVersion
%   preference, and never switches it. Tests that reach checkEnvironment
%   apply this fixture to make that switch explicitly. It also runs
%   checkEnvironment once so the KG link resolver is registered, and
%   restores the version that was active before on teardown.
%
%   Usage:
%       testCase.applyFixture(omkg.test.fixtures.KgOpenMindsVersionFixture());

    methods
        function setup(fixture)
            originalVersion = openminds.version();
            pinnedVersion = omkg.getpref("KgOpenMINDSVersion");
            if ~strcmp(originalVersion, sprintf("v%d.0", pinnedVersion))
                openminds.version(pinnedVersion);
                fixture.addTeardown(@() openminds.version(originalVersion));
            end
            omkg.internal.checkEnvironment()
        end
    end
end
