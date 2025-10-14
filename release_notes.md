
## Summary

Initial public release of a MATLAB toolbox for synchronizing openMINDS metadata with the EBRAINS Knowledge Graph (KG). It provides user-facing functions for listing, pulling, saving, and deleting KG instances, along with utilities for configuration and preferences management.

Note: This is a pre-1.0 release. The API is not yet stable and may change in future versions. Breaking changes may occur as the toolbox matures based on user feedback and requests. Documentation is currently limited.

## Highlights

### Core commands
- **kglist**: list instances by type/criteria
- **kgpull**: download instances and resolve references
- **kgsave**: serialize and push instances to the KG
- **kgdelete**: remove instances from the KG

### Data handling
- Serialization/deserialization via internal `KGSerializer` and `KGResolver`
- Link resolution across connected instances

### Configuration and utilities
- Workspace/space configuration with defaults (see `resources/defaults/default_spaces.json`)
- Preferences management (get/set) and toolbox startup helpers

**Full Changelog**: https://github.com/ehennestad/openminds-kg-sync/commits/v0.9.0