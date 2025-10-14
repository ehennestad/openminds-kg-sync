classdef KGSerializer < openminds.internal.serializer.JsonLdSerializer
% KGSerializer - Serializer that creates json-ld for the Knowledge Graph

% Todo:
%
% When saving,
% - recursive should be true/inf, and links should be followed to the end

    properties
        % Will only serialize properties in this list. Useful for targeted
        % patch operations.
        PropertyFilter (1,:) string = string.empty
    end

    methods
        function obj = KGSerializer(config, kgOptions)
            arguments
                config.RecursionDepth = 0
                config.IncludeIdentifier (1,1) logical = false % Should this be fixed?
                config.EnableCaching (1,1) logical = true
                config.EnableValidation (1,1) logical = true
                config.PrettyPrint (1,1) logical = true
                kgOptions.PropertyFilter (1,:) string = string.empty
            end
            config.PropertyNameSyntax = "expanded"; % compact not supported for KG
            config.IncludeEmptyProperties = false; % minimize payloads
            config.OutputMode = "multiple";

            nvPairs = namedargs2cell(config);
            obj = obj@openminds.internal.serializer.JsonLdSerializer(nvPairs{:})
            obj.PropertyFilter = kgOptions.PropertyFilter;
        end
    end

    methods (Access = protected)
        function allStructs = postProcessInstances(obj, allStructs)
            arguments
                obj (1,1) openminds.internal.serializer.JsonLdSerializer
                allStructs (1,:) {omkg.validator.mustBeCellOfStructs}
            end

            % Apply property filter if present
            if ~isempty(obj.PropertyFilter)
                % Only keep property names in the PropertyFilter array
                WHITE_LIST = ["at_id", "at_type"]; % Need to keep these
                obj.PropertyFilter = unique([obj.PropertyFilter, WHITE_LIST]);

                for i = 1:numel(allStructs)
                    currentStruct = allStructs{i};

                    currentFields = fieldnames(currentStruct);
                    fieldsRemove = setdiff(currentFields, obj.PropertyFilter);

                    currentStruct = rmfield(currentStruct, fieldsRemove);
                    allStructs{i} = currentStruct;
                end
            end
            allStructs = postProcessInstances@openminds.internal.serializer.JsonLdSerializer(obj, allStructs);
        end
    end
end
