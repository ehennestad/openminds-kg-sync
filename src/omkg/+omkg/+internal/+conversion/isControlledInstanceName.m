function tf = isControlledInstanceName(instanceIRI)
% isControlledInstanceName - Whether the openMINDS instance library holds the instance an IRI names
%
% Syntax:
%   tf = omkg.internal.conversion.isControlledInstanceName(instanceIRI)
%
% Input Arguments:
%   instanceIRI string - openMINDS instance IRIs, of any schema version.
%
% Output Arguments:
%   tf logical - True, per IRI, when the instance library of the active
%       openMINDS version holds an instance of the IRI's type with the
%       IRI's instance name.
%
%   The library is the set of instances openMINDS resolves locally. Asking
%   openMINDS for a name outside it does not fail cleanly: a controlled
%   term admits user-defined names and returns an empty instance with a
%   warning, while other types error. A caller that needs the library
%   instance, and nothing else, therefore has to ask first, which is what
%   this function is for.
%
%   The library holds instances of more types than the controlled terms,
%   for example licenses, parcellation entity versions and brain atlas
%   versions, so membership is read from the library itself and not from
%   the CONTROLLED_INSTANCES constant that only controlled term classes
%   declare.
%
%   The IRI is parsed by openMINDS, which also resolves the few plural
%   type segments such as "licenses". The name is matched exactly,
%   although openMINDS resolves names without regard to case. The
%   Knowledge Graph lists case variants of one name as aliases of a single
%   instance, and only an exact match can tell which of them is the
%   library's spelling.
%
%   An IRI that does not name an instance, or whose type is absent from
%   the active openMINDS version, is reported as unknown rather than
%   invalid.
%
% See also: omkg.internal.conversion.selectCanonicalInstanceIRI,
%   openminds.utility.parseInstanceIRI

    arguments
        instanceIRI string
    end

    tf = false(size(instanceIRI));
    for i = 1:numel(instanceIRI)
        tf(i) = isLibraryInstance(instanceIRI(i));
    end
end

function tf = isLibraryInstance(instanceIRI)
    tf = false;

    try
        [typeEnum, instanceName] = openminds.utility.parseInstanceIRI(instanceIRI);
    catch
        % Not an instance IRI, or a type that is not part of the openMINDS
        % version currently on the path. Either way the name is unknown.
        return
    end

    instances = openminds.internal.listControlledInstances(...
        typeEnum, openminds.enum.Modules.empty, instanceName);
    tf = height(instances) > 0;
end
