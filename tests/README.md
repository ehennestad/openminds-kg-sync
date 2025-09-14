# Test Organization

## Test Structure

The tests are organized in a namespace hierarchy that should mirror the source code:

```
tests/
├── +omkg/+test/                    # All tests under omkg.test namespace
│   ├── +api/                       # Public API function tests
│   │   ├── KglistTest.m           # Tests for kglist()
│   │   └── KgpullTest.m           # Tests for kgpull()
│   │
│   ├── +internal/                  # Internal component tests
│   │   ├── DownloadMetadataTest.m # Tests for omkg.sync.downloadMetadata()
│   │   └── +conversion/           # Conversion component tests (empty)
│   │
│   ├── +util/                      # Utility function tests
│   │   ├── ConstantsTest.m        # Tests for omkg.constants.*
│   │   └── UUIDExtractionTest.m   # Tests for omkg.util.getIdentifierUUID()
│   │
│   ├── +validator/                 # Validator tests
│   │   └── ValidatorTest.m        # Tests for omkg.validator.*
│   │
│   └── +helper/                    # Test helpers (NOT actual tests)
│       ├── +mock/                  # Mock objects
│       │   └── KGIntancesAPIMockClient.m
│       ├── +util/                  # Test utilities
│       │   └── KGMockAPIClientExampleTest.m  # Examples of mock usage
│       └── +fixture/               # Test fixtures (empty)
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
- **Test fixtures** (test data) → `+helper/+fixture/`

Each test class has a single responsibility and focuses on testing specific components. The namespace hierarchy matches the source code structure for easy navigation.
