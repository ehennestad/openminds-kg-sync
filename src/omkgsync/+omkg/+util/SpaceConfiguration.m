classdef SpaceConfiguration
% Manage "space" defaults stored in a JSON that uses forward lists.
%
% JSON group shape (kept close to original):
%   group.default : string or [] (nullable)
%   group.<space> : cellstr list of class names (0..N spaces)
%
% In memory we keep:
%   Index        : containers.Map(class -> space)              % GLOBAL
%   SpaceToGroup : containers.Map(space -> group)              % derived
%   GroupDefault : containers.Map(group -> default)            % fallback
%
% Usage:
%   cfg = omkg.util.SpaceConfiguration.loadDefault();
% 
%   % O(1) lookups across the whole config:
%   cfg.getSpace("Affiliation")          % -> "common"
%   cfg.getSpace("ChemicalMixture")      % -> "in-depth" (via group default)
%   
%   % Move/assign a class without specifying a group:
%   cfg = cfg.assignClass("spatial", "CoordinatePoint");
% 
%   % Remove a class from all spaces:
%   cfg = cfg.unassignClass("CoordinatePoint");
%   
%   % Save:
%   cfg.save("space-defaults_v2.json");

    properties (SetAccess = private)
        Data struct
        FilePath string = ""
        Dirty logical = false
    end

    properties (Access = private)
        Index % class -> space (containers.Map or dictionary)
        SpaceToGroup % space -> group (containers.Map or dictionary)
        GroupDefault % group -> default (containers.Map or dictionary)
    end

    methods
        function obj = SpaceConfiguration(data, filePath)
            arguments
                data (1,1) struct
                filePath (1,1) string = ""
            end
            
            obj = obj.initializeMaps_();
            obj.Data = data;
            obj.FilePath = filePath;
            obj = obj.rebuildIndex_();
            obj.Dirty = false;
        end

        function space = getSpace(obj, type)
        % Return the space for a class if explicitly mapped.
        % If unmapped, fall back to module's default.
            arguments
                obj
                type (1,1) openminds.enum.Types
            end
            
            className = char(type);
            
            % Check for exact mapping first
            if isKey(obj.Index, className)
                space = string(obj.Index(className));
                return
            end
            
            % Fall back to module default
            space = obj.getModuleDefaultSpace_(type);
        end

        function obj = setModuleDefault(obj, module, defaultSpace)
            % Set/replace module default (use "" to clear).
            arguments
                obj
                module (1,1) openminds.enum.Modules
                defaultSpace (1,1) string
            end
            obj = obj.ensureGroup_(module);
            moduleName = char(module);
            obj.Data.(moduleName).default = char(defaultSpace);
            obj.GroupDefault(moduleName) = char(defaultSpace);
            obj.Dirty = true;
        end

        function obj = clearGroupDefault(obj, module)
            % Explicitly clears the group's default.
            arguments
                obj
                module (1,1) openminds.enum.Modules
            end
            moduleName = char(module);
            obj = obj.ensureGroup_(module);
            obj.Data.(moduleName).default = [];
            obj.GroupDefault(moduleName) = "";
            obj.Dirty = true;
        end

        function obj = assignClass(obj, spaceName, typeName)
            % Assign typeName to a space. Type uniqueness is global.
            % The corresponding group is inferred via SpaceToGroup.
            arguments
                obj
                spaceName (1,1) string
                typeName (1,1) openminds.enum.Types
            end

            spaceKey = char(spaceName);
            typeKey = char(typeName);

            obj.validateSpaceExists_(spaceKey);
            groupName = obj.SpaceToGroup(spaceKey);

            % Remove class from wherever it currently lives (any group/space)
            obj = obj.unassignClass(typeName, true); % silent

            % Add class to target space
            obj = obj.addClassToSpace_(groupName, spaceKey, typeKey);
            
            % Update Index
            obj.Index(typeKey) = spaceKey;
            obj.Dirty = true;
        end

        function obj = unassignClass(obj, className, silent)
            % Remove className from whichever space list it is in (global).
            arguments
                obj
                className
                silent (1,1) logical = false
            end
            
            % Convert to char (handles both string and enum inputs)
            classKey = char(className);
            
            removed = obj.removeClassFromAllSpaces_(classKey);
            
            if isKey(obj.Index, classKey)
                remove(obj.Index, classKey);
            end

            if ~silent && ~removed
                warning("OMKG:SpaceConfiguration:NotFound", ...
                    "Class '%s' not found in any space list.", classKey);
            end
            
            obj.Dirty = obj.Dirty || removed;
        end

        function save(obj, filePath)
            % Save Data back to JSON in forward-list format.
            arguments
                obj
                filePath (1,1) string = ""
            end
            
            targetPath = obj.resolveFilePath_(filePath);
            jsonText = jsonencode(obj.Data, "PrettyPrint", true);
            obj.writeToFile_(targetPath, jsonText);
        end
    end

    methods (Access = private)
        function obj = initializeMaps_(obj)
            % Initialize maps with dictionary if available, fallback to containers.Map
            try
                obj.Index = dictionary();
                obj.SpaceToGroup = dictionary();
                obj.GroupDefault = dictionary();
            catch
                obj.Index = containers.Map('KeyType', 'char', 'ValueType', 'char');
                obj.SpaceToGroup = containers.Map('KeyType', 'char', 'ValueType', 'char');
                obj.GroupDefault = containers.Map('KeyType', 'char', 'ValueType', 'char');
            end
        end
        
        function space = getModuleDefaultSpace_(obj, type)
            % Get the default space for a module, or error if none exists
            module = type.getModule();
            moduleName = char(module);
            
            if isKey(obj.GroupDefault, moduleName)
                defaultSpace = obj.GroupDefault(moduleName);
                if ~isempty(defaultSpace)
                    space = string(defaultSpace);
                    return
                end
            end
            
            error("OMKG:SpaceConfiguration:NoFallback", ...
                "Class '%s' not mapped and module '%s' has no usable default.", ...
                char(type), moduleName);
        end
        
        function validateSpaceExists_(obj, spaceName)
            % Validate that a space exists in the configuration
            if ~isKey(obj.SpaceToGroup, spaceName)
                error("OMKG:SpaceConfiguration:UnknownSpace", ...
                    "Space '%s' was not found in any group.", spaceName);
            end
        end
        
        function obj = addClassToSpace_(obj, groupName, spaceName, className)
            % Add a class to a space within a group
            % Ensure list exists and is cellstr
            if ~isfield(obj.Data.(groupName), spaceName)
                obj.Data.(groupName).(spaceName) = cell(1,0);
            else
                % Normalize existing list to cellstr if needed
                classList = obj.Data.(groupName).(spaceName);
                classList = obj.normalizeClassList(classList);
                obj.Data.(groupName).(spaceName) = classList;
            end

            % Add to target space if not present
            classList = obj.Data.(groupName).(spaceName);
            if ~any(strcmp(classList, className))
                obj.Data.(groupName).(spaceName) = [classList; {className}];
            end
        end
        
        function removed = removeClassFromAllSpaces_(obj, className)
            % Remove className from all space lists across all groups
            removed = false;
            groupNames = fieldnames(obj.Data);
            
            for i = 1:numel(groupNames)
                groupName = groupNames{i};
                groupData = obj.Data.(groupName);
                
                if ~isstruct(groupData)
                    continue;
                end
                
                spaceNames = setdiff(fieldnames(groupData), {'default'});
                for j = 1:numel(spaceNames)
                    spaceName = spaceNames{j};
                    classList = groupData.(spaceName);
                    classList = obj.normalizeClassList(classList);
                    
                    if iscellstr(classList) || iscell(classList) || isstring(classList)
                        keep = ~strcmp(classList, className);
                        if any(~keep)
                            obj.Data.(groupName).(spaceName) = classList(keep);
                            removed = true;
                        end
                    end
                end
            end
        end
        
        function obj = rebuildIndex_(obj)
            % Build global Index(class -> space), SpaceToGroup(space -> group),
            % and GroupDefault(group -> default). Enforce class uniqueness.
            [classIndex, spaceToGroup, groupDefaults] = obj.createEmptyMaps_();

            groupNames = fieldnames(obj.Data);
            for i = 1:numel(groupNames)
                groupName = groupNames{i};
                groupData = obj.Data.(groupName);
                
                obj.validateGroupStructure_(groupName, groupData);
                groupDefaults = obj.processGroupDefault_(groupDefaults, groupName, groupData);
                [classIndex, spaceToGroup] = obj.processGroupSpaces_(classIndex, spaceToGroup, groupName, groupData);
            end

            obj.Index = classIndex;
            obj.SpaceToGroup = spaceToGroup;
            obj.GroupDefault = groupDefaults;
        end
        
        function [classIndex, spaceToGroup, groupDefaults] = createEmptyMaps_(~)
            % Create empty maps for rebuilding indices
            classIndex = containers.Map('KeyType','char','ValueType','char');
            spaceToGroup = containers.Map('KeyType','char','ValueType','char');
            groupDefaults = containers.Map('KeyType','char','ValueType','char');
        end
        
        function validateGroupStructure_(~, groupName, groupData)
            % Validate that group data is a struct
            if ~isstruct(groupData)
                error("OMKG:SpaceConfiguration:SchemaError", ...
                    "Group '%s' must be a struct.", groupName);
            end
        end
        
        function groupDefaults = processGroupDefault_(~, groupDefaults, groupName, groupData)
            % Process the default field for a group
            if isfield(groupData, 'default') && ~isempty(groupData.default)
                groupDefaults(groupName) = char(groupData.default);
            else
                groupDefaults(groupName) = "";
            end
        end
        
        function [classIndex, spaceToGroup] = processGroupSpaces_(obj, classIndex, spaceToGroup, groupName, groupData)
            % Process all spaces within a group
            spaceNames = setdiff(fieldnames(groupData), {'default'});
            
            for i = 1:numel(spaceNames)
                spaceName = spaceNames{i};
                obj.validateSpaceUniqueness_(spaceToGroup, spaceName, groupName);
                spaceToGroup(spaceName) = groupName;
                
                classList = groupData.(spaceName);
                classIndex = obj.processSpaceClasses_(classIndex, spaceName, groupName, classList);
            end
        end
        
        function validateSpaceUniqueness_(~, spaceToGroup, spaceName, groupName)
            % Validate that spaces are unique across groups
            if isKey(spaceToGroup, spaceName) && ~strcmp(spaceToGroup(spaceName), groupName)
                error("OMKG:SpaceConfiguration:SpaceAmbiguity", ...
                    "Space '%s' appears under both '%s' and '%s'.", ...
                    spaceToGroup(spaceName), groupName, spaceName);
            end
        end
        
        function classIndex = processSpaceClasses_(obj, classIndex, spaceName, groupName, classList)
            % Process all classes within a space
            if isempty(classList)
                return;
            end
            
            classList = obj.normalizeClassList(classList);

            for i = 1:numel(classList)
                className = classList{i};
                obj.validateClassUniqueness_(classIndex, className, spaceName);
                classIndex(className) = spaceName;
            end
        end
        
        function validateClassUniqueness_(~, classIndex, className, spaceName)
            % Validate that classes are globally unique
            if isKey(classIndex, className) && ~strcmp(classIndex(className), spaceName)
                error("OMKG:SpaceConfiguration:ClassDuplicate", ...
                    "Class '%s' found in multiple spaces ('%s' and '%s').", ...
                    className, classIndex(className), spaceName);
            end
        end
        
        function targetPath = resolveFilePath_(obj, filePath)
            % Resolve the file path for saving, using object's FilePath if needed
            if filePath == ""
                if obj.FilePath == ""
                    error("OMKG:SpaceConfiguration:NoFilePath", ...
                        "No file path provided and object has no FilePath set.");
                end
                targetPath = obj.FilePath;
            else
                targetPath = filePath;
            end
        end
        
        function writeToFile_(~, filePath, content)
            % Write content to file with proper error handling
            fileHandle = fopen(filePath, "w");
            if fileHandle < 0
                error("OMKG:SpaceConfiguration:IO", ...
                    "Failed to open '%s' for writing.", filePath);
            end
            
            cleanup = onCleanup(@() fclose(fileHandle));
            fwrite(fileHandle, content, "char");
        end

        function obj = ensureGroup_(obj, schemaGroup)
            % Ensure a group exists in the data structure
            groupName = char(schemaGroup);
            
            if ~isfield(obj.Data, groupName)
                obj.Data.(groupName) = struct('default', []);
            else
                obj.validateExistingGroup_(groupName);
                obj.ensureGroupHasDefault_(groupName);
            end
        end
        
        function validateExistingGroup_(obj, groupName)
            % Validate that existing group is a struct
            if ~isstruct(obj.Data.(groupName))
                error("OMKG:SpaceConfiguration:SchemaError", ...
                    "Group '%s' exists but is not a struct.", groupName);
            end
        end
        
        function ensureGroupHasDefault_(obj, groupName)
            % Ensure group has a default field
            if ~isfield(obj.Data.(groupName), 'default')
                obj.Data.(groupName).default = [];
            end
        end
    

    end

    methods (Static)
        function obj = loadDefault()
            filePath = fullfile(omkg.toolboxdir, ...
                'omkgsync', 'resources', 'defaults', 'default_spaces.json');
            obj = omkg.util.SpaceConfiguration.load(filePath);
        end

        function obj = load(filePath)
            arguments
                filePath (1,1) string
            end
            if ~isfile(filePath)
                error("OMKG:SpaceConfiguration:NotFound", "Config file not found: %s", filePath);
            end
            jsonText = fileread(filePath);
            data = omkg.util.SpaceConfiguration.jsondecode(jsonText);
            obj = omkg.util.SpaceConfiguration(data, filePath);
        end

        function obj = fromJSONText(jsonText)
            arguments
                jsonText (1,1) string
            end
            data = omkg.util.SpaceConfiguration.jsondecode(jsonText);
            obj = omkg.util.SpaceConfiguration(data);
        end
    end

    methods (Static, Access = private)

        function data = jsondecode(jsonText)
            data = jsondecode(char(jsonText));
            if ~isstruct(data) || ~isscalar(data)
                error("OMKG:SpaceConfiguration:SchemaError", ...
                    "Top-level JSON must decode to a scalar struct.");
            end
        end

        function classList = normalizeClassList(classList)
            if ischar(classList)
                classList = {classList};
            elseif isstring(classList)
                classList = cellstr(classList);
            elseif iscell(classList) && ~iscellstr(classList)
                % Handle cell arrays of strings (modern MATLAB string arrays in cells)
                classList = cellfun(@char, classList, 'UniformOutput', false);
            elseif ~iscellstr(classList) && ~iscell(classList)
                error("OMKG:SpaceConfiguration:SchemaError", ...
                    "Group '%s' field '%s' must be a cellstr list.", groupName, spaceName);
            end
        end
    end
end
