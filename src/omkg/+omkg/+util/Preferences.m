classdef Preferences < matlab.mixin.CustomDisplay & handle
%Preferences for the OpenMINDS-KG-Sync Toolbox
%
%       Preference name                 Description
%       -----------------------------   ---------------------------------------
%       DefaultServer       (string)  : Which KG Server to interact with.
%                                       Options: "preprod" (default) or "prod"
%       DefaultSpace        (string)  : Which KG space to interact with.
%                                       Choose an existing KG space or use
%                                       "auto" to resolve space
%                                       automatically given type.
%                                       Auto-resolving is handled by
%                                       omkg.util.SpaceConfiguration

    properties (SetObservable)
        DefaultServer (1,1) ebrains.kg.enum.KGServer = "preprod"
        DefaultSpace (1,1) string = "myspace"
    end

    properties (Constant, Access = private)
        Filename = fullfile(prefdir, 'OMKGToolboxPreferences.mat')
    end

    methods (Access = private) % Constructor

        function obj = Preferences()
            if isfile(obj.Filename)
                try
                    S = load(obj.Filename);
                    obj = S.obj;
                catch
                    warning('Could not load preferences, using defaults')
                end
            end
            obj.addListeners()
        end

        function save(obj)
            save(obj.Filename, 'obj');
        end
    end

    methods (Hidden)
        function reset(obj)
            mc = metaclass(obj);

            propertyList = mc.PropertyList( ~[mc.PropertyList.Constant] );
            propertyNames = string( {propertyList.Name} );
            propertyDefaultValues = {propertyList.DefaultValue};

            for i = 1:numel(propertyNames)
                obj.(propertyNames(i)) = propertyDefaultValues{i};
            end

            obj.save()
        end
    end

    methods (Sealed, Hidden) % Overrides subsref

        function varargout = subsasgn(obj, s, value)
            %subsasgn Override subsasgn to save preferences when they change

            numOutputs = nargout;
            varargout = cell(1, numOutputs);

            isPropertyAssigned = strcmp(s(1).type, '.') && ...
                any( strcmp(properties(obj), s(1).subs) );

            % Use the builtin subsref with appropriate number of outputs
            if numOutputs > 0
                [varargout{:}] = builtin('subsasgn', obj, s, value);
            else
                builtin('subsasgn', obj, s)
            end

            if isPropertyAssigned
                obj.save()
            end
        end
    end

    methods (Access = protected) % Overrides CustomDisplay methods

        function str = getHeader(obj)
            className = class(obj);
            helpLink = sprintf('<a href="matlab:help %s" style="font-weight:bold">%s</a>', className, 'Preferences');
            str = sprintf('%s for the OpenMINDS-KG-Sync Toolbox:\n', helpLink);
        end

        function groups = getPropertyGroups(obj)
            propNames = obj.getActivePreferenceGroup();

            s = struct();
            for i = 1:numel(propNames)
                s.(propNames{i}) = obj.(propNames{i});
            end

            groups = matlab.mixin.util.PropertyGroup(s);
        end
    end

    methods (Access = private)

        function addListeners(~)
        %createListeners Create listeners for some preferences
        end

        function propertyNames = getActivePreferenceGroup(obj)
            %getCurrentPreferenceGroup Get current preference group
            %
            %   This method returns a cell array of names of preferences that
            %   are currently active. Some preference values are dependent on
            %   the values of other preferences, and will sometimes not have an
            %   effect.
            %
            %   This method is used by the getPropertyGroups that in turn
            %   determines how the preference object will be displayed. The
            %   effect is that dependent preferences are hidden when they are
            %   not active.

            propertyNames = properties(obj);

            namesToHide = {};
            % Todo: Find hidden property names

            propertyNames = setdiff(propertyNames, namesToHide, 'stable');
        end
    end

    %% STATIC METHODS
    methods (Static, Hidden)

        function obj = getSingleton()
            %getSingleton Get singleton instance of class
            persistent objStore

            if isempty(objStore)
                objStore = omkg.util.Preferences();
            end

            obj = objStore;
        end
    end
end
