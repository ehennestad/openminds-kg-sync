classdef KgpullTest < matlab.unittest.TestCase
% KgpullTest - Unit tests for the kgpull function
%
% This test class covers:
% - Basic metadata retrieval with valid identifiers
% - Identifier validation (UUID format, KG prefix handling)
% - Link resolution functionality at different depths
% - Error handling for invalid identifiers and network issues
% - Integration with KGIntancesAPIMockClient
% - Edge cases (empty responses, client errors)

    properties (TestParameter)
        % Test with different valid UUID formats
        validUUIDs = {
            "550e8400-e29b-41d4-a716-446655440000", ...
            "6ba7b810-9dad-11d1-80b4-00c04fd430c8", ...
            "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
        }
        
        % Test with different link resolution depths
        linkDepths = {0, 1, 2, 5}
    end
    
    properties
        MockClient
        TestIdentifier
        MockKgNode
        MockLinkedNodes
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            % Create mock client (for KG instances api) and test data
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            testCase.TestIdentifier = "550e8400-e29b-41d4-a716-446655440000";
            
            % Create mock KG node data
            testCase.MockKgNode = testCase.createMockKgNode();
            testCase.MockLinkedNodes = testCase.createMockLinkedNodes();
            
            % Set up mock client responses
            testCase.MockClient.setInstanceResponse(testCase.MockKgNode);
            testCase.MockClient.setBulkResponse(testCase.MockLinkedNodes);
        end
    end
    
    methods (Test)
        
        function testBasicPull(testCase)
            % Test basic metadata retrieval with valid identifier
            
            result = kgpull(testCase.TestIdentifier, 'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(result, 'Should return non-empty result');
            testCase.verifyInstanceOf(result, 'openminds.abstract.Schema', ...
                'Should return openMINDS schema instance');
            testCase.verifyClass(result, 'openminds.core.Person', ...
                'Should return openMINDS schema instance');
            
            % Verify client was called correctly
            testCase.verifyTrue(testCase.MockClient.wasCalledWith('getInstance', 1, testCase.TestIdentifier), ...
                'Client should have been called with correct identifier');
        end
        
        function testPullWithKgPrefix(testCase)
            % Test with KG-prefixed identifier
            kgPrefix = omkg.constants.KgInstanceIRIPrefix;
            prefixedId = kgPrefix + "/" + testCase.TestIdentifier;
            
            result = kgpull(prefixedId, 'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(result, 'Should handle KG-prefixed identifiers');
            
            % Verify the UUID was extracted correctly for the API call
            testCase.verifyTrue(testCase.MockClient.wasCalledWith('getInstance', 1, testCase.TestIdentifier), ...
                'Client should extract UUID from prefixed identifier');
        end
        
        function testInvalidIdentifier(testCase)
            % Test error handling for invalid identifiers
            invalidIds = ["not-a-uuid", "123", "", "invalid-format-here"];
            
            for i = 1:length(invalidIds)
                testCase.verifyError(...
                    @() kgpull(invalidIds(i), 'Client', testCase.MockClient), ...
                    "OMKGSYNC:validator:InvalidUUID", ...
                    sprintf('Should reject invalid identifier: %s', invalidIds(i)));
            end
        end
        
        function testValidUUIDs(testCase, validUUIDs)
            % Test that various valid UUID formats are accepted
            
            testCase.verifyWarningFree(...
                @() kgpull(validUUIDs, 'Client', testCase.MockClient), ...
                sprintf('Should accept valid UUID: %s', validUUIDs));
        end
        
        function testLinkResolution(testCase, linkDepths)
            % Test link resolution at different depths
            
            result = kgpull(testCase.TestIdentifier, ...
                'NumLinksToResolve', linkDepths, ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(result, ...
                sprintf('Should resolve links at depth %d', linkDepths));
            
            % Note: Link resolution testing requires mocking the global downloadInstancesBulk function
            % For now, we verify that the main getInstance call was made
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1, ...
                sprintf('Should call getInstance for depth %d', linkDepths));
        end
        
        function testServerOption(testCase)
            % Test server selection option
            
            result = kgpull(testCase.TestIdentifier, ...
                'Server', ebrains.kg.enum.KGServer.PREPROD, ...
                'Client', testCase.MockClient);
            
            testCase.verifyNotEmpty(result, 'Should accept server option');
        end
        
        function testEmptyResponse(testCase)
            % Test handling of empty response from KG
            
            testCase.MockClient.setInstanceResponse([]);
            
            testCase.verifyError(...
                @() kgpull(testCase.TestIdentifier, 'Client', testCase.MockClient), ...
                'EBRAINS:KG:InstanceNotFound', ...
                'Should handle empty KG response gracefully');
        end
        
        function testClientError(testCase)
            % Test handling of client errors
            
            testException = MException('MATLAB:test:MockError', 'Network error');
            testCase.MockClient.setError('getInstance', testException);
            
            testCase.verifyError(...
                @() kgpull(testCase.TestIdentifier, 'Client', testCase.MockClient), ...
                'MATLAB:test:MockError', ...
                'Should propagate client errors');
        end
    end
    
    methods (Static)
        
        function mockNode = createMockKgNode()
            % Create mock KG node data structure
            mockNode = struct();
            mockNode.x_id = "550e8400-e29b-41d4-a716-446655440000";
            mockNode.x_type = "https://openminds.ebrains.eu/core/Person";
            mockNode.givenName = "John";
            mockNode.familyName = "Doe";
            
            % Add some linked references
            mockNode.affiliation = struct();
            mockNode.affiliation.x_id = "https://kg.ebrains.eu/api/instances/660e8400-e29b-41d4-a716-446655440001";
        end
        
        function mockNodes = createMockLinkedNodes()
            % Create mock linked node data
            mockNodes = cell(1, 2);
            
            % First linked node (affiliation)
            mockNodes{1} = struct();
            mockNodes{1}.x_id = "https://kg.ebrains.eu/api/instances/660e8400-e29b-41d4-a716-446655440001";
            mockNodes{1}.x_type = "https://openminds.ebrains.eu/core/Organization";
            mockNodes{1}.shortName = "Test University";
            
            % Second linked node
            mockNodes{2} = struct();
            mockNodes{2}.x_id = "https://kg.ebrains.eu/api/instances/770e8400-e29b-41d4-a716-446655440002";
            mockNodes{2}.x_type = "https://openminds.ebrains.eu/core/Dataset";
            mockNodes{2}.shortName = "Test Dataset";
        end
    end
end
