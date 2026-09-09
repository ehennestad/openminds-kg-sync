classdef ControlledInstanceCache < handle
% ControlledInstanceCache - Remembers the openMINDS IRI of KG controlled instances
%
%   Maps the Knowledge Graph IRI of a controlled instance to its openMINDS
%   IRI. A link to a controlled instance takes its openMINDS identity while
%   its parent is converted, because a link resolver may not change the
%   identifier of a reference it resolves later. That decision needs the
%   openMINDS IRI before the parent is built, and this cache supplies it.
%
%   It is filled from the Knowledge Graph itself: every controlled instance
%   node carries its openMINDS IRI in schema:identifier. downloadMetadata
%   fetches the unknown controlled instance links of a node before
%   converting it, so the lookup does not depend on what was seen before,
%   and omkg.downloadControlledInstances fills it for every controlled
%   term type in one go. Nothing ships with the toolbox.
%
%   Used only while the ControlledInstanceIdentity preference is
%   "openminds". Under "kg" record and isKnown are no-ops, so callers need
%   not branch on the policy.
%
%   Persisted as JSON in the folder named by the
%   ControlledInstanceCacheFolder preference, or under userpath when that
%   is empty. The file is keyed by openMINDS version, since an openMINDS
%   IRI carries a version specific namespace. It is not keyed by Knowledge
%   Graph server: preprod is a daily-refreshed mirror of prod, so a UUID
%   names the same instance on either. The KG space and stage a fill
%   requested are recorded for provenance.
%
% Usage:
%   cache = omkg.internal.ControlledInstanceCache.instance();
%   cache.record(kgIRI, openMindsIRI)
%   if cache.isKnown(kgIRI), iri = cache.lookup(kgIRI); end
%
% See also: omkg.downloadControlledInstances, omkg.setpref

    properties (SetAccess = private)
        % Path of the file the cache was loaded from, or will be saved to
        FilePath (1,1) string = ""
    end

    properties (Access = private)
        Entries dictionary = dictionary(string.empty, string.empty)
        FilePathOverride (1,1) string = ""  % Injectable cache file for testing
    end

    properties (Constant, Access = private)
        SCHEMA_VERSION = "1.0"
        FILE_NAME_PATTERN = "controlled_instance_cache_v%d.json"
        DEFAULT_SUBFOLDER = "omkg"

        % Controlled instances live in the "controlled" space at the
        % RELEASED stage, which is what every fill requests.
        KG_SOURCE_SPACE = "controlled"
        KG_SOURCE_STAGE = "RELEASED"
    end

    methods (Access = private)
        function obj = ControlledInstanceCache(options)
            arguments
                options.File (1,1) string = ""
            end
            obj.FilePathOverride = options.File;
        end
    end

    methods (Static)
        function obj = instance(options)
            % instance - Get or create the singleton cache
            %
            % Syntax:
            %   cache = omkg.internal.ControlledInstanceCache.instance()
            %   cache = omkg.internal.ControlledInstanceCache.instance(Name, Value)
            %
            % Name-Value Arguments:
            %   File  - Cache file to use instead of the configured location.
            %           Given only when creating the singleton, e.g. in tests.
            %   Reset - Discard the current singleton first.

            arguments
                options.File (1,1) string = ""
                options.Reset (1,1) logical = false
            end

            persistent singletonInstance

            if options.Reset || isempty(singletonInstance) || ~isvalid(singletonInstance)
                singletonInstance = omkg.internal.ControlledInstanceCache("File", options.File);
            end

            obj = singletonInstance;
        end
    end

    methods
        function tf = isEnabled(~)
            % isEnabled - Whether controlled instances take openMINDS identity
            tf = omkg.getpref("ControlledInstanceIdentity") == "openminds";
        end

        function tf = isKnown(obj, kgIRI)
            % isKnown - Whether the openMINDS IRI of each KG IRI is cached
            %
            %   Always false while the cache is disabled.

            arguments
                obj (1,1) omkg.internal.ControlledInstanceCache
                kgIRI string
            end

            kgIRI = reshape(kgIRI, 1, []);
            if ~obj.isEnabled() || isempty(kgIRI)
                tf = false(size(kgIRI));
                return
            end

            obj.ensureLoaded();
            tf = isKey(obj.Entries, kgIRI);
        end

        function openMindsIRI = lookup(obj, kgIRI)
            % lookup - The cached openMINDS IRI for a KG IRI

            arguments
                obj (1,1) omkg.internal.ControlledInstanceCache
                kgIRI (1,1) string
            end

            obj.ensureLoaded();
            if ~isKey(obj.Entries, kgIRI)
                error('OMKG:ControlledInstanceCache:NotCached', ...
                    'No openMINDS IRI is cached for "%s".', kgIRI)
            end
            openMindsIRI = obj.Entries(kgIRI);
        end

        function record(obj, kgIRI, openMindsIRI)
            % record - Remember the openMINDS IRI of a KG controlled instance
            %
            %   Does nothing while the cache is disabled. A new entry is
            %   written to disk immediately: new entries are rare once the
            %   cache is warm, and this keeps the file correct without a
            %   save step at every call site.

            arguments
                obj (1,1) omkg.internal.ControlledInstanceCache
                kgIRI string
                openMindsIRI string
            end

            if ~obj.isEnabled()
                return
            end

            kgIRI = reshape(kgIRI, 1, []);
            openMindsIRI = reshape(openMindsIRI, 1, []);
            assert(numel(kgIRI) == numel(openMindsIRI), ...
                'OMKG:ControlledInstanceCache:SizeMismatch', ...
                'Expected one openMINDS IRI per Knowledge Graph IRI.')

            obj.ensureLoaded();

            isNew = ~isKey(obj.Entries, kgIRI);
            isChanged = false(size(kgIRI));
            isChanged(~isNew) = obj.Entries(kgIRI(~isNew)) ~= openMindsIRI(~isNew);
            if ~any(isNew | isChanged)
                return
            end

            obj.Entries(kgIRI) = openMindsIRI;
            obj.save();
        end

        function n = numEntries(obj)
            % numEntries - Number of cached instances
            obj.ensureLoaded();
            n = obj.Entries.numEntries;
        end

        function clear(obj)
            % clear - Forget every entry and remove the cache file
            obj.Entries = dictionary(string.empty, string.empty);
            obj.FilePath = obj.getFilePath();
            if isfile(obj.FilePath)
                delete(obj.FilePath)
            end
        end

        function filePath = getFilePath(obj)
            % getFilePath - Where the cache for the active openMINDS version lives
            %
            %   The ControlledInstanceCacheFolder preference names the folder.
            %   When it is empty the folder is "omkg" under userpath, which
            %   is the user's own MATLAB folder rather than a hidden
            %   preferences directory.

            if strlength(obj.FilePathOverride) > 0
                filePath = obj.FilePathOverride;
                return
            end

            folder = omkg.getpref("ControlledInstanceCacheFolder");
            if strlength(folder) == 0
                folder = fullfile(userpath, obj.DEFAULT_SUBFOLDER);
            end

            fileName = sprintf(obj.FILE_NAME_PATTERN, omkg.getpref("KgOpenMINDSVersion"));
            filePath = fullfile(folder, fileName);
        end
    end

    methods (Access = private)
        function ensureLoaded(obj)
            % ensureLoaded - Load the file for the current location and version
            %
            %   The location follows two preferences and the openMINDS
            %   version, any of which can change during a session, so the
            %   file is reloaded whenever the resolved path differs from the
            %   one currently held.

            filePath = obj.getFilePath();
            if filePath == obj.FilePath
                return
            end

            obj.FilePath = filePath;
            obj.Entries = dictionary(string.empty, string.empty);
            obj.load();
        end

        function load(obj)
            if ~isfile(obj.FilePath)
                return
            end

            try
                data = jsondecode(fileread(obj.FilePath));
            catch ME
                warning('OMKG:ControlledInstanceCache:LoadFailed', ...
                    'Ignoring unreadable controlled instance cache "%s": %s', ...
                    obj.FilePath, ME.message)
                return
            end

            expectedVersion = obj.activeOpenMindsVersion();
            if ~isfield(data, 'openmindsVersion') || string(data.openmindsVersion) ~= expectedVersion
                warning('OMKG:ControlledInstanceCache:VersionMismatch', ...
                    ['Ignoring controlled instance cache "%s": it was not built ', ...
                    'for openMINDS %s. Run omkg.downloadControlledInstances to rebuild it.'], ...
                    obj.FilePath, expectedVersion)
                return
            end

            if ~isfield(data, 'entries') || isempty(data.entries)
                return
            end

            entries = data.entries;
            if iscell(entries)
                entries = [entries{:}];
            end
            kgIRIs = string({entries.kg});
            omIRIs = string({entries.om});

            % A hand edited or older file can hold pairs that openMINDS can
            % not resolve. Drop them here so they never reach a lookup.
            isValid = strlength(kgIRIs) > 0 ...
                & omkg.internal.conversion.isOpenMindsInstanceIRI(omIRIs);
            if ~all(isValid)
                warning('OMKG:ControlledInstanceCache:InvalidEntries', ...
                    'Ignoring %d entries of "%s" that do not name an openMINDS instance.', ...
                    nnz(~isValid), obj.FilePath)
            end
            obj.Entries(kgIRIs(isValid)) = omIRIs(isValid);
        end

        function save(obj)
            folder = fileparts(obj.FilePath);
            if strlength(folder) > 0 && ~isfolder(folder)
                mkdir(folder)
            end

            kgIRIs = keys(obj.Entries);
            data = struct();
            data.schemaVersion = obj.SCHEMA_VERSION;
            data.openmindsVersion = obj.activeOpenMindsVersion();
            data.kg = struct(...
                'space', obj.KG_SOURCE_SPACE, ...
                'stage', obj.KG_SOURCE_STAGE);
            data.generatedAt = string(datetime('now', 'TimeZone', 'UTC'), "yyyy-MM-dd'T'HH:mm:ss'Z'");
            data.entries = struct('kg', cellstr(kgIRIs), 'om', cellstr(obj.Entries(kgIRIs)));

            fid = fopen(obj.FilePath, "wt");
            fileCleanup = onCleanup(@() fclose(fid));
            fwrite(fid, jsonencode(data, 'PrettyPrint', true));
        end

        function versionString = activeOpenMindsVersion(~)
            versionString = sprintf("v%d.0", omkg.getpref("KgOpenMINDSVersion"));
        end
    end
end
