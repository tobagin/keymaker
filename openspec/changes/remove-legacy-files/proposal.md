# Remove Legacy Code Files

## Why

Phase 3 of the KeyMaker refactoring plan addresses technical debt by removing obsolete legacy files that are no longer used in the codebase. These files were superseded by newer implementations but remain in the repository:

1. **EmergencyVaultOld.vala** (1,782 lines) - Old emergency vault implementation superseded by the modular vault system
2. **KeyRotationDialogOld.vala** (1,138 lines) - Old key rotation dialog superseded by the current implementation

These files contribute ~2,920 lines of dead code that:
- Confuse developers and contributors
- Increase repository size unnecessarily
- May cause accidental usage or reference
- Clutter IDE navigation and search results
- Create maintenance burden

The files are **not referenced** in:
- Build system (meson.build)
- Any source code imports
- Any active code paths

They exist only as historical artifacts and should be removed to maintain a clean codebase.

## What Changes

### File Removal
- Delete `src/backend/EmergencyVaultOld.vala` (1,782 lines)
- Delete `src/ui/dialogs/KeyRotationDialogOld.vala` (1,138 lines)

### Verification
- Verify no code references these files (already confirmed)
- Verify build succeeds after removal
- Update documentation references if any exist

### Documentation Updates
- Update REFACTORING-PLAN.md to mark Phase 3 as complete
- Remove references to legacy files from project documentation

## Impact

**Affected specs:**
- `code-structure` (cleanup of obsolete code)

**Affected code:**
- **None** - These files are not imported or used anywhere

**Breaking changes:**
- **None** - Files are not part of the public API or used by any code

**Migration requirements:**
- **None** - No code migration needed

**Dependencies:**
- Phase 1 (file naming) completed - files were already renamed to PascalCase
- No other dependencies

**Benefits:**
- Removes 2,920 lines of dead code
- Reduces repository size
- Improves codebase clarity
- Eliminates confusion for new contributors
- Reduces IDE indexing overhead
