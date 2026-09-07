function omNode = convertKgNode(kgNode, omReferenceNode, options)
% convertKgNode - Convert a knowledge graph node to an openMINDS formatted node.
%
% Syntax:
%   omNode = omkg.internal.conversion.convertKgNode(kgNode)
%   omNode = omkg.internal.conversion.convertKgNode(kgNode, omReferenceNode)
%   omNode = omkg.internal.conversion.convertKgNode(kgNode, omReferenceNode, options)
%
% Input Arguments:
%   - kgNode (1,:) - Struct or cell array of metadata nodes/instances returned
%       from the instances API endpoint (jsonld converted to struct by
%       jsondecode). JSON-LD keyword fields may be in x_ form (x_id, x_type)
%       as produced by jsondecode, or in the at_ form (at_id, at_type) used
%       by openMINDS_MATLAB.
%   - omReferenceNode (openminds.Node) - Optional reference node for
%       setting properties. If not provided, a new openMINDS node will be
%       created. Used if we are resolving a node instead of creating a new
%       one.
%
% Name-Value Arguments (options):
%  Specify options using name-value arguments as Name1=Value1,...,NameN=ValueN,
%  where Name is the argument name and Value is the corresponding value.
%
%  - ParentNode (Type) - Default: []. Parent node for the converted instance or linked node.
%
% Output Arguments:
%   omNode - Converted openMINDS node or an array of openMINDS nodes if
%       multiple input kgNode structures are provided.

    arguments
        kgNode (1,:) {mustBeA(kgNode, ["struct", "cell"])} % Metadata node/instance returned from the instances api endpoint
        omReferenceNode {mustBeA(omReferenceNode, ["double", "openminds.Node"])} = []
        options.ParentNode = [];
    end

    % Hand structs to openMINDS in the at_ form it expects for keywords
    kgNode = omkg.internal.conversion.normalizeJsonLdKeywords(kgNode);
    options.ParentNode = omkg.internal.conversion.normalizeJsonLdKeywords(options.ParentNode);

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

    % A single node may still arrive wrapped in a cell, e.g. a bulk
    % response holding exactly one instance.
    if iscell(kgNode)
        kgNode = kgNode{1};
    end

    [identifier, type] = omkg.internal.conversion.getNodeKeywords(kgNode, "@id", "@type");

    % A controlled instance is identified by its openMINDS IRI, not by the
    % UUID the Knowledge Graph assigned it. The IRI travels in
    % schema:identifier, which filterProperties drops, so read it first.
    controlledInstanceIRI = omkg.internal.conversion.getControlledInstanceIRI(kgNode);
    isControlledInstance = strlength(controlledInstanceIRI) > 0;
    if isControlledInstance
        identifier = controlledInstanceIRI;
    end

    processedKgNode = omkg.internal.conversion.filterProperties(kgNode);
    processedKgNode = omkg.internal.conversion.removeNamespaceIRIFromPropertyNames(processedKgNode);

    omDummyNode = openminds.fromTypeName(type, identifier); % create a dummy to get some info about the class we will create

    propertyNames = fieldnames(processedKgNode)';
    propertyValues = cell(size(propertyNames));
    toKeep = true(size(propertyNames));

    for i = 1:numel(propertyNames)
        currentPropertyName = propertyNames{i};
        currentPropertyValue = processedKgNode.(currentPropertyName);

        if ~isprop(omDummyNode, currentPropertyName)
            showUnsupportedPropertyWarning(class(omDummyNode), currentPropertyName)
            toKeep(i) = false;
            continue
        end

        % Recursively process linked/embedded nodes
        if isstruct(currentPropertyValue) || iscell(currentPropertyValue)
            if isLinkedNode(currentPropertyValue)
                % Every link, controlled instances included, becomes a
                % reference that is resolved by download. The downloaded
                % node carries the identity to use, so nothing has to be
                % known about the target up front.
                currentPropertyValue = createUnresolvedNode(currentPropertyValue, omDummyNode.(currentPropertyName));

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

    % A controlled instance is always built fresh, even when a reference
    % node was supplied: its identifier changes from the Knowledge Graph
    % UUID to the openMINDS IRI, and id can not be set on an existing node.
    % Callers use the returned value, as the resolver contract requires.
    if ~isempty(omReferenceNode) && ~isControlledInstance
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
                [parentIdentifier, parentType] = omkg.internal.conversion.getNodeKeywords(options.ParentNode, "@id", "@type");
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

function unresolvedNodes = createUnresolvedNode(node, expectedObject)
    numNodes = numel(node);
    unresolvedNodes = cell(1, numNodes); % todo, init correct type
    for iNode = 1:numNodes
        thisNode = node(iNode);

        if openminds.utility.isMixedInstance( expectedObject )
            unresolvedNodes{iNode} = feval(class(expectedObject), thisNode);
        else
            % An id alone creates a node; the link must be an explicit
            % reference so that it is resolved later and never saved as
            % an empty node.
            unresolvedNodes{iNode} = feval(class(expectedObject), ...
                'id', thisNode.at_id, 'IsReference', true);
        end
    end
    unresolvedNodes = [unresolvedNodes{:}];
end

function tf = isLinkedNode(node)
    tf = isstruct(node) && isfield(node, 'at_id');
end

function tf = isEmbeddedNode(node)
    isEmbedded = @(x) isstruct(x) && isfield(x, 'at_type');

    if iscell(node) % non-scalar
        tf = all(cellfun(@(c) isEmbedded(c), node));
    elseif isstruct(node)
        tf = isfield(node, 'at_type');
    else
        tf = false;
    end
end

function showUnsupportedPropertyWarning(typeName, propertyName)
    warning(...
        'OMKG:ConvertKgNode:UnsupportedProperty', ...
        ['A downloaded instance of type "%s" includes a property ', ...
         'named "%s", but this property is not defined in the current ', ....
         'version of openMINDS and the property will be dropped.'], ...
         typeName, propertyName);
end
