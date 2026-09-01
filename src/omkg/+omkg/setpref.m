function pref = setpref(preferenceName, preferenceValue)
% setpref - Set a user preference
%
% Syntax:
%   omkg.setpref(preferenceName, preferenceValue) sets the value of the
%   specified user preference.
%
% Input Arguments:
%   preferenceName (1,1) string - The name of the preference to set.
%   preferenceValue - The new value of the preference.

    arguments
        preferenceName (1,1) string
        preferenceValue
    end

    pref = omkg.util.Preferences.getSingleton;
    pref.(preferenceName) = preferenceValue;

    if preferenceName == "DefaultServer"
        % The registered link resolver holds the server as instance state,
        % so it is swapped for one configured with the new server.
        openminds.registerLinkResolver(...
            omkg.internal.KGResolver(Server=pref.DefaultServer), Replace=true)
    end

    if ~nargout
        clear pref
    end
end
