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
    % instances the cache does not know yet are fetched first.
    prefetchControlledInstances(kgNode, cache, options.Client, options.Server);

    kgIRI = omkg.internal.conversion.getNodeKeywords(kgNode, "@id");
    rootNode = omkg.internal.conversion.convertKgNode(kgNode, options.ReferenceNode);

    [allNodes, newNodes] = deal({rootNode});
    resolvedIRIs = kgIRI;

    for i = 1:options.NumLinksToResolve

        linkedIRIs = omkg.internal.conversion.extractLinkedIdentifiers(newNodes);
        linkedIRIs = setdiff(linkedIRIs, resolvedIRIs);

        if ~isempty(linkedIRIs)
            if options.Verbose
                fprintf(['Following links of %s order. ', ...
                    'Please wait while downloading %d new metadata instances...\n'], ...
                    omkg.util.getOrdinalNumberString(i), numel(linkedIRIs));
            end
            kgNodes = options.Client.getInstancesBulk(linkedIRIs, ...
                "Server", options.Server);

            prefetchControlledInstances(kgNodes, cache, options.Client, options.Server);
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

function prefetchControlledInstances(kgNodes, cache, client, server)
% prefetchControlledInstances - Learn the openMINDS IRIs of unknown controlled links
%
%   Only links on properties that can hold a controlled instance are
%   considered, so persons, datasets and the like are not fetched just to
%   look at their identifiers. Does nothing under the "kg" identity policy,
%   where the cache answers nothing and every link stays a reference.

    if ~cache.isEnabled()
        return
    end

    candidateIRIs = listControlledInstanceLinks(kgNodes);
    candidateIRIs = candidateIRIs(~cache.isKnown(candidateIRIs));
    if isempty(candidateIRIs)
        return
    end

    linkedNodes = client.getInstancesBulk(candidateIRIs, "Server", server);
    linkedNodes = omkg.internal.conversion.normalizeJsonLdKeywords(linkedNodes);
    if ~iscell(linkedNodes)
        linkedNodes = num2cell(linkedNodes);
    end

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

function linkIRIs = listControlledInstanceLinks(kgNodes)
% listControlledInstanceLinks - KG IRIs of links that may point at controlled instances
%
%   A link is a candidate when the property it sits on expects a
%   controlled term, or a mixed type, which may admit one. The expected
%   type comes from a blank instance of the node's own type.

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
            if ~isprop(template, propertyName) || ~isstruct(value) || ~isfield(value, 'at_id')
                continue
            end
            expected = template.(propertyName);
            if isa(expected, 'openminds.controlledterms.ControlledTerm') ...
                    || openminds.utility.isMixedInstance(expected)
                linkIRIs = [linkIRIs, string({value.at_id})]; %#ok<AGROW>
            end
        end
    end
    linkIRIs = unique(linkIRIs);
end
