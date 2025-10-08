function identifierMap = getControlledTermIdMap(typeName, identifiers, options)
% getControlledTermIdMap - Retrieves controlled term ID maps based on specified type.
%
% Syntax:
%   identifierMap = omkg.internal.retrieval.getControlledTermIdMap(typeName, identifiers, options)
%   This function retrieves controlled term IDs from an API based on the
%   specified type name and a list of identifiers. If no identifiers
%   are provided, it lists all instances of the specified type.
% 
% Input Arguments:
%   typeName    (1,1) string  - The type name for the controlled terms.
%   identifiers  (1,:) string  - A list of identifiers to fetch specific terms (optional).
% 
% Name-Value Arguments:
%  - ApiClient - An instance of the API client to be used for 
%    fetching the controlled term instances.
%
% Output Arguments:
%   identifierMap  - A mapping of identifiers to their respective controlled term IDs.

    arguments
        typeName (1,1) string = "https://openminds.ebrains.eu/controlledTerms/ActionStatusType"
        identifiers (1,:) string = string.missing
        options.ApiClient = ebrains.kg.api.InstancesClient()
    end

    if isempty(identifiers)
        response = options.ApiClient.listInstances(typeName, ...
            "stage", "RELEASED", "Server", "prod", "space", "controlled");
    else
        response = options.ApiClient.getInstancesBulk(identifiers, ...
            "stage", "RELEASED", "Server", "prod");
    end

    identifierMap = processInstanceResponse(response);
end

function result = processInstanceResponse(data)
% processInstanceResponse - Extract KG uuids and openMINDS identifiers from response data
    numInstances = numel(data);
    [kgIds, omIds] = deal(repmat("", 1, numInstances));
    for j = 1:numel(data)
        thisData = data(j);
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
