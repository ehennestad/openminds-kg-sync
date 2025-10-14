function linkedIdentifiers = extractLinkedIdentifiers(metadataNode, linkedIdentifiers)
% extractLinkedIdentifiers - Extract identifiers for forward linked nodes
%
%   Given a metadata node, will extract all forward links and append to a
%   list of linked identifiers given as an input.

    arguments
        metadataNode (1,:) cell
        linkedIdentifiers (1,:) string = string.empty
    end

    for i = 1:numel(metadataNode)
        currentUnresolvedLinks = metadataNode{i}.getUnresolvedLinks();
        linkedIdentifiers = [linkedIdentifiers, currentUnresolvedLinks]; %#ok<AGROW>
    end

    linkedIdentifiers = unique(linkedIdentifiers);
end
