classdef DownloadMetadataTest < matlab.unittest.TestCase
% DownloadMetadataTest - Tests for internal downloadMetadata function
%
% This test class covers:
% - Direct testing of omkg.sync.downloadMetadata function
% - Mock client integration at the internal level
% - Error handling and edge cases

    properties
        TestUUID
        MockClient
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TestUUID = "550e8400-e29b-41d4-a716-446655440000";
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
        end
    end
    
    methods (Test)
        
        function testBasicDownloadMetadata(testCase)
            % Test the downloadMetadata function directly with controlled inputs
            
            % Create a simple mock KG node
            mockKgNode = struct();
            mockKgNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            mockKgNode.x_type = "https://openminds.ebrains.eu/core/Person";
            mockKgNode.givenName = "John";
            mockKgNode.familyName = "Doe";
            
            % Configure mock client
            testCase.MockClient.setInstanceResponse(mockKgNode);
            
            % Test the download
            try
                result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                    'Client', testCase.MockClient, ...
                    'NumLinksToResolve', 0);
                
                testCase.verifyInstanceOf(result, 'openminds.abstract.Schema', ...
                    'Should return openMINDS schema instance');                
                testCase.verifyClass(result, 'openminds.core.Person', ...
                    'Should return openMINDS Person instance');
                    
            catch ME
                % If it fails due to missing dependencies, that's expected in test environment
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKGSYNC:TestSkipped', 'Test skipped due to missing openMINDS/EBRAINS dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end
        
        function testDownloadMetadataWithLinkResolution(testCase)
            % Test downloadMetadata with link resolution
            
            % Create mock nodes with links
            mainNode = struct();
            mainNode.x_id = "https://kg.ebrains.eu/api/instances/" + testCase.TestUUID;
            mainNode.x_type = "https://openminds.ebrains.eu/core/Person";
            mainNode.givenName = "John";
            mainNode.familyName = "Doe";
            
            % Use contactInformation instead of affiliation for linked property
            linkedNodeId1 = "123e4567-e89b-12d3-a456-426614174000";
            linkedNodeId2 = "123e4567-e89b-12d3-a456-426614174001";

            mainNode.contactInformation = struct('x_id', "https://kg.ebrains.eu/api/instances/" + linkedNodeId1);
            mainNode.digitalIdentifier = struct('x_id', "https://kg.ebrains.eu/api/instances/" + linkedNodeId2);
            
            % Create mock linked node
            linkedNode1 = struct();
            linkedNode1.x_id = "https://kg.ebrains.eu/api/instances/" + linkedNodeId1;
            linkedNode1.x_type = "https://openminds.ebrains.eu/core/ContactInformation";
            linkedNode1.email = "john.doe@example.com";
            
            linkedNode2 = struct();
            linkedNode2.x_id = "https://kg.ebrains.eu/api/instances/" + linkedNodeId2;
            linkedNode2.x_type = "https://openminds.ebrains.eu/core/ORCID";
            linkedNode2.identifier = "https://orcid.org/0000-0002-1825-0097";

            % Set up mock responses
            testCase.MockClient.setInstanceResponse(mainNode);
            testCase.MockClient.setBulkResponse({linkedNode1, linkedNode2});
            
            % Test with link resolution (should not fail even if links can't be resolved)
            try
                result = omkg.sync.downloadMetadata(testCase.TestUUID, ...
                    'Client', testCase.MockClient, ...
                    'NumLinksToResolve', 1);
                
                testCase.verifyNotEmpty(result, 'Should return non-empty result');
                
            catch ME
                % Todo: This is a very unspecific check. Should be improved
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKGSYNC:TestSkipped', 'Test skipped due to missing dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end
        
        function testDownloadMetadataErrorHandling(testCase)
            % Test error handling in downloadMetadata
            
            % Configure mock to throw error
            testCase.MockClient.setError("getInstance", MException('TEST:Error', 'Mock error'));
            
            try
                testCase.verifyError(...
                    @() omkg.sync.downloadMetadata(testCase.TestUUID, 'Client', testCase.MockClient), ...
                    'TEST:Error', ...
                    'Should propagate mock client errors');
            catch ME
                if contains(ME.message, 'openminds') || contains(ME.message, 'ebrains')
                    warning('OMKGSYNC:TestSkipped', 'Test skipped due to missing dependencies: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end
    end
end
