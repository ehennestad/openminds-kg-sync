classdef MockInstancesClient < ebrains.kg.api.InstancesClient
% MockInstancesClient - Mock implementation of ebrains.kg.api.InstancesClient for testing
    
    properties
        Response
        Calls struct % Array of all method calls made
    end
    
    methods
        function obj = MockInstancesClient()
            obj.Response = [];
            obj.Calls = struct('method', {}, 'timestamp', {}, 'type', {}, 'options', {});
        end
        
        function setResponse(obj, response)
            obj.Response = response;
        end
        
        function recordCall(obj, methodName, type, options)
            % Record a method call with all its arguments
            call = struct();
            call.method = methodName;
            call.timestamp = datetime('now');
            call.type = type;
            call.options = options;
            
            obj.Calls(end+1) = call;
        end
        
        function data = listInstances(obj, type, options)
            % Mock implementation of listInstances
            arguments
                obj
                type
                options.filterProperty string = ""
                options.filterValue string = ""
                options.from uint64 = uint64.empty
                options.size uint64 = uint64.empty
                options.space string = ""
                options.stage = ""  % Can be string or enum
                options.Server = "" % Can be string or enum
            end
            
            % Record this call
            obj.recordCall('listInstances', type, options);
            
            data = obj.Response;
        end
        
        function calls = getCallsFor(obj, methodName)
            % Get all calls for a specific method
            if isempty(obj.Calls)
                calls = [];
            else
                calls = obj.Calls(strcmp({obj.Calls.method}, methodName));
            end
        end
        
        function call = getLastCallFor(obj, methodName)
            % Get the last call for a specific method
            calls = obj.getCallsFor(methodName);
            if ~isempty(calls)
                call = calls(end);
            else
                call = [];
            end
        end
        
        function call = getLastCall(obj)
            % Get the very last call made (any method)
            if ~isempty(obj.Calls)
                call = obj.Calls(end);
            else
                call = [];
            end
        end
        
        function tf = wasLastCalledWith(obj, methodName, paramName, expectedValue)
            % Check if the last call to a method had a specific parameter value
            call = obj.getLastCallFor(methodName);
            if isempty(call)
                tf = false;
            else
                if isfield(call.options, paramName)
                    tf = isequal(call.options.(paramName), expectedValue);
                else
                    tf = false;
                end
            end
        end
        
        function tf = wasCalledWith(obj, methodName, paramName, expectedValue)
            % Check if any call to a method had a specific parameter value
            calls = obj.getCallsFor(methodName);
            tf = false;
            for i = 1:length(calls)
                if isfield(calls(i).options, paramName)
                    if isequal(calls(i).options.(paramName), expectedValue)
                        tf = true;
                        return;
                    end
                end
            end
        end
        
        function count = getCallCount(obj, methodName)
            % Get the number of times a method was called
            if nargin < 2
                count = length(obj.Calls);
            else
                count = length(obj.getCallsFor(methodName));
            end
        end
        
        function clearCalls(obj)
            % Clear the call history
            obj.Calls = [];
        end
    end
end
