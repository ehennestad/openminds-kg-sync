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
%  - ParentNode - Default: []. The node the converted node is embedded
%    in, used to describe where a failed conversion sits. Either a
%    single node, or a cell array of nodes forming the containment
%    chain, outermost first, which is how the recursion below passes
%    ancestry down through nested embedded nodes.
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

        if omkg.internal.isEmptyValue(currentPropertyValue)
            % A KG node can carry an optional property as an explicit null,
            % decoded by jsondecode as []. Passing that through as a
            % Name=Value pair fails validation for scalar-typed properties
            % that have no tolerance for an explicit empty (e.g. a (1,1)
            % string property), so absent values are dropped instead of
            % forwarded.
            toKeep(i) = false;
            continue
        end

        % Recursively process linked/embedded nodes
        if isstruct(currentPropertyValue) || iscell(currentPropertyValue)
            if isLinkedNode(currentPropertyValue)
                currentPropertyValue = convertLinkedNodes(currentPropertyValue, ...
                    omDummyNode.(currentPropertyName), controlledInstanceCache);
            elseif isEmbeddedNode(currentPropertyValue)
                ancestors = [toAncestorChain(options.ParentNode), {kgNode}];
                currentPropertyValue = omkg.internal.conversion.convertKgNode(...
                    currentPropertyValue, "ParentNode", ancestors);
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
                errorMessage = embeddedFailureMessage(...
                    formatNodeType(type), toAncestorChain(options.ParentNode));
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

function ancestors = toAncestorChain(parentNode)
% toAncestorChain - Normalise the ParentNode option to a cell chain
%
%   Outermost node first. A caller may pass a single node, which is a
%   chain of one; the recursion passes a cell array.

    if isempty(parentNode)
        ancestors = {};
    elseif iscell(parentNode)
        ancestors = reshape(parentNode, 1, []);
    else
        ancestors = {parentNode};
    end
end

function message = embeddedFailureMessage(embeddedType, ancestors)
% embeddedFailureMessage - Say what failed and where it sits
%
%   An embedded node is stored inline and carries no @id of its own, so it
%   cannot be named directly. The containment chain is walked from the
%   innermost node outwards for the nearest ancestor that does carry one:
%   for a singly embedded node that is its immediate parent, and for a
%   nested one it is the enclosing instance further out. The types from
%   that ancestor inwards are reported as a path, so the message locates
%   the failure however deeply it is nested.

    types = strings(1, numel(ancestors));
    identifier = "";
    firstNamed = 1;
    for i = numel(ancestors):-1:1
        % This runs while reporting a failure, so it must not raise one of
        % its own: an ancestor that is not a readable node costs its name
        % in the message, nothing more.
        try
            [thisIdentifier, thisType] = omkg.internal.conversion.getNodeKeywords(...
                ancestors{i}, "@id", "@type");
            types(i) = formatNodeType(thisType);
            thisIdentifier = string(thisIdentifier);
        catch
            types(i) = "<unknown type>";
            thisIdentifier = "";
        end

        if strlength(identifier) == 0 && isscalar(thisIdentifier) ...
                && strlength(thisIdentifier) > 0
            identifier = thisIdentifier;
            firstNamed = i;
        end
    end

    if strlength(identifier) == 0
        % Nothing in the chain is addressable, e.g. a caller that passed an
        % embedded node as the parent. The path is still worth reporting.
        message = sprintf(...
            'Failed to create embedded instance of type "%s" at "%s".', ...
            embeddedType, strjoin(types, " > "));
    else
        message = sprintf(...
            ['Failed to create embedded instance of type "%s" at "%s" ', ...
            'in the instance with identifier "%s".'], ...
            embeddedType, strjoin(types(firstNamed:end), " > "), identifier);
    end
end

function typeStr = formatNodeType(nodeType)
% formatNodeType - One printable type name for a node's @type
%
%   getNodeKeywords returns @type as whatever jsondecode made of it: a cell
%   array when the KG sent a list, a char vector when it sent a single type,
%   and '' when the node carries none. Only the first form can be indexed
%   with braces, so a message built that way throws for the other two and
%   replaces the conversion error it was meant to report with an indexing
%   error.

    typeStr = string(nodeType);
    typeStr = typeStr(:)';
    % string('') is "" rather than an empty string array, so a node with no
    % @type has to be filtered on text length, not on isempty alone.
    typeStr = typeStr(strlength(typeStr) > 0);
    if isempty(typeStr)
        typeStr = "<unknown type>";
    else
        typeStr = strjoin(typeStr, ", ");
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
