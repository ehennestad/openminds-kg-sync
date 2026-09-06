function checkEnvironment()
% Check that environment is compatible with running KG sync operations

    % Ensure openminds version 3.0 is used
    ver = openminds.version();
    if ~strcmp(ver, "v3.0")
        warning("KG currently uses openMINDS v3.0, changing version of openMINDS_MATLAB to v3.0...")
        openminds.version(3);
    end

    % Ensure a KG resolver is registered in openminds' link resolver
    % registry. Registration is idempotent per IRI prefix, so a resolver
    % that was registered earlier (possibly reconfigured) is kept.
    openminds.registerLinkResolver( omkg.internal.KGResolver() )
end
