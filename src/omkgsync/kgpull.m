function omInstance = kgpull(identifier, options)

    arguments
        identifier (1,1) string {omkg.validator.mustBeValidKGIdentifier} 
        options.NumLinksToResolve = 0
        options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    omkg.internal.checkEnvironment()

    nvPairs = namedargs2cell(options);
    omInstance = omkg.downloadMetadata(identifier, nvPairs{:});
end
