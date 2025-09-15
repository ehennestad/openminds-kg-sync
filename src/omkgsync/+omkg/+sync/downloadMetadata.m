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
        options.ReferenceNode {mustBeA(options.ReferenceNode, ["double", "openminds.abstract.Schema"])} = []
    end

    % Todo:
    % - Apply server arg to client.
    % - Expose more args to pass to api client endpoints?

    omkg.internal.checkEnvironment()

    uuid = omkg.util.getIdentifierUUID(kgIdentifier);

    controlledTermUuidMap = omkg.internal.conversion.getIdentifierMapping();
    controlledTermKgIds = controlledTermUuidMap.keys();
    
    % Download instance
    kgNode = options.Client.getInstance(uuid, "Server", options.Server);
    
    kgIRI = ebrains.kg.internal.getNodeKeywords(kgNode, "@id");
    rootNode = omkg.internal.conversion.convertKgNode(kgNode);
    
    allNodes = {rootNode};
    resolvedIRIs = kgIRI;

    for i = 1:options.NumLinksToResolve
        
        linkedIRIs = omkg.internal.conversion.extractLinkedIdentifiers(rootNode);
        linkedIRIs = setdiff(linkedIRIs, controlledTermKgIds);
        linkedIRIs = setdiff(linkedIRIs, resolvedIRIs);
        
        if ~isempty(linkedIRIs)
            if options.Verbose
                fprintf(['Following links of %s order. ', ...
                    'Please wait while downloading %d new metadata instances...\n'], ...
                    orderStr(i), numel(linkedIRIs));
            end
            kgNodes = options.Client.getInstancesBulk(linkedIRIs, ...
                "Server", options.Server);
            % kgNodes = ebrains.kg.api.downloadInstancesBulk(linkedIRIs);

            newNodes = omkg.internal.conversion.convertKgNode(kgNodes);

            if ~iscell(newNodes)
                newNodes = num2cell(newNodes);
            end

            allNodes = [allNodes, newNodes]; %#ok<AGROW>
            rootNode = newNodes;
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

function result = orderStr(val)
    if val == 1
        result = sprintf('%dst', val); %1st
    elseif val == 2
        result = sprintf('%dnd', val); %2nd
    elseif val == 3
        result = sprintf('%drd', val); %3rd
    else
        result = sprintf('%dth', val); %nth
    end
end
