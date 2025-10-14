classdef SaveMode
    enumeration
        Update("update") % Patch
        Replace("replace")
    end
    properties
        Name
    end
    methods
        function obj = SaveMode(name)
            obj.Name = name;
        end
    end
end
