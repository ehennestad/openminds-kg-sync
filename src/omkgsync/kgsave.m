function ids = kgsave(openmindsInstance, kgOptions, options)
% KGSAVE Save openMINDS instances to EBRAINS Knowledge Graph
%
% Syntax:
%   ids = kgsave(openmindsInstance)
%   ids = kgsave(openmindsInstance, kgOptions)
%   ids = kgsave(openmindsInstance, kgOptions, options)
%
% Description:
%   Save openMINDS metadata instances to the EBRAINS Knowledge Graph. This
%   function handles both creating new instances and updating existing ones
%   automatically based on whether the instance already has a KG identifier.
%
% Input Arguments:
%   openmindsInstance - openMINDS schema instances to save
%       Type: openminds.abstract.Schema (array)
%
%   kgOptions - Knowledge Graph options (optional)
%       Fields:
%         - space: Target space for new instances (default: from preferences)
%         - Server: KG server to use (default: from preferences)
%
%   options - Additional options (optional)
%       Fields:
%         - Client: API client instance (default: new InstancesClient)
%         - SaveMode: How to handle existing instances (default: "update")
%                    "update" - merge with existing data
%                    "replace" - completely replace existing data
%
% Output Arguments:
%   ids - KG identifiers of saved instances
%       Type: string array
%
% Examples:
%   % Save a single instance
%   person = openminds.core.Person();
%   person.givenName = "John";
%   id = kgsave(person);
%
%   % Save multiple instances with custom options
%   instances = [person1, person2, person3];
%   ids = kgsave(instances, 'SaveMode', omkg.enum.SaveMode.Replace);
%
% See also: kglist, kgpull, kgdelete

    arguments
        openmindsInstance (1,:) openminds.abstract.Schema
        kgOptions.space (1,1) string = omkg.getpref("DefaultSpace")
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
        options.SaveMode (1,1) omkg.enum.SaveMode = omkg.enum.SaveMode.Update
    end
    
    % Check environment compatibility
    omkg.internal.checkEnvironment()
    
    % Validate inputs
    if isempty(openmindsInstance)
        ids = string.empty();
        return
    end
    
    % Set default space preference if provided
    if isfield(kgOptions, 'space') && ~isempty(kgOptions.space)
        omkg.setpref('DefaultSpace', kgOptions.space);
    end
    
    % Configure metadata store with provided options
    serializer = omkg.internal.KGSerializer();
    metadataStore = omkg.internal.KGMetadataStore( ...
        'Serializer', serializer, ...
        'InstanceClient', options.Client);
    
    % Save instances and collect IDs
    numInstances = numel(openmindsInstance);
    ids = strings(1, numInstances);
    
    for i = 1:numInstances
        try
            % Convert SaveMode enum to string for KGMetadataStore
            saveModeStr = string(options.SaveMode.Name);
            id = openmindsInstance(i).save(metadataStore, 'SaveMode', saveModeStr);
            ids(i) = id;
        catch ME
            % Add context to error and re-throw
            error('OMKG:kgsave:SaveFailed', ...
                'Failed to save instance %d of %d: %s', ...
                i, numInstances, ME.message);
        end
    end
end
