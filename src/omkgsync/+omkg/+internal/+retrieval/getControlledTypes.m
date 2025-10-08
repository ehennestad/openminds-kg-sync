function typeNames = getControlledTypes(options)
% getControlledTypes - Retrieves a list of controlled types from the API.
%
% Syntax:
%   typeNames = getControlledTypes() 
%   typeNames = getControlledTypes(Name, Value)
%
% Name-Value Arguments:
%  - ApiClient - An instance of the API client to be used for 
%    fetching the controlled term instances.
%
% Output Arguments:
%   typeNames - A cell array of names of controlled types retrieved 
%   from the API.

    arguments
        options.ApiClient = ebrains.kg.api.InstancesClient()
    end
    
    typeData = options.ApiClient.listTypes(...
        "Server", "PROD", ...
        "space", "controlled", ...
        "stage", "RELEASED", ...
        "withProperties", false);
    numel(typeData)
    typeNames = processTypeResponse(typeData);
end



function result = processTypeResponse(typeData)
% processTypeResponse - Extract the type name, but only for controlled term types
%
%   Returns a string array with names (@type IRI) of controlled term types
    result = string.empty;
    for i = 1:numel(typeData)
        currentTypeSpec = typeData{i};
        if startsWith(currentTypeSpec.http___schema_org_identifier, ...
                "https://openminds.ebrains.eu/controlledTerms/")
            result(end+1) = currentTypeSpec.http___schema_org_identifier; %#ok<AGROW>
        else
            disp(currentTypeSpec.http___schema_org_identifier)
            warning('Expected type name to start with "https://openminds.ebrains.eu/controlledTerms/"')
        end
    end
end
