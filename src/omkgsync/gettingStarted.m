function gettingStarted()
    % GETTINGSTARTED Open the getting started guide for the toolbox
    %
    %   GETTINGSTARTED() opens the getting started guide for the toolbox.
    %
    %   Example:
    %       omkg.gettingStarted()
    %
    %   See also omkg.toolboxdir, omkg.toolboxversion

    % Display welcome message
    fprintf('Welcome to openMINDS_KG_Sync!\n\n');
    fprintf('Sync openMINDS metadata to and from EBRAINS KG\n\n');
    
    % Display version information
    fprintf('Version: %s\n', omkg.toolboxversion());
    
    % Display directory information
    fprintf('Toolbox directory: %s\n\n', omkg.toolboxdir());
    
    % Display available functions
    fprintf('Available functions:\n');
    fprintf('  - omkg.toolboxdir\n');
    fprintf('  - omkg.toolboxversion\n');
    fprintf('  - omkg.gettingStarted\n\n');
    
    % Display examples
    fprintf('Examples:\n');
    examplesDir = fullfile(omkg.toolboxdir(), 'code', 'examples');
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
    docsDir = fullfile(omkg.toolboxdir(), 'docs');
    if exist(docsDir, 'dir')
        fprintf('  Documentation is available in the docs directory:\n');
        fprintf('  %s\n', docsDir);
    else
        fprintf('  Documentation directory not found.\n');
    end
    
    fprintf('\nFor more information, see the README.md file in the toolbox directory.\n');
end
