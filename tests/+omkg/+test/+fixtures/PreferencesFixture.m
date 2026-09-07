classdef PreferencesFixture < matlab.unittest.fixtures.Fixture
% PreferencesFixture - Snapshot and restore omkg preferences
%
%   omkg.util.Preferences is a singleton that persists to a file in
%   prefdir, i.e. the real preferences used outside of tests. Applying
%   this fixture captures the current values on setup and registers a
%   teardown that restores them, so a test suite that changes
%   preferences (including resetting them to defaults) does not
%   permanently overwrite whatever the user had configured before the
%   tests ran.
%
%   Usage:
%       testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());

    methods
        function setup(fixture)
            prefs = omkg.getpref();
            originalValues = fixture.captureValues(prefs);
            fixture.addTeardown(@() fixture.applyValues(prefs, originalValues));
        end
    end

    methods (Access = private, Static)
        function values = captureValues(prefs)
            propertyNames = string(properties(prefs));
            values = struct();
            for i = 1:numel(propertyNames)
                values.(propertyNames(i)) = prefs.(propertyNames(i));
            end
        end

        function applyValues(prefs, values)
            propertyNames = string(fieldnames(values));
            for i = 1:numel(propertyNames)
                prefs.(propertyNames(i)) = values.(propertyNames(i));
            end
        end
    end
end
