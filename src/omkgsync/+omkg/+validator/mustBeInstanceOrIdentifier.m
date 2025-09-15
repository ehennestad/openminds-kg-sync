function mustBeInstanceOrIdentifier(target)
% mustBeInstanceOrIdentifier - Validates input is either openMINDS instance or KG identifier
%
% This validator ensures the input is either:
% - An openMINDS schema instance or array (openminds.abstract.Schema)
% - A valid KG identifier string or string array
%
% Syntax:
%   mustBeInstanceOrIdentifier(target)
%
% Input Arguments:
%   target - The value to validate (scalar or array)

    arguments
        target
    end

    if isa(target, 'openminds.abstract.Schema')
        % For openMINDS instances (scalar or array), validate they all have IDs
        for i = 1:numel(target)
            if isempty(target(i).id) || target(i).id == ""
                error("OMKG:mustBeInstanceOrIdentifier:missingId", ...
                    "openMINDS instance at index %d must have a valid 'id' property for deletion.", i)
            end
            % Validate each instance ID is a valid KG identifier
            omkg.validator.mustBeValidKGIdentifier(target(i).id)
        end
    elseif isa(target, 'cell')
        for i = 1:numel(target)
            currentTarget = target{i};
            assert(openminds.utility.isInstance(currentTarget))
            % Validate each instance ID is a valid KG identifier
            omkg.validator.mustBeValidKGIdentifier(currentTarget.id)
        end


    elseif isstring(target) || ischar(target)
        % For strings (scalar or array), validate each is a valid KG identifier
        target = string(target);
        for i = 1:numel(target)
            omkg.validator.mustBeValidKGIdentifier(target(i));
        end
    else
        error("OMKG:mustBeInstanceOrIdentifier:invalidType", ...
            "Input must be either an openMINDS schema instance or a KG identifier string. " + ...
            "Got: %s", class(target))
    end
end
