function kgsave(openmindsInstance, kgOptions, options)

    arguments
        openmindsInstance (1,:) openminds.abstract.Schema
        kgOptions.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
        options.SaveMode (1,1) omkg.enum.SaveMode = "update"
    end
    
    % Todo: Configure metadata store based on inputs...
    metadataStore = omkg.internal.KGMetadataStore();

    openmindsInstance.save(metadataStore)
end
