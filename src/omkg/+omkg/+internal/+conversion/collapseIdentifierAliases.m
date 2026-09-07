function identifierRecords = collapseIdentifierAliases(identifierPairs)
% collapseIdentifierAliases - Group identifier pairs into one record per KG instance
%
% Syntax:
%   identifierRecords = omkg.internal.conversion.collapseIdentifierAliases(identifierPairs)
%
% Input Arguments:
%   identifierPairs - Struct array with the fields "kg" and "om", one row
%       per openMINDS identifier, so a Knowledge Graph instance carrying
%       several identifiers appears in several rows.
%
% Output Arguments:
%   identifierRecords - Struct array with the fields "kg", "om" and
%       "aliases", one row per Knowledge Graph instance. "om" is the
%       canonical openMINDS IRI and "aliases" holds the remaining ones.
%
%   Some controlled instances in the Knowledge Graph carry more than one
%   schema identifier: when an identifier is corrected, the superseded
%   spelling is kept so that existing references still resolve, and both
%   are returned for the same UUID.
%
%   Keeping them in a flat list left the choice of identifier to the order
%   the Knowledge Graph happened to return them in, because a map built
%   from that list silently keeps the last value for a repeated key.
%   Recording the canonical identifier and its aliases separately makes the
%   choice explicit and lets both directions resolve: an alias still names
%   its Knowledge Graph instance, while the canonical identifier is the one
%   written back.
%
% See also: omkg.internal.conversion.selectCanonicalInstanceIRI,
%           omkg.internal.conversion.removeInvalidIdentifierPairs

    arguments
        identifierPairs struct
    end

    identifierRecords = struct('kg', {}, 'om', {}, 'aliases', {});
    if isempty(identifierPairs)
        return
    end

    kgIds = string({identifierPairs.kg});
    omIds = string({identifierPairs.om});

    [uniqueKgIds, ~, groupIndex] = unique(kgIds);

    numRecords = numel(uniqueKgIds);
    identifierRecords = repmat(...
        struct('kg', "", 'om', "", 'aliases', string.empty), 1, numRecords);

    unresolvedKgIds = string.empty;
    for i = 1:numRecords
        candidateIRIs = unique(omIds(groupIndex == i));

        [canonicalIRI, isCanonicalKnown] = ...
            omkg.internal.conversion.selectCanonicalInstanceIRI(candidateIRIs);

        identifierRecords(i).kg = uniqueKgIds(i);
        identifierRecords(i).om = canonicalIRI;
        identifierRecords(i).aliases = candidateIRIs(candidateIRIs ~= canonicalIRI);

        if ~isCanonicalKnown
            unresolvedKgIds(end+1) = uniqueKgIds(i); %#ok<AGROW>
        end
    end

    if ~isempty(unresolvedKgIds)
        warning('OMKG:ControlledInstanceRegistry:AmbiguousIdentifiers', ...
            ['%d Knowledge Graph instance(s) carry several openMINDS ', ...
            'identifiers that openMINDS does not disambiguate. The ', ...
            'alphabetically first is treated as canonical for:\n  %s'], ...
            numel(unresolvedKgIds), strjoin(unresolvedKgIds, newline + "  "))
    end
end
