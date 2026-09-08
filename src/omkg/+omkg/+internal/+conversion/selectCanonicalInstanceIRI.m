function [canonicalIRI, isResolved] = selectCanonicalInstanceIRI(candidateIRIs)
% selectCanonicalInstanceIRI - Pick the canonical IRI among openMINDS instance aliases
%
% Syntax:
%   canonicalIRI = omkg.internal.conversion.selectCanonicalInstanceIRI(candidateIRIs)
%   [canonicalIRI, isResolved] = omkg.internal.conversion.selectCanonicalInstanceIRI(candidateIRIs)
%
% Input Arguments:
%   candidateIRIs - openMINDS instance IRIs that the Knowledge Graph lists
%       as schema identifiers for one and the same instance.
%
% Output Arguments:
%   canonicalIRI - The IRI to use when mapping the Knowledge Graph instance
%       to openMINDS.
%   isResolved   - True when openMINDS recognises exactly one candidate.
%
%   Some controlled instances in the Knowledge Graph carry more than one
%   schema identifier, typically a legacy misspelling alongside the
%   corrected spelling (for example "metadataManagment" next to
%   "metadataManagement"). Both are returned for the same Knowledge Graph
%   UUID, so one has to be chosen when building the lookup map.
%
%   The candidate whose instance name is listed in the CONTROLLED_INSTANCES
%   constant of the corresponding openMINDS type is chosen, because that
%   constant is the set of names openMINDS is able to resolve. Resolving a
%   name outside that set yields an empty instance and only a warning, so
%   picking the wrong candidate fails silently.
%
%   When the type is absent from the active openMINDS version, does not
%   declare the constant, or when the number of recognised candidates is not
%   exactly one, the alphabetically first candidate is returned and
%   isResolved is false.
%
%   Repeated occurrences of the same IRI are not aliases and are collapsed
%   before the choice is made.
%
% See also: omkg.internal.conversion.removeInvalidIdentifierPairs

    arguments
        candidateIRIs (1,:) string
    end

    % unique also sorts, which keeps the fallback below independent of the
    % order the Knowledge Graph returned the identifiers in. Repeats of one
    % IRI are not aliases and must not be reported as ambiguous.
    candidateIRIs = unique(candidateIRIs);

    if isscalar(candidateIRIs)
        canonicalIRI = candidateIRIs;
        isResolved = true;
        return
    end

    isKnownInstance = false(size(candidateIRIs));
    for i = 1:numel(candidateIRIs)
        isKnownInstance(i) = isControlledInstanceName(candidateIRIs(i));
    end

    if nnz(isKnownInstance) == 1
        canonicalIRI = candidateIRIs(isKnownInstance);
        isResolved = true;
    else
        canonicalIRI = candidateIRIs(1);
        isResolved = false;
    end
end

function tf = isControlledInstanceName(instanceIRI)
% isControlledInstanceName - Whether openMINDS declares this name for its type

    tf = false;

    pathSegments = split(extractAfter(instanceIRI, "/instances/"), "/");
    if numel(pathSegments) ~= 2
        return
    end

    try
        typeEnum = openminds.enum.Types(pathSegments(1));
        metaClass = meta.class.fromName(typeEnum.ClassName);
    catch
        % The type is not part of the openMINDS version currently on the
        % path, so its instance names are unknown rather than invalid.
        return
    end

    if isempty(metaClass)
        return
    end

    controlledInstancesProperty = findobj(metaClass.PropertyList, ...
        "Name", "CONTROLLED_INSTANCES");
    if isempty(controlledInstancesProperty)
        % Not every controlled term type enumerates its instances.
        return
    end

    tf = any(string(controlledInstancesProperty.DefaultValue) == pathSegments(2));
end
