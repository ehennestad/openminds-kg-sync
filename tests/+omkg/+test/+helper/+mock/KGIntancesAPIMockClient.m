classdef KGIntancesAPIMockClient < ebrains.kg.api.InstancesClient
% KGIntancesAPIMockClient - Comprehensive mock for all KG API endpoints
%
% This mock supports all EBRAINS KG API methods used across the toolbox:
% - listInstances (for kglist)
% - getInstance (for kgpull)
% - createNewInstance, createNewInstanceWithId, updateInstance, replaceInstance (for kgsave)
% - deleteInstance (for kgdelete, kgdeleteById)
% - getInstancesBulk (for kgpull link resolution)
%
% Testing Methods:
% - wasCalledWithOption(method, option, value) - checks all parameter groups
% - wasCalledWithOptionalParam(method, param, value) - checks optionalParams only
% - wasCalledWithRequiredParam(method, param, value) - checks requiredParams only

    properties
        % Response data for different methods
        ListResponse = []
        ListTypesResponse = []
        InstanceResponse = []
        BulkResponse = []
        CreateResponse = []
        UpdateResponse = []
        ReplaceResponse = []
        DeleteResponse = []

        % Error simulation
        ErrorToThrow = []
        MethodsToError = string.empty()

        % Call tracking
        Calls = struct('method', {}, 'timestamp', {}, 'args', {}, 'options', {})

        % Behavior configuration
        SimulateNetworkDelay = false
        NetworkDelaySeconds = 0.1
    end

    methods
        function obj = KGIntancesAPIMockClient()
            % Initialize with empty responses
            obj.clearResponses();
        end

        %% Response Configuration Methods
        function setListResponse(obj, response)
            obj.ListResponse = response;
        end

        function setListTypesResponse(obj, response)
            obj.ListTypesResponse = response;
        end

        function setInstanceResponse(obj, response)
            obj.InstanceResponse = response;
        end

        function setBulkResponse(obj, response)
            obj.BulkResponse = response;
        end

        function setCreateResponse(obj, response)
            obj.CreateResponse = response;
        end

        function setUpdateResponse(obj, response)
            obj.UpdateResponse = response;
        end

        function setReplaceResponse(obj, response)
            obj.ReplaceResponse = response;
        end

        function setDeleteResponse(obj, response)
            obj.DeleteResponse = response;
        end

        function clearResponses(obj)
            obj.ListResponse = [];
            obj.ListTypesResponse = [];
            obj.InstanceResponse = [];
            obj.BulkResponse = [];
            obj.CreateResponse = [];
            obj.UpdateResponse = [];
            obj.ReplaceResponse = [];
            obj.DeleteResponse = [];
        end

        %% Error Simulation Methods
        function setError(obj, methodName, errorMsg)
            % Set an error to be thrown for specific method calls
            if nargin < 3
                errorMsg = methodName; % If only one arg, apply to all methods
                methodName = "all";
            end
            obj.ErrorToThrow = errorMsg;
            if methodName == "all"
                obj.MethodsToError = ["listInstances", "getInstance", "createNewInstance", ...
                                     "createNewInstanceWithId", "updateInstance", "replaceInstance", ...
                                     "deleteInstance", "getInstancesBulk"];
            else
                obj.MethodsToError = [obj.MethodsToError, methodName];
            end
        end

        function clearErrors(obj)
            obj.ErrorToThrow = [];
            obj.MethodsToError = string.empty();
        end

        %% KG API Method Implementations
        function result = listInstances(obj, type, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                type  (1,1) string
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
                requiredParams.space (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.searchByLabel          string
                optionalParams.filterProperty         string
                optionalParams.filterValue
                optionalParams.from                   uint64
                optionalParams.size                   uint64
                optionalParams.returnTotalResults     logical
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('listInstances', {type}, struct('requiredParams', requiredParams, 'optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('listInstances');
            obj.simulateDelay();

            result = obj.ListResponse;
        end

        function result = getInstance(obj, identifier, stage, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifier string
                stage (1,1) string { mustBeMember(stage, ["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('getInstance', {identifier}, struct('stage', stage, 'optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('getInstance');
            obj.simulateDelay();

            result = obj.InstanceResponse;
            if isempty(result)
                error('EBRAINS:KG:InstanceNotFound', 'Instance not found: %s', identifier);
            end
        end

        function result = createNewInstance(obj, payloadJson, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                requiredParams.space                  (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks    logical
                optionalParams.incomingLinksPageSize  int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('createNewInstance', {payloadJson}, struct('requiredParams', requiredParams, 'optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('createNewInstance');
            obj.simulateDelay();

            result = obj.CreateResponse;
            if isempty(result)
                % Generate a default response
                result = struct();
                result.data = struct();
                result.data.x_id = "generated-" + string(java.util.UUID.randomUUID());
            end
        end

        function result = createNewInstanceWithId(obj, identifier, payloadJson, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifier (1,1) string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                requiredParams.space                  (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks    logical
                optionalParams.incomingLinksPageSize  int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('createNewInstanceWithId', {identifier, payloadJson}, struct('requiredParams', requiredParams, 'optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('createNewInstanceWithId');
            obj.simulateDelay();

            result = obj.CreateResponse;
            if isempty(result)
                % Generate a default response with the provided ID
                result = struct();
                result.data = struct();
                result.data.x_id = identifier;
            end
        end

        function result = updateInstance(obj, identifier, payloadJson, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifier string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('updateInstance', {identifier, payloadJson}, struct('optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('updateInstance');
            obj.simulateDelay();

            result = obj.UpdateResponse;
        end

        function result = replaceInstance(obj, identifier, payloadJson, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifier string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('replaceInstance', {identifier, payloadJson}, struct('optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('replaceInstance');
            obj.simulateDelay();

            result = obj.ReplaceResponse;
        end

        function result = deleteInstance(obj, identifier, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifier string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('deleteInstance', {identifier}, struct('serverOptions', serverOptions));
            obj.checkForError('deleteInstance');
            obj.simulateDelay();

            result = obj.DeleteResponse;
        end

        function result = getInstancesBulk(obj, identifiers, stage, optionalParams, serverOptions)
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                identifiers (1,:) string
                stage (1,1) string { mustBeMember(stage,["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            obj.recordCall('getInstancesBulk', {identifiers, stage}, struct('optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('getInstancesBulk');
            obj.simulateDelay();

            result = obj.BulkResponse;
        end

        function result = listTypes(obj, requiredParams, optionalParams, serverOptions)
            % listTypes - Mock implementation of listTypes for registry testing
            arguments
                obj (1,1) omkg.test.helper.mock.KGIntancesAPIMockClient
                requiredParams.stage (1,1) string = "RELEASED"
                requiredParams.space (1,1) string = "controlled"
                optionalParams.withProperties logical = false
                serverOptions.Server (1,1) string = "PROD"
            end

            obj.recordCall('listTypes', {}, struct('requiredParams', requiredParams, 'optionalParams', optionalParams, 'serverOptions', serverOptions));
            obj.checkForError('listTypes');
            obj.simulateDelay();

            if isempty(obj.ListTypesResponse)
                % Return default controlled term types for testing
                result = {
                    struct('http___schema_org_identifier', 'https://openminds.ebrains.eu/controlledTerms/Species')
                    struct('http___schema_org_identifier', 'https://openminds.ebrains.eu/controlledTerms/Technique')
                };
            else
                result = obj.ListTypesResponse;
            end
        end

        %% Helper Methods for Registry Testing
        function addNewType(obj, typeIri)
            % addNewType - Add a new type to the mock response (for testing new type detection)
            if isempty(obj.ListTypesResponse)
                obj.ListTypesResponse = obj.listTypes();
            end

            newType = struct('http___schema_org_identifier', typeIri);
            obj.ListTypesResponse{end+1} = newType;
        end

        %% Call Tracking and Verification Methods
        function recordCall(obj, methodName, args, options)
            if nargin < 4
                options = struct();
            end

            call = struct();
            call.method = methodName;
            call.timestamp = datetime('now');
            call.args = args;
            call.options = options;

            obj.Calls(end+1) = call;
        end

        function calls = getCallsFor(obj, methodName)
            if isempty(obj.Calls)
                calls = [];
            else
                calls = obj.Calls(strcmp({obj.Calls.method}, methodName));
            end
        end

        function call = getLastCallFor(obj, methodName)
            calls = obj.getCallsFor(methodName);
            if ~isempty(calls)
                call = calls(end);
            else
                call = [];
            end
        end

        function tf = wasCalledWith(obj, methodName, argIndex, expectedValue)
            % Check if method was called with specific argument value
            calls = obj.getCallsFor(methodName);
            tf = false;
            for i = 1:length(calls)
                if length(calls(i).args) >= argIndex
                    if isequal(calls(i).args{argIndex}, expectedValue)
                        tf = true;
                        return;
                    end
                end
            end
        end

        function tf = wasCalledWithOption(obj, methodName, optionName, expectedValue)
            % Check if method was called with specific option value
            % Searches through requiredParams, optionalParams, and serverOptions
            calls = obj.getCallsFor(methodName);
            tf = false;
            for i = 1:length(calls)
                % Check in all parameter groups
                paramGroups = {'requiredParams', 'optionalParams', 'serverOptions'};
                for groupIdx = 1:length(paramGroups)
                    groupName = paramGroups{groupIdx};
                    if isfield(calls(i).options, groupName)
                        paramGroup = calls(i).options.(groupName);
                        if isfield(paramGroup, optionName)
                            if isequal(paramGroup.(optionName), expectedValue)
                                tf = true;
                                return;
                            end
                        end
                    end
                end
            end
        end

        function tf = wasCalledWithOptionalParam(obj, methodName, paramName, expectedValue)
            % Convenience method to check optionalParams specifically
            calls = obj.getCallsFor(methodName);
            tf = false;
            for i = 1:length(calls)
                if isfield(calls(i).options, 'optionalParams')
                    optionalParams = calls(i).options.optionalParams;
                    if isfield(optionalParams, paramName)
                        if isequal(optionalParams.(paramName), expectedValue)
                            tf = true;
                            return;
                        end
                    end
                end
            end
        end

        function tf = wasCalledWithRequiredParam(obj, methodName, paramName, expectedValue)
            % Convenience method to check requiredParams specifically
            calls = obj.getCallsFor(methodName);
            tf = false;
            for i = 1:length(calls)
                if isfield(calls(i).options, 'requiredParams')
                    requiredParams = calls(i).options.requiredParams;
                    if isfield(requiredParams, paramName)
                        if isequal(requiredParams.(paramName), expectedValue)
                            tf = true;
                            return;
                        end
                    end
                end
            end
        end

        function count = getCallCount(obj, methodName)
            if nargin < 2
                count = length(obj.Calls);
            else
                count = length(obj.getCallsFor(methodName));
            end
        end

        function clearCalls(obj)
            obj.Calls = struct('method', {}, 'timestamp', {}, 'args', {}, 'options', {});
        end

        %% Test Helper Methods
        function setupDefaultResponses(obj)
            % Set up reasonable default responses for testing

            % Default list response
            obj.setListResponse({obj.createMockInstance()});

            % Default instance response
            obj.setInstanceResponse(obj.createMockKgNode());

            % Default bulk response
            obj.setBulkResponse({obj.createMockInstance(), obj.createMockInstance()});

            % Default create response
            createResp = struct();
            createResp.data = struct();
            createResp.data.x_id = "mock-created-id";
            obj.setCreateResponse(createResp);
        end

        function instance = createMockInstance(~, type)
            if nargin < 2
                type = "Person";
            end

            instance = struct();
            uuid = "mock-" + lower(type) + "-" + string(randi(1000));
            instance.x_id = "https://kg.ebrains.eu/api/instances/" + uuid;
            instance.x_type = "https://openminds.ebrains.eu/core/" + type;

            switch type
                case "Person"
                    instance.givenName = "Mock";
                    instance.familyName = "Person";
                case "Dataset"
                    instance.shortName = "Mock Dataset";
                    instance.description = "A mock dataset for testing";
                otherwise
                    % todo: this is not general!
                    instance.shortName = "Mock " + type;
            end
        end

        function kgNode = createMockKgNode(obj)
            kgNode = obj.createMockInstance("Person");
        end

        %% Private Helper Methods
    end

    methods (Access = private)
        function checkForError(obj, methodName)
            if ~isempty(obj.ErrorToThrow) && (isempty(obj.MethodsToError) || any(obj.MethodsToError == methodName))
                throw(obj.ErrorToThrow);
            end
        end

        function simulateDelay(obj)
            if obj.SimulateNetworkDelay
                pause(obj.NetworkDelaySeconds);
            end
        end
    end
end
