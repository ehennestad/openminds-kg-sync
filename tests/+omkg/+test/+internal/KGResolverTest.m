classdef KGResolverTest < matlab.unittest.TestCase
% KGResolverTest - Unit tests for omkg.internal.KGResolver
%
%   Covers the openminds.interface.LinkResolver contract as implemented for
%   the Knowledge Graph: identifier matching, in-place population of typed
%   references, replacement of mixed-type references, local resolution of
%   controlled instances, and registration/replacement in the openMINDS
%   link resolver registry.

    properties (Constant)
        PersonIri = "https://kg.ebrains.eu/api/instances/550e8400-e29b-41d4-a716-446655440000"
        ControlledIri = "https://kg.ebrains.eu/api/instances/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        ControlledOpenMindsIri = "https://openminds.ebrains.eu/instances/species/musMusculus"
    end

    properties
        MockClient omkg.test.helper.mock.KGIntancesAPIMockClient
    end

    methods (TestClassSetup)
        function setupEnvironment(~)
            omkg.internal.checkEnvironment()
        end
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.MockClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            testCase.MockClient.setInstanceResponse(testCase.createPersonKgNode());
        end

        function restoreResolverRegistry(testCase)
            % Tests that register resolvers must leave the default
            % registration behind for other tests.
            registry = openminds.internal.resolver.LinkResolverRegistry.getSingleton();
            testCase.addTeardown(@() restoreDefaultRegistration(registry))

            function restoreDefaultRegistration(registry)
                registry.reset()
                omkg.internal.checkEnvironment()
            end
        end
    end

    methods (Test)
        function testCanResolveKgIdentifier(testCase)
            resolver = testCase.createResolver();

            testCase.verifyTrue(resolver.canResolve(testCase.PersonIri))
            testCase.verifyTrue(resolver.canResolve(testCase.ControlledIri))
        end

        function testCannotResolveOtherIdentifiers(testCase)
            resolver = testCase.createResolver();

            testCase.verifyFalse(resolver.canResolve("https://openminds.ebrains.eu/instances/species/musMusculus"))
            testCase.verifyFalse(resolver.canResolve("https://example.org/other"))
        end

        function testResolveNodePopulatesTypedReferenceInPlace(testCase)
            resolver = testCase.createResolver();
            personStub = openminds.core.Person('id', testCase.PersonIri, 'IsReference', true);

            resolved = resolver.resolveNode(personStub);

            testCase.verifySameHandle(resolved, personStub, ...
                'A typed reference should be populated in place')
            testCase.verifyEqual(personStub.givenName, "John")
            testCase.verifyEqual(personStub.familyName, "Doe")
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1)
        end

        function testResolveNodeReplacesMixedTypeReference(testCase)
            resolver = testCase.createResolver();
            reference = openminds.internal.MixedTypeReference(testCase.PersonIri);

            resolved = resolver.resolveNode(reference);

            testCase.verifyClass(resolved, 'openminds.core.Person', ...
                'A mixed type reference should be replaced by an instance of the downloaded type')
            testCase.verifyEqual(resolved.givenName, "John")
            testCase.verifyEqual(string(resolved.id), testCase.PersonIri)
        end

        function testResolveNodeUsesConfiguredServer(testCase)
            resolver = testCase.createResolver("Server", ebrains.kg.enum.KGServer.PREPROD);
            personStub = openminds.core.Person('id', testCase.PersonIri, 'IsReference', true);

            resolver.resolveNode(personStub);

            testCase.verifyTrue(testCase.MockClient.wasCalledWithOption(...
                'getInstance', 'Server', ebrains.kg.enum.KGServer.PREPROD))
        end

        function testResolveNodeResolvesControlledInstanceLocally(testCase)
            resolver = testCase.createResolver();
            speciesStub = openminds.controlledterms.Species('id', testCase.ControlledIri, 'IsReference', true);

            resolved = resolver.resolveNode(speciesStub);

            testCase.verifyClass(resolved, 'openminds.controlledterms.Species')
            testCase.verifyEqual(string(resolved.id), testCase.ControlledOpenMindsIri)
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 0, ...
                'Controlled instances should not be downloaded')
        end

        function testTraversalStoresReplacedInstance(testCase)
            % A nested mixed-type reference resolved through the openMINDS
            % traversal must end up as the returned typed instance.
            openminds.registerLinkResolver(testCase.createResolver(), "Replace", true)

            % The dataset itself must not be a bare reference, or the
            % traversal would try to resolve it too.
            dataset = openminds.core.Dataset('fullName', "Test dataset");
            dataset.custodian = openminds.internal.MixedTypeReference(testCase.PersonIri);

            dataset.resolve('NumLinksToResolve', 1);

            custodian = dataset.custodian;
            testCase.verifyClass(custodian, 'openminds.core.Person')
            testCase.verifyEqual(custodian.givenName, "John")
        end

        function testReplaceRegisteredResolver(testCase)
            firstClient = omkg.test.helper.mock.KGIntancesAPIMockClient();
            firstClient.setInstanceResponse(testCase.createPersonKgNode());
            openminds.registerLinkResolver(testCase.createResolver("Client", firstClient), "Replace", true)

            % Registering without Replace keeps the first resolver
            openminds.registerLinkResolver(testCase.createResolver())
            personStub = openminds.core.Person('id', testCase.PersonIri, 'IsReference', true);
            personStub.resolve();
            testCase.verifyEqual(firstClient.getCallCount('getInstance'), 1)
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 0)

            % Registering with Replace swaps in the new resolver
            openminds.registerLinkResolver(testCase.createResolver(), "Replace", true)
            personStub = openminds.core.Person('id', testCase.PersonIri, 'IsReference', true);
            personStub.resolve();
            testCase.verifyEqual(firstClient.getCallCount('getInstance'), 1)
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1)
        end
    end

    methods (Access = private)
        function resolver = createResolver(testCase, options)
            arguments
                testCase
                options.Server (1,1) ebrains.kg.enum.KGServer = "prod"
                options.Client = testCase.MockClient
            end

            % Inject the identifier map to keep the test independent of the
            % controlled instance registry.
            identifierMap = dictionary(testCase.ControlledIri, testCase.ControlledOpenMindsIri);

            resolver = omkg.internal.KGResolver(...
                "Server", options.Server, ...
                "Client", options.Client, ...
                "IdentifierMap", identifierMap);
        end
    end

    methods (Static, Access = private)
        function kgNode = createPersonKgNode()
            % Mimics the jsondecode output of the KG instances API
            kgNode = struct();
            kgNode.x_id = omkg.test.internal.KGResolverTest.PersonIri;
            kgNode.x_type = "https://openminds.ebrains.eu/core/Person";
            kgNode.https___openminds_ebrains_eu_vocab_givenName = "John";
            kgNode.https___openminds_ebrains_eu_vocab_familyName = "Doe";
        end
    end
end
