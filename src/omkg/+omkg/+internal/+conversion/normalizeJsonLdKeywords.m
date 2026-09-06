function node = normalizeJsonLdKeywords(node)
% normalizeJsonLdKeywords - Rename x_-prefixed JSON-LD keyword fields to at_ form
%
% Syntax:
%   node = omkg.internal.conversion.normalizeJsonLdKeywords(node)
%
% Description:
%   MATLAB's jsondecode turns JSON-LD keywords like "@id" into the field
%   name "x_id". openMINDS_MATLAB uses the "at_" form ("at_id") for these
%   keywords in all decoded documents. This function renames the keyword
%   fields of a decoded KG payload, recursively through nested structs and
%   cell arrays, so that KG nodes follow the same convention. Input that is
%   already in at_ form is returned unchanged.
%
% Input Arguments:
%   node - Decoded JSON payload: struct, struct array, cell array or any
%       other value (returned unchanged).
%
% Output Arguments:
%   node - The same payload with keyword fields in at_ form.

    KEYWORD_FIELDS_X = ["x_context", "x_id", "x_type", "x_graph", "x_vocab"];
    KEYWORD_FIELDS_AT = ["at_context", "at_id", "at_type", "at_graph", "at_vocab"];

    if iscell(node)
        node = cellfun(@omkg.internal.conversion.normalizeJsonLdKeywords, ...
            node, 'UniformOutput', false);

    elseif isstruct(node)
        fieldNames = string( fieldnames(node) );
        [isKeyword, keywordIndex] = ismember(fieldNames, KEYWORD_FIELDS_X);
        fieldNames(isKeyword) = KEYWORD_FIELDS_AT(keywordIndex(isKeyword));

        % struct2cell keeps the array shape in trailing dimensions, so
        % rebuilding along dimension 1 preserves struct array shapes.
        fieldValues = struct2cell(node);
        fieldValues = cellfun(@omkg.internal.conversion.normalizeJsonLdKeywords, ...
            fieldValues, 'UniformOutput', false);
        node = cell2struct(fieldValues, cellstr(fieldNames), 1);

    else
        % Scalars, text and numeric arrays need no processing
    end
end
