function map = getIdentifierMapping(options)
% getIdentifierMapping - Get identifier mapping (wrapper for ControlledInstanceIdentifierRegistry)
%
%   This function provides backward compatibility with the old API.
%   It now delegates to the ControlledInstanceIdentifierRegistry singleton.
%
% Syntax:
%   map = getIdentifierMapping()
%   map = getIdentifierMapping('Reverse', true)
%
% Input:
%   options.Reverse - If true, maps openMINDS -> KG, else KG -> openMINDS
%
% Output:
%   map - dictionary or containers.Map object
%
% See also: omkg.internal.conversion.ControlledInstanceIdentifierRegistry

    arguments
        options.Reverse (1,1) logical = false
    end

    % Get singleton instance and delegate to it
    registry = omkg.internal.conversion.ControlledInstanceIdentifierRegistry.instance();
    if options.Reverse
        map = registry.OmToKgMap;
    else
        map = registry.KgToOmMap;
    end
end
