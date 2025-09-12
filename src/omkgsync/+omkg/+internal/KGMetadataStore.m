classdef KGMetadataStore < openminds.interface.MetadataStore

    properties (Access = private)
        InstanceClient = ebrains.kg.api.InstancesClient()
    end

    methods
        function obj = KGMetadataStore(propValues)

            arguments
                propValues.Serializer = omkg.internal.KGSerializer()
                propValues.InstanceClient = ebrains.kg.api.InstancesClient()
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

            % Work through properties and save linked instances recursively.
            propNames = properties(instance);
            for i = 1:numel(propNames)
                currentPropertyName = propNames{i};
                currentPropertyValue = instance.(currentPropertyName);
                
                if openminds.utility.isControlledInstance(currentPropertyValue)
                    % Check that the id is part of the KG 2 OM map?
                    continue
                end

                if openminds.utility.isInstance(currentPropertyValue)
                    if isLinked() % Todo
                        currentPropertyValue.save(obj)
                    elseif isEmbedded() % Todo
                        currentPropertyValue.save(obj, 'IsEmbedded', true)
                    elseif openminds.utility.isMixedInstance(currentPropertyValue) % Should not be necessary...
                        currentPropertyValue.save(obj)
                    end
                else
                    continue
                end
            end

            if options.IsEmbedded
                % Embedded instances are not saved on their own.
            else
                instanceID = instance.id;
                
                % Save instance
                jsonDoc = instance.serialize("Serializer", obj.Serializer);
    
                if isKgIdentifier(instanceID)
                    if options.SaveMode == "update"
                        resp = obj.InstanceClient.updateInstance(instanceID, jsonDoc, "returnPayload", false);
                    elseif options.SaveMode == "replace"
                        resp = obj.InstanceClient.replaceInstance(instanceID, jsonDoc, "returnPayload", false);
                    else
                        error("Internal error. Unsupported save mode %s", options.SaveMode)
                    end
                                
                    % Assert id is the same as before

                else
                    % Todo: Determine space to save to.
                    resp = obj.InstanceClient.createNewInstance(jsonDoc, "returnPayload", false);
                    id = resp.id; % TODO
                end
            end
        end
    end
end
