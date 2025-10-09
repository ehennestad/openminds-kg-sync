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
                    omId = typeIri + "/" + lower(typeName) + instIdx;

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
                omId = sprintf('%s/%s%d', typeIri, lower(typeName), i);

                instance = struct();
                instance.x_id = uuid;
                instance.http___schema_org_identifier = {omId};

                instances{i} = instance;
            end
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

        function cleanupTestCache()
            % cleanupTestCache - Remove test cache file
            toolboxDir = omkg.toolboxdir();
            cacheFile = fullfile(toolboxDir, 'userdata', 'kg2om_identifier_loopkup.json');

            if isfile(cacheFile)
                delete(cacheFile);
            end
        end
    end
end
