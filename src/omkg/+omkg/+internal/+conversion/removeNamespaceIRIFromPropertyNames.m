function metadataNode = removeNamespaceIRIFromPropertyNames(metadataNode)
% removeNamespaceIRIFromPropertyNames - Remove the openminds namespace IRI prefix from property names
    arguments
        metadataNode (1,1) struct
    end
    
    OPENMINDS_IRI = [...
        "https___openminds_ebrains_eu_vocab_", ... % openMINDS Version 3 and below
        "https___openminds_om_i_org_props_" ];    % openMINDS Version 4 and above

    currentIRI = matlab.lang.makeValidName(openminds.constant.PropertyIRIPrefix);
    assert(ismember(currentIRI, OPENMINDS_IRI), ...
        'OMKG:RemoveNameSpaceIRI:CurrentVersionNotSupported', ...
        'Internal Error: Current openMINDS version is not supported, please raise an issue.')

    propertyNames = fieldnames(metadataNode);
    for i = 1:numel(OPENMINDS_IRI)
        propertyNames = strrep(propertyNames, ...
            OPENMINDS_IRI(i), '');
    end

    propertyValues = struct2cell(metadataNode);
    metadataNode = cell2struct(propertyValues, propertyNames);
end
