function gettingStarted()
    % GETTINGSTARTED Open the getting started guide for the toolbox
    %
    %   GETTINGSTARTED() opens the getting started guide for the toolbox.
    %
    %   Example:
    %       omkgsync.gettingStarted()
    %
    %   See also omkgsync.toolboxdir, omkgsync.toolboxversion

    % Display welcome message
    fprintf('Welcome to openMINDS_KG_Sync!\n\n');
    fprintf('Sync openMINDS metadata to and from EBRAINS KG\n\n');
    
    % Display version information
    fprintf('Version: %s\n', omkgsync.toolboxversion());
    
    % Display directory information
    fprintf('Toolbox directory: %s\n\n', omkgsync.toolboxdir());
    
    % Display available functions
    fprintf('Available functions:\n');
    fprintf('  - omkgsync.toolboxdir\n');
    fprintf('  - omkgsync.toolboxversion\n');
    fprintf('  - omkgsync.gettingStarted\n\n');
    
    % Display examples
    fprintf('Examples:\n');
    examplesDir = fullfile(omkgsync.toolboxdir(), 'code', 'examples');
    if exist(examplesDir, 'dir')
        exampleFiles = dir(fullfile(examplesDir, '*.m'));
        if ~isempty(exampleFiles)
            for i = 1:length(exampleFiles)
                fprintf('  - %s\n', exampleFiles(i).name);
            end
        else
            fprintf('  No examples found.\n');
        end
    else
        fprintf('  Examples directory not found.\n');
    end
    
    % Display documentation
    fprintf('\nDocumentation:\n');
    docsDir = fullfile(omkgsync.toolboxdir(), 'docs');
    if exist(docsDir, 'dir')
        fprintf('  Documentation is available in the docs directory:\n');
        fprintf('  %s\n', docsDir);
    else
        fprintf('  Documentation directory not found.\n');
    end
    
    fprintf('\nFor more information, see the README.md file in the toolbox directory.\n');
end
