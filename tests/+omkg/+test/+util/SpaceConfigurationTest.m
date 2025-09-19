classdef SpaceConfigurationTest < matlab.unittest.TestCase
% SpaceConfigurationTest - Tests for SpaceConfiguration class
%
% This test class covers:
% - Configuration loading and parsing
% - Space lookup functionality
% - Class assignment and removal operations
% - Module default handling
% - File I/O operations
% - Error handling scenarios

    properties
        TestDataDir
        SampleConfig
        TempFilePath
    end
    
    methods (TestClassSetup)
        function setupTestClass(testCase)
            % Create test data directory
            testCase.TestDataDir = fullfile(tempdir, 'SpaceConfigTest');
            if ~isfolder(testCase.TestDataDir)
                mkdir(testCase.TestDataDir);
            end
            
            % Define sample configuration data
            testCase.SampleConfig = struct();
            testCase.SampleConfig.core = struct();
            testCase.SampleConfig.core.default = "common";
            testCase.SampleConfig.core.common = {"Person", "Organization"};
            testCase.SampleConfig.core.detailed = {"Affiliation"};
            
            testCase.SampleConfig.computation = struct();
            testCase.SampleConfig.computation.default = [];
            testCase.SampleConfig.computation.spatial = {"CoordinatePoint", "BoundingBox"};
            testCase.SampleConfig.computation.modeling = {"ModelVersion"};
            
            % Create temp file path
            testCase.TempFilePath = fullfile(testCase.TestDataDir, 'test_config.json');
        end
    end
    
    methods (TestClassTeardown)
        function teardownTestClass(testCase)
            % Clean up test directory
            if isfolder(testCase.TestDataDir)
                rmdir(testCase.TestDataDir, 's');
            end
        end
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            % Clean up any existing temp files
            if isfile(testCase.TempFilePath)
                delete(testCase.TempFilePath);
            end
        end
    end
    
    methods (Test)
        
        function testConstructorWithValidData(testCase)
            % Test constructor with valid configuration data
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            testCase.verifyClass(config, 'omkg.util.SpaceConfiguration', ...
                'Constructor should return SpaceConfiguration object');
            testCase.verifyEqual(config.Data, testCase.SampleConfig, ...
                'Data property should match input');
            testCase.verifyEqual(config.FilePath, "", ...
                'FilePath should be empty when not provided');
            testCase.verifyFalse(config.Dirty, ...
                'Dirty flag should be false after construction');
        end
        
        function testConstructorWithFilePath(testCase)
            % Test constructor with file path
            
            testFilePath = "/path/to/config.json";
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig, testFilePath);
            
            testCase.verifyEqual(config.FilePath, testFilePath, ...
                'FilePath should be set correctly');
        end
        
        function testGetSpaceExactMapping(testCase)
            % Test getSpace with exact class mapping
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Test exact mappings
            space = config.getSpace(openminds.enum.Types.Person);
            testCase.verifyEqual(space, "common", ...
                'Person should map to common space');
                
            space = config.getSpace(openminds.enum.Types.CoordinatePoint);
            testCase.verifyEqual(space, "spatial", ...
                'CoordinatePoint should map to spatial space');
        end
        
        function testGetSpaceModuleDefault(testCase)
            % Test getSpace falling back to module default
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            expectedValue = config.Data.core.default;
            actualValue = config.getSpace(openminds.enum.Types.Consortium);
            testCase.verifyEqual(actualValue, expectedValue);
        end
        
        function testSetModuleDefault(testCase)
            % Test setting module defaults
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Set a new default
            config = config.setModuleDefault(openminds.enum.Modules.core, "detailed");
            
            testCase.verifyTrue(config.Dirty, ...
                'Dirty flag should be set after modification');

            expectedValue = "detailed";
            actualValue = string(config.Data.core.default);

            testCase.verifyEqual(actualValue, expectedValue, ...
                'Module default should be updated in data');
        end
        
        function testClearGroupDefault(testCase)
            % Test clearing group defaults
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Clear existing default
            config = config.clearGroupDefault(openminds.enum.Modules.core);
            
            testCase.verifyTrue(config.Dirty, ...
                'Dirty flag should be set after clearing default');
            testCase.verifyEmpty(config.Data.core.default, ...
                'Default should be empty after clearing');
        end
        
        function testAssignClass(testCase)
            % Test assigning a class to a space
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Assign Person to detailed space (move from common)
            config = config.assignClass("detailed", openminds.enum.Types.Person);
            
            testCase.verifyTrue(config.Dirty, ...
                'Dirty flag should be set after assignment');
            
            % Verify Person is in detailed space
            testCase.verifyTrue(any(strcmp(config.Data.core.detailed, "Person")), ...
                'Person should be in detailed space');
            
            % Verify Person is removed from common space
            if isfield(config.Data.core, 'common')
                testCase.verifyFalse(any(strcmp(config.Data.core.common, "Person")), ...
                    'Person should be removed from common space');
            end
            
            % Verify getSpace returns new mapping
            space = config.getSpace(openminds.enum.Types.Person);
            testCase.verifyEqual(space, "detailed", ...
                'getSpace should return new mapping');
        end
        
        function testAssignClassToNonexistentSpace(testCase)
            % Test error when assigning to nonexistent space
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            testCase.verifyError(...
                @() config.assignClass("nonexistent", openminds.enum.Types.Person), ...
                'OMKG:SpaceConfiguration:UnknownSpace', ...
                'Should error when assigning to unknown space');
        end
        
        function testUnassignClass(testCase)
            % Test removing a class from all spaces
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Clear the core module default so getSpace will error after unassignment
            config = config.clearGroupDefault(openminds.enum.Modules.core);
            
            % Unassign Person
            config = config.unassignClass(openminds.enum.Types.Person);
            
            testCase.verifyTrue(config.Dirty, ...
                'Dirty flag should be set after unassignment');
            
            % Verify Person is removed from common space
            testCase.verifyFalse(any(strcmp(config.Data.core.common, "Person")), ...
                'Person should be removed from common space');
            
            % Verify getSpace now errors
            testCase.verifyError(@() config.getSpace(openminds.enum.Types.Person), ...
                'OMKG:SpaceConfiguration:NoFallback', ...
                'Should error after class is unassigned');
        end
        
        function testUnassignNonexistentClass(testCase)
            % Test warning when unassigning nonexistent class
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % This should issue a warning but not error
            testCase.verifyWarning(...
                @() config.unassignClass("NonexistentClass"), ...
                'OMKG:SpaceConfiguration:NotFound', ...
                'Should warn when class not found');
        end
        
        function testUnassignClassSilent(testCase)
            % Test silent unassignment (no warning)
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % This should not issue a warning
            testCase.verifyWarningFree(...
                @() config.unassignClass("NonexistentClass", true), ...
                'Silent unassignment should not produce warnings');
        end
        
        function testSaveWithFilePath(testCase)
            % Test saving configuration to specified file
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            % Save to temp file
            config.save(testCase.TempFilePath);
            
            testCase.verifyTrue(isfile(testCase.TempFilePath), ...
                'File should be created');
            
            % Verify content
            savedData = jsondecode(fileread(testCase.TempFilePath));
            testCase.verifyEqual(string(savedData.core.default), testCase.SampleConfig.core.default, ...
                'Saved data should match original');
        end
        
        function testSaveWithObjectFilePath(testCase)
            % Test saving using object's FilePath property
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig, testCase.TempFilePath);
            
            % Save without specifying path (should use object's FilePath)
            config.save();
            
            testCase.verifyTrue(isfile(testCase.TempFilePath), ...
                'File should be created using object FilePath');
        end
        
        function testSaveWithoutFilePath(testCase)
            % Test error when saving without file path
            
            config = omkg.util.SpaceConfiguration(testCase.SampleConfig);
            
            testCase.verifyError(@() config.save(), ...
                'OMKG:SpaceConfiguration:NoFilePath', ...
                'Should error when no file path provided');
        end
        
        function testLoadFromFile(testCase)
            % Test loading configuration from file
            
            % Create test file
            jsonText = jsonencode(testCase.SampleConfig, "PrettyPrint", true);
            fid = fopen(testCase.TempFilePath, 'w');
            fwrite(fid, jsonText, 'char');
            fclose(fid);
            
            % Load configuration
            config = omkg.util.SpaceConfiguration.load(testCase.TempFilePath);
            
            testCase.verifyClass(config, 'omkg.util.SpaceConfiguration', ...
                'Should return SpaceConfiguration object');
            testCase.verifyEqual(string(config.Data.core.default), testCase.SampleConfig.core.default, ...
                'Loaded data should match original');
            testCase.verifyEqual(config.FilePath, string(testCase.TempFilePath), ...
                'FilePath should be set correctly');
        end
        
        function testLoadFromNonexistentFile(testCase)
            % Test error when loading from nonexistent file
            
            nonexistentPath = fullfile(testCase.TestDataDir, 'nonexistent.json');
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration.load(nonexistentPath), ...
                'OMKG:SpaceConfiguration:NotFound', ...
                'Should error when file not found');
        end
        
        function testFromJSONText(testCase)
            % Test creating configuration from JSON text
            
            jsonText = jsonencode(testCase.SampleConfig);
            config = omkg.util.SpaceConfiguration.fromJSONText(jsonText);
            
            testCase.verifyClass(config, 'omkg.util.SpaceConfiguration', ...
                'Should return SpaceConfiguration object');
            testCase.verifyEqual(string(config.Data.core.default), testCase.SampleConfig.core.default, ...
                'Data should match original');
            testCase.verifyEqual(config.FilePath, "", ...
                'FilePath should be empty');
        end
        
        function testFromInvalidJSON(testCase)
            % Test error with invalid JSON
            
            invalidJSON = "{ invalid json }";
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration.fromJSONText(invalidJSON), ...
                'MATLAB:json:ExpectedNameOrEnd', ...
                'Should error with invalid JSON');
        end
        
        function testInvalidConfigStructure(testCase)
            % Test error with invalid configuration structure
            
            % Array instead of scalar struct
            invalidConfig = [struct(), struct()];
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration(invalidConfig), ...
                'MATLAB:validation:IncompatibleSize', ...
                'Should error with invalid config structure');
        end
        
        function testClassUniquenessValidation(testCase)
            % Test validation of class uniqueness across spaces
            
            % Create config with duplicate class
            duplicateConfig = testCase.SampleConfig;
            duplicateConfig.core.detailed = {"Person", "Affiliation"}; % Person also in common
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration(duplicateConfig), ...
                'OMKG:SpaceConfiguration:ClassDuplicate', ...
                'Should error when class appears in multiple spaces');
        end
        
        function testSpaceUniquenessValidation(testCase)
            % Test validation of space uniqueness across groups
            
            % Create config with duplicate space name
            duplicateConfig = testCase.SampleConfig;
            duplicateConfig.computation.common = {"SomeClass"}; % common also in core
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration(duplicateConfig), ...
                'OMKG:SpaceConfiguration:SpaceAmbiguity', ...
                'Should error when space appears in multiple groups');
        end
        
        function testInvalidGroupStructure(testCase)
            % Test error with invalid group structure
            
            invalidConfig = struct();
            invalidConfig.core = "not a struct"; % Should be struct
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration(invalidConfig), ...
                'OMKG:SpaceConfiguration:SchemaError', ...
                'Should error when group is not a struct');
        end
        
        function testInvalidSpaceList(testCase)
            % Test error with invalid space list
            
            invalidConfig = struct();
            invalidConfig.core = struct();
            invalidConfig.core.default = [];
            invalidConfig.core.common = 123; % Should be cellstr, not numeric
            
            testCase.verifyError(...
                @() omkg.util.SpaceConfiguration(invalidConfig), ...
                'OMKG:SpaceConfiguration:SchemaError', ...
                'Should error when space list is not cellstr');
        end
    end
    
    methods (Test, TestTags = {'Integration'})
        
        function testLoadDefaultConfiguration(testCase)
            % Integration test: Load default configuration if it exists
            % This test is tagged as Integration since it depends on actual files
            
            try
                config = omkg.util.SpaceConfiguration.loadDefault();
                testCase.verifyClass(config, 'omkg.util.SpaceConfiguration', ...
                    'Should load default configuration');
                testCase.verifyTrue(strlength(config.FilePath) > 0, ...
                    'Should have valid file path');
            catch ME
                if contains(ME.identifier, 'NotFound')
                    % Default config file doesn't exist - that's okay for testing
                    testCase.assumeTrue(false, 'Default configuration file not found');
                else
                    rethrow(ME);
                end
            end
        end
    end
end
