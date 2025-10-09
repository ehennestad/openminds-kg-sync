classdef KgIntegrationTest < matlab.unittest.TestCase
    
    methods (TestClassSetup)
        function setTestPreferences(testCase)
            currentServerPref = omkg.getpref("DefaultServer");
            omkg.setpref("DefaultServer", "PROD");
            testCase.addTeardown(@() omkg.setpref("DefaultServer", currentServerPref))
        end
    end

    methods (Test, TestTags={'LiveIntegration'})
        function testList(testCase)
            p = kglist("Person", "from", 100, "size", 20, "space", "common", "stage", "RELEASED");

            testCase.verifyClass(p, 'openminds.core.Person')
            testCase.verifyLength(p, 20)
        end
    end
end
