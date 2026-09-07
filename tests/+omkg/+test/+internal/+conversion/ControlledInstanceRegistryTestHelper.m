classdef ControlledInstanceRegistryTestHelper
    % ControlledInstanceRegistryTestHelper - Helper methods for registry tests
    %
    % This class provides utility methods for creating test data and
    % configuring mock clients for registry tests.

    methods (Static)
        function mockClient = createConfiguredMock(numTypes, instancesPerType)
            % createConfiguredMock - Create and configure a mock client with test data
            %
            % Syntax:
            %   mockClient = ControlledInstanceRegistryTestHelper.createConfiguredMock()
            %   mockClient = ControlledInstanceRegistryTestHelper.createConfiguredMock(numTypes, instancesPerType)
            %
            % Inputs:
            %   numTypes - Number of controlled term types (default: 3)
            %   instancesPerType - Number of instances per type (default: 5)

            arguments
                numTypes (1,1) double = 3
                instancesPerType (1,1) double = 5
            end

            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            % Create type responses
            typeNames = [
                "Species"
                "Technique"
                "Sex"
                "Organ"
                "Disease"
                "BiologicalSex"
                "Handedness"
                "Species"
                "Technique"
                "UBERONParcellation"
            ];

            typeResponse = cell(numTypes, 1);
            for i = 1:numTypes
                typeName = typeNames(mod(i-1, numel(typeNames)) + 1);
                typeResponse{i} = struct('http___schema_org_identifier', ...
                    "https://openminds.ebrains.eu/controlledTerms/" + typeName);
            end
            mockClient.setListTypesResponse(typeResponse);

            % Create instance responses
            allInstances = {};
            for typeIdx = 1:numTypes
                typeName = typeNames(mod(typeIdx-1, numel(typeNames)) + 1);
                typeIri = "https://openminds.ebrains.eu/controlledTerms/" + typeName;

                for instIdx = 1:instancesPerType
                    uuid = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.generateUUID();
                    omId = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper...
                        .instanceIRI(typeIri, lower(typeName) + instIdx);

                    instance = struct();
                    instance.x_id = uuid;
                    instance.http___schema_org_identifier = {char(omId)};

                    allInstances{end+1} = instance; %#ok<AGROW>
                end
            end

            mockClient.setListResponse(allInstances);
            mockClient.setBulkResponse(allInstances);
        end

        function uuid = generateUUID()
            % generateUUID - Generate a random UUID for testing
            %
            % Output:
            %   uuid - A valid UUID v4 string

            % Generate random hex values
            hex = dec2hex(randi([0, 255], 1, 16), 2)';
            hex = lower(string(hex(:)'));

            % Format as UUID v4
            uuid = sprintf('%s%s%s%s-%s%s-%s%s-%s%s-%s%s%s%s%s%s', hex{:});
        end

        function instances = createTestInstances(typeIri, count)
            % createTestInstances - Create test instances for a specific type
            %
            % Inputs:
            %   typeIri - Type IRI (e.g., 'https://openminds.ebrains.eu/controlledTerms/Species')
            %   count - Number of instances to create
            %
            % Output:
            %   instances - Cell array of instance structs

            arguments
                typeIri (1,1) string
                count (1,1) double = 5
            end

            instances = cell(1, count);
            [~, typeName] = fileparts(typeIri);

            for i = 1:count
                uuid = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper.generateUUID();
                omId = omkg.test.internal.conversion.ControlledInstanceRegistryTestHelper...
                    .instanceIRI(typeIri, lower(typeName) + i);

                instance = struct();
                instance.x_id = uuid;
                instance.http___schema_org_identifier = {char(omId)};

                instances{i} = instance;
            end
        end

        function iri = instanceIRI(typeIri, instanceName)
            % instanceIRI - Build the instance IRI the KG reports for a controlled instance
            %
            % Input:
            %   typeIri - Type IRI, e.g. "https://openminds.ebrains.eu/controlledTerms/Species"
            %   instanceName - Name of the instance within that type
            %
            % Output:
            %   iri - Instance IRI, e.g.
            %       "https://openminds.ebrains.eu/instances/species/species1"
            %
            %   Controlled instances are identified by an IRI under the
            %   "instances" segment. This differs from the type IRI, which
            %   sits under "controlledTerms" and is what the Knowledge Graph
            %   reports as @type; only the instance form can be parsed by
            %   openminds.utility.parseInstanceIRI.
            %
            %   The type segment is lowerCamelCase for the type names used
            %   in these fixtures. Real data is not uniform: types whose
            %   name starts with an acronym keep it, as in
            %   "instances/UBERONParcellation/...".

            arguments
                typeIri (1,1) string
                instanceName (1,1) string
            end

            [namespaceIri, typeName] = fileparts(typeIri);
            namespaceIri = fileparts(namespaceIri);
            typeName = lower(extractBefore(typeName, 2)) + extractAfter(typeName, 1);

            iri = namespaceIri + "/instances/" + typeName + "/" + instanceName;
        end

        function typeResponse = createTypeResponse(typeNames)
            % createTypeResponse - Create type response data for mock
            %
            % Input:
            %   typeNames - String array of type names (without namespace)
            %
            % Output:
            %   typeResponse - Cell array of type structs

            arguments
                typeNames (:,1) string
            end

            typeResponse = cell(numel(typeNames), 1);
            for i = 1:numel(typeNames)
                typeResponse{i} = struct('http___schema_org_identifier', ...
                    "https://openminds.ebrains.eu/controlledTerms/" + typeNames(i));
            end
        end

        function idMap = createIdentifierMap(kgIds, omIds)
            % createIdentifierMap - Create identifier map structure
            %
            % Inputs:
            %   kgIds - String array of KG UUIDs
            %   omIds - String array of openMINDS identifiers
            %
            % Output:
            %   idMap - Struct array with 'kg' and 'om' fields

            arguments
                kgIds (:,1) string
                omIds (:,1) string
            end

            if numel(kgIds) ~= numel(omIds)
                error('kgIds and omIds must have the same length');
            end

            idMap = struct('kg', num2cell(kgIds), 'om', num2cell(omIds));
        end
    end
end
