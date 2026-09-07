function [identifierPairs, rejectedPairs] = removeInvalidIdentifierPairs(identifierPairs)
% removeInvalidIdentifierPairs - Drop identifier pairs that can not be resolved
%
% Syntax:
%   identifierPairs = omkg.internal.conversion.removeInvalidIdentifierPairs(identifierPairs)
%   [identifierPairs, rejectedPairs] = omkg.internal.conversion.removeInvalidIdentifierPairs(identifierPairs)
%
% Input Arguments:
%   identifierPairs - Struct array with the fields "kg" and "om", pairing a
%       Knowledge Graph instance IRI with an openMINDS instance IRI.
%
% Output Arguments:
%   identifierPairs - The input with unresolvable pairs removed, as a row.
%   rejectedPairs   - The pairs that were removed, as a row.
%
%   A pair is kept only if its openMINDS IRI has the shape
%   <namespace>/instances/<typeName>/<instanceName>. That is the only shape
%   openminds.utility.parseInstanceIRI accepts, so any other shape throws
%   once the IRI reaches openminds.instanceFromIRI. Pairs are also dropped
%   when either identifier is empty, which happens for Knowledge Graph
%   instances that carry no openMINDS schema identifier at all.
%
%   The check is deliberately restricted to the shape of the IRI. Whether
%   the type or instance exists is version dependent, and dropping pairs on
%   that basis would discard mappings that resolve under another openMINDS
%   version.
%
% See also: omkg.internal.conversion.selectCanonicalInstanceIRI

    arguments
        identifierPairs struct
    end

    if isempty(identifierPairs)
        rejectedPairs = identifierPairs;
        return
    end

    kgIds = string({identifierPairs.kg});
    omIds = string({identifierPairs.om});

    isValid = strlength(kgIds) > 0 ...
        & startsWith(omIds, omkg.constants.OpenMINDSInstanceIRIPrefix);

    % Everything after the "/instances/" segment has to be exactly a type
    % name and an instance name. The Knowledge Graph does not escape "/" in
    % instance names (for example "molecularEntity/GABA-A/BZ"), so such an
    % IRI can not be split into a type and a name unambiguously.
    instancePath = repmat("", size(omIds));
    instancePath(isValid) = extractAfter(omIds(isValid), "/instances/");
    isValid = isValid ...
        & count(instancePath, "/") == 1 ...
        & ~startsWith(instancePath, "/") ...
        & ~endsWith(instancePath, "/");

    % Reshape to a row so that callers can concatenate results from several
    % calls. jsondecode returns a column, the API retrieval path a row.
    rejectedPairs = reshape(identifierPairs(~isValid), 1, []);
    identifierPairs = reshape(identifierPairs(isValid), 1, []);
end
