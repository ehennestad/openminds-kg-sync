classdef KGResolver < openminds.interface.LinkResolver
% KGResolver - Resolve EBRAINS Knowledge Graph reference nodes to instances
%
%   Implements the openminds.interface.LinkResolver contract for identifiers
%   in the EBRAINS Knowledge Graph (KG) instance namespace. A resolver does
%   exactly one thing: fetch or populate a single reference node. Traversal,
%   link depth and cycle detection belong to openMINDS_MATLAB.
%
%   The resolver holds its configuration (server and API client) as
%   instance state. To reconfigure, construct a new resolver and
%   re-register it:
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
%   Controlled instances (e.g. controlled terms) are downloaded like any
%   other node. The downloaded node carries its openMINDS IRI in
%   schema:identifier, and the converted instance is identified by that IRI
%   rather than by the Knowledge Graph UUID, so a typed controlled instance
%   reference is replaced rather than populated in place.
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

            arguments
                options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
                options.Client (1,1) ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
            end

            obj.Server = options.Server;
            obj.Client = options.Client;
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

        function tf = canResolve(obj, IRI)
        % canResolve - Whether the given IRI is a KG instance identifier
            arguments
                obj (1,1) omkg.internal.KGResolver
                IRI (1,1) string
            end
            tf = startsWith(IRI, obj.IRIPrefix);
        end
    end
end
