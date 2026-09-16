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
%   This is the counterpart of ommtest.helper.ModelVersionFixture in
%   openMINDS_MATLAB, which is part of that repository's test tooling and
%   not of the packaged toolbox, with the version taken from the
%   preference instead of an argument.
%
%   Restoring the version does not undo everything a switch causes. Class
%   definitions are reloaded when the version changes, but only once no
%   instance of them is held in memory: an instance that outlives the
%   test, directly or in a singleton, pins the definition it was created
%   from. Leave no openMINDS instances behind and this fixture is enough.
%
%   Usage:
%       testCase.applyFixture(omkg.test.fixtures.KgOpenMindsVersionFixture());
%
%   See also matlab.unittest.fixtures.Fixture, openminds.version

    methods
        function setup(fixture)
            previousVersion = openminds.version();
            pinnedVersion = sprintf("v%d.0", omkg.getpref("KgOpenMINDSVersion"));

            if ~strcmp(previousVersion, pinnedVersion)
                fixture.addTeardown(@openminds.version, previousVersion);
                openminds.version(pinnedVersion);
                fixture.TeardownDescription = sprintf(...
                    'Restored openMINDS model version %s.', previousVersion);
            end
            omkg.internal.checkEnvironment()

            fixture.SetupDescription = sprintf(...
                'Selected openMINDS model version %s.', pinnedVersion);
        end
    end

    methods (Access = protected)
        function tf = isCompatible(~, ~)
            % Every instance selects the version the preference names, so
            % a shared fixture stands in for any other.
            tf = true;
        end
    end
end
