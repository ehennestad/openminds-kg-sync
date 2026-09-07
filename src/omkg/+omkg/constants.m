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

        % Type (@type) IRI prefixes for controlled terms specifically (not
        % openMINDS types in general). In v3-and-below, controlled term
        % types live under "controlledTerms/" and core schema types under
        % "core/" (a distinct segment). In v4-and-above both collapse into
        % a single "types/" segment shared with every other schema type,
        % so matching against this prefix alone no longer distinguishes a
        % controlled term type from a core type for v4 data (see
        % openMINDS_MATLAB's code/resources/.vocab/types.json). Do not
        % reuse this to recognize openMINDS type IRIs in general: its v3
        % entry only covers controlledTerms/, not core/, sands/, etc.
        OpenMINDSControlledTypeIRIPrefix = ["https://openminds.ebrains.eu/controlledTerms/", "https://openminds.om-i.org/types/"]
    end
end
