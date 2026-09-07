function checkEnvironment()
% Check that environment is compatible with running KG sync operations

    % The KG does not expose which openMINDS schema version it serves (and
    % may run mixed versions across spaces), so the expected version is a
    % pinned preference rather than something detected at runtime.
    pinnedVersion = omkg.getpref("KgOpenMINDSVersion");
    expectedVersionStr = sprintf("v%d.0", pinnedVersion);

    currentVersionStr = openminds.version();
    if ~strcmp(currentVersionStr, expectedVersionStr)
        warning("KG currently uses openMINDS %s, changing version of openMINDS_MATLAB to %s...", ...
            expectedVersionStr, expectedVersionStr)
        openminds.version(pinnedVersion);
    end

    % Ensure a KG resolver is registered in openminds' link resolver
    % registry. Registration is idempotent per IRI prefix, so a resolver
    % that was registered earlier (possibly reconfigured) is kept.
    openminds.registerLinkResolver( omkg.internal.KGResolver() )
end
