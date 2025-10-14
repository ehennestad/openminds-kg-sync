function pref = setpref(preferenceName, preferenceValue)

    arguments
        preferenceName (1,1) string
        preferenceValue
    end

    pref = omkg.util.Preferences.getSingleton;
    pref.(preferenceName) = preferenceValue;
    if ~nargout
        clear pref
    end
end
