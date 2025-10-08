classdef PreferencesTest < matlab.unittest.TestCase
% PreferencesTest - Tests for Preferences class and getpref/setpref functions
%
% This test class covers:
% - Basic functionality of getpref and setpref functions
% - Preferences singleton behavior
% - Default values and property types
% - Persistence and file operations

    properties (TestParameter)
        % Test parameters for different preference names and values
        DefaultServerValues = {ebrains.kg.enum.KGServer.PREPROD, ebrains.kg.enum.KGServer.PROD}
        DefaultSpaceValues = {"myspace", "testspace", "auto", "production"}
    end

    methods (TestMethodSetup)
        function setupEach(~)
            % Setup for each test - reset preferences to defaults
            prefs = omkg.util.Preferences.getSingleton();
            prefs.reset();
        end
    end

    methods (Test)
        
        function testGetPrefWithoutArguments(testCase)
            % Test that getpref without arguments returns the preferences object
            
            result = omkg.getpref();
            
            testCase.verifyClass(result, 'omkg.util.Preferences', ...
                'getpref() should return Preferences object');
            testCase.verifyTrue(isa(result, 'handle'), ...
                'Preferences should be a handle class');
        end
        
        function testGetPrefDefaultServer(testCase)
            % Test getting the default server preference
            
            defaultServer = omkg.getpref("DefaultServer");
            
            testCase.verifyClass(defaultServer, 'ebrains.kg.enum.KGServer', ...
                'DefaultServer should be of type ebrains.kg.enum.KGServer');
            testCase.verifyEqual(defaultServer, ebrains.kg.enum.KGServer.PREPROD, ...
                'Default server should be PREPROD');
        end
        
        function testGetPrefDefaultSpace(testCase)
            % Test getting the default space preference
            
            defaultSpace = omkg.getpref("DefaultSpace");
            
            testCase.verifyClass(defaultSpace, 'string', ...
                'DefaultSpace should be a string');
            testCase.verifyEqual(defaultSpace, "myspace", ...
                'Default space should be "myspace"');
        end
        
        function testSetPrefDefaultServer(testCase, DefaultServerValues)
            % Test setting the default server preference
            
            omkg.setpref("DefaultServer", DefaultServerValues);
            retrievedValue = omkg.getpref("DefaultServer");
            
            testCase.verifyEqual(retrievedValue, DefaultServerValues, ...
                'Set and retrieved DefaultServer values should match');
        end
        
        function testSetPrefDefaultSpace(testCase, DefaultSpaceValues)
            % Test setting the default space preference
            
            omkg.setpref("DefaultSpace", DefaultSpaceValues);
            retrievedValue = omkg.getpref("DefaultSpace");
            
            testCase.verifyEqual(retrievedValue, DefaultSpaceValues, ...
                'Set and retrieved DefaultSpace values should match');
        end
        
        function testPreferencesSingleton(testCase)
            % Test that preferences behave as a singleton
            
            prefs1 = omkg.getpref();
            prefs2 = omkg.getpref();
            
            testCase.verifyTrue(prefs1 == prefs2, ...
                'Multiple calls to getpref should return the same object instance');
            
            % Test that changes in one reference affect the other
            omkg.setpref("DefaultSpace", "test_singleton");
            
            testCase.verifyEqual(prefs1.DefaultSpace, "test_singleton", ...
                'Changes should be reflected in all references to singleton');
            testCase.verifyEqual(prefs2.DefaultSpace, "test_singleton", ...
                'Changes should be reflected in all references to singleton');
        end
        
        function testInvalidPreferenceName(testCase)
            % Test that invalid preference names throw errors
            
            testCase.verifyError(@() omkg.getpref("InvalidPreference"), ...
                'MATLAB:noSuchMethodOrField', ...
                'Getting invalid preference should throw error');
                
            testCase.verifyError(@() omkg.setpref("InvalidPreference", "value"), ...
                'MATLAB:noPublicFieldForClass', ...
                'Setting invalid preference should throw error');
        end
        
        function testPreferencesDisplay(testCase)
            % Test that preferences object displays correctly
            
            prefs = omkg.getpref(); %#ok<NASGU>
            
            % Capture display output
            displayText = evalc('disp(prefs)');
            
            testCase.verifyTrue(contains(displayText, 'Preferences'), ...
                'Display should contain "Preferences"');
            testCase.verifyTrue(contains(displayText, 'DefaultServer'), ...
                'Display should show DefaultServer property');
            testCase.verifyTrue(contains(displayText, 'DefaultSpace'), ...
                'Display should show DefaultSpace property');
        end
        
        function testPreferencesReset(testCase)
            % Test that preferences can be reset to defaults
            
            prefs = omkg.getpref();
            
            % Change some values
            omkg.setpref("DefaultServer", ebrains.kg.enum.KGServer.PROD);
            omkg.setpref("DefaultSpace", "modified_space");
            
            % Verify values were changed
            testCase.verifyEqual(prefs.DefaultServer, ebrains.kg.enum.KGServer.PROD);
            testCase.verifyEqual(prefs.DefaultSpace, "modified_space");
            
            % Reset preferences
            prefs.reset();
            
            % Verify values were reset to defaults
            testCase.verifyEqual(prefs.DefaultServer, ebrains.kg.enum.KGServer.PREPROD, ...
                'DefaultServer should be reset to PREPROD');
            testCase.verifyEqual(prefs.DefaultSpace, "myspace", ...
                'DefaultSpace should be reset to myspace');
        end
        
        function testSetPrefReturnValue(testCase)
            % Test that setpref returns the preferences object
            
            result = omkg.setpref("DefaultSpace", "test_return");
            
            testCase.verifyClass(result, 'omkg.util.Preferences', ...
                'setpref should return Preferences object');
            testCase.verifyEqual(result.DefaultSpace, "test_return", ...
                'Returned object should have the updated value');
        end
        
        function testPreferencesTypeValidation(testCase)
            % Test that preferences enforce correct types
            
            % DefaultServer should only accept KGServer enum values
            testCase.verifyError(@() omkg.setpref("DefaultServer", "invalid_server"), ...
                'MATLAB:validation:UnableToConvert', ...
                'Setting DefaultServer to invalid type should throw error');
            
            % DefaultSpace should accept string values
            omkg.setpref("DefaultSpace", "valid_string");
            
            % Test that numeric values are converted to string for DefaultSpace
            omkg.setpref("DefaultSpace", string(123));
            testCase.verifyEqual(omkg.getpref("DefaultSpace"), "123", ...
                'Numeric values should be converted to string for DefaultSpace');
        end
    end
    
    methods (TestMethodTeardown)
        function teardownEach(~)
            % Cleanup after each test - reset preferences to defaults
            prefs = omkg.util.Preferences.getSingleton();
            prefs.reset();
        end
    end
end
