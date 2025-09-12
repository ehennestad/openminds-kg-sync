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
    if startsWith(identifier, omkg.constant.KgInstanceIRIPrefix)
        identifier = omkg.util.getIdentifierUUID(identifier);
    end

    % UUID regex: 8-4-4-4-12 hex digits (RFC 4122 format)
    uuidPattern = "^[0-9a-fA-F]{8}-" + ...
                  "[0-9a-fA-F]{4}-" + ...
                  "[0-9a-fA-F]{4}-" + ...
                  "[0-9a-fA-F]{4}-" + ...
                  "[0-9a-fA-F]{12}$";

    if ~contains(identifier, regexpPattern(uuidPattern))
        error("OMKGSYNC:validator:InvalidUUID", ...
              "Identifier must be a valid UUID. Got: %s", identifier);
    end
end
