function omNode = convertKgNode(kgNode, omReferenceNode, options)
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
        options.ParentNode = [];
    end

    % Loop through each node if a list is provided
    if numel(kgNode) > 1
        omNode = cell(1, numel(kgNode));
        if ~iscell(kgNode); kgNode = num2cell(kgNode); end
        for i = 1:numel(kgNode)
            omNode{i} = omkg.internal.conversion.convertKgNode(kgNode{i}, "ParentNode", options.ParentNode);
        end
        
        omNode = omkg.util.concatTypesIfHomogeneous(omNode);
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
        if isstruct(currentPropertyValue) || iscell(currentPropertyValue)
            if isLinkedNode(currentPropertyValue)
                try
                    if all(isKey(controlledInstanceMap, {currentPropertyValue.x_id})) 
                        % Todo: check and resolve one by one. What if some are
                        % resolvable and others are not.
                        currentPropertyValue = resolveAsControlledInstances(currentPropertyValue, controlledInstanceMap);
                    else
                        currentPropertyValue = createUnresolvedNode(currentPropertyValue, omDummyNode.(currentPropertyName));
                    end
                catch ME
                    % TODO: Improve error handling for property conversion
                    rethrow(ME);
                end

            elseif isEmbeddedNode(currentPropertyValue)
                currentPropertyValue = omkg.internal.conversion.convertKgNode(currentPropertyValue, "ParentNode", kgNode);
            end
        elseif ischar(currentPropertyValue)
            % Todo: Consider if this should be added to user preferences class.
            convertChar = getpref('omkg', 'ConvertChar', false);
            if convertChar
                % If string, text numbers are correctly converted to numerics,
                % if char they are converted to numeric arrays...
                currentPropertyValue = string(currentPropertyValue);
            end
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
            omReferenceNode.set(propertyNames, propertyValues);
        else
            error('OMKG:ConvertKgNode:ReferenceNodeWrongType', ...
                ['Expected reference node to be of type "%s", but it was ', ...
                'of type "%s".'], class(omDummyNode), class(omReferenceNode))
        end
        omNode = omReferenceNode;
    else
        try
            nvPairs = [propertyNames; propertyValues];
            omNode = openminds.fromTypeName(type, identifier, nvPairs(:));
        catch MECause
            errorId = 'OMKG:ConvertKGNode:ConversionFailed';
            
            if isempty(options.ParentNode)
                errorMessage = sprintf(...
                    'Failed to create instance with identifier "%s".', ...
                    identifier);
            else
                % Todo: will not work for nested embedded instances.
                [parentIdentifier, parentType] = ebrains.kg.internal.getNodeKeywords(options.ParentNode, "@id", "@type");
                errorMessage = sprintf(...
                    ['Failed to create embedded instance for type "%s" with ', ...
                    'identifier "%s".'], ...
                    parentType{1}, parentIdentifier);
            end

            ME = MException(errorId, errorMessage);
            ME = ME.addCause(MECause);
            throw(ME)
        end
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
            unresolvedNodes{iNode} = feval(class(expectedObject), 'id', thisNode.x_id);
        end
    end
    unresolvedNodes = [unresolvedNodes{:}];
end

function tf = isLinkedNode(node)
    tf = isstruct(node) && isfield(node, 'x_id');
end

function tf = isEmbeddedNode(node)
    isEmbedded = @(x) isstruct(x) && isfield(x, 'x_type');
    
    if iscell(node) % non-scalar
        tf = all(cellfun(@(c) isEmbedded(c), node));
    elseif isstruct(node)
        tf = isfield(node, 'x_type');
    else
        tf = false;
    end
end

function showUnsupportedPropertyWarning(typeName, propertyName)
    warning(...
        ['A downloaded instance of type "%s" includes a property ', ...
         'named "%s", but this property is not defined in the current ', ....
         'version of openMINDS and the property will be dropped.'], ...
         typeName, propertyName);
end
