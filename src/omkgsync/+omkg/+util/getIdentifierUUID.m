function identifier = getIdentifierUUID(identifier)
    if startsWith(identifier, omkg.constants.KgInstanceIRIPrefix + "/")
        identifier = extractAfter(identifier, omkg.constants.KgInstanceIRIPrefix + "/");
    end
end