function checkEnvironment()
% Check that environment is compatible with running KG sync operations

    % Ensure openminds version 3.0 is used
    ver = openminds.version();
    if ~strcmp(ver, "v3.0")
        warning("KG currently uses openMINDS v3.0, changing version of openMINDS_MATLAB to v3.0...")
        openminds.version(3);
    end

    % Ensure KG resolver is added to openminds' linkresolver registry
    resolverRegistry = openminds.internal.resolver.LinkResolverRegistry.instance();
    if ~resolverRegistry.hasLinkResolver('omkg.internal.KGResolver')
        resolverRegistry.addLinkResolver( omkg.internal.KGResolver() )
    end
end
