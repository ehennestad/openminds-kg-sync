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
%   The identifier map can hold IRIs of either namespace, while
%   openminds.instanceFromIRI recognises only the namespace of the active
%   model version: given the other one, openMINDS_MATLAB v0.11.0 goes on to
%   treat the IRI as a file path and fails. The IRI is therefore rewritten
%   to the active namespace before the library is asked for it.

    arguments
        openMindsIdentifier (1,1) string
    end

    activeNamespaceIRI = openminds.constant.BaseIRI() + "/";
    for namespaceIRI = omkg.constants.OpenMINDSNamespaceIRI
        if startsWith(openMindsIdentifier, namespaceIRI)
            openMindsIdentifier = replace(openMindsIdentifier, namespaceIRI, activeNamespaceIRI);
            break
        end
    end

    instance = openminds.instanceFromIRI(openMindsIdentifier);
end
