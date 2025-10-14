function kgdelete(target, kgOptions, options)
% kgdelete - Deletes instance(s) from the knowledge graph.
%
% Syntax:
%   kgdelete(target)
%   kgdelete(target, kgOptions)
%   kgdelete(target, kgOptions, options)
%
% Description:
%   Deletes openMINDS instances or KG identifiers from the EBRAINS Knowledge
%   Graph. Supports both individual instances/IDs and arrays.
%
% Input Arguments:
%   target - Target to delete
%       Type: openminds.abstract.Schema array OR string array
%       Description: Either openMINDS schema instances (with valid IDs) or
%                   KG identifier strings
%
%   kgOptions - Knowledge Graph options (optional)
%       Fields:
%         - Server: KG server to use (default: from preferences)
%
%   options - Additional options (optional)
%       Fields:
%         - Client: API client instance (default: new InstancesClient)
%         - Verbose: Display confirmation messages (default: true)
%
% Output Arguments:
%   None
%
% Examples:
%   % Delete by openMINDS instance
%   person = openminds.core.Person();
%   person.id = "https://kg.ebrains.eu/api/instances/12345678-1234-5678-9012-123456789012";
%   kgdelete(person);
%
%   % Delete by identifier
%   kgdelete("12345678-1234-5678-9012-123456789012");
%
%   % Delete multiple instances
%   kgdelete([person1, person2], 'Verbose', false);
%
% See also: kgsave, kglist, kgpull

    arguments
        target {omkg.validator.mustBeInstanceOrIdentifier}
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
        options.Verbose (1,1) logical = true
    end

    % Check environment compatibility
    omkg.internal.checkEnvironment()

    % Handle array inputs
    if numel(target) > 1
        if ~iscell(target); target = num2cell(target); end % Normalize to cell array
        for i = 1:numel(target)
            nvPairs = [namedargs2cell(kgOptions), namedargs2cell(options)];
            kgdelete(target{i}, nvPairs{:});
        end
        return
    end

    % Extract identifier based on input type
    if isa(target, 'openminds.abstract.Schema')
        instanceId = target.id;
        if options.Verbose
            targetDescription = sprintf("instance of type '%s'", class(target));
        end
    else
        instanceId = string(target);
        if options.Verbose
            targetDescription = "instance";
        end
    end

    % Extract UUID and delete
    uuid = omkg.util.getIdentifierUUID(instanceId);

    % Pass server options to client
    nvPairs = namedargs2cell(kgOptions);
    options.Client.deleteInstance(uuid, nvPairs{:});

    if options.Verbose
        fprintf('Deleted %s with id: %s\n', targetDescription, instanceId);
    end
end
