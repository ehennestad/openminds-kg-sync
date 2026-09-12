classdef KGResolverTest < matlab.unittest.TestCase
% KGResolverTest - Unit tests for omkg.internal.KGResolver
%
%   Covers the openminds.interface.LinkResolver contract as implemented for
%   the Knowledge Graph: identifier matching, in-place population of typed
%   references, replacement of mixed-type references, local resolution of
%   controlled instances that keeps the reference identifier, and
%   registration/replacement in the openMINDS link resolver registry.

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

        function seedControlledInstanceCache(testCase)
            % The resolver consults the controlled instance cache under the
            % "openminds" identity policy. Seed a temporary one with the
            % controlled instance these tests use, isolating the user's
            % real preferences and cache.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.applyFixture(omkg.test.fixtures.PreferencesFixture());
            omkg.setpref("ControlledInstanceIdentity", "openminds");
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            cache = omkg.internal.ControlledInstanceCache.instance(...
                'Reset', true, 'File', fullfile(tempFolder.Folder, "cache.json"));
            cache.record(testCase.ControlledIri, testCase.ControlledOpenMindsIri);
            testCase.addTeardown(@() ...
                omkg.internal.ControlledInstanceCache.instance('Reset', true));
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

        function testResolveNodePopulatesControlledInstanceInPlace(testCase)
            % A typed controlled-instance reference is filled from the local
            % library and keeps the KG identifier it was created with. The
            % resolver contract forbids returning a node with another
            % identifier, since every link to the node carries this one.
            resolver = testCase.createResolver();
            speciesStub = openminds.controlledterms.Species('id', testCase.ControlledIri, 'IsReference', true);
            libraryInstance = omkg.internal.conversion.getControlledInstance(testCase.ControlledOpenMindsIri);

            resolved = resolver.resolveNode(speciesStub);

            testCase.verifySameHandle(resolved, speciesStub, ...
                'A typed controlled-instance reference should be populated in place')
            testCase.verifyEqual(string(resolved.id), testCase.ControlledIri, ...
                'The resolved node must keep the identifier of the reference')
            testCase.verifyEqual(resolved.name, libraryInstance.name)
            testCase.verifyEqual(resolved.definition, libraryInstance.definition)
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 0, ...
                'Controlled instances should not be downloaded')
        end

        function testResolveNodeReplacesMixedTypeControlledReference(testCase)
            resolver = testCase.createResolver();
            reference = openminds.internal.MixedTypeReference(testCase.ControlledIri);
            libraryInstance = omkg.internal.conversion.getControlledInstance(testCase.ControlledOpenMindsIri);

            resolved = resolver.resolveNode(reference);

            testCase.verifyClass(resolved, 'openminds.controlledterms.Species', ...
                'A mixed type reference should be replaced by an instance of the library type')
            testCase.verifyEqual(string(resolved.id), testCase.ControlledIri, ...
                'The replacement must carry the identifier of the reference')
            testCase.verifyEqual(resolved.name, libraryInstance.name)
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 0, ...
                'Controlled instances should not be downloaded')
        end

        function testResolveNodeRejectsControlledInstanceOfOtherType(testCase)
            resolver = testCase.createResolver();
            wrongTypeStub = openminds.controlledterms.BiologicalSex('id', testCase.ControlledIri, 'IsReference', true);

            testCase.verifyError(@() resolver.resolveNode(wrongTypeStub), ...
                'OMKG:KGResolver:ControlledInstanceTypeMismatch')
        end

        function testTraversalKeepsControlledInstanceIdentity(testCase)
            % Resolving through the openMINDS traversal checks that the
            % resolver did not change the identifier of the reference.
            openminds.registerLinkResolver(testCase.createResolver(), "Replace", true)
            libraryInstance = omkg.internal.conversion.getControlledInstance(testCase.ControlledOpenMindsIri);

            subject = openminds.core.research.Subject();
            subject.species = openminds.controlledterms.Species('id', testCase.ControlledIri, 'IsReference', true);

            subject.resolve('NumLinksToResolve', 1);

            species = subject.species;
            testCase.verifyClass(species, 'openminds.controlledterms.Species')
            testCase.verifyEqual(string(species.id), testCase.ControlledIri)
            testCase.verifyEqual(species.name, libraryInstance.name)
            testCase.verifyFalse(species.isReference(), ...
                'The traversal should mark the populated node as resolved')
        end

        function testUnderKgIdentityPolicyControlledInstanceIsDownloaded(testCase)
            % Under "kg" identity the cache is not consulted, so a controlled
            % instance reference is downloaded like any other node and keeps
            % its Knowledge Graph identifier.
            omkg.setpref("ControlledInstanceIdentity", "kg");
            testCase.MockClient.setInstanceResponse(testCase.createSpeciesKgNode());
            resolver = testCase.createResolver();
            speciesStub = openminds.controlledterms.Species('id', testCase.ControlledIri, 'IsReference', true);

            resolved = resolver.resolveNode(speciesStub);

            testCase.verifyEqual(string(resolved.id), testCase.ControlledIri, ...
                'The reference identifier must be kept')
            testCase.verifyEqual(resolved.name, "Mus musculus")
            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1)
        end

        function testControlledInstanceMissingFromLibraryIsDownloaded(testCase)
            % The cache can know a controlled instance the local library
            % does not hold: the KG has terms openMINDS has not released.
            % convertKgNode leaves such a link a reference to be resolved by
            % download, and the resolver must do that rather than fill the
            % reference from a library instance that does not exist, which
            % would leave it empty and marked resolved.
            omkg.internal.ControlledInstanceCache.instance().record(testCase.ControlledIri, ...
                "https://openminds.om-i.org/instances/species/notAnInstanceInTheLibrary");
            testCase.MockClient.setInstanceResponse(testCase.createSpeciesKgNode());
            resolver = testCase.createResolver();
            speciesStub = openminds.controlledterms.Species('id', testCase.ControlledIri, 'IsReference', true);

            resolved = resolver.resolveNode(speciesStub);

            testCase.verifyEqual(testCase.MockClient.getCallCount('getInstance'), 1, ...
                'A term the library does not hold must be downloaded')
            testCase.verifyEqual(string(resolved.id), testCase.ControlledIri)
            testCase.verifyEqual(resolved.name, "Mus musculus")
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

            resolver = omkg.internal.KGResolver(...
                "Server", options.Server, ...
                "Client", options.Client);
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

        function kgNode = createSpeciesKgNode()
            % A controlled instance as the KG returns it: its own UUID as
            % @id, and the openMINDS IRI it was ingested with in
            % schema:identifier next to the KG IRI.
            kgNode = struct();
            kgNode.x_id = omkg.test.internal.KGResolverTest.ControlledIri;
            kgNode.x_type = "https://openminds.om-i.org/types/Species";
            kgNode.http___schema_org_identifier = { ...
                'https://openminds.om-i.org/instances/species/musMusculus', ...
                char(omkg.test.internal.KGResolverTest.ControlledIri)};
            kgNode.https___openminds_ebrains_eu_vocab_name = "Mus musculus";
        end
    end
end
