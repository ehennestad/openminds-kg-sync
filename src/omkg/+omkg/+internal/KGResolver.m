classdef KGResolver < openminds.interface.LinkResolver
% KGResolver - Resolve EBRAINS Knowledge Graph reference nodes to instances
%
%   Implements the openminds.interface.LinkResolver contract for identifiers
%   in the EBRAINS Knowledge Graph (KG) instance namespace. A resolver does
%   exactly one thing: fetch or populate a single reference node. Traversal,
%   link depth and cycle detection belong to openMINDS_MATLAB.
%
%   The resolver holds its configuration (server and API client) as
%   instance state.
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
%   library, without any download, when the ControlledInstanceIdentity
%   preference is "openminds" and the controlled instance cache knows the
%   reference. The reference keeps its Knowledge Graph identifier: the
%   library instance's values are copied onto it. Under the "kg" policy a
%   controlled instance is downloaded like any other node.
%   The resolved node keeps the KG identifier of the reference, as the
%   resolver contract requires; only the property values come from the
%   library instance.
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
            cache = omkg.internal.ControlledInstanceCache.instance();

            % Under the "openminds" identity policy a controlled instance
            % the cache knows is populated from the local library. One the
            % Knowledge Graph has but the library does not is downloaded
            % like any other node, which is how convertKgNode left it:
            % asking the library for it would yield an empty instance and
            % a warning, not an error, and the reference would be marked
            % resolved with nothing in it.
            isLibraryInstance = false;
            if cache.isKnown(identifier)
                openMindsIdentifier = cache.lookup(identifier);
                isLibraryInstance = ...
                    omkg.internal.conversion.isControlledInstanceName(openMindsIdentifier);
            end

            if isLibraryInstance
                instance = obj.resolveControlledInstance(instance, openMindsIdentifier);
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

    methods (Static, Access = private)
        function instance = resolveControlledInstance(instance, openMindsIdentifier)
        % resolveControlledInstance - Populate a reference from the local library
        %
        %   The library instance is identified by its openMINDS IRI, while
        %   the reference is identified by its KG IRI and every link to it
        %   is written with that IRI. A resolver must not change the
        %   identifier of the reference it resolves, so the library
        %   instance is not returned as is. Its property values are copied
        %   onto a node that carries the identifier of the reference.
        %
        %   getPropertyValues leaves out id and IsReference, so the typed
        %   path below (instance.set(...)) cannot touch the reference's
        %   identifier even though it sets in place; the mixed-type path
        %   sets id explicitly from the reference for the same reason.

            libraryInstance = omkg.internal.conversion.getControlledInstance(openMindsIdentifier);
            [propertyNames, propertyValues] = omkg.internal.getPropertyValues(libraryInstance);

            if openminds.interface.LinkResolver.isTypeKnown(instance)
                if ~isa(instance, class(libraryInstance))
                    error('OMKG:KGResolver:ControlledInstanceTypeMismatch', ...
                        ['The reference "%s" is a %s, but its identifier maps to ', ...
                         'the controlled instance "%s", which is a %s.'], ...
                        instance.id, class(instance), openMindsIdentifier, ...
                        class(libraryInstance))
                end
                instance.set(propertyNames, propertyValues);
            else
                nvPairs = [propertyNames; propertyValues];
                instance = feval(class(libraryInstance), ...
                    'id', string(instance.id), nvPairs{:});
            end
        end
    end
end
