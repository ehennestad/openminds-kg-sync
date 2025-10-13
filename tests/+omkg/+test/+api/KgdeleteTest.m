classdef KgdeleteTest < matlab.unittest.TestCase
% KgdeleteTest - Unit tests for the unified kgdelete function
%
% This test class verifies that the unified kgdelete function works correctly
% with both openMINDS instances and KG identifier strings.

    properties
        UUID = "12345678-1234-5678-9012-123456789012"
        KGPrefixedID = omkg.constants.KgInstanceIRIPrefix + "/" + "12345678-1234-5678-9012-123456789012";
    end

    methods (TestClassSetup)
        function setupOnce(testCase) %#ok<MANU>
            omkg.internal.checkEnvironment()
        end
    end

    methods (Test)
        function testDeleteByIdentifierString(testCase)
            % Test deleting by KG identifier string
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            % Mock successful deletion
            mockClient.setDeleteResponse(struct('success', true));

            % Should not throw error
            testCase.verifyWarningFree(...
                @() kgdelete(testCase.KGPrefixedID, 'Client', mockClient, 'Verbose', false));
                        % Should not throw error

            testCase.verifyWarningFree(...
                @() kgdelete(testCase.UUID, 'Client', mockClient, 'Verbose', false));
        end

        function testDeleteByOpenMINDSInstance(testCase)

            personInstance = openminds.core.Person('id', testCase.KGPrefixedID);

            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            mockClient.setDeleteResponse(struct('success', true));

            testCase.verifyWarningFree(...
                @() kgdelete(personInstance, 'Client', mockClient, 'Verbose', false));
        end

        function testDeleteMultipleIdentifiers(testCase)
            % Test deleting multiple identifiers
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            testIds = [...
                "12345678-1234-5678-9012-123456789012", ...
                "87654321-4321-8765-2109-876543210987"...
                ];

            % Mock successful deletion
            mockClient.setDeleteResponse(struct('success', true));

            % Should not throw error
            testCase.verifyWarningFree(...
                @() kgdelete(testIds, 'Client', mockClient, 'Verbose', false));
        end

        function testValidatorWithArrays(testCase)
            % Test that the validator correctly handles arrays
            import omkg.validator.mustBeInstanceOrIdentifier

            % Test string array - should pass
            testIds = ["12345678-1234-5678-9012-123456789012", ...
                      "87654321-4321-8765-2109-876543210987"];
            testCase.verifyWarningFree(@() mustBeInstanceOrIdentifier(testIds));

            % Test single string - should pass
            singleId = "12345678-1234-5678-9012-123456789012";
            testCase.verifyWarningFree(@() mustBeInstanceOrIdentifier(singleId));

            % Test invalid input type should fail
            testCase.verifyError(@() mustBeInstanceOrIdentifier(123), ...
                "OMKG:mustBeInstanceOrIdentifier:invalidType");
        end

        function testInvalidInputType(testCase)
            % Test that invalid input types are rejected
            testCase.verifyError(@() kgdelete(123), "OMKG:mustBeInstanceOrIdentifier:invalidType");
            testCase.verifyError(@() kgdelete([]), "OMKG:mustBeInstanceOrIdentifier:invalidType");
        end

        function testVerboseOutput(testCase)
            % Test that verbose output works correctly
            mockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();

            % Mock successful deletion
            mockClient.setDeleteResponse(struct('success', true));

            % Capture output
            output = evalc('kgdelete(testCase.UUID, ''Client'', mockClient, ''Verbose'', true)');
            testCase.verifyTrue(contains(output, 'Deleted'));
            testCase.verifyTrue(contains(output, testCase.UUID));
        end
    end
end
