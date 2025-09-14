function omNode = convertKgNode(kgNode, omReferenceNode)
% convertKgNode - Convert a knowledge graph node to an openMINDS formatted node.
%
% Syntax:
%   omNode = omkg.internal.conversion.convertKgNode(kgNode)
%
% Input Arguments:
%   kgNode (1,:) - Struct or cell array of metadata nodes/instances returned from the
%       instances api endpoint.
%
% Output Arguments:
%   omNode - Converted openMINDS node or an array of openMINDS nodes if
%       multiple input kgNode structures are provided.

    arguments
        kgNode (1,:) {mustBeA(kgNode, ["struct", "cell"])} % Metadata node/instance returned from the instances api endpoint
        omReferenceNode {mustBeA(omReferenceNode, ["double", "openminds.abstract.Schema"])} = []
    end

    % Loop through each node if a list is provided
    if numel(kgNode) > 1
        omNode = cell(1, numel(kgNode));
        if ~iscell(kgNode); kgNode = num2cell(kgNode); end
        for i = 1:numel(kgNode)
            omNode{i} = omkg.internal.conversion.convertKgNode(kgNode{i});
        end
        try
            % Todo: Check if all are the same type, if yes, concat
            omNode = [omNode{:}];
        catch ME
            % Pass, we keep it as a cell array
        end
        return
    end

    persistent controlledInstanceMap
    if isempty(controlledInstanceMap)
        controlledInstanceMap = omkg.internal.conversion.getIdentifierMapping();
    end

    [identifier, type] = ebrains.kg.internal.getNodeKeywords(kgNode, "@id", "@type");
    
    omNode = omkg.internal.conversion.filterProperties(kgNode);
    omNode = omkg.internal.conversion.removeContextPrefix(omNode);
    
    omDummyNode = openminds.fromTypeName(type, identifier); % create a dummy to get some info about the class we will create

    propertyNames = fieldnames(omNode)';
    propertyValues = cell(size(propertyNames));
    toKeep = true(size(propertyNames));

    for i = 1:numel(propertyNames)
        currentPropertyName = propertyNames{i};
        currentPropertyValue = omNode.(currentPropertyName);

        if ~isprop(omDummyNode, currentPropertyName)
            showUnsupportedPropertyWarning(class(omDummyNode), currentPropertyName)
            toKeep(i) = false;
            continue
        end

        % Recursively process linked/embedded nodes
        if isstruct(omNode.(currentPropertyName))
            if isLinkedNode(currentPropertyValue)
                try
                    if all(isKey(controlledInstanceMap, {currentPropertyValue.x_id}))
                        currentPropertyValue = resolveAsControlledInstances(currentPropertyValue, controlledInstanceMap);
                    else
                        currentPropertyValue = createUnresolvedNode(currentPropertyValue, omDummyNode.(currentPropertyName));
                    end
                catch ME
                    % TODO: Improve error handling for property conversion
                    rethrow(ME);
                end

            elseif isEmbeddedNode(currentPropertyValue)
                currentPropertyValue = omkg.internal.conversion.convertKgNode(currentPropertyValue);
            end
        elseif ischar(currentPropertyValue)
            currentPropertyValue = string(currentPropertyValue);

        else
            % pass : value should not need processing
        end
         
        propertyValues{i} = currentPropertyValue;
    end

    propertyNames = propertyNames(toKeep);
    propertyValues = propertyValues(toKeep);

    if ~isempty(omReferenceNode)
        if isa(omReferenceNode, class(omDummyNode))
            % TODO: Verify this branch is working correctly
            omReferenceNode.set(propertyNames, propertyValues)
        else
            error('OMKG:ConvertKgNode:ReferenceNodeWrongType', ...
                ['Expected reference node to be of type "%s", but it was ', ...
                'of type "%s".'], class(omDummyNode), class(omReferenceNode))
        end
        omNode = omReferenceNode;
    else
        nvPairs = [propertyNames; propertyValues];
        omNode = openminds.fromTypeName(type, identifier, nvPairs(:));
    end
end

function nodes = resolveAsControlledInstances(nodes, identfierMap)
    newNodes = cell(1, numel(nodes));

    for i = 1:numel(nodes)
        omId = identfierMap(nodes(i).x_id);
        newNodes{i} = openminds.instanceFromIRI(omId);
    end
    try
        nodes = [newNodes{:}];
    catch
        nodes = newNodes;
    end
end

function unresolvedNodes = createUnresolvedNode(node, expectedObject)
    numNodes = numel(node);
    unresolvedNodes = cell(1, numNodes); % todo, init correct type
    for iNode = 1:numNodes
        thisNode = node(iNode);

        if openminds.utility.isMixedInstance( expectedObject )
            unresolvedNodes{iNode} = feval(class(expectedObject), thisNode);
        else
            % % if isa(expectedType, 'openminds.abstract.ControlledTerm')
            % %     % Todo: resolve using kg to OMI controlled instance map
            % % else
            % % end
            unresolvedNodes{iNode} = feval(class(expectedObject), 'id', thisNode.x_id);
        end
    end
    unresolvedNodes = [unresolvedNodes{:}];
end

function tf = isLinkedNode(node)
    tf = isstruct(node) && isfield(node, 'x_id');
end

function tf = isEmbeddedNode(node)
    tf = isstruct(node) && isfield(node, 'x_type');
end

function tf = isControlledInstance(node)
    tf = false; %todo
    % isstruct(node) && isfield()
end

function showUnsupportedPropertyWarning(typeName, propertyName)
    warning(...
        ['A downloaded instance of type "%s" includes a property ', ...
         'named "%s", but this property is not defined in the current ', ....
         'version of openMINDS and the property will be dropped.'], ...
         typeName, propertyName);
end
