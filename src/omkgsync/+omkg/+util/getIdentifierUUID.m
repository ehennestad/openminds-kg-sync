function identifier = getIdentifierUUID(identifier)
    if startsWith(identifier, omkg.constant.KgInstanceIRIPrefix + "/")
        identifier = extractAfter(identifier, omkg.constant.KgInstanceIRIPrefix + "/");
    end
end