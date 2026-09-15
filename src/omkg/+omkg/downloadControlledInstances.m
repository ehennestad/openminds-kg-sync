function downloadControlledInstances(options)
% downloadControlledInstances - Fill the controlled instance cache from the KG
%
% Syntax:
%   omkg.downloadControlledInstances()
%   omkg.downloadControlledInstances(Name, Value)
%
% Name-Value Arguments:
%   Client   - API client to download with. Default: a new
%              ebrains.kg.api.InstancesClient.
%   PageSize - Instances requested per call. Default: 500.
%   Server   - KG server to download from. Default: the "DefaultServer"
%              preference. The cache is not keyed by server, since preprod
%              mirrors prod.
%   Verbose  - Print progress. Default: true.
%
%   Records the openMINDS IRI of every controlled instance in the Knowledge
%   Graph's "controlled" space. Under the "openminds" identity policy a
%   pull looks these up before converting a node, fetching any it does not
%   know, so running this is optional: it warms the lookup in one go, e.g.
%   before working offline or pulling many datasets.
%
%   The types to fetch are taken from openminds.enum.Types, keeping those
%   whose class lives in openminds.controlledterms. This is decided
%   offline and excludes the other types held in the same KG space, such
%   as atlas annotations, of which there are thousands.
%
%   Each type is fetched in pages, so a large type does not become one
%   oversized response. The offset advances by what each page held, so a
%   server that returns fewer instances than asked for is paged through
%   completely.
%
%   Requires the ControlledInstanceIdentity preference to be "openminds",
%   because the lookup is unused under "kg". Needs valid EBRAINS
%   credentials.
%
% See also: omkg.setpref, omkg.internal.ControlledInstanceCache

    arguments
        options.Client (1,1) ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
        options.PageSize (1,1) double {mustBePositive, mustBeInteger} = 500
        options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Verbose (1,1) logical = true
    end

    omkg.internal.checkEnvironment()

    cache = omkg.internal.ControlledInstanceCache.instance();
    if ~cache.isEnabled()
        error('OMKG:DownloadControlledInstances:CacheDisabled', ...
            ['Controlled instances keep their Knowledge Graph identity under the ', ...
            'current policy, so there is no lookup to fill. Set ', ...
            'omkg.setpref("ControlledInstanceIdentity", "openminds") to use one.'])
    end

    typeIRIs = listControlledTermTypeIRIs();
    numTypes = numel(typeIRIs);

    [kgIRIs, openMindsIRIs] = deal(string.empty);
    for i = 1:numTypes
        if options.Verbose
            fprintf('Fetching "%s" (%d/%d)\n', typeIRIs(i), i, numTypes);
        end

        kgNodes = listAllInstances(options.Client, typeIRIs(i), ...
            options.PageSize, options.Server);

        for j = 1:numel(kgNodes)
            openMindsIRI = omkg.internal.conversion.getControlledInstanceIRI(kgNodes{j});
            if strlength(openMindsIRI) == 0
                continue
            end
            kgIRIs(end+1) = string(kgNodes{j}.at_id); %#ok<AGROW>
            openMindsIRIs(end+1) = openMindsIRI; %#ok<AGROW>
        end
    end

    cache.record(kgIRIs, openMindsIRIs);

    if options.Verbose
        fprintf('Cached %d controlled instances in "%s".\n', ...
            numel(kgIRIs), cache.getFilePath());
    end
end

function typeIRIs = listControlledTermTypeIRIs()
% listControlledTermTypeIRIs - @type IRIs of the controlled term types openMINDS knows
    types = enumeration('openminds.enum.Types');
    isControlledTerm = startsWith([types.ClassName], "openminds.controlledterms.");
    typeIRIs = [types(isControlledTerm).TypeIRI];
    typeIRIs = reshape(typeIRIs, 1, []);
end

function kgNodes = listAllInstances(client, typeIRI, pageSize, server)
% listAllInstances - Every instance of a type, one page at a time
%
%   The client returns only the data of a page, not the total. A page
%   shorter than requested does not mark the end either, since the server
%   may cap the page size below what was asked for. The listing therefore
%   runs until a page comes back empty, and the offset advances by the
%   number of instances each page actually held.

    kgNodes = cell(1, 0);
    from = 0;
    while true
        page = client.listInstances(typeIRI, ...
            "space", "controlled", "stage", "RELEASED", "Server", server, ...
            "from", from, "size", pageSize);
        page = omkg.internal.conversion.normalizeJsonLdKeywords(page);
        if ~iscell(page)
            page = num2cell(page);
        end
        page = reshape(page, 1, []);

        if isempty(page)
            break
        end
        kgNodes = [kgNodes, page]; %#ok<AGROW>
        from = from + numel(page);
    end
end
