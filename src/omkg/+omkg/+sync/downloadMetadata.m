function omNode = downloadMetadata(kgIdentifier, options)
% downloadMetadata - Downloads metadata from KG given a KG identifier
%
% Syntax:
%   metadataInstance = omkg.sync.downloadMetadata(identifier, options)
%
% Input Arguments:
%   identifier (1,1) string - The unique identifier for the metadata
%   options (1,1) struct - Struct containing options for downloading
%       options.NumLinksToResolve (1,1) double - Number of links to resolve (default: 2)
%       options.Server (1,1) string - "prod" (default) or "preprod"
%
% Output Arguments:
%   metadataInstance - The instance of the metadata corresponding to the identifier

    arguments
        kgIdentifier (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.NumLinksToResolve = 0
        options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
        options.Verbose (1,1) logical = false
        options.ReferenceNode {mustBeA(options.ReferenceNode, ["double", "openminds.Node"])} = []
    end

    % Todo:
    % - Apply server arg to client.
    % - Expose more args to pass to api client endpoints?

    omkg.internal.checkEnvironment()

    uuid = omkg.util.getIdentifierUUID(kgIdentifier);
    cache = omkg.internal.ControlledInstanceCache.instance();

    % Download instance
    kgNode = options.Client.getInstance(uuid, "Server", options.Server);

    % A link to a controlled instance takes its openMINDS identity while
    % its parent is converted, so the identifiers of any controlled
    % instances the cache does not know yet are fetched first. The nodes
    % that fetch returns are kept: a link that turns out not to be a
    % controlled instance is an ordinary linked node, which the link
    % resolution below would otherwise download a second time.
    prefetched = emptyPrefetchedNodes();
    prefetched = prefetchControlledInstances(kgNode, cache, ...
        options.Client, options.Server, prefetched);

    kgIRI = omkg.internal.conversion.getNodeKeywords(kgNode, "@id");
    rootNode = omkg.internal.conversion.convertKgNode(kgNode, options.ReferenceNode);

    [allNodes, newNodes] = deal({rootNode});
    resolvedIRIs = kgIRI;

    for i = 1:options.NumLinksToResolve

        linkedIRIs = omkg.internal.conversion.extractLinkedIdentifiers(newNodes);
        linkedIRIs = setdiff(linkedIRIs, resolvedIRIs);

        if ~isempty(linkedIRIs)
            % Links the pre-fetch already asked for are not requested
            % again, whether it retrieved them or found them missing.
            kgNodes = prefetched.Nodes(ismember(prefetched.IRIs, linkedIRIs));
            linkedIRIs = linkedIRIs(~ismember(linkedIRIs, prefetched.RequestedIRIs));

            if ~isempty(linkedIRIs)
                if options.Verbose
                    fprintf(['Following links of %s order. ', ...
                        'Please wait while downloading %d new metadata instances...\n'], ...
                        omkg.util.getOrdinalNumberString(i), numel(linkedIRIs));
                end
                fetchedNodes = fetchNodes(options.Client, linkedIRIs, options.Server);
                kgNodes = [kgNodes, fetchedNodes]; %#ok<AGROW>
            end

            if isempty(kgNodes)
                continue % None of the links could be retrieved
            end

            prefetched = prefetchControlledInstances(kgNodes, cache, ...
                options.Client, options.Server, prefetched);
            newNodes = omkg.internal.conversion.convertKgNode(kgNodes);

            if ~iscell(newNodes)
                newNodes = num2cell(newNodes);
            end

            % Reconstruct list of IRIs as response is not same order as request
            linkedIRIs = cellfun(@(c) c.id, newNodes);

            allNodes = [allNodes, newNodes]; %#ok<AGROW>
            resolvedIRIs = [resolvedIRIs, linkedIRIs]; %#ok<AGROW>
        else
            % No more links to resolve
        end
    end

    if options.Verbose
        fprintf('Done.\n');
    end

    omkg.internal.resolveLinks(allNodes{1}, resolvedIRIs(2:end), allNodes(2:end))
    omNode = allNodes{1};
end

function prefetched = emptyPrefetchedNodes()
% emptyPrefetchedNodes - What the pre-fetch has asked for and what it got
%
%   RequestedIRIs holds every link the pre-fetch requested, so that a link
%   the Knowledge Graph did not return is not requested a second time and
%   reported missing twice. IRIs and Nodes hold the links that were
%   returned, in the same order.
    prefetched = struct(...
        'RequestedIRIs', string.empty(1, 0), ...
        'IRIs', string.empty(1, 0), ...
        'Nodes', {cell(1, 0)});
end

function prefetched = prefetchControlledInstances(kgNodes, cache, client, server, prefetched)
% prefetchControlledInstances - Learn the openMINDS IRIs of unknown controlled links
%
%   Only links on properties that can hold a controlled instance are
%   considered, so persons, datasets and the like are not fetched just to
%   look at their identifiers. Does nothing under the "kg" identity policy,
%   where the cache answers nothing and every link stays a reference.
%
%   The nodes retrieved are added to prefetched, so that the caller can
%   reuse those which are not controlled instances instead of downloading
%   them again.

    if ~cache.isEnabled()
        return
    end

    candidateIRIs = listControlledInstanceLinks(kgNodes);
    candidateIRIs = candidateIRIs(~cache.isKnown(candidateIRIs));
    candidateIRIs = candidateIRIs(~ismember(candidateIRIs, prefetched.RequestedIRIs));
    if isempty(candidateIRIs)
        return
    end

    linkedNodes = fetchNodes(client, candidateIRIs, server);
    linkedNodes = omkg.internal.conversion.normalizeJsonLdKeywords(linkedNodes);

    prefetched.RequestedIRIs = [prefetched.RequestedIRIs, candidateIRIs];
    prefetched.IRIs = [prefetched.IRIs, cellfun(@(n) string(n.at_id), linkedNodes)];
    prefetched.Nodes = [prefetched.Nodes, linkedNodes];

    [kgIRIs, openMindsIRIs] = deal(string.empty);
    for i = 1:numel(linkedNodes)
        openMindsIRI = omkg.internal.conversion.getControlledInstanceIRI(linkedNodes{i});
        if strlength(openMindsIRI) == 0
            continue % Not a controlled instance after all
        end
        kgIRIs(end+1) = string(linkedNodes{i}.at_id); %#ok<AGROW>
        openMindsIRIs(end+1) = openMindsIRI; %#ok<AGROW>
    end
    cache.record(kgIRIs, openMindsIRIs);
end

function kgNodes = fetchNodes(client, kgIRIs, server)
% fetchNodes - Download the given nodes, leaving out any the KG does not return
%
%   A request for several identifiers silently leaves out those the
%   Knowledge Graph cannot return, while a request for a single identifier
%   is answered with an error. A link that cannot be retrieved is treated
%   the same way in both cases: reported with a warning and left out, so
%   that one dead link does not abort the pull.

    try
        kgNodes = client.getInstancesBulk(kgIRIs, "Server", server);
    catch ME
        if strcmp(ME.identifier, 'EBRAINS:KG_API:getInstance:NotFound')
            warning('OMKG:DownloadMetadata:LinkedInstanceNotFound', ...
                'Failed to retrieve the linked instance "%s": %s', ...
                strjoin(kgIRIs, ", "), ME.message)
            kgNodes = cell(1, 0);
            return
        end
        rethrow(ME)
    end

    if ~iscell(kgNodes)
        kgNodes = num2cell(kgNodes);
    end
    kgNodes = reshape(kgNodes, 1, []);
end

function linkIRIs = listControlledInstanceLinks(kgNodes)
% listControlledInstanceLinks - KG IRIs of links that may point at controlled instances
%
%   A link is a candidate when the property it sits on expects a
%   controlled term, or a mixed type, which may admit one. The expected
%   type comes from a blank instance of the node's own type. Embedded
%   nodes are searched the same way, because a controlled term often sits
%   one level down: the unit of a quantity is a link inside the
%   QuantitativeValue that holds it, not on the node being converted.

    kgNodes = omkg.internal.conversion.normalizeJsonLdKeywords(kgNodes);
    if ~iscell(kgNodes)
        kgNodes = num2cell(kgNodes);
    end

    linkIRIs = string.empty;
    for i = 1:numel(kgNodes)
        node = kgNodes{i};
        [identifier, type] = omkg.internal.conversion.getNodeKeywords(node, "@id", "@type");
        properties = omkg.internal.conversion.removeNamespaceIRIFromPropertyNames(...
            omkg.internal.conversion.filterProperties(node));
        template = openminds.fromTypeName(type, identifier);

        for propertyName = string(fieldnames(properties))'
            value = properties.(propertyName);
            if ~isprop(template, propertyName)
                continue
            end

            if isLinkedNode(value)
                expected = template.(propertyName);
                if isa(expected, 'openminds.controlledterms.ControlledTerm') ...
                        || openminds.utility.isMixedInstance(expected)
                    linkIRIs = [linkIRIs, string({value.at_id})]; %#ok<AGROW>
                end
            elseif isEmbeddedNode(value)
                linkIRIs = [linkIRIs, listControlledInstanceLinks(value)]; %#ok<AGROW>
            end
        end
    end
    linkIRIs = unique(linkIRIs);
end

function tf = isLinkedNode(value)
    tf = isstruct(value) && isfield(value, 'at_id');
end

function tf = isEmbeddedNode(value)
% isEmbeddedNode - Whether a property value is one or more embedded nodes
%
%   An embedded node declares its type but is not a link; a list of them
%   arrives as a struct array, or as a cell when the types differ.
    isEmbedded = @(x) isstruct(x) && isfield(x, 'at_type') && ~isfield(x, 'at_id');

    if iscell(value)
        tf = ~isempty(value) && all(cellfun(isEmbedded, value));
    else
        tf = isEmbedded(value);
    end
end
