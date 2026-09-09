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
%   class would fail property validation when set on a target. A string
%   that holds no text counts as empty too. isempty alone does not say so:
%   "" is a 1-by-1 string, and an unset (1,1) string property holds
%   exactly that, so a filter on isempty keeps every unset scalar string
%   property while dropping unset lists. The rule applied here is the one
%   openMINDS uses for the same question in ControlledTerm.isEmptyValue,
%   which is private there.

    arguments
        instance (1,1) openminds.Node
    end

    propertyStruct = instance.toStruct();

    propertyNames = fieldnames(propertyStruct)';
    propertyValues = struct2cell(propertyStruct)';

    hasValue = ~cellfun(@isEmptyValue, propertyValues);
    propertyNames = propertyNames(hasValue);
    propertyValues = propertyValues(hasValue);
end

function tf = isEmptyValue(value)
    if isempty(value)
        tf = true;
    elseif isstring(value)
        tf = all(ismissing(value) | value == "");
    else
        tf = false;
    end
end
