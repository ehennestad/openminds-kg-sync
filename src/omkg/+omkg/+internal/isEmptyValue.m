function tf = isEmptyValue(value)
% isEmptyValue - Determine whether a property value should count as empty
%
% Syntax:
%   tf = omkg.internal.isEmptyValue(value)
%
% Input Arguments:
%   value - The candidate property value.
%
% Output Arguments:
%   tf (1,1) logical - True if the value is empty, or a string holding no
%       text.
%
%   isempty alone does not say so: "" is a 1-by-1 string, and an unset
%   (1,1) string property holds exactly that, so a filter on isempty
%   keeps every unset scalar string property while dropping unset lists.
%   The rule applied here is the one openMINDS uses for the same question
%   in ControlledTerm.isEmptyValue, which is private there.

    if isempty(value)
        tf = true;
    elseif isstring(value)
        tf = all(ismissing(value) | value == "");
    else
        tf = false;
    end
end
