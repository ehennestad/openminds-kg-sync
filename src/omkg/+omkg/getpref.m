function pref = getpref(preferenceName)
% getpref - Retrieve a specific user preference.
%
% Syntax:
%   pref = getpref(preferenceName) Retrieves the value of the specified
%   user preference from the Preferences singleton.
%
% Input Arguments:
%   preferenceName (1,1) string - The name of the preference to retrieve.
%
% Output Arguments:
%   pref - The value of the specified preference.

    arguments
        preferenceName (1,1) string = missing
    end

    pref = omkg.util.Preferences.getSingleton;

    if ~ismissing(preferenceName)
        pref = pref.(preferenceName);
    end
end
