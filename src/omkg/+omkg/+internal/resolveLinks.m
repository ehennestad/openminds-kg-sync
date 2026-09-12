function resolveLinks(instance, instanceIds, instanceCollection)
%resolveLinks Resolve linked types, i.e replace an @id with the actual
% instance object.

    if isstruct(instance) % Instance is not resolvable (E.g belongs to remote collection)
        return
    end

    metaType = openminds.introspection.fromInstance(instance);

    for i = 1:metaType.NumProperties
        thisPropertyName = metaType.PropertyNames{i};
        if metaType.isPropertyWithLinkedType(thisPropertyName)
            linkedInstances = instance.(thisPropertyName);

            resolvedInstances = cell(size(linkedInstances));

            for j = 1:numel(linkedInstances)
                if openminds.utility.isMixedInstance(linkedInstances(j))
                    try
                        instanceId = linkedInstances(j).Instance.id;
                    catch
                        instanceId = linkedInstances(j).Instance;
                    end
                else
                    instanceId = linkedInstances(j).id;
                end

                isMatchedInstance = instanceIds == string(instanceId);

                if any(isMatchedInstance)
                    resolvedInstances{j} = instanceCollection{isMatchedInstance};
                    omkg.internal.resolveLinks(resolvedInstances{j}, instanceIds, instanceCollection)
                else
                    % A controlled instance is taken from the local library.
                    % The library is asked first, because the KG also links
                    % to nodes by an IRI in the openMINDS instance namespace
                    % that has no instance behind it (e.g. a viewer
                    % specification's display colour).
                    if omkg.internal.conversion.hasControlledInstance(instanceId)
                        resolvedInstances{j} = omkg.internal.conversion.getControlledInstance(instanceId);
                    else
                        % Neither downloaded nor in the library. The entry
                        % is kept as it is, so that a link which could not
                        % be resolved is not dropped from the property
                        % alongside those which could.
                        resolvedInstances{j} = linkedInstances(j);
                    end
                end
            end

            try
                resolvedInstances = [resolvedInstances{:}];
            catch
                assert(isa(resolvedInstances, 'cell'), ...
                    'Expected resolved instances to be a cell array')
            end

            if ~isempty(resolvedInstances)
                instance.(thisPropertyName) = resolvedInstances;
            end

        elseif metaType.isPropertyWithEmbeddedType(thisPropertyName)
            embeddedInstances = instance.(thisPropertyName);

            for j = 1:numel(embeddedInstances)
                if openminds.utility.isMixedInstance(embeddedInstances(j))
                    embeddedInstance = embeddedInstances(j).Instance;
                else
                    embeddedInstance = embeddedInstances(j);
                end
                omkg.internal.resolveLinks(embeddedInstance, instanceIds, instanceCollection)
            end
        end
    end
end
