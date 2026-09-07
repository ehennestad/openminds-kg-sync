classdef KGResolver < openminds.interface.LinkResolver
% KGResolver - Resolve EBRAINS Knowledge Graph reference nodes to instances
%
%   Implements the openminds.interface.LinkResolver contract for identifiers
%   in the EBRAINS Knowledge Graph (KG) instance namespace. A resolver does
%   exactly one thing: fetch or populate a single reference node. Traversal,
%   link depth and cycle detection belong to openMINDS_MATLAB.
%
%   The resolver holds its configuration (server, API client, and the KG to
%   openMINDS identifier map for controlled instances) as instance state.
%   To reconfigure, construct a new resolver and re-register it:
%
%       openminds.registerLinkResolver(omkg.internal.KGResolver(Server="prod"), Replace=true)
%
%   RESOLUTION MODES:
%   A typed reference node (e.g. an openminds.core.Person that only has an
%   id) is populated in place. A reference whose type is not known until the
%   node is downloaded cannot be, because an instance cannot change its
%   class, so a new instance of the downloaded type is built and returned
%   instead. openminds.interface.LinkResolver.isTypeKnown tells the two
%   cases apart. Callers must use the returned value.
%
%   Controlled instances (e.g. controlled terms) exist both in the KG and in
%   the local openMINDS instance library. These are resolved from the local
%   library using the KG to openMINDS identifier map, without any download.
%
%   See also openminds.registerLinkResolver, omkg.sync.downloadMetadata

    properties (Constant)
        IRIPrefix = omkg.constants.KgInstanceIRIPrefix + "/"
    end

    properties (SetAccess = immutable)
        % Server - KG server to download instances from
        Server (1,1) ebrains.kg.enum.KGServer

        % Client - API client used for downloading instances
        Client (1,1) ebrains.kg.api.InstancesClient
    end

    properties (Access = private)
        % IdentifierMap - Map from KG identifiers to openMINDS identifiers
        % for controlled instances (dictionary or containers.Map).
        IdentifierMap = []

        % The identifier map is loaded from the controlled instance registry
        % on first use rather than in the constructor. Registering the
        % resolver at startup must be cheap and offline, and the registry
        % itself calls omkg.internal.checkEnvironment (which constructs a
        % resolver), so loading eagerly would recurse.
        IsIdentifierMapLoaded (1,1) logical = false
    end

    methods
        function obj = KGResolver(options)
        % KGResolver - Create a resolver for KG identifiers
        %
        % Syntax:
        %   resolver = omkg.internal.KGResolver()
        %   resolver = omkg.internal.KGResolver(Name, Value)
        %
        % Name-Value Arguments:
        %   Server (ebrains.kg.enum.KGServer) - KG server to resolve from.
        %       Default: the "DefaultServer" preference.
        %   Client (ebrains.kg.api.InstancesClient) - API client to use.
        %   IdentifierMap - Map from KG identifiers to openMINDS identifiers
        %       for controlled instances. Default: loaded on first use from
        %       omkg.internal.conversion.getIdentifierMapping.

            arguments
                options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
                options.Client (1,1) ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
                options.IdentifierMap {mustBeA(options.IdentifierMap, ["double", "dictionary", "containers.Map"])} = []
            end

            obj.Server = options.Server;
            obj.Client = options.Client;

            if ~isnumeric(options.IdentifierMap)
                obj.IdentifierMap = options.IdentifierMap;
                obj.IsIdentifierMapLoaded = true;
            end
        end

        function instance = resolveNode(obj, instance)
        % resolveNode - Fetch or populate a single KG reference node
        %
        %   The instance is populated in place when its type is known and
        %   replaced by a new instance of the downloaded type when it is not.

            arguments
                obj (1,1) omkg.internal.KGResolver
                instance (1,1) openminds.Node
            end

            identifier = string(instance.id);
            identifierMap = obj.getIdentifierMap();

            if isKey(identifierMap, identifier) % Controlled instance
                openMindsIdentifier = identifierMap(identifier);
                instance = openminds.instanceFromIRI(openMindsIdentifier);
            else
                if openminds.interface.LinkResolver.isTypeKnown(instance)
                    % The instance is populated with the downloaded values.
                    referenceNode = instance;
                else
                    % The type is unknown until the node is downloaded, so
                    % a new typed instance is created from the KG node.
                    referenceNode = [];
                end
                instance = omkg.sync.downloadMetadata(identifier, ...
                    "ReferenceNode", referenceNode, ...
                    "Server", obj.Server, ...
                    "Client", obj.Client);
            end
        end

        function tf = canResolve(obj, IRI)
        % canResolve - Whether the given IRI is a KG instance identifier
            arguments
                obj (1,1) omkg.internal.KGResolver
                IRI (1,1) string
            end
            tf = startsWith(IRI, obj.IRIPrefix);
        end
    end

    methods (Access = private)
        function identifierMap = getIdentifierMap(obj)
        % getIdentifierMap - Return the identifier map, loading it on first use
            if ~obj.IsIdentifierMapLoaded
                obj.IdentifierMap = omkg.internal.conversion.getIdentifierMapping();
                obj.IsIdentifierMapLoaded = true;
            end
            identifierMap = obj.IdentifierMap;
        end
    end
end
