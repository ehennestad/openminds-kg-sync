function kgdelete(openmindsInstance, options)
% kgdelete - Deletes an instance from the knowledge graph.
%
% Syntax:
%   kgdelete(openmindsInstance, options)
%
% Input Arguments:
%   - openmindsInstance (1,:) openminds.abstract.Schema -
%     The schema instance to be deleted from the knowledge graph.
%   - options.Client ebrains.kg.api.InstancesClient -
%     The client used to interact with the knowledge graph API. Default is a
%     new instance of ebrains.kg.api.InstancesClient.
%
% Output Arguments:
%   None

    arguments
        openmindsInstance (1,:) openminds.abstract.Schema
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    options.Client.deleteInstance(openmindsInstance.id)
end
