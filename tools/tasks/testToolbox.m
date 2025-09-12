function testToolbox(varargin)
    projectRootDir = omkgsynctools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir))
    addpath(genpath('MATLAB-AddOnds'))
    ls
    matbox.tasks.testToolbox(projectRootDir, varargin{:})
end
