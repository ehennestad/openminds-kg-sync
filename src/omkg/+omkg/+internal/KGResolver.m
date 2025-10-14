classdef KGResolver < openminds.internal.resolver.AbstractLinkResolver

    properties (Constant)
        IRIPrefix = "https://kg.ebrains.eu/api/instances/" % Todo: get from constant
    end

    methods (Static)
        function instance = resolve(instance, options)
            arguments
                instance (1,1) openminds.abstract.Schema % todo: support array
                options.NumLinksToResolve = 0
            end

            persistent Kg2OmIdentifierMap
            if isempty(Kg2OmIdentifierMap)
                Kg2OmIdentifierMap = omkg.internal.conversion.getIdentifierMapping();
            end

            identifier = instance.id;

            if isKey(Kg2OmIdentifierMap, identifier) % Controlled instance
                openMindsIdentifier = Kg2OmIdentifierMap(identifier);
                instance = openminds.instanceFromIRI(openMindsIdentifier);
            else
                nvPairs = namedargs2cell(options);
                if isa(instance, 'openminds.internal.MixedTypeReference')
                    % No node to update, we need to create a new typed instance
                    referenceNode = [];
                else
                    % Pass instance as reference node, instance will be
                    % updated/populated with resolved values.
                    referenceNode = instance;
                end
                instance = omkg.sync.downloadMetadata(identifier, nvPairs{:}, 'ReferenceNode', referenceNode);
            end
        end

        function tf = canResolve(IRI)
            arguments
                IRI (1,:) string
            end
            tf = all(startsWith(IRI, omkg.internal.KGResolver.IRIPrefix));
        end
    end
end
