function tf = hasControlledInstance(openMindsIdentifier)
% hasControlledInstance - Whether the local library holds an instance for an IRI
%
% Syntax:
%   tf = omkg.internal.conversion.hasControlledInstance(openMindsIdentifier)
%
% Input Arguments:
%   openMindsIdentifier (1,1) string - An IRI, typically the @id of a linked
%       node. Either openMINDS instance namespace (openminds.ebrains.eu or
%       openminds.om-i.org) is accepted; any other IRI yields false.
%
% Output Arguments:
%   tf (1,1) logical - True when the IRI names an instance of the local
%       openMINDS instance library, which is what
%       omkg.internal.conversion.getControlledInstance can return.
%
%   The KG links to some nodes by an IRI in the openMINDS instance namespace
%   that has no instance behind it, neither in the KG nor in the library
%   (e.g. .../instances/singleColor/#FF909F for a viewer specification's
%   display colour). The namespace alone therefore does not tell whether
%   the library can resolve a link. This check does, without downloading
%   anything.

    arguments
        openMindsIdentifier (1,1) string
    end

    tf = false;

    if ~startsWith(openMindsIdentifier, omkg.constants.OpenMINDSInstanceIRIPrefix)
        return
    end

    try
        [instanceType, instanceName] = openminds.utility.parseInstanceIRI(openMindsIdentifier);
    catch ME
        % An IRI that does not name a type of the active model version, or
        % is not shaped like an instance IRI, cannot be in the library.
        % Anything else is a genuine failure and is passed on.
        notAnInstanceErrorIds = [ ...
            "openMINDS:ParseInstanceIRI:NotAnInstanceIRI", ...
            "openMINDS:ParseInstanceIRI:UnresolvedType"];
        if ismember(ME.identifier, notAnInstanceErrorIds)
            return
        end
        rethrow(ME)
    end

    libraryInstances = openminds.internal.listControlledInstances( ...
        instanceType, openminds.enum.Modules.empty, instanceName);
    tf = ~isempty(libraryInstances);
end
