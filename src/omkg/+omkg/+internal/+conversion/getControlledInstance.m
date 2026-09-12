function instance = getControlledInstance(openMindsIdentifier)
% getControlledInstance - Library instance for an openMINDS instance IRI
%
% Syntax:
%   instance = omkg.internal.conversion.getControlledInstance(openMindsIdentifier)
%
% Input Arguments:
%   openMindsIdentifier (1,1) string - An openMINDS instance IRI, in either
%       the openminds.ebrains.eu (v3 and below) or the openminds.om-i.org
%       (v4 and above) namespace.
%
% Output Arguments:
%   instance - The instance from the local openMINDS instance library,
%       identified by the IRI in the namespace of the active model version.
%
%   openminds.instanceFromIRI resolves an instance IRI by the name it
%   carries, not by its namespace, so an IRI from another schema version
%   than the one active resolves to the same instance under its active
%   namespace identifier (openMINDS_MATLAB v0.12.0 and later,
%   openMetadataInitiative/openMINDS_MATLAB#179).

    arguments
        openMindsIdentifier (1,1) string
    end

    instance = openminds.instanceFromIRI(openMindsIdentifier);
end
