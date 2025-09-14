function mustBeValidKGIdentifier(identifier)
% mustBeValidKGIdentifier - Validate identifier as UUID (optionally prefixed).
%
% Supports Knowledge Graph identifiers of the form:
%   <KgInstanceIRIPrefix><uuid> or just <uuid>.
%
% Throws an error if the identifier is not valid.

    arguments
        identifier (1,1) string
    end

    % If identifier starts with the KG instance prefix, strip it
    if startsWith(identifier, omkg.constants.KgInstanceIRIPrefix)
        identifier = omkg.util.getIdentifierUUID(identifier);
    end

    try
        omkg.validator.mustBeValidUUID(identifier)
    catch ME
       rethrow(ME)
    end
end
