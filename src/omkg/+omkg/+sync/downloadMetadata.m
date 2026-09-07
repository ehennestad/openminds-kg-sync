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

    % Download instance
    kgNode = options.Client.getInstance(uuid, "Server", options.Server);

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

            newNodes = omkg.internal.conversion.convertKgNode(kgNodes);

            if ~iscell(newNodes)
                newNodes = num2cell(newNodes);
            end

            % Reconstruct the list of IRIs, as the response is not in the
            % order of the request. Take them from the Knowledge Graph nodes
            % rather than the converted ones: a converted controlled
            % instance carries its openMINDS IRI, while the reference in
            % the parent still holds the Knowledge Graph IRI that
            % resolveLinks matches against.
            linkedIRIs = getKnowledgeGraphIRIs(kgNodes);

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

function iris = getKnowledgeGraphIRIs(kgNodes)
% getKnowledgeGraphIRIs - The @id of each node, in the order they were returned
    kgNodes = omkg.internal.conversion.normalizeJsonLdKeywords(kgNodes);
    if ~iscell(kgNodes)
        kgNodes = num2cell(kgNodes);
    end
    iris = string(cellfun(@(node) node.at_id, kgNodes, 'UniformOutput', false));
    iris = reshape(iris, 1, []);
end
