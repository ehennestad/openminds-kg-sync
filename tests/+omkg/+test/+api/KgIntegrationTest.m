classdef KgIntegrationTest < matlab.unittest.TestCase

    properties (TestParameter)
        Type = {'Person', 'DatasetVersion', 'Subject', 'TissueSample'}
    end

    methods (TestClassSetup)
        function setTestPreferences(testCase)
            currentServerPref = omkg.getpref("DefaultServer");
            omkg.setpref("DefaultServer", "PREPROD");
            testCase.addTeardown(@() omkg.setpref("DefaultServer", currentServerPref))
        end
    end

    methods (Test, TestTags={'LiveIntegration'})
        function testList(testCase, Type)
            Type = openminds.enum.Types(Type);
            instances = kglist(Type, ...
                "from", 100, ...
                "size", 20, ...
                "space", "auto", ...
                "stage", "RELEASED");

            testCase.verifyClass(instances, Type.ClassName)
            testCase.verifyLength(instances, 20)
        end

        function testPullWithLinks(testCase)
            instances = kglist("DatasetVersion", ...
                "from", 100, ...
                "size", 20, ...
                "space", "auto", ...
                "stage", "RELEASED");

            testCase.verifyClass(instances, "openminds.core.DatasetVersion")

            id = instances(1).id;

            try
                dsv = kgpull(id, "NumLinksToResolve", 2);
            catch ME
                testCase.verifyFail('Failed to pull instance with id "%s"', id)
            end

            testCase.verifyClass(dsv, "openminds.core.DatasetVersion")

            % verify that links are resolved
            firstAuthor = dsv.author(1);
            testCase.verifyClass(firstAuthor, "openminds.core.Person")
            testCase.verifyTrue(firstAuthor.givenName ~= "", "Expected given name to be different from null")
        end

        function testSave(testCase)
            person = openminds.core.Person(...
                'givenName', 'John', ...
                'familyName', 'Doe', ...
                'contactInformation', openminds.core.ContactInformation('email', 'johndoe@testing.io'));

            kgsave(person, "space", "myspace");

            kgdelete(person.contactInformation.id)
            kgdelete(person.id)
        end

        function testModify(testCase)
            person = openminds.core.Person(...
                'givenName', 'John', ...
                'contactInformation', openminds.core.ContactInformation('email', 'johndoe@testing.io'));

            savedIdPre = kgsave(person, "space", "myspace");

            personFetchedPreEdit = kgpull(savedIdPre);
            testCase.verifyTrue(personFetchedPreEdit.familyName=="")

            personFetchedPreEdit.familyName = 'Doe';
            savedIdPost = kgsave(personFetchedPreEdit, "space", "myspace");

            testCase.verifyEqual(savedIdPre, savedIdPost)

            personFetchedPostEdit = kgpull(savedIdPre);
            testCase.verifyTrue(personFetchedPostEdit.familyName=="Doe")

            kgdelete(person.contactInformation.id)
            kgdelete(person.id)
        end
    end
end
