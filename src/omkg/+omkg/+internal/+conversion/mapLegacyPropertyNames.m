function [kgNode, mapped] = mapLegacyPropertyNames(kgNode, typeName)
% mapLegacyPropertyNames - Move properties stored under pre-v4 names to their current names
%
% Syntax:
%   [kgNode, mapped] = omkg.internal.conversion.mapLegacyPropertyNames(kgNode, typeName)
%
% Input Arguments:
%   kgNode   (1,1) struct - A Knowledge Graph node with the namespace IRI
%                           already removed from its property names.
%   typeName (1,1) string - Short name of the node's openMINDS type, e.g.
%                           "Contribution".
%
% Output Arguments:
%   kgNode - The node with each legacy property renamed to its current
%            name, when the current name was absent.
%   mapped - (1,:) string, the legacy names that were renamed.
%
% The Knowledge Graph stores some properties under names from before
% openMINDS v4. The table in resources/defaults/legacy_property_names.json
% says, per type, which current property holds the same value. A node
% that carries both names keeps the current one and drops the legacy
% copy, since the two were observed to hold the same value.

    arguments
        kgNode (1,1) struct
        typeName (1,1) string
    end

    mapped = strings(1, 0);
    table = legacyNameTable();
    if ~isfield(table, typeName)
        return
    end

    aliases = table.(typeName);
    for legacyName = string(fieldnames(aliases))'
        if ~isfield(kgNode, legacyName)
            continue
        end
        currentName = string(aliases.(legacyName));
        if ~isfield(kgNode, currentName)
            kgNode.(currentName) = kgNode.(legacyName);
        end
        kgNode = rmfield(kgNode, legacyName);
        mapped(end+1) = legacyName; %#ok<AGROW>
    end
end

function table = legacyNameTable()
% The table is read once per session; the file does not change at run time.
    persistent cached
    if isempty(cached)
        filePath = fullfile(omkg.toolboxdir(), 'omkg', 'resources', 'defaults', 'legacy_property_names.json');
        cached = jsondecode(fileread(filePath));
        if isfield(cached, 'x_comment')
            cached = rmfield(cached, 'x_comment');
        end
    end
    table = cached;
end
