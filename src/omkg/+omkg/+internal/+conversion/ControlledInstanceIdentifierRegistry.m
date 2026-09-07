classdef ControlledInstanceIdentifierRegistry < handle
% ControlledInstanceIdentifierRegistry - Singleton class for managing controlled instance identifiers
%
%   This class manages the mapping between EBRAINS Knowledge Graph UUIDs
%   and openMINDS identifiers for controlled instances. It handles the
%   download, caching and refresh of that mapping, and provides lookup
%   methods.
%
%   A refresh replaces the whole mapping. The Knowledge Graph offers no
%   delta endpoint for controlled instances, so listing the identifiers of
%   a type costs the same request as fetching them. A partial refresh would
%   save response payload but not round trips, and could never observe an
%   instance that was removed from the Knowledge Graph.
%
% Usage:
%   registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance();
%   kgId = registry.getKgId(openMindsId);
%   omId = registry.getOpenMindsId(kgId);
%   registry.update(); % Refresh from the Knowledge Graph
%
% See also: getIdentifierMapping

    % Todo:
    % - immutability of verbose, apiclient
    % - pattern for using a different file, i.e during testing...

    properties (SetAccess = immutable)
        Verbose logical = true  % Control console output
    end

    properties (Access = private)
        IdentifierMap struct = struct('kg', {}, 'om', {})
        LastUpdateTime datetime = datetime.empty
        UpdateInProgress logical = false
        ApiClient ebrains.kg.api.InstancesClient  % Injectable API client for testing
    end

    properties (Dependent)
        KgToOmMap
        OmToKgMap
    end

    properties (Access = private)
        KgToOmMap_
        OmToKgMap_
    end

    properties (Constant, Access = private)
        UPDATE_INTERVAL_HOURS = 24
    end

    methods (Access = private) % Private constructor for singleton pattern
        function obj = ControlledInstanceIdentifierRegistry(options)
            arguments
                options.ApiClient (1,1) ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient();
                options.Verbose (1,1) logical = true
                options.File = []
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

    methods (Static) % Singleton getter
        function obj = instance(options)
            % instance - Get or create the singleton instance
            %
            % Syntax:
            %   registry = ControlledInstanceIdentifierRegistry.instance()
            %   registry = ControlledInstanceIdentifierRegistry.instance(name, value)
            %
            % Name-value arguments:
            %   apiClient - (Optional) API client for testing/mocking
            %   Verbose - (Optional) Enable/disable console output (default: true)

            arguments
                options.ApiClient ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
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
                singletonInstance = omkg.internal.conversion.ControlledInstanceIdentifierRegistry(...
                    "ApiClient", options.ApiClient, ...
                    "Verbose", options.Verbose);
            else
                % Allow setting API client for testing % Todo: Consider
                % whether api client should be immutable
                if ~isempty(options.ApiClient)
                    singletonInstance.ApiClient = options.ApiClient;
                end
                % Allow updating verbosity
                % if isfield(options, 'Verbose')
                %     singletonInstance.Verbose = options.Verbose;
                % end
            end

            obj = singletonInstance;
        end
    end

    methods
        function value = get.OmToKgMap(obj)
            if isempty(obj.OmToKgMap_)
                obj.OmToKgMap_ = obj.createMapping("Reverse", true);
            end
            value = obj.OmToKgMap_;
        end
        function value = get.KgToOmMap(obj)
            if isempty(obj.KgToOmMap_)
                obj.KgToOmMap_ = obj.createMapping("Reverse", false);
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

            arguments
                obj (1,1) omkg.internal.conversion.ControlledInstanceIdentifierRegistry
                openMindsId (1,1) string
            end

            if isKey(obj.OmToKgMap, openMindsId)
                kgId = string( obj.OmToKgMap(openMindsId) );
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

            arguments
                obj (1,1) omkg.internal.conversion.ControlledInstanceIdentifierRegistry
                kgId (1,1) string
            end

            if isKey(obj.KgToOmMap, kgId)
                omId = string( obj.KgToOmMap(kgId) );
            else
                error(...
                    'OMKG:ControlledInstanceRegistry:IdNotFound', ...
                    'KG id not found')
            end
        end

        function update(obj)
            % update - Replace the identifier mappings from the Knowledge Graph
            %
            % Syntax:
            %   registry.update()
            %
            %   Downloads every controlled instance and replaces the cached
            %   mapping, so that instances removed from the Knowledge Graph
            %   and identifiers that changed are both picked up.

            arguments
                obj (1,1) omkg.internal.conversion.ControlledInstanceIdentifierRegistry
            end

            if obj.UpdateInProgress
                warning('OMKG:ControlledInstanceRegistry:UpdateInProgress', ...
                    'Update already in progress. Skipping.');
                return
            end

            updateInProgressResetObj = obj.setUpdateInProgress(); %#ok<NASGU>
            obj.downloadAll();
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

    end

    methods (Access = private) % Internal methods for update
        function [cleanupObj] = setUpdateInProgress(obj)
            obj.UpdateInProgress = true;
            cleanupObj = onCleanup(@() obj.resetUpdateInProgress);
        end

        function resetUpdateInProgress(obj)
            obj.UpdateInProgress = false;
        end

        function downloadAll(obj)
            % downloadAll - Download all controlled instance identifiers
            %
            %   Replaces IdentifierMap wholesale. Call update() rather than
            %   this method, so that concurrent refreshes are serialized.

            if obj.Verbose
                fprintf('Downloading all controlled instance identifiers...\n');
            end

            % Get all controlled term types
            controlledTermTypeIRI = omkg.internal.retrieval.getControlledTypes(...
                'ApiClient',  obj.ApiClient);

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
                    'ApiClient', obj.ApiClient);
                instanceUuidListing{i} = identifierMap;
            end

            [obj.IdentifierMap, rejectedPairs] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(...
                    [instanceUuidListing{:}]);

            obj.LastUpdateTime = datetime('now');
            obj.saveToFile();
            obj.clearCachedMaps()

            if obj.Verbose
                fprintf('Download complete. %d identifiers retrieved.\n', ...
                    numel(obj.IdentifierMap));
                if ~isempty(rejectedPairs)
                    fprintf(['%d identifier(s) were discarded because they ', ...
                        'are not resolvable openMINDS instance IRIs.\n'], ...
                        numel(rejectedPairs));
                end
            end
        end
        function clearCachedMaps(obj)
            obj.KgToOmMap_ = [];
            obj.OmToKgMap_ = [];
        end

        function map = createMapping(obj, options)
            % createMapping - Get identifier mapping as dictionary or containers.Map
            %
            % Syntax:
            %   map = registry.createMapping()
            %   map = registry.createMapping(name, value)
            %
            % Name-Value arguments:
            %   Reverse - If true, maps openMINDS -> KG, else KG -> openMINDS
            %
            % Output arguments:
            %   map - dictionary or containers.Map object
            %
            %   Duplicate keys are resolved before the map is built. Both
            %   dictionary and containers.Map silently keep the last value
            %   for a repeated key, which would make the result depend on
            %   the order in which the Knowledge Graph returned the data.

            arguments
                obj
                options.Reverse (1,1) logical = false
            end

            mapConstructorFcn = getMapConstructor();

            kgIds = string({obj.IdentifierMap.kg});
            omIds = string({obj.IdentifierMap.om});

            if options.Reverse
                % An openMINDS IRI identifies at most one Knowledge Graph
                % instance, so a duplicate here would be a data error with
                % no principled winner. Keep the first in sorted order.
                [omIds, keepIdx] = unique(omIds);
                map = mapConstructorFcn(omIds, kgIds(keepIdx));
            else
                [kgIds, omIds] = selectCanonicalIdentifiers(kgIds, omIds);
                map = mapConstructorFcn(kgIds, omIds);
            end
        end
    end

    methods (Access = private) % Internal methods for save/load
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

            fid = fopen(mapFilepath, "wt");
            fileCleanup = onCleanup(@() fclose(fid));
            fwrite(fid, jsonencode(saveData, 'PrettyPrint', true));
        end

        function loadFromFile(obj)
            % loadFromFile - Load identifier map from JSON file

            mapFilepath = obj.getFilePath();
            if ~isfile(mapFilepath)
                mapFilepath = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'resources', 'kg2om_identifier_loopkup.json');
                if ~isfile(mapFilepath)
                    return
                end
            end

            try
                data = jsondecode(fileread(mapFilepath));

                % Handle both old and new file formats
                if isfield(data, 'identifiers')
                    obj.IdentifierMap = data.identifiers;
                    if isfield(data, 'lastUpdateTime') && ~isempty(data.lastUpdateTime)
                        obj.LastUpdateTime = datetime(data.lastUpdateTime);
                    end
                else
                    % Old format - just an array of identifiers
                    obj.IdentifierMap = data;
                    obj.LastUpdateTime = datetime.empty;
                end

                % The shipped resource and files written before this check
                % existed contain pairs that openMINDS can not resolve.
                % Drop them here so they never reach the lookup maps.
                obj.IdentifierMap = ...
                    omkg.internal.conversion.removeInvalidIdentifierPairs(obj.IdentifierMap);
            catch ME
                warning('OMKG:ControlledInstanceRegistry:LoadFailed', ...
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

function [uniqueKgIds, canonicalOmIds] = selectCanonicalIdentifiers(kgIds, omIds)
% selectCanonicalIdentifiers - Reduce alias rows to one openMINDS IRI per KG id
%
%   Some Knowledge Graph instances carry several openMINDS schema
%   identifiers and therefore appear as several rows with the same KG id.

    [uniqueKgIds, firstIdx, groupIndex] = unique(kgIds);
    canonicalOmIds = omIds(firstIdx);

    instanceCount = accumarray(groupIndex(:), 1);
    aliasedGroups = reshape(find(instanceCount > 1), 1, []);

    unresolvedKgIds = string.empty;
    for groupNumber = aliasedGroups
        [canonicalOmIds(groupNumber), isResolved] = ...
            omkg.internal.conversion.selectCanonicalInstanceIRI(...
                omIds(groupIndex == groupNumber));

        if ~isResolved
            unresolvedKgIds(end+1) = uniqueKgIds(groupNumber); %#ok<AGROW>
        end
    end

    if ~isempty(unresolvedKgIds)
        warning('OMKG:ControlledInstanceRegistry:AmbiguousIdentifiers', ...
            ['%d Knowledge Graph instance(s) map to several openMINDS ', ...
            'instances that openMINDS does not disambiguate. The ', ...
            'alphabetically first identifier is used for:\n  %s'], ...
            numel(unresolvedKgIds), strjoin(unresolvedKgIds, newline + "  "))
    end
end

function fcnHandle = getMapConstructor()
% getMapConstructor - Get function handle for a map constructor. Use
% dictionary if available, otherwise fall back to containers.Map
    if exist('dictionary', 'file')
        fcnHandle = @dictionary;
    else
        fcnHandle = @containers.Map;
    end
end
