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

    properties (SetAccess = immutable)
        Verbose logical = true  % Control console output
    end

    properties (Access = private)
        IdentifierMap struct = struct('kg', {}, 'om', {}, 'aliases', {})
        LastUpdateTime datetime = datetime.empty
        UpdateInProgress logical = false
        FilePathOverride string = string.empty  % Injectable cache file for testing
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

        % Version of the cache file layout. Raise it when a change makes an
        % older file unreadable rather than merely missing fields.
        SCHEMA_VERSION = "1.0"

        % Knowledge Graph scope the mapping is built from. A UUID only means
        % something for a given server, space and stage, so these are
        % recorded with the cache. They mirror the requests made by
        % omkg.internal.retrieval.getControlledTypes and
        % getControlledTermIdMap, which are the source of truth.
        KG_SOURCE_SERVER = "PROD"
        KG_SOURCE_SPACE = "controlled"
        KG_SOURCE_STAGE = "RELEASED"
    end

    methods (Access = private) % Private constructor for singleton pattern
        function obj = ControlledInstanceIdentifierRegistry(options)
            arguments
                options.ApiClient (1,1) ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient();
                options.Verbose (1,1) logical = true
                options.File string = string.empty
            end

            if ~isempty(options.ApiClient)
                obj.ApiClient = options.ApiClient;
            end

            obj.Verbose = options.Verbose;
            obj.FilePathOverride = options.File;

            obj.loadFromFile();
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
                options.ApiClient ebrains.kg.api.InstancesClient = ...
                    ebrains.kg.api.InstancesClient.empty
                options.File string = string.empty
                options.Reset (1,1) logical = false
                options.Verbose (1,1) logical = true
            end

            % checkEnvironment is deliberately not called here. Every public
            % entry point calls it before anything reaches this registry,
            % and calling it here would put the registry on the resolver
            % construction path: checkEnvironment registers a KGResolver,
            % which reads this registry.

            persistent singletonInstance

            if options.Reset
                if ~isempty(singletonInstance)
                    if isvalid(singletonInstance)
                        delete(singletonInstance)
                    end
                    singletonInstance = [];
                end
            end

            % Only forward an API client that the caller actually supplied,
            % so that a plain instance() call does not replace a client that
            % was injected for testing.
            constructorArgs = {"Verbose", options.Verbose, "File", options.File};
            if ~isempty(options.ApiClient)
                constructorArgs = [constructorArgs, {"ApiClient", options.ApiClient}];
            end

            if isempty(singletonInstance) || ~isvalid(singletonInstance)
                singletonInstance = ...
                    omkg.internal.conversion.ControlledInstanceIdentifierRegistry(constructorArgs{:});
            elseif ~isempty(options.ApiClient)
                singletonInstance.ApiClient = options.ApiClient;
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

        function filepath = getFilePath(obj)
            % getFilePath - Path of the cached identifier map for the active version
            %
            %   A File given to the constructor overrides this, and also
            %   suppresses the shipped resource, so that a test can run
            %   against a known map without touching the user's cache.
            %
            %   The cache lives in prefdir, next to the toolbox preferences,
            %   because the toolbox folder is read-only for an installed
            %   toolbox. It is keyed by openMINDS version: an openMINDS
            %   instance IRI carries a version specific namespace, and a map
            %   written for one version resolves to nothing under another.

            if ~isempty(obj.FilePathOverride)
                filepath = obj.FilePathOverride;
                return
            end

            filepath = fullfile(prefdir, "omkg", ...
                sprintf("kg2om_identifier_lookup_v%d.json", ...
                    omkg.getpref("KgOpenMINDSVersion")));
        end

        function filepath = getSeedFilePath(~)
            % getSeedFilePath - Path of the identifier map shipped with the toolbox

            resourceDir = fullfile(...
                fileparts(fileparts(mfilename('fullpath'))), 'resources');

            filepath = fullfile(resourceDir, ...
                sprintf("kg2om_identifier_lookup_v%d.json", ...
                    omkg.getpref("KgOpenMINDSVersion")));
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

            [identifierPairs, rejectedPairs] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(...
                    [instanceUuidListing{:}]);
            obj.IdentifierMap = ...
                omkg.internal.conversion.collapseIdentifierAliases(identifierPairs);

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
            %   The canonical identifier is chosen when the records are
            %   built, so the forward direction has one value per key. The
            %   reverse direction also accepts every alias, so a superseded
            %   identifier still names its Knowledge Graph instance.

            arguments
                obj
                options.Reverse (1,1) logical = false
            end

            mapConstructorFcn = getMapConstructor();

            % Reshape so that an empty registry still yields row vectors
            kgIds = reshape(string({obj.IdentifierMap.kg}), 1, []);
            omIds = reshape(string({obj.IdentifierMap.om}), 1, []);

            if options.Reverse && ~isempty(obj.IdentifierMap)
                % Every alias names the same instance as its canonical
                % identifier, so both have to reach the reverse lookup.
                aliasesPerRecord = {obj.IdentifierMap.aliases};
                aliasCount = cellfun(@numel, aliasesPerRecord);

                omIds = [omIds, reshape(string([aliasesPerRecord{:}]), 1, [])];
                kgIds = [kgIds, repelem(kgIds, aliasCount)];
            end

            if options.Reverse
                map = mapConstructorFcn(omIds, kgIds);
            else
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

            % Record what the mapping describes, not just the mapping. A
            % Knowledge Graph UUID only identifies an instance within a
            % given server, space, stage and openMINDS version, so a file
            % without that scope cannot be checked for applicability.
            saveData = struct();
            saveData.schemaVersion = obj.SCHEMA_VERSION;
            saveData.openmindsVersion = obj.activeOpenMindsVersion();
            saveData.kg = struct(...
                'server', obj.KG_SOURCE_SERVER, ...
                'space', obj.KG_SOURCE_SPACE, ...
                'stage', obj.KG_SOURCE_STAGE);
            saveData.generatedAt = obj.formatTimestamp(obj.LastUpdateTime);
            saveData.identifiers = obj.IdentifierMap;

            fid = fopen(mapFilepath, "wt");
            fileCleanup = onCleanup(@() fclose(fid));
            fwrite(fid, jsonencode(saveData, 'PrettyPrint', true));
        end

        function loadFromFile(obj)
            % loadFromFile - Load identifier map from JSON file
            %
            %   Falls back to the resource shipped with the toolbox, which
            %   only exists for the openMINDS versions it was generated for.
            %   Starting with an empty map is a valid outcome: controlled
            %   instances are then resolved by downloading them from the
            %   Knowledge Graph instead of from the local openMINDS library.

            mapFilepath = obj.getFilePath();
            if ~isfile(mapFilepath)
                if ~isempty(obj.FilePathOverride)
                    % An explicit file means that file and nothing else.
                    return
                end
                mapFilepath = obj.getSeedFilePath();
                if ~isfile(mapFilepath)
                    return
                end
            end

            try
                data = jsondecode(fileread(mapFilepath));

                % Handle both old and new file formats
                if isfield(data, 'identifiers')
                    identifiers = data.identifiers;
                    obj.LastUpdateTime = obj.readTimestamp(data);
                else
                    % Oldest format - a bare array of identifier pairs
                    identifiers = data;
                    obj.LastUpdateTime = datetime.empty;
                end

                if ~obj.isApplicable(data, mapFilepath)
                    obj.LastUpdateTime = datetime.empty;
                    return
                end

                % Records written before aliases were recorded list one row
                % per identifier and have to be grouped after loading.
                isCollapsed = isstruct(identifiers) && isfield(identifiers, 'aliases') ...
                    || iscell(identifiers) && ~isempty(identifiers) ...
                        && isfield(identifiers{1}, 'aliases');

                identifiers = normalizeDecodedRecords(identifiers);

                % The shipped resource and files written before this check
                % existed contain identifiers openMINDS can not resolve.
                % Drop them here so they never reach the lookup maps.
                identifiers = ...
                    omkg.internal.conversion.removeInvalidIdentifierPairs(identifiers);

                if isCollapsed
                    obj.IdentifierMap = identifiers;
                else
                    obj.IdentifierMap = ...
                        omkg.internal.conversion.collapseIdentifierAliases(identifiers);
                end
            catch ME
                warning('OMKG:ControlledInstanceRegistry:LoadFailed', ...
                    'Failed to load identifier map: %s', ME.message);
            end
        end

        function tf = isApplicable(obj, data, mapFilepath)
            % isApplicable - Whether a loaded file describes the active setup
            %
            %   The file name carries the openMINDS version, but a file that
            %   was copied or moved can still claim a version it was not
            %   built for. Checking the recorded scope catches that.

            tf = true;
            if ~isfield(data, 'openmindsVersion')
                % Written before the scope was recorded. The file name is
                % the only evidence available, so take it at face value.
                return
            end

            expectedVersion = obj.activeOpenMindsVersion();
            if string(data.openmindsVersion) ~= expectedVersion
                tf = false;
                warning('OMKG:ControlledInstanceRegistry:VersionMismatch', ...
                    ['Ignoring identifier map "%s": it was built for ', ...
                    'openMINDS %s but %s is active. Run ', ...
                    'omkg.updateControlledInstances to rebuild it.'], ...
                    mapFilepath, string(data.openmindsVersion), expectedVersion);
            end
        end

        function timestamp = readTimestamp(~, data)
            % readTimestamp - Read the generation time from a loaded file

            timestamp = datetime.empty;

            % generatedAt is ISO 8601. lastUpdateTime was written with the
            % locale dependent default datetime format, so it is only read.
            if isfield(data, 'generatedAt') && ~isempty(data.generatedAt)
                timestamp = datetime(data.generatedAt, ...
                    'InputFormat', "yyyy-MM-dd'T'HH:mm:ss", 'TimeZone', 'UTC');
                timestamp.TimeZone = '';
            elseif isfield(data, 'lastUpdateTime') && ~isempty(data.lastUpdateTime)
                try
                    timestamp = datetime(data.lastUpdateTime);
                catch
                    % An unparseable timestamp only means the age is
                    % unknown, which needsUpdate already treats as stale.
                end
            end
        end

        function versionString = activeOpenMindsVersion(~)
            % activeOpenMindsVersion - openMINDS version the mapping applies to

            versionString = sprintf("v%d.0", omkg.getpref("KgOpenMINDSVersion"));
        end

        function timestamp = formatTimestamp(~, value)
            % formatTimestamp - Render a timestamp as UTC ISO 8601

            if isempty(value)
                timestamp = "";
                return
            end

            utcValue = value;
            if isempty(utcValue.TimeZone)
                utcValue.TimeZone = 'local';
            end
            utcValue.TimeZone = 'UTC';
            timestamp = string(utcValue, "yyyy-MM-dd'T'HH:mm:ss");
        end

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


