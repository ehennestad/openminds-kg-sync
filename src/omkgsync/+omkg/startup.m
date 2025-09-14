if isempty( which('openminds.version') )
    env om a
end

omkg.internal.checkEnvironment();

fprintf("Default server: %s\n", omkg.getpref('DefaultServer'))
fprintf("Default space: %s\n", omkg.getpref('DefaultSpace'))
