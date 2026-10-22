function checkEnvironment()
% checkEnvironment - Check that the session can run KG sync operations
%
%   Errors if the active openMINDS_MATLAB model version is not the one the
%   Knowledge Graph is pinned to (the KgOpenMINDSVersion preference). The
%   version is never switched here: it is a global setting of the host
%   session, and MATLAB does not reload class definitions while instances
%   of them exist, so the switch is the user's to make after clearing any
%   openMINDS instances.

    % The KG does not expose which openMINDS schema version it serves (and
    % may run mixed versions across spaces), so the expected version is a
    % pinned preference rather than something detected at runtime.
    pinnedVersion = omkg.getpref("KgOpenMINDSVersion");
    expectedVersionStr = sprintf("v%d.0", pinnedVersion);

    currentVersionStr = openminds.version();
    if ~strcmp(currentVersionStr, expectedVersionStr)
        error("OMKG:checkEnvironment:OpenMindsVersionMismatch", ...
            ['The Knowledge Graph is pinned to openMINDS %s (preference ', ...
            '"KgOpenMINDSVersion"), but openMINDS_MATLAB is on %s. Run ', ...
            'openminds.version(%d) to switch. Clear any openMINDS instances ', ...
            'from memory first (e.g. clear the variables holding them, or ', ...
            '"clear classes"): MATLAB does not reload class definitions ', ...
            'while instances of the previous version exist.'], ...
            expectedVersionStr, currentVersionStr, pinnedVersion)
    end

    % Ensure a KG resolver is registered in openminds' link resolver
    % registry. Registration is idempotent per IRI prefix, so a resolver
    % that was registered earlier (possibly reconfigured) is kept.
    openminds.registerLinkResolver( omkg.internal.KGResolver() )
end
