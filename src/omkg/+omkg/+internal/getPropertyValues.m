function [propertyNames, propertyValues] = getPropertyValues(instance)
% getPropertyValues - Names and values of the properties holding a value
%
% Syntax:
%   [propertyNames, propertyValues] = omkg.internal.getPropertyValues(instance)
%
% Input Arguments:
%   instance (1,1) openminds.Node - The instance to read.
%
% Output Arguments:
%   propertyNames  (1,:) cell - Names of the properties that hold a value.
%   propertyValues (1,:) cell - Their values, in the same order.
%
%   Empty values are left out: they add nothing, and an empty of the wrong
%   class would fail property validation when set on a target. See
%   omkg.internal.isEmptyValue for what counts as empty.
%
%   toStruct() itself already leaves out id and IsReference, both Hidden
%   properties: a caller that copies these values onto another instance to
%   resolve it, as omkg.internal.KGResolver does, relies on that exclusion
%   to never change the identifier of the instance it is populating. This
%   function adds no logic of its own to protect that; it is a property of
%   toStruct()'s default IncludeHidden=false, noted here because a caller
%   depends on it.

    arguments
        instance (1,1) openminds.Node
    end

    propertyStruct = instance.toStruct();

    propertyNames = fieldnames(propertyStruct)';
    propertyValues = struct2cell(propertyStruct)';

    hasValue = ~cellfun(@omkg.internal.isEmptyValue, propertyValues);
    propertyNames = propertyNames(hasValue);
    propertyValues = propertyValues(hasValue);
end
