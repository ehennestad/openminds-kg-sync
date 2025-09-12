function linkedIdentifiers = extractLinkedIdentifiers(metadataNode, linkedIdentifiers)
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
                if currentValue.State == "reference"
                    linkedIdentifiers(end+1) = {currentValue.id}; %#ok<AGROW>
                end
            elseif openminds.utility.isMixedInstance(currentValue)
                keyboard
            elseif isstruct(currentValue) && isfield(currentValue, 'id') % TODO: This should not be a struct!
                linkedIdentifiers = [linkedIdentifiers, string({currentValue.id})]; %#ok<AGROW>
            end
        end

        % if strcmp(currentField, 'at_id')
        %     linkedIdentifiers(end+1) = metadataNode.("at_id"); %#ok<AGROW>
        % else
        %     if isstruct(metadataNode.(currentField))
        %         currentNode = metadataNode.(currentField);
        %         linkedIdentifiers = omkg.internal.conversion.extractLinkedIdentifiers(currentNode, linkedIdentifiers);
        %     end
        % end
    end
    linkedIdentifiers = unique(linkedIdentifiers);
end
