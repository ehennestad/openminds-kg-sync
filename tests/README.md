# Test Organization

## Test Structure

The tests are organized in a namespace hierarchy that should mirror the source code:

```
tests/
├── +omkg/+test/                    # All tests under omkg.test namespace
│   ├── DownloadControlledInstancesTest.m  # Tests for omkg.downloadControlledInstances()
│   ├── ToolboxVersionTest.m        # Tests for omkg.toolboxversion()
│   │
│   ├── +api/                       # Public API function tests
│   │   ├── KgIntegrationTest.m    # Live KG tests (tagged LiveIntegration)
│   │   ├── KgdeleteTest.m         # Tests for kgdelete()
│   │   ├── KglistTest.m           # Tests for kglist()
│   │   ├── KgpullTest.m           # Tests for kgpull()
│   │   └── KgsaveTest.m           # Tests for kgsave()
│   │
│   ├── +internal/                  # Internal component tests
│   │   ├── ControlledInstanceCacheTest.m
│   │   ├── DownloadMetadataTest.m # Tests for omkg.sync.downloadMetadata()
│   │   ├── GetPropertyValuesTest.m
│   │   ├── KGResolverTest.m
│   │   ├── KGSerializerTest.m
│   │   ├── ResolveLinksTest.m
│   │   └── +conversion/           # Conversion component tests
│   │
│   ├── +util/                      # Utility function tests
│   │   ├── ConstantsTest.m        # Tests for omkg.constants.*
│   │   ├── GetOrdinalStringTest.m
│   │   ├── PreferencesTest.m
│   │   ├── SpaceConfigurationTest.m
│   │   └── UUIDExtractionTest.m   # Tests for omkg.util.getIdentifierUUID()
│   │
│   ├── +validator/                 # Validator tests
│   │   └── ValidatorTest.m        # Tests for omkg.validator.*
│   │
│   ├── +fixtures/                  # Test fixtures (NOT actual tests)
│   │   └── PreferencesFixture.m
│   │
│   └── +helper/                    # Test helpers (NOT actual tests)
│       ├── +mock/                  # Mock objects
│       │   └── KGIntancesAPIMockClient.m
│       └── +util/                  # Test utilities
│           └── KGMockAPIClientExampleTest.m  # Examples of mock usage
│
└── README.md                       # This documentation
```

## Design Principles

1. **Clear Separation**: Tests and helpers are clearly distinguished
2. **Component-Based**: Each test class focuses on specific components
3. **Namespace Organization**: Mirrors source code structure (`omkg.test.*`)
4. **Scalable**: Easy to add new tests in logical locations
5. **Discovery-Friendly**: `runtests('IncludeSubfolders', true)` finds all `TestCase` classes, ignores helpers

## Usage Examples

```matlab
% Run all tests
runtests('IncludeSubfolders', true)

% Run only API tests
runtests('tests/+omkg/+test/+api')

% Run specific component tests
runtests('tests/+omkg/+test/+util')

% Run specific test file
runtests('tests/+omkg/+test/+api/KgpullTest.m')
```

## Test Organization

The test suite is organized by component type:

- **API tests** (public functions) → `+api/`
- **Internal tests** (internal functions) → `+internal/`  
- **Utility tests** (helper functions) → `+util/`
- **Validator tests** (validation functions) → `+validator/`
- **Mock objects** (test helpers) → `+helper/+mock/`
- **Test fixtures** (test data) → `+fixtures/`

Each test class has a single responsibility and focuses on testing specific components. The namespace hierarchy matches the source code structure for easy navigation.
