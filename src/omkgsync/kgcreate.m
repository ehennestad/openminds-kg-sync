function kgcreate(openmindsInstance, kgOptions, options)

    arguments
        openmindsInstance (1,:) openminds.abstract.Schema
        kgOptions.space (1,1) string = omkg.getpref("DefaultSpace")
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    % Todo: Serialization: 
    % - Replace blank node identifiers with kg
    % identifiers. ALSO, is that needed, or can we just strip the blank
    % node identifier prefix???
    % - Serialization should return documents and document ids, maybe as a
    % struct array???

    serializer = omkg.internal.KGSerializer();

    jsonLdDocuments = openmindsInstance.serialize('Serializer', serializer);
    jsonLdDocuments = fliplr(jsonLdDocuments);

    nvPairs = namedargs2cell(kgOptions);

    % Upload one by one
    for i = 1:numel(jsonLdDocuments)

        currentDocument = jsonLdDocuments{i};

        response = options.Client.createNewInstanceWithId(id, jsonLdDocuments, nvPairs{:});
    end

    % Todo: Should we update the id of the local instance? or return the
    % external instance?
end
