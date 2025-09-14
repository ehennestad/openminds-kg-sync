classdef KGMetadataStore < openminds.interface.MetadataStore
% KGMetadataStore - Metadata store implementation for EBRAINS Knowledge Graph
%
% This class handles saving openMINDS instances to the EBRAINS KG with
% intelligent handling of linked vs embedded properties:
%
% LINKED PROPERTIES:
%   - Saved as separate instances in KG
%   - Referenced by ID only in parent instance
%
% EMBEDDED PROPERTIES:
%   - Serialized inline within parent instance
%   - Not saved as separate KG instances

    properties (SetAccess = private)
        DefaultServer (1,1) ebrains.kg.enum.KGServer
        DefaultSpace (1,1) string
    end

    properties (Access = private)
        InstanceClient = ebrains.kg.api.InstancesClient()
        SpaceConfiguration omkg.util.SpaceConfiguration
        Verbose (1,1) logical = true
    end

    methods
        function obj = KGMetadataStore(propValues)

            arguments
                propValues.Serializer = omkg.internal.KGSerializer()
                propValues.InstanceClient = ebrains.kg.api.InstancesClient()
                propValues.DefaultServer (1,1) ebrains.kg.enum.KGServer
                propValues.DefaultSpace (1,1) string
                propValues.SpaceConfiguration = omkg.util.SpaceConfiguration.loadDefault()
                propValues.Verbose (1,1) logical = true
            end
            obj.set(propValues)
        end
    end

    methods
        function id = save(obj, instance, options)
            arguments
                obj (1,1) omkg.internal.KGMetadataStore
                instance (1,1) openminds.abstract.Schema
                options.IsEmbedded (1,1) logical = false
                options.SaveMode (1,1) string {mustBeMember(options.SaveMode, ["update", "replace"])} = "update"
            end

            if instance.isReference()
                id = instance.id;
                return
            end

            linkedTypes = instance.getLinkedTypes();
            embeddedTypes = instance.getEmbeddedTypes();

            % Recursively save linked types
            for i = 1:numel(linkedTypes)
                currentValue = linkedTypes{i};
                if openminds.utility.isControlledInstance(currentValue)
                    % Check that the id is part of the KG 2 OM map?
                    continue
                end
                currentValue.save(obj)
            end

            % Recursively save embedded types
            for i = 1:numel(embeddedTypes)
                currentValue = embeddedTypes{i};
                currentValue.save(obj, 'IsEmbedded', true)
            end

            if options.IsEmbedded
                id = instance.id;
                % Embedded instances are not saved on their own.
            else
                instanceID = instance.id;
                
                % Save instance
                jsonDoc = instance.serialize("Serializer", obj.Serializer);
    
                if obj.isKgIdentifier(instanceID)
                    uuid = omkg.util.getIdentifierUUID(instanceID);

                    if options.SaveMode == "update"
                        obj.InstanceClient.updateInstance(uuid, jsonDoc, "returnPayload", false);
                    elseif options.SaveMode == "replace"
                        obj.InstanceClient.replaceInstance(uuid, jsonDoc, "returnPayload", false);
                    else
                        error("OMKG:KGMetadataStore:UnsupportedSaveMode", ...
                            "Unsupported save mode: %s", options.SaveMode)
                    end
                    id = instanceID; % Return the existing ID

                else % Create new instance

                    % Assume a blank node identifier with a valid uuid
                    % portion. Using existing uuid to ensure idempotency if
                    % possible.
                    try
                        uuid = obj.getUuidFromInstance(instance);
                    catch
                        uuid = matlab.lang.internal.uuid();
                    end

                    % Determine space to save to
                    if obj.DefaultSpace == "auto"
                        space = obj.resolveSpace(instance);
                    else
                        space = obj.DefaultSpace;
                    end

                    resp = obj.InstanceClient.createNewInstanceWithId(...
                        uuid, jsonDoc, "space", space, "returnPayload", true);
                    id = resp.data.x_id;
                    
                    if obj.Verbose
                        fprintf('Saved instance "%s" of type "%s" to space "%s".\n', string(instance), class(instance), space)
                    end

                    % Update the local instance with the new KG ID
                    instance.id = id;
                end
            end
        end
    end
    
    methods (Access = private)
        function isKg = isKgIdentifier(~, identifier)
            % Check if identifier is a KG identifier (contains KG URL pattern)
            if isempty(identifier) || ~ischar(identifier) && ~isstring(identifier)
                isKg = false;
            else
                kgPrefix = omkg.constants.KgInstanceIRIPrefix;
                isKg = startsWith(string(identifier), kgPrefix);
            end
        end

        function tf = isBlankNodeIdentifier(~, identifier)
            tf = startsWith(identifier, '_:');
        end

        function uuid = getUuidFromInstance(obj, instance)
            if obj.isBlankNodeIdentifier(instance.id)
                uuid = extractAfter('_:', instance.id);
            else
                error('Unsupported instance identifier.')
            end
            omkg.validator.mustBeValidUUID(uuid)
        end
    
        function space = resolveSpace(obj, instance)
            type = openminds.enum.Types.fromClassName(class(instance));
            space = obj.SpaceConfiguration.getSpace(type);
        end
    end
end
