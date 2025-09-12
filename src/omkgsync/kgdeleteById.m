function kgdeleteById(id, kgOptions, options)
% kgdeleteById - Deletes a knowledge graph instance by its identifier.
%
% Syntax:
%   kgdeleteById(id)
%
%   kgdeleteById(id, Name, Value)
%
% Input Arguments:
%   - id (string) - 
%     The identifier of the knowledge graph instance to delete.
%
%  - options (name-value pairs) -
%    Optional name-value pairs. Available options:
%
%    - Server (ebrains.kg.enum.KGServer) -
%      The server to connect to. Can be "prod" (default) or "preprod".
%
%    - Client (ebrains.kg.api.InstancesClient) - 
%      An instance of the client for making API calls (default is a new client).
%
% Output Arguments:
%   None

    arguments
        id (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    nvPairs = namedargs2cell(kgOptions);
    options.Client.deleteInstance(id, nvPairs{:});
    fprintf('Deleted instance with id: %s\n', id)
end
