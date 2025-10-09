function space = resolveSpace(type, options)
% resolveSpace - Resolves the space a type belongs to
%
% Syntax:
%   space = resolveSpace(type, options) Resolves the space based on the
%   specified type and options provided.
%
% Input Arguments:
%   - type (1,1) openminds.enum.Types - The type of space to resolve.
%   
% Name-Value Arguments:
% - SpaceProfile (1,1) string - The space profile to use for the
%   resolution (default is 'default'). Not implemented yet.
%
% Output Arguments:
%   space - The resolved space name.

    arguments
        type (1,1) openminds.enum.Types
        options.SpaceProfile (1,1) string {mustBeMember(options.SpaceProfile, "default")} = "default"
    end

    persistent spaceConfig
    if isempty(spaceConfig)
        spaceConfig = omkg.util.SpaceConfiguration.loadDefault();
    end

    space = spaceConfig.getSpace(type);
end
