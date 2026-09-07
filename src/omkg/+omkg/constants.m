classdef constants
% OMKG Constants - Centralized constant definitions
%
% This class provides all constants used throughout the openMINDS KG Sync toolbox,
% including wrapped EBRAINS constants for consistency and openMINDS-specific values.
%
% Usage:
%   kgPrefix = omkg.constants.KgInstanceIRIPrefix;
%   omNamespace = omkg.constants.OpenMINDSNamespaceIRI;

    properties (Constant)
        % EBRAINS Knowledge Graph constants (wrapped for consistency)
        KgNamespaceIRI = ebrains.common.constant.KgNamespaceIRI()
        KgInstanceIRIPrefix = ebrains.common.constant.KgInstanceIRIPrefix()

        % OpenMINDS-specific constants. The KG holds instances tagged with
        % either the v3-and-below namespace (openminds.ebrains.eu) or the
        % v4-and-above namespace (openminds.om-i.org), so both are listed
        % here for matching against downloaded data.
        OpenMINDSNamespaceIRI = ["https://openminds.ebrains.eu/", "https://openminds.om-i.org/"]
        OpenMINDSInstanceIRIPrefix = ["https://openminds.ebrains.eu/instances/", "https://openminds.om-i.org/instances/"]
    end
end
