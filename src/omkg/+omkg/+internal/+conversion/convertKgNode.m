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

    controlledInstanceCache = omkg.internal.ControlledInstanceCache.instance();

    [identifier, type] = omkg.internal.conversion.getNodeKeywords(kgNode, "@id", "@type");

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
                currentPropertyValue = convertLinkedNodes(currentPropertyValue, ...
                    omDummyNode.(currentPropertyName), controlledInstanceCache);
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

function instances = convertLinkedNodes(nodes, expectedObject, cache)
% convertLinkedNodes - Turn each link into a library instance or a reference
%
%   Whether a link is a controlled instance is decided per link, because
%   a property such as studyTarget can hold controlled terms next to
%   instances that exist only in the Knowledge Graph. A controlled instance
%   becomes the local library instance here, while the parent link is
%   converted, since a link resolver must keep the identifier of the
%   reference it resolves and so cannot make that swap later.
%
%   The cache answers only under the "openminds" identity policy; under
%   "kg" every link stays a reference and keeps its Knowledge Graph
%   identifier. A controlled instance the Knowledge Graph knows but the
%   local openMINDS library does not also stays a reference, with a
%   warning, rather than failing the conversion of its parent. Library
%   membership is checked before the instance is requested: openMINDS
%   admits user-defined terms, so asking it for an unknown name yields an
%   empty instance and a warning rather than an error.
    instances = cell(1, numel(nodes));

    for i = 1:numel(nodes)
        kgIdentifier = string(nodes(i).at_id);

        isLibraryInstance = false;
        if cache.isKnown(kgIdentifier)
            openMindsIdentifier = cache.lookup(kgIdentifier);
            isLibraryInstance = ...
                omkg.internal.conversion.isControlledInstanceName(openMindsIdentifier);
            if ~isLibraryInstance
                warning('OMKG:ConvertKgNode:ControlledInstanceNotInLibrary', ...
                    ['The controlled instance "%s" is not in the local openMINDS ', ...
                    'library. The link keeps its Knowledge Graph identifier ', ...
                    '"%s" and will be resolved by download.'], ...
                    openMindsIdentifier, kgIdentifier)
            end
        end

        if isLibraryInstance
            instances{i} = omkg.internal.conversion.getControlledInstance(openMindsIdentifier);
        else
            instances{i} = createUnresolvedNode(nodes(i), expectedObject);
        end
    end
    instances = omkg.util.concatTypesIfHomogeneous(instances);
end

function unresolvedNode = createUnresolvedNode(node, expectedObject)
% createUnresolvedNode - A reference that download can resolve later
%
%   node is a single KG link (convertLinkedNodes calls this once per
%   element), never an array.

    if openminds.utility.isMixedInstance(expectedObject)
        unresolvedNode = feval(class(expectedObject), node);
    else
        % An id alone creates a node; the link must be an explicit
        % reference so that it is resolved later and never saved as
        % an empty node.
        unresolvedNode = feval(class(expectedObject), ...
            'id', node.at_id, 'IsReference', true);
    end
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
