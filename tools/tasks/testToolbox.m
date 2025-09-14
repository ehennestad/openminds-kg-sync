function testToolbox(varargin)
    projectRootDir = omkgsynctools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir))
    matbox.tasks.testToolbox(projectRootDir, varargin{:})
end
