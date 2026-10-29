function [instances, nextPageFcn] = kglist(type, kgOptions, options)
% kglist - List instances for a specified type
%
% Syntax:
%   instances = kglist(type)
%   [instances, nextPageFcn] = kglist(type, Name, Value)
%
% Output Arguments:
%   instances   - Instances of the listed type. An instance the Knowledge
%                 Graph returned but that could not be converted is left
%                 out, and every such instance is reported in one warning
%                 (OMKG:kglist:ConversionFailed) with its identifier and
%                 the reason, so the array may be shorter than the page.
%   nextPageFcn - Function handle that lists the next page with the same
%                 options (space, stage, filter, server, client). The
%                 offset advances by the number of instances the Knowledge
%                 Graph returned for this page, so a server that caps the
%                 page size is paged through completely. Returns an empty
%                 array once the listing is exhausted.
%
% Example:
%   [people, nextPage] = kglist("Person", "space", "common", "size", 20);
%   while ~isempty(people)
%       % ... process people ...
%       [people, nextPage] = nextPage();
%   end

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

    % Snapshot the request before filterProperty is expanded to its IRI,
    % since the next page is requested through kglist again and its
    % validator expects the plain property name.
    pageRequest = kgOptions;
    if ~isfield(pageRequest, "from")
        pageRequest.from = uint64(0);
    end

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
    data = omkg.internal.conversion.normalizeJsonLdKeywords(data);
    if ~iscell(data)
        data = num2cell(data);
    end

    numInstances = numel(data);
    converted = cell(1, numInstances);
    failed = struct('Identifier', {}, 'Reason', {});

    for i = 1:numInstances
        try
            converted{i} = omkg.internal.conversion.convertKgNode(data{i});
        catch ME
            failed(end+1) = struct( ...
                'Identifier', nodeIdentifier(data{i}), ...
                'Reason', deepestCause(ME)); %#ok<AGROW>
        end
    end

    % Only the instances that converted are returned. A placeholder for
    % a failed one would be a node with a blank identifier and no
    % content, which a collection could not tell from a real node.
    converted = converted(~cellfun(@isempty, converted));
    if ~isempty(converted)
        instances = [converted{:}];
    end
    reportFailedConversions(failed, numInstances)

    pageRequest.from = pageRequest.from + numInstances;
    pageArgs = namedargs2cell(pageRequest);
    clientArgs = namedargs2cell(options);
    nextPageFcn = @() kglist(type, pageArgs{:}, clientArgs{:});
end

function reportFailedConversions(failed, numListed)
% One warning for the whole page, naming each instance that was left out
% and why, so a shorter page is never silent.
    if isempty(failed)
        return
    end
    details = arrayfun(@(entry) sprintf('  %s: %s', entry.Identifier, entry.Reason), ...
        failed, 'UniformOutput', false);
    warning('OMKG:kglist:ConversionFailed', ...
        ['%d of the %d instances the Knowledge Graph returned could not be ', ...
        'converted and were left out:\n%s'], numel(failed), numListed, strjoin(details, newline))
end

function reason = deepestCause(ME)
% The innermost cause names what was wrong with the data; the outer
% messages only say which instance it was.
    while ~isempty(ME.cause)
        ME = ME.cause{1};
    end
    reason = string(strtok(ME.message, newline));
end

function identifier = nodeIdentifier(node)
    if isfield(node, 'at_id')
        identifier = string(node.at_id);
    else
        identifier = "<node without an identifier>";
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
