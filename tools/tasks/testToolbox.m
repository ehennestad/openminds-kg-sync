function testToolbox(varargin)
    projectRootDir = omkgsynctools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir))

    % The openMINDS add-on puts its model types on the path from its
    % startup script, which MATLAB runs when a session starts, not when the
    % add-on is installed into the running session.
    openminds.startup()

    matbox.tasks.testToolbox(projectRootDir, varargin{:}, "ExcludeTags", "LiveIntegration")
end
