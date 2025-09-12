classdef KGSerializer < openminds.internal.serializer.JsonLdSerializer
    
    % Todo: 
    % 
    % When saving, 
    % - recursive should be true/inf, and links should be followed to the end
    % - leaf nodes need to be saved first (lnked nodes must exist in KG).

    methods
        function obj = KGSerializer(config)

            arguments
                config.RecursionDepth = 0
                config.IncludeIdentifier (1,1) logical = false % Should this be fixed?
                config.EnableCaching (1,1) logical = true
                config.EnableValidation (1,1) logical = true
                config.PrettyPrint (1,1) logical = true
            end
            config.PropertyNameSyntax = "expanded"; % compact not supported for KG
            config.IncludeEmptyProperties = false; % minimize payloads
            config.OutputMode = "multiple";

            nvPairs = namedargs2cell(config);
            obj = obj@openminds.internal.serializer.JsonLdSerializer(nvPairs{:})
        end
    end
end
