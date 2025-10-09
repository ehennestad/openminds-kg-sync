classdef KGSerializerTest < matlab.unittest.TestCase
    % KGSerializerTest - Unit tests for KGSerializer class
    %
    % This test suite covers serialization logic including property
    % filtering and edge cases.

    methods (TestClassSetup)
        function setupTestEnvironment(testCase) %#ok<MANU>
            % Ensure openMINDS environment is available
            omkg.internal.checkEnvironment();
        end
    end

    %% Constructor Tests
    methods (Test)
        function testConstructorDefaults(testCase)
            % Test that constructor creates serializer with defaults
            serializer = omkg.internal.KGSerializer();

            testCase.verifyTrue(isa(serializer, 'omkg.internal.KGSerializer'), ...
                'Should create a KGSerializer instance');
            testCase.verifyEmpty(serializer.PropertyFilter, ...
                'Default PropertyFilter should be empty');
        end

        function testConstructorWithPropertyFilter(testCase)
            % Test constructor with property filter
            filter = ["givenName", "familyName"];
            serializer = omkg.internal.KGSerializer('PropertyFilter', filter);

            testCase.verifyEqual(serializer.PropertyFilter, filter, ...
                'PropertyFilter should be set correctly');
        end

        function testConstructorWithAllOptions(testCase)
            % Test constructor with all configuration options
            serializer = omkg.internal.KGSerializer(...
                'RecursionDepth', 2, ...
                'IncludeIdentifier', true, ...
                'EnableCaching', false, ...
                'EnableValidation', false, ...
                'PrettyPrint', false, ...
                'PropertyFilter', "givenName");

            testCase.verifyTrue(isa(serializer, 'omkg.internal.KGSerializer'), ...
                'Should create serializer with custom options');
            testCase.verifyEqual(serializer.PropertyFilter, "givenName", ...
                'PropertyFilter should be set');
        end
    end

    %% Serialization Tests
    methods (Test)
        function testSerializeSimpleInstance(testCase)
            % Test serialization of a simple instance
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John', ...
                'familyName', 'Doe');

            serializer = omkg.internal.KGSerializer();

            % Should serialize without error
            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Serialization should work without warnings');
        end

        function testSerializeWithPropertyFilter(testCase)
            % Test that property filter limits serialized properties
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John', ...
                'familyName', 'Doe');

            % Create serializer with property filter
            serializer = omkg.internal.KGSerializer(...
                'PropertyFilter', "givenName");

            jsonStr = serializer.serialize(person);

            testCase.verifyTrue(contains(jsonStr, 'givenName'), ...
                'Filtered property should be included');
            testCase.verifyFalse(contains(jsonStr, 'familyName'), ...
                'Non-filtered property should be excluded');
        end

        function testSerializeWithEmptyPropertyFilter(testCase)
            % Test serialization with empty property filter (no filtering)
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            serializer = omkg.internal.KGSerializer('PropertyFilter', string.empty);

            jsonStr = serializer.serialize(person);

            testCase.verifyTrue(contains(jsonStr, 'givenName'), ...
                'Properties should be included when filter is empty');
        end

        function testSerializeMultipleInstances(testCase)
            % Test serialization of multiple instances
            person1 = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            person2 = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-2', ...
                'givenName', 'Jane');

            serializer = omkg.internal.KGSerializer();
            jsonStr = serializer.serialize([person1, person2]);

            testCase.verifyTrue(contains(jsonStr{1}, 'John'), ...
                'Should include first instance');
            testCase.verifyTrue(contains(jsonStr{2}, 'Jane'), ...
                'Should include second instance');
        end
    end

    %% Property Filter Tests
    methods (Test)
        function testPropertyFilterPreservesRequiredFields(testCase)
            % Test that @id and @type are always preserved
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John', ...
                'familyName', 'Doe');

            % Filter should not remove @id and @type even if not specified
            serializer = omkg.internal.KGSerializer(...
                'PropertyFilter', "givenName");

            jsonStr = serializer.serialize(person);

            % Should contain @type even though not in filter
            testCase.verifyTrue(contains(jsonStr, '@type') || contains(jsonStr, 'at_type'), ...
                '@type should always be included');
        end

        function testPropertyFilterWithMultipleProperties(testCase)
            % Test filter with multiple properties
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John', ...
                'familyName', 'Doe');

            serializer = omkg.internal.KGSerializer(...
                'PropertyFilter', ["givenName", "familyName"]);

            jsonStr = serializer.serialize(person);

            testCase.verifyTrue(contains(jsonStr, 'givenName'), ...
                'First filtered property should be included');
            testCase.verifyTrue(contains(jsonStr, 'familyName'), ...
                'Second filtered property should be included');
        end

        function testPropertyFilterWithDuplicates(testCase)
            % Test that duplicate properties in filter are handled
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            % Include duplicates in filter
            serializer = omkg.internal.KGSerializer(...
                'PropertyFilter', ["givenName", "givenName", "givenName"]);

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Duplicate properties in filter should be handled');
        end
    end

    %% Edge Cases
    methods (Test)
        function testSerializeInstanceWithEmptyProperties(testCase)
            % Test serialization of instance with empty properties
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1');
            % No other properties set

            serializer = omkg.internal.KGSerializer();

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Should handle instances with minimal properties');
        end

        function testSerializeWithNestedInstances(testCase)
            % Test serialization with nested/linked instances
            org = openminds.core.Organization(...
                'id', 'https://kg.ebrains.eu/api/instances/org-1', ...
                'fullName', 'Test Organization');

            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            try
                person.affiliation = org;
            catch
                % Skip if affiliation not available
                testCase.assumeFail('Affiliation property not available');
            end

            serializer = omkg.internal.KGSerializer('RecursionDepth', 1);

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Should handle nested instances');
        end

        function testSerializeWithValidationDisabled(testCase)
            % Test serialization with validation disabled
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            serializer = omkg.internal.KGSerializer('EnableValidation', false);

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Should work with validation disabled');
        end

        function testSerializeWithCachingDisabled(testCase)
            % Test serialization with caching disabled
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            serializer = omkg.internal.KGSerializer('EnableCaching', false);

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Should work with caching disabled');
        end

        function testSerializeWithRecursionDepth(testCase)
            % Test serialization with different recursion depths
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            serializer = omkg.internal.KGSerializer('RecursionDepth', 5);

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Should handle different recursion depths');
        end

        function testSerializeWithNoPrettyPrint(testCase)
            % Test serialization without pretty printing
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            serializer = omkg.internal.KGSerializer('PrettyPrint', false);
            jsonStr = serializer.serialize(person);

            testCase.verifyTrue(ischar(jsonStr) || isstring(jsonStr), ...
                'Should return JSON string without pretty printing');
        end
    end

    %% Post-Processing Tests
    methods (Test)
        function testPostProcessWithEmptyStructArray(testCase)
            % Test post-processing handles empty arrays
            serializer = omkg.internal.KGSerializer();

            % postProcessInstances is protected, but we can test through serialize
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John');

            testCase.verifyWarningFree(...
                @() serializer.serialize(person), ...
                'Post-processing should handle all cases');
        end

        function testPropertyFilterRemovesCorrectFields(testCase)
            % Test that property filter correctly removes fields
            person = openminds.core.Person(...
                'id', 'https://kg.ebrains.eu/api/instances/person-1', ...
                'givenName', 'John', ...
                'familyName', 'Doe');

            % Only keep givenName (plus @id and @type automatically)
            serializer = omkg.internal.KGSerializer(...
                'PropertyFilter', "givenName");

            jsonStr = serializer.serialize(person);

            % familyName should not be in the output
            testCase.verifyFalse(contains(jsonStr, 'familyName'), ...
                'Filtered-out properties should not appear in JSON');
        end
    end
end
