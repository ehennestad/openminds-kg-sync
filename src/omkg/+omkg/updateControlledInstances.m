function updateControlledInstances()
% updateControlledInstances - Refresh the controlled instance identifier map
%
% Syntax:
%   omkg.updateControlledInstances()
%
%   Downloads the mapping between EBRAINS Knowledge Graph UUIDs and
%   openMINDS instance IRIs for every controlled term type, and caches it
%   for the openMINDS version named by the KgOpenMINDSVersion preference.
%
%   The mapping lets a controlled instance referenced by a Knowledge Graph
%   node be resolved from the local openMINDS instance library instead of
%   being downloaded. It is not required: without it those instances are
%   downloaded from the Knowledge Graph like any other node.
%
%   The download makes one request per controlled term type, so it takes a
%   while and needs valid EBRAINS credentials. It is never triggered
%   automatically.
%
% See also: omkg.getpref, omkg.setpref

    omkg.internal.checkEnvironment()

    registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance();
    registry.update()
end
