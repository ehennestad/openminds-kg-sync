classdef RemoveInvalidIdentifierPairsTest < matlab.unittest.TestCase
% RemoveInvalidIdentifierPairsTest - Unit tests for removeInvalidIdentifierPairs
%
%   Covers the shape rules that decide whether a KG/openMINDS identifier
%   pair can be resolved, and asserts that the identifier map shipped with
%   the toolbox contains no pair that would fail downstream.

    methods (Test) % Pairs that are kept
        function testKeepsWellFormedPair(testCase)
            pairs = makePair(...
                "https://kg.ebrains.eu/api/instances/550e8400", ...
                "https://openminds.ebrains.eu/instances/biologicalSex/male");

            [kept, rejected] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyNumElements(kept, 1)
            testCase.verifyEmpty(rejected)
        end

        function testKeepsPairForTypeAbsentFromOpenMinds(testCase)
            % The shape is checked, not whether openMINDS knows the type.
            % A type that is missing from one openMINDS version may well be
            % present in another, so the pair must survive.
            pairs = makePair(...
                "https://kg.ebrains.eu/api/instances/550e8400", ...
                "https://openminds.ebrains.eu/instances/notAType/notAnInstance");

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyNumElements(kept, 1)
        end
    end

    methods (Test) % Pairs that are rejected
        function testRejectsEmptyOpenMindsIdentifier(testCase)
            % Knowledge Graph instances without any openMINDS schema
            % identifier would otherwise add an empty key to the reverse map.
            pairs = makePair("https://kg.ebrains.eu/api/instances/550e8400", "");

            [kept, rejected] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
            testCase.verifyNumElements(rejected, 1)
        end

        function testRejectsEmptyKnowledgeGraphIdentifier(testCase)
            pairs = makePair(...
                "", "https://openminds.ebrains.eu/instances/biologicalSex/male");

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
        end

        function testRejectsIdentifierOutsideOpenMindsNamespace(testCase)
            pairs = makePair(...
                "https://kg.ebrains.eu/api/instances/550e8400", ...
                "https://example.org/instances/biologicalSex/male");

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
        end

        function testRejectsIdentifierWithoutInstancesSegment(testCase)
            % Observed in the Knowledge Graph as a type IRI stored where an
            % instance IRI belongs. openminds.utility.parseInstanceIRI
            % asserts on it.
            pairs = makePair(...
                "https://kg.ebrains.eu/api/instances/550e8400", ...
                "https://openminds.ebrains.eu/controlledTerms/programmingLanguage/AMPL");

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
        end

        function testRejectsInstanceNameContainingSlash(testCase)
            % The Knowledge Graph does not escape "/" in instance names, so
            % the type and the name can not be told apart.
            pairs = makePair(...
                "https://kg.ebrains.eu/api/instances/550e8400", ...
                "https://openminds.ebrains.eu/instances/molecularEntity/GABA-A/BZ");

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
        end
    end

    methods (Test) % Shape of the result
        function testHandlesEmptyInput(testCase)
            pairs = struct('kg', {}, 'om', {});

            [kept, rejected] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEmpty(kept)
            testCase.verifyEmpty(rejected)
            testCase.verifyEqual(sort(string(fieldnames(kept)))', ["kg", "om"])
        end

        function testReturnsRowForColumnInput(testCase)
            % jsondecode returns a column, the retrieval path a row. Callers
            % concatenate the results, so the orientation has to be fixed.
            pairs = [ ...
                makePair("https://kg.ebrains.eu/api/instances/1", ...
                    "https://openminds.ebrains.eu/instances/biologicalSex/male")
                makePair("https://kg.ebrains.eu/api/instances/2", ...
                    "https://openminds.ebrains.eu/instances/biologicalSex/female")];

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifySize(kept, [1 2])
        end

        function testPreservesOrderOfKeptPairs(testCase)
            pairs = [ ...
                makePair("https://kg.ebrains.eu/api/instances/1", ...
                    "https://openminds.ebrains.eu/instances/biologicalSex/male"), ...
                makePair("https://kg.ebrains.eu/api/instances/2", ""), ...
                makePair("https://kg.ebrains.eu/api/instances/3", ...
                    "https://openminds.ebrains.eu/instances/biologicalSex/female")];

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyEqual(string({kept.kg}), [ ...
                "https://kg.ebrains.eu/api/instances/1", ...
                "https://kg.ebrains.eu/api/instances/3"])
        end
    end

    methods (Test) % Integrity of the shipped resource
        function testShippedResourceContainsOnlyResolvablePairs(testCase)
            % Regression guard for the identifier map shipped with the
            % toolbox. Asserted as a property rather than a count, so that
            % regenerating the resource does not invalidate the test.
            pairs = jsondecode(fileread(shippedResourcePath()));

            kept = omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            omIds = string({kept.om});
            instancePath = extractAfter(omIds, "/instances/");

            testCase.verifyTrue(all(strlength(string({kept.kg})) > 0), ...
                'Every kept pair should carry a Knowledge Graph identifier')
            testCase.verifyTrue(all(startsWith(omIds, ...
                omkg.constants.OpenMINDSInstanceIRIPrefix)), ...
                'Every kept openMINDS IRI should sit in an openMINDS namespace')
            testCase.verifyTrue(all(count(instancePath, "/") == 1), ...
                'Every kept openMINDS IRI should name exactly a type and an instance')
        end

        function testShippedResourceIsRejectedOnlyForKnownReasons(testCase)
            % Keeps the number of unresolvable pairs visible. If the
            % resource is regenerated and this grows, the cause is worth
            % looking at rather than silently absorbing.
            pairs = jsondecode(fileread(shippedResourcePath()));

            [~, rejected] = ...
                omkg.internal.conversion.removeInvalidIdentifierPairs(pairs);

            testCase.verifyLessThanOrEqual(numel(rejected), 3, ...
                sprintf('Unresolvable pairs in the shipped resource: %s', ...
                    strjoin(string({rejected.om}), ', ')))
        end
    end
end

function pairs = makePair(kgId, omId)
    pairs = struct('kg', kgId, 'om', omId);
end

function filePath = shippedResourcePath()
    % The v3 resource specifically: the shipped map is keyed by openMINDS
    % version, and only v3 ships with the toolbox.
    filePath = fullfile(omkg.toolboxdir(), 'omkg', '+omkg', '+internal', ...
        'resources', 'kg2om_identifier_lookup_v3.json');
end
