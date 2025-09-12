function identifierMap = downloadControlledInstanceIdentifiers()
% downloadControlledInstanceIdentifiers - Download KG uuids and openMINDS
% @ids for controlled instances
%
% Syntax:
%   identifierMap = downloadControlledInstanceIdentifiers()
%   This function retrieves and compiles the identifiers of controlled
%   instances from the EBRAINS knowledge graph.
%
% Output (saves to file):
%   identifierMap - A struct array containing the UUIDs of the controlled
%   instances downloaded from the knowledge graph.

    % Use api client to list all controlled term types in the controlled space
    apiClient = ebrains.kgcore.api.Basic();
    [~, response] = apiClient.listTypes("RELEASED", "space", "controlled");
    controlledTermTypeIRI = processTypeResponse(response);

    % Download all the instances of each type and retrieve the identifiers
    numTypes = numel(controlledTermTypeIRI);
    instanceUuidListing = cell(1, numTypes);
    for i = 1:numTypes
        fprintf('Fetching information for "%s"\n', controlledTermTypeIRI{i})
        [~, response] = apiClient.listInstances("RELEASED", controlledTermTypeIRI{i}, "space", "controlled");
        instanceUuidListing{i} = processInstanceResponse(response);
    end

    identifierMap = [instanceUuidListing{:}];

    mapFilepath = fullfile(...
        ebrains.common.namespacedir('ebrains.kg'), ...
        'resources', ...
        'kg2om_identifier_loopkup.json');

    utility.filewrite(mapFilepath, jsonencode(identifierMap, 'PrettyPrint', true))
    if ~nargout
        clear identifierMap
    end
end

function result = processTypeResponse(response)
% processTypeResponse - Extract the type name, but only for controlled term types
%
%   Returns a string array with names (@type IRI) of controlled term types
    result = string.empty;
    for i = 1:numel(response.data)
        thisData = response.data{i};
        if startsWith(thisData.http___schema_org_identifier, ...
                "https://openminds.ebrains.eu/controlledTerms/")
            result(end+1) = thisData.http___schema_org_identifier; %#ok<AGROW>
        end
    end
end

function result = processInstanceResponse(instanceResponse)
% processInstanceResponse - Extract KG uuids and openMINDS identifiers from response data
    numInstances = numel(instanceResponse.data);
    [kgIds, omIds] = deal(repmat("", 1, numInstances));
    for j = 1:numel(instanceResponse.data)
        thisData = instanceResponse.data(j);
        if iscell(thisData)
            thisData = thisData{1};
        end
        kgIds(j) = string(thisData.x_id);

        schemaIds = thisData.http___schema_org_identifier;
        isOpenMindsIdentifier = startsWith(schemaIds, 'https://openminds');
        if any(isOpenMindsIdentifier)
            currentOpenMindsIdentifier = string(schemaIds(isOpenMindsIdentifier));
            omIds(j) = currentOpenMindsIdentifier(1);

            if numel(currentOpenMindsIdentifier) > 1
                omIds = [omIds, currentOpenMindsIdentifier(2:end)]; %#ok<AGROW>
                kgIds = [kgIds, repmat(kgIds(j), 1, numel(currentOpenMindsIdentifier)-1)]; %#ok<AGROW>
            end
        end
    end
    result = struct('kg', num2cell(kgIds), 'om', num2cell(omIds));
end
