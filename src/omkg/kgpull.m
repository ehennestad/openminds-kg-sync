function omInstance = kgpull(identifier, options)
% KGPULL Retrieve an openMINDS instance from the EBRAINS Knowledge Graph
%
% Syntax:
%   omInstance = kgpull(identifier)
%   omInstance = kgpull(identifier, options)
%
% Description:
%   Downloads the instance with the given Knowledge Graph identifier and
%   returns it as an openMINDS instance. Linked instances are returned as
%   unresolved references unless NumLinksToResolve is raised.
%
% Input Arguments:
%   identifier - KG identifier of the instance to retrieve
%       Type: string
%       Either a bare UUID or a full KG instance IRI.
%
% Name-Value Arguments:
%   NumLinksToResolve - How many orders of links to follow and download
%       Type: double (nonnegative integer)
%       Default: 0, i.e. links are left as references.
%
%   Server - KG server to download from
%       Type: ebrains.kg.enum.KGServer
%       Default: the "DefaultServer" preference.
%
%   Client - API client instance
%       Type: ebrains.kg.api.InstancesClient
%       Default: a new InstancesClient.
%
% Output Arguments:
%   omInstance - The downloaded instance
%       Type: openminds.Node
%
% Examples:
%   % Retrieve a single instance, leaving its links unresolved
%   person = kgpull("12345678-1234-5678-9012-123456789012");
%
%   % Follow links two levels deep
%   dataset = kgpull(datasetId, "NumLinksToResolve", 2);
%
% See also: kgsave, kglist, kgdelete

    arguments
        identifier (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.NumLinksToResolve (1,1) double {mustBeNonnegative, mustBeInteger} = 0
        options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    omkg.internal.checkEnvironment()

    nvPairs = namedargs2cell(options);
    omInstance = omkg.sync.downloadMetadata(identifier, nvPairs{:});
end
