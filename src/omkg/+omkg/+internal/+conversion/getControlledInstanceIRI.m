function instanceIRI = getControlledInstanceIRI(kgNode)
% getControlledInstanceIRI - openMINDS IRI of a controlled instance downloaded from the KG
%
% Syntax:
%   instanceIRI = omkg.internal.conversion.getControlledInstanceIRI(kgNode)
%
% Input Arguments:
%   kgNode - A single Knowledge Graph node with JSON-LD keywords in the
%       at_ form, as returned by normalizeJsonLdKeywords.
%
% Output Arguments:
%   instanceIRI - The canonical openMINDS instance IRI, or "" when the node
%       carries none.
%
%   The Knowledge Graph assigns every node a UUID of its own and keeps the
%   identifier the node was ingested with in schema:identifier. For a
%   controlled instance that is the openMINDS IRI, which is the portable
%   identity the instance should carry once converted: the UUID only means
%   something within that Knowledge Graph.
%
%   schema:identifier also holds the Knowledge Graph's own IRI for the
%   node, and for some instances more than one openMINDS IRI, typically a
%   corrected spelling next to the superseded one. Only IRIs shaped like an
%   openMINDS instance IRI are considered, and where several remain the one
%   openMINDS recognises is chosen.
%
% See also: omkg.internal.conversion.isOpenMindsInstanceIRI,
%           omkg.internal.conversion.selectCanonicalInstanceIRI

    arguments
        kgNode (1,1) struct
    end

    instanceIRI = "";

    if ~isfield(kgNode, 'http___schema_org_identifier')
        return
    end

    candidateIRIs = string(kgNode.http___schema_org_identifier);
    candidateIRIs = candidateIRIs(...
        omkg.internal.conversion.isOpenMindsInstanceIRI(candidateIRIs));

    if isempty(candidateIRIs)
        return
    end

    instanceIRI = omkg.internal.conversion.selectCanonicalInstanceIRI(candidateIRIs);
end
