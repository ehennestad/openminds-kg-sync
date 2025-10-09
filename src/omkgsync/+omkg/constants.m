classdef constants
% OMKGSYNC Constants - Centralized constant definitions
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

        % OpenMINDS-specific constants
        OpenMINDSNamespaceIRI = "https://openminds.ebrains.eu/"
        OpenMINDSInstanceIRIPrefix = "https://openminds.ebrains.eu/instances/"
    end
end
