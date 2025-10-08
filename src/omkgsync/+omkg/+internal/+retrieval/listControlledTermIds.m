function identifiers = listControlledTermIds(typeName, options)
% listControlledTermIds - Retrieve controlled term identifiers
%
% Syntax:
%   identifiers = omkg.internal.retrieval.listControlledTermIds(typeName, options) 
%   This function retrieves a list of identifiers for controlled terms 
%   based on the specified type name and options provided.
%
% Input Arguments:
%  - typeName (string) - The type name for the controlled terms to be 
%    retrieved.
%
% Name-Value Arguments:
%  - ApiClient - An instance of the API client to be used for 
%    fetching the controlled term instances.
%
% Output Arguments:
%  - identifiers (string array) - An array of identifiers for the 
%    controlled terms retrieved from the API.

    arguments
        typeName (1,1) string = "https://openminds.ebrains.eu/controlledTerms/UBERONParcellation"
        options.ApiClient = ebrains.kg.api.InstancesClient()
    end

    response = options.ApiClient.listInstances(typeName, ...
        "space", "controlled", ...
        "stage", "RELEASED", ...
        "returnPayload", false);

    response = [response{:}];
    identifiers = string({response.x_id});
end
