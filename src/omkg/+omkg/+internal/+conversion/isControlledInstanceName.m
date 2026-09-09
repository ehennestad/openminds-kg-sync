function tf = isControlledInstanceName(instanceIRI)
% isControlledInstanceName - Whether openMINDS declares the instance an IRI names
%
% Syntax:
%   tf = omkg.internal.conversion.isControlledInstanceName(instanceIRI)
%
% Input Arguments:
%   instanceIRI string - openMINDS instance IRIs, of any schema version.
%
% Output Arguments:
%   tf logical - True, per IRI, when the active openMINDS version lists the
%       instance name in the CONTROLLED_INSTANCES constant of the IRI's type.
%
%   That constant is the set of names openMINDS resolves from the library.
%   Resolving a name outside it does not fail: openMINDS deliberately admits
%   user-defined terms, so it returns an empty instance and warns. A caller
%   that needs the library instance, and nothing else, therefore has to ask
%   first, which is what this function is for.
%
%   The name is matched exactly, although openMINDS resolves names without
%   regard to case. The Knowledge Graph lists case variants of one name as
%   aliases of a single instance, and only an exact match can tell which of
%   them is the library's spelling.
%
%   An IRI whose type is absent from the active openMINDS version, or whose
%   type does not enumerate its instances, is reported as unknown rather
%   than invalid.
%
% See also: omkg.internal.conversion.selectCanonicalInstanceIRI

    arguments
        instanceIRI string
    end

    tf = false(size(instanceIRI));
    for i = 1:numel(instanceIRI)
        tf(i) = isDeclaredInstance(instanceIRI(i));
    end
end

function tf = isDeclaredInstance(instanceIRI)
    tf = false;

    pathSegments = split(extractAfter(instanceIRI, "/instances/"), "/");
    if numel(pathSegments) ~= 2
        return
    end

    try
        typeEnum = openminds.enum.Types(pathSegments(1));
        metaClass = meta.class.fromName(typeEnum.ClassName);
    catch
        % The type is not part of the openMINDS version currently on the
        % path, so its instance names are unknown rather than invalid.
        return
    end

    if isempty(metaClass)
        return
    end

    controlledInstancesProperty = findobj(metaClass.PropertyList, ...
        "Name", "CONTROLLED_INSTANCES");
    if isempty(controlledInstancesProperty)
        % Not every controlled term type enumerates its instances.
        return
    end

    tf = any(string(controlledInstancesProperty.DefaultValue) == pathSegments(2));
end
