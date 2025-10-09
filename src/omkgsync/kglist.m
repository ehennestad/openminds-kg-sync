function [instances, nextPageFcn] = kglist(type, kgOptions, options)
% kglist - List instances for a specified type
    
    arguments
        type (1,1) openminds.enum.Types
        % opts.searchByLabel          string - Deactivated - can not confirm how this works.
        kgOptions.filterProperty  string {mustBePropertyOfType(kgOptions.filterProperty, type)}
        kgOptions.filterValue     string
        kgOptions.from            uint64
        kgOptions.size            uint64
        kgOptions.space (1,1) string = omkg.getpref("DefaultSpace")
        kgOptions.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    omkg.internal.checkEnvironment()

    if isfield(kgOptions, "filterProperty")
        mustHaveFilterValue(kgOptions)
        kgOptions.filterProperty = expandPropertyName(kgOptions.filterProperty);
    end

    if kgOptions.space == "auto" % Autoresolve space for given type
        kgOptions.space = omkg.util.resolveSpace(type);
    end
    
    % Initialize outputs
    instances = feval(sprintf('%s.empty', type.ClassName));
    nextPageFcn = @() [];
    
    % Get instances from KG API Client
    nvPairs = namedargs2cell(kgOptions);
    data = options.Client.listInstances(type, nvPairs{:});

    if isempty(data); return; end

    % Post-process (convert to openMINDS type instances)
    if ~iscell(data)
        data = num2cell(data);
    end

    numInstances = numel(data);
    instances(numInstances) = feval( type.ClassName );

    for i = 1:numInstances
        try
            instances(i) = omkg.internal.conversion.convertKgNode(data{i});
        catch ME
            warning('Could not create metadata for instance with id "%s" with following error: %s', data{i}.x_id, ME.message)
        end
    end

    % Create a nextPage function handle
    if isfield(kgOptions, 'from')
        nextPageFcn = @() kglist(type, ...
            'from', kgOptions.from+kgOptions.size, ...
            'size', kgOptions.size, ...
            'Client', options.Client);
    end
end

function mustBePropertyOfType(propertyName, type)
    arguments
        propertyName (1,1) string
        type (1,1) openminds.enum.Types
    end

    instanceProps = string( properties( feval(type.ClassName) ) );
    if ~ismember(propertyName, instanceProps)
        instancePropsStr = strjoin("  - " + instanceProps, newline);
        error(...
            "OMKG:kglist:validator:InvalidPropertyName", ...
            ['filterProperty "%s" is not a property of type "%s". ' ...
            'Please provide one of the following property names ' ...
            'instead:\n%s\n'], propertyName, string(type), instancePropsStr)
    end
end

function mustHaveFilterValue(kgOptions)
    assert(isfield(kgOptions, "filterValue"), ...
        "OMKG:kglist:validator:FilterValueMissing", ...
        ['Please provide a corresponding filterValue for ', ...
        'filterProperty "%s"'], kgOptions.filterProperty)
end

function expandedName = expandPropertyName(name)
    expandedName = sprintf("%s%s", openminds.constant.PropertyIRIPrefix, name);
end
