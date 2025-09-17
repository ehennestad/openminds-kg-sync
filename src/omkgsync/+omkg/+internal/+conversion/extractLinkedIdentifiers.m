function linkedIdentifiers = extractLinkedIdentifiers(metadataNode, linkedIdentifiers)
% extractLinkedIdentifiers - Extract identifiers for forward linked nodes
%
%   Given a metadata node, will extract all forward links and append to a
%   list of linked identifiers. 

    arguments
        metadataNode
        linkedIdentifiers (1,:) string = string.empty
    end

    fields = properties(metadataNode);

    for i = 1:numel(fields)
        currentField = fields{i};
        currentValue = metadataNode.(currentField);
        if ~isempty(currentValue)

            if openminds.utility.isInstance(currentValue)
                for j = 1:numel(currentValue)
                    if currentValue(j).State == "reference"
                        linkedIdentifiers(end+1) = {currentValue(j).id}; %#ok<AGROW>
                    end
                end
            elseif openminds.utility.isMixedInstance(currentValue)
                % TODO: Handle mixed instances
                error('OMKG:ExtractLinkedIds:NotImplemented', ...
                    ['Internal error - Extracting linked ids from mixed ', ...
                    'type instances is not supported yet, please report if ', ...
                    'you see this error.'])
            elseif isstruct(currentValue) && isfield(currentValue, 'x_id') % TODO: This should not be a struct!
                linkedIdentifiers = [linkedIdentifiers, string({currentValue.x_id})]; %#ok<AGROW>
            end
        end
    end
    linkedIdentifiers = unique(linkedIdentifiers);
end
