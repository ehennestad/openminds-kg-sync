function omInstance = kgpull(identifier, options)
% kgpull - Download an instance from the EBRAINS Knowledge Graph
%
% Syntax:
%   omInstance = kgpull(identifier)
%   omInstance = kgpull(identifier, Name, Value)
%
% Input Arguments:
%   identifier (1,1) string - UUID or full KG IRI of the instance
%
% Name-Value Arguments:
%   NumLinksToResolve (1,1) double - Number of levels of linked instances
%       to download and attach (default: 0)
%   Stage (1,:) ebrains.kg.enum.KGStage - Stages to look in, in order of
%       preference; the first stage that holds the instance wins
%       (default: "IN_PROGRESS"). Every released instance also exists in
%       IN_PROGRESS, so the default returns the draft of an instance,
%       which is the version an edit-and-save workflow needs. Pass
%       "RELEASED" for the published version only.
%   Server (1,1) ebrains.kg.enum.KGServer - "prod" or "preprod"
%       (default: the "DefaultServer" preference)
%   Client ebrains.kg.api.InstancesClient - Client that sends the requests
%
% Output Arguments:
%   omInstance - The openMINDS instance corresponding to the identifier

    arguments
        identifier (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.NumLinksToResolve = 0
        options.Stage (1,:) ebrains.kg.enum.KGStage {mustBeNonempty} = "IN_PROGRESS"
        options.Server (1,1) ebrains.kg.enum.KGServer = omkg.getpref("DefaultServer")
        options.Client ebrains.kg.api.InstancesClient = ebrains.kg.api.InstancesClient()
    end

    omkg.internal.checkEnvironment()

    nvPairs = namedargs2cell(options);
    omInstance = omkg.sync.downloadMetadata(identifier, nvPairs{:});
end
