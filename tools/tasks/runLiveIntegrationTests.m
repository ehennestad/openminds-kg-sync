function runLiveIntegrationTests()
    projectRootDir = omkgsynctools.projectdir();
    matbox.tasks.testToolbox(projectRootDir, ...
        "HasTag", "LiveIntegration")
end
