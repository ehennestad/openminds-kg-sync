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
%  - Ancestors - Default: []. Where the node sits when it is embedded in
%    another node, used to describe where a failed conversion sits. A
%    struct array with one element per enclosing node, outermost first,
%    with the fields:
%      ClassName    - The openMINDS class of the enclosing node.
%      Identifier   - Its @id, or "" if it has none.
%      PropertyName - The property of it that holds the embedded node.
%      Index        - The position of the embedded node in that property
%                     when the property holds a list, otherwise [].
%    The recursion below extends the chain by one element for every
%    level of embedding.
%
% Output Arguments:
%   omNode - Converted openMINDS node or an array of openMINDS nodes if
%       multiple input kgNode structures are provided.

    arguments
        kgNode (1,:) {mustBeA(kgNode, ["struct", "cell"])} % Metadata node/instance returned from the instances api endpoint
        omReferenceNode {mustBeA(omReferenceNode, ["double", "openminds.Node"])} = []
        options.Ancestors {mustBeA(options.Ancestors, ["double", "struct"])} = [];
    end

    % Hand structs to openMINDS in the at_ form it expects for keywords
    kgNode = omkg.internal.conversion.normalizeJsonLdKeywords(kgNode);

    % Loop through each node if a list is provided
    if numel(kgNode) > 1
        omNode = cell(1, numel(kgNode));
        if ~iscell(kgNode); kgNode = num2cell(kgNode); end
        ancestors = options.Ancestors;
        for i = 1:numel(kgNode)
            if ~isempty(ancestors)
                % The list is the value of the innermost enclosing
                % property, so the position locates the element within it.
                ancestors(end).Index = i;
            end
            omNode{i} = omkg.internal.conversion.convertKgNode(kgNode{i}, "Ancestors", ancestors);
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
                enclosingNode = struct(...
                    'ClassName', class(omDummyNode), ...
                    'Identifier', string(identifier), ...
                    'PropertyName', string(currentPropertyName), ...
                    'Index', []);
                currentPropertyValue = omkg.internal.conversion.convertKgNode(...
                    currentPropertyValue, "Ancestors", [options.Ancestors, enclosingNode]);
            end
        elseif ischar(currentPropertyValue)
            if omkg.getpref("ConvertChar")
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
            ME = MException('OMKG:ConvertKGNode:ConversionFailed', '%s', ...
                failureMessage(class(omDummyNode), identifier, options.Ancestors));
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

function message = failureMessage(className, identifier, ancestors)
% failureMessage - Say which instance failed to convert, and where it sits
%
%   A Knowledge Graph instance is named by its openMINDS class and its
%   identifier. An embedded node has no identifier of its own, so it is
%   located by the property path that leads to it from the outermost
%   enclosing node, which is a Knowledge Graph instance and can be named.
%   The path is written the way the value is indexed in MATLAB, e.g.
%   "propertyValuePair(3).value", so it can be followed in the Knowledge
%   Graph payload and on the converted instance alike.

    if isempty(ancestors)
        message = sprintf(...
            'Failed to create instance of type %s with identifier "%s".', ...
            className, identifier);
        return
    end

    root = ancestors(1);
    rootDescription = root.ClassName;
    if ~isempty(root.Identifier) && strlength(root.Identifier) > 0
        rootDescription = sprintf('%s (%s)', root.ClassName, root.Identifier);
    end

    message = sprintf(...
        'Failed to create embedded instance of type %s for property "%s" of %s.', ...
        className, propertyPath(ancestors), rootDescription);
end

function path = propertyPath(ancestors)
% propertyPath - Property path from the outermost ancestor to the node
%
%   One segment per level of embedding, e.g. "affiliation(2)" for the
%   second of a person's affiliations, or "propertyValuePair(3).value" for
%   the value embedded in the third property-value pair of a property
%   value list.

    segments = strings(1, numel(ancestors));
    for i = 1:numel(ancestors)
        segments(i) = string(ancestors(i).PropertyName);
        if ~isempty(ancestors(i).Index)
            segments(i) = segments(i) + "(" + ancestors(i).Index + ")";
        end
    end
    path = strjoin(segments, ".");
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
