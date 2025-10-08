classdef controlledInstanceRegistry < handle
% controlledInstanceRegistry - Singleton class for managing controlled instance identifiers
%
%   This class manages the mapping between EBRAINS Knowledge Graph UUIDs
%   and openMINDS identifiers for controlled instances. It handles initial
%   download, incremental background updates, and provides lookup methods.
%
% Usage:
%   registry = omkg.internal.conversion.controlledInstanceRegistry.instance();
%   kgId = registry.getKgId(openMindsId);
%   omId = registry.getOpenMindsId(kgId);
%   registry.update(); % Force update
%
% See also: getIdentifierMapping

    properties (Access = private)
        IdentifierMap struct = struct('kg', {}, 'om', {})
        LastUpdateTime datetime = datetime.empty
        UpdateInProgress logical = false
        TypeUpdateOrder string = string.empty
        LastTypeUpdated double = 0
        ApiClient = []  % Injectable API client for testing
        Verbose logical = true  % Control console output
    end    
    
    properties (Dependent)
        KgToOmMap
        OmToKgMap
    end

    properties
        KgToOmMap_
        OmToKgMap_
    end

    properties (Constant, Access = private)
        UPDATE_INTERVAL_HOURS = 24
        TYPES_PER_UPDATE = 5  % Number of types to update per background update call
    end
    
    methods (Access = private)
        function obj = controlledInstanceRegistry(options)
            
            % Private constructor for singleton pattern

            arguments
                options.ApiClient = []
                options.File = []
                options.Verbose (1,1) logical = true
            end
            
            if ~isempty(options.ApiClient)
                obj.ApiClient = options.ApiClient;
            end
            
            obj.Verbose = options.Verbose;

            obj.loadFromFile();
            if isempty(obj.IdentifierMap)
                obj.downloadAll();
            end
        end
    end
    
    methods (Static)
        function obj = instance(options)
            % instance - Get or create the singleton instance
            %
            % Syntax:
            %   registry = controlledInstanceRegistry.instance()
            %   registry = controlledInstanceRegistry.instance(apiClient)
            %
            % Input:
            %   apiClient - (Optional) API client for testing/mocking
            %   Verbose - (Optional) Enable/disable console output (default: true)
            
            arguments
                options.ApiClient = []
                options.File string = string.empty
                options.Reset (1,1) logical = false
                options.Verbose (1,1) logical = true
            end
            
            omkg.internal.checkEnvironment()

            persistent singletonInstance

            if options.Reset
                if ~isempty(singletonInstance)
                    if isvalid(singletonInstance)
                        delete(singletonInstance)
                    end
                    singletonInstance = [];
                end
            end
            
            if isempty(singletonInstance) || ~isvalid(singletonInstance)
                singletonInstance = omkg.internal.conversion.controlledInstanceRegistry(...
                    "ApiClient", options.ApiClient, ...
                    "Verbose", options.Verbose);
            else
                % Allow setting API client for testing % Todo: Consider
                % whether api client should be immutable 
                if ~isempty(options.ApiClient)
                    singletonInstance.ApiClient = options.ApiClient;
                end
                % Allow updating verbosity
                if isfield(options, 'Verbose')
                    singletonInstance.Verbose = options.Verbose;
                end
            end
            
            obj = singletonInstance;
        end
    end

    methods
        function value = get.OmToKgMap(obj)
            if isempty(obj.OmToKgMap_)
                obj.OmToKgMap_ = obj.getMapping(true);
            end
            value = obj.OmToKgMap_;
        end
        function value = get.KgToOmMap(obj)
            if isempty(obj.KgToOmMap_)
                obj.KgToOmMap_ = obj.getMapping(false);
            end
            value = obj.KgToOmMap_;
        end
    end
    
    methods (Access = public)
        function kgId = getKgId(obj, openMindsId)
            % getKgId - Get Knowledge Graph UUID from openMINDS identifier
            %
            % Syntax:
            %   kgId = registry.getKgId(openMindsId)
            %
            % Input:
            %   openMindsId - openMINDS identifier (string or char)
            %
            % Output:
            %   kgId - Knowledge Graph UUID (string)
            
            openMindsId = string(openMindsId);

            if isKey(obj.OmToKgMap, openMindsId)
                kgId = obj.OmToKgMap(openMindsId);
            else
                error(...
                    'OMKG:ControlledInstanceRegistry:IdNotFound', ...
                    'openMINDS id not found')
            end
        end
        
        function omId = getOpenMindsId(obj, kgId)
            % getOpenMindsId - Get openMINDS identifier from Knowledge Graph UUID
            %
            % Syntax:
            %   omId = registry.getOpenMindsId(kgId)
            %
            % Input:
            %   kgId - Knowledge Graph UUID (string or char)
            %
            % Output:
            %   omId - openMINDS identifier (string)
            
            
            kgId = string(kgId);

            if isKey(obj.KgToOmMap, kgId)
                omId = obj.KgToOmMap(kgId);
            else
                error(...
                    'OMKG:ControlledInstanceRegistry:IdNotFound', ...
                    'KG id not found')
            end
        end
        
        function map = getMapping(obj, reverse)
            % getMapping - Get identifier mapping as dictionary or containers.Map
            %
            % Syntax:
            %   map = registry.getMapping()
            %   map = registry.getMapping(reverse)
            %
            % Input:
            %   reverse - If true, maps openMINDS -> KG, else KG -> openMINDS
            %
            % Output:
            %   map - dictionary or containers.Map object
            
            arguments
                obj
                reverse (1,1) logical = false
            end

            if reverse && ~isempty(obj.OmToKgMap_)
                map = obj.OmToKgMap_;
                return
            elseif ~reverse && ~isempty(obj.KgToOmMap_)
                map = obj.KgToOmMap_;
                return
            end
            
            keys = string({obj.IdentifierMap.kg});
            values = string({obj.IdentifierMap.om});
            
            if reverse
                if exist('dictionary', 'file')
                    map = dictionary(values, keys);
                else
                    map = containers.Map(values, keys);
                end
            else
                if exist('dictionary', 'file')
                    map = dictionary(keys, values);
                else
                    map = containers.Map(keys, values);
                end
            end
        end
        
        function update(obj, forceComplete)
            % update - Update identifier mappings (incremental or complete)
            %
            % Syntax:
            %   registry.update()        % Incremental update
            %   registry.update(true)    % Force complete update
            %
            % Input:
            %   forceComplete - If true, updates all types (default: false)
            
            arguments
                obj
                forceComplete (1,1) logical = false
            end
            
            if obj.UpdateInProgress
                warning('controlledInstanceRegistry:UpdateInProgress', ...
                    'Update already in progress. Skipping.');
                return
            end
            
            obj.UpdateInProgress = true;
            try
                if forceComplete
                    obj.downloadAll();
                else
                    obj.updateIncremental();
                end
            catch ME
                obj.UpdateInProgress = false;
                rethrow(ME);
            end
            obj.UpdateInProgress = false;
        end
        
        function tf = needsUpdate(obj)
            % needsUpdate - Check if update is needed based on time interval
            %
            % Syntax:
            %   tf = registry.needsUpdate()
            %
            % Output:
            %   tf - True if update is needed
            
            if isempty(obj.LastUpdateTime)
                tf = true;
                return
            end
            
            hoursSinceUpdate = hours(datetime('now') - obj.LastUpdateTime);
            tf = hoursSinceUpdate >= obj.UPDATE_INTERVAL_HOURS;
        end
        
        function downloadAll(obj)
            % downloadAll - Download all controlled instance identifiers
            %
            % Syntax:
            %   registry.downloadAll()
            
            if obj.Verbose
                fprintf('Downloading all controlled instance identifiers...\n');
            end
            
            % Get API client
            apiClient = obj.getApiClient();
            
            % Get all controlled term types
            controlledTermTypeIRI = omkg.internal.retrieval.getControlledTypes(...
                'ApiClient', apiClient);
            
            % Store the type order for incremental updates
            obj.TypeUpdateOrder = controlledTermTypeIRI;
            obj.LastTypeUpdated = 0;
            
            % Download all instances
            numTypes = numel(controlledTermTypeIRI);
            instanceUuidListing = cell(1, numTypes);
            for i = 1:numTypes
                if obj.Verbose
                    fprintf('Fetching information for "%s" (%d/%d)\n', ...
                        controlledTermTypeIRI{i}, i, numTypes);
                end
                
                identifierMap = omkg.internal.retrieval.getControlledTermIdMap(...
                    controlledTermTypeIRI{i}, [], ...
                    'ApiClient', apiClient);
                instanceUuidListing{i} = identifierMap;
            end
            
            obj.IdentifierMap = [instanceUuidListing{:}];
            obj.LastUpdateTime = datetime('now');
            obj.saveToFile();
            
            if obj.Verbose
                fprintf('Download complete. %d identifiers retrieved.\n', ...
                    numel(obj.IdentifierMap));
            end
        end
    end
    
    methods (Access = private)
        function updateIncremental(obj)
            % updateIncremental - Update a subset of types incrementally (optimized)
            %
            % Strategy: 
            %   1. Use listControlledTermIds (fast) to get all current IDs
            %   2. Compare with cached IDs to find new ones
            %   3. Only fetch detailed data for new IDs
            %   4. Refresh type list at cycle start to detect new types
            
            if isempty(obj.TypeUpdateOrder)
                % Initialize type order if not set
                apiClient = obj.getApiClient();
                obj.TypeUpdateOrder = omkg.internal.retrieval.getControlledTypes(...
                    'ApiClient', apiClient);
                obj.LastTypeUpdated = 0;
            end
            
            % Refresh type list when starting a new cycle to detect new types
            if obj.LastTypeUpdated == 0
                apiClient = obj.getApiClient();
                currentTypes = omkg.internal.retrieval.getControlledTypes(...
                    'ApiClient', apiClient);
                
                % Add any new types to the update order
                newTypes = setdiff(currentTypes, obj.TypeUpdateOrder);
                if ~isempty(newTypes)
                    if obj.Verbose
                        fprintf('Detected %d new type(s) in Knowledge Graph\n', numel(newTypes));
                    end
                    newTypes = reshape(newTypes, 1, []);
                    obj.TypeUpdateOrder = [obj.TypeUpdateOrder, newTypes];
                end
            end
            
            numTypes = numel(obj.TypeUpdateOrder);
            if numTypes == 0
                return
            end
            
            % Determine which types to update
            startIdx = obj.LastTypeUpdated + 1;
            endIdx = min(startIdx + obj.TYPES_PER_UPDATE - 1, numTypes);
            
            typesToUpdate = obj.TypeUpdateOrder(startIdx:endIdx);
            
            if obj.Verbose
                fprintf('Incremental update: processing types %d-%d of %d\n', ...
                    startIdx, endIdx, numTypes);
            end
            
            % Get API client
            apiClient = obj.getApiClient();
            
            % Process each type with optimized fetching
            for i = 1:numel(typesToUpdate)
                typeIRI = typesToUpdate(i);
                if obj.Verbose
                    fprintf('  Checking "%s" for updates\n', typeIRI);
                end
                
                % Step 1: Fast listing of all IDs for this type
                currentIds = omkg.internal.retrieval.listControlledTermIds(...
                    typeIRI, 'ApiClient', apiClient);
                
                % Step 2: Find new IDs (not in our cache)
                cachedIds = obj.getKgIdsForType(typeIRI);
                newIds = setdiff(currentIds, cachedIds);
                
                if ~isempty(newIds)
                    if obj.Verbose
                        fprintf('    Found %d new identifiers, fetching details...\n', numel(newIds));
                    end
                    
                    % Step 3: Only fetch detailed data for new IDs
                    newIdentifiers = omkg.internal.retrieval.getControlledTermIdMap(...
                        typeIRI, newIds, 'ApiClient', apiClient);
                    
                    % Add to our map
                    obj.IdentifierMap = [obj.IdentifierMap, newIdentifiers];
                else
                    if obj.Verbose
                        fprintf('    No new identifiers found\n');
                    end
                end
            end
            
            % Update tracking variables
            obj.LastTypeUpdated = endIdx;
            if endIdx >= numTypes
                % Completed full cycle, reset
                obj.LastTypeUpdated = 0;
                obj.LastUpdateTime = datetime('now');
            end
            
            obj.saveToFile();
        end
        
        function kgIds = getKgIdsForType(obj, ~)
            % getKgIdsForType - Get all cached KG IDs for a specific type
            %
            % Note: Since we don't store type information with each identifier,
            % we return all cached KG IDs. The comparison with current IDs from
            % the KG will determine what's new. This is still efficient because
            % listControlledTermIds is fast (doesn't return full payloads).
            %
            % Future enhancement: Store type info with each identifier for
            % more precise per-type caching.
            
            kgIds = string({obj.IdentifierMap.kg});
        end
        
        function apiClient = getApiClient(obj)
            % getApiClient - Get API client (real or injected for testing)
            
            if isempty(obj.ApiClient)
                obj.ApiClient = ebrains.kg.api.InstancesClient();
            end
            apiClient = obj.ApiClient;
        end
        
        function updateIdentifiersForType(obj, ~, newIdentifiers)
            % updateIdentifiersForType - Replace identifiers for a specific type
            
            % Note: We can't easily determine which identifiers belong to which type
            % from the stored data, so for incremental updates, we append new ones
            % and rely on periodic full updates to clean up. A more sophisticated
            % approach would store type information with each identifier.
            
            if isempty(newIdentifiers)
                return
            end
            
            % For now, append new identifiers (duplicates will be handled by lookup logic)
            obj.IdentifierMap = [obj.IdentifierMap, newIdentifiers];
        end
        
        function saveToFile(obj)
            % saveToFile - Save identifier map to JSON file
            
            mapFilepath = obj.getFilePath();
            
            % Ensure directory exists
            [dirPath, ~, ~] = fileparts(mapFilepath);
            if ~isfolder(dirPath)
                mkdir(dirPath)
            end
            
            % Save metadata along with identifiers
            saveData = struct();
            saveData.identifiers = obj.IdentifierMap;
            saveData.lastUpdateTime = char(obj.LastUpdateTime);
            saveData.typeUpdateOrder = obj.TypeUpdateOrder;
            saveData.lastTypeUpdated = obj.LastTypeUpdated;
            
            fid = fopen(mapFilepath, "wt");
            fileCleanup = onCleanup(@() fclose(fid));
            fwrite(fid, jsonencode(saveData, 'PrettyPrint', true));
        end
        
        function loadFromFile(obj)
            % loadFromFile - Load identifier map from JSON file
            
            mapFilepath = obj.getFilePath();
            if ~isfile(mapFilepath)
                return
            end
            
            try
                data = jsondecode(fileread(mapFilepath));
                
                % Handle both old and new file formats
                if isfield(data, 'identifiers')
                    obj.IdentifierMap = data.identifiers;
                    if isfield(data, 'lastUpdateTime') && ~isempty(data.lastUpdateTime)
                        obj.LastUpdateTime = datetime(data.lastUpdateTime);
                    end
                    if isfield(data, 'typeUpdateOrder')
                        obj.TypeUpdateOrder = string(data.typeUpdateOrder);
                    end
                    if isfield(data, 'lastTypeUpdated')
                        obj.LastTypeUpdated = data.lastTypeUpdated;
                    end
                else
                    % Old format - just an array of identifiers
                    obj.IdentifierMap = data;
                    obj.LastUpdateTime = datetime.empty;
                end
            catch ME
                warning('controlledInstanceRegistry:LoadFailed', ...
                    'Failed to load identifier map: %s', ME.message);
            end
        end
        
        function filepath = getFilePath(~)
            % getFilePath - Get the file path for the identifier map
            
            filepath = fullfile(...
                omkg.toolboxdir(), ...
                'userdata', ...
                'kg2om_identifier_loopkup.json');
        end
    end
end
