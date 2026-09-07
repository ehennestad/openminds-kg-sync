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

    typeNames = processTypeResponse(typeData);
end

function result = processTypeResponse(typeData)
% processTypeResponse - Extract the type name, but only for controlled term types
%
%   Returns a string array with names (@type IRI) of controlled term types
%
%   Note: for v4-and-above data, the type namespace no longer
%   distinguishes controlled term types from other schema types (see
%   omkg.constants.OpenMINDSTypeIRIPrefix), so this filter is a no-op for
%   those entries and correctness relies on the API call already scoping
%   the request to the "controlled" space.

    TYPE_NAMESPACE_IRI = omkg.constants.OpenMINDSTypeIRIPrefix;

    result = string.empty;
    for i = 1:numel(typeData)
        currentTypeSpec = typeData{i};
        semanticTypename = currentTypeSpec.http___schema_org_identifier;

        if startsWith(semanticTypename, TYPE_NAMESPACE_IRI)
            % result(end+1) = extractAfter(semanticTypename, TYPE_NAMESPACE_IRI); %#ok<AGROW>
            result(end+1) = semanticTypename; %#ok<AGROW>
        else
            % pass
            % disp(currentTypeSpec.http___schema_org_identifier)
            % warning('Expected type name to start with "https://openminds.ebrains.eu/controlledTerms/"')
        end
    end
end