function records = normalizeDecodedRecords(records)
% normalizeDecodedRecords - Give decoded identifier records predictable types
%
%   jsondecode leaves two shapes to sort out. It returns a struct array
%   only when every element has the same fields with the same shapes, so a
%   file where some records carry aliases and others do not decodes to a
%   cell array of scalar structs. And a single JSON string decodes to a
%   char row, whose numel counts characters rather than identifiers.

    if iscell(records)
        recordCell = records;
    else
        recordCell = num2cell(records);
    end

    if isempty(recordCell)
        records = struct('kg', {}, 'om', {});
        return
    end

    hasAliases = isfield(recordCell{1}, 'aliases');
    if hasAliases
        normalized = struct('kg', {}, 'om', {}, 'aliases', {});
    else
        normalized = struct('kg', {}, 'om', {});
    end

    for i = 1:numel(recordCell)
        thisRecord = recordCell{i};
        normalized(i).kg = string(thisRecord.kg);
        normalized(i).om = string(thisRecord.om);
        if hasAliases
            normalized(i).aliases = toStringRow(thisRecord.aliases);
        end
    end
    records = normalized;
end

function value = toStringRow(value)
% toStringRow - Coerce a decoded JSON array of strings to a string row
    if isempty(value)
        value = string.empty;
    else
        value = reshape(string(value), 1, []);
    end
end