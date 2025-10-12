# Centralize Settings Access

## Why

The codebase currently has **11 different files** that directly instantiate GLib.Settings objects, resulting in:
1. **Duplicated initialization code** with `#if DEVELOPMENT` conditionals scattered across the codebase
2. **Inconsistent access patterns** - some files use the existing SettingsManager wrapper, others don't
3. **Testing difficulties** - hard-coded Settings instantiation makes unit testing harder
4. **Maintenance burden** - changes to settings schema require updates in multiple locations

The existing `src/utils/Settings.vala` provides a `SettingsManager` class with static access patterns, but it's underutilized. Only 4 files currently use it, while 11 files create Settings instances directly.

## What Changes

This change will:
- **Expand the SettingsManager** to provide type-safe property access for all settings keys (currently only has a few convenience methods)
- **Migrate all direct Settings instantiation** (11 files) to use SettingsManager instead
- **Remove duplicated `#if DEVELOPMENT` conditionals** from UI and backend files
- **Establish a single source of truth** for settings access patterns
- Add **comprehensive property accessors** for all 16 settings keys in the main schema

**Files affected:**
- `src/Application.vala` - migrate to SettingsManager
- `src/backend/TotpManager.vala` - migrate to SettingsManager
- `src/backend/vault/EmergencyVault.vala` - migrate to SettingsManager
- `src/backend/BackupManager.vala` - migrate to SettingsManager
- `src/models/KeyServiceMapping.vala` - migrate to SettingsManager
- `src/ui/KeyRow.vala` - migrate to SettingsManager
- `src/ui/dialogs/PreferencesDialog.vala` - migrate to SettingsManager
- `src/ui/dialogs/GenerateDialog.vala` - migrate to SettingsManager
- `src/ui/pages/KeysPage.vala` - migrate to SettingsManager
- `src/ui/pages/HostsPage.vala` - migrate to SettingsManager
- `src/ui/Window.vala` - migrate to SettingsManager
- `src/utils/Settings.vala` - expand with property accessors

**Breaking changes:** None - this is an internal refactor that doesn't change external behavior.

## Impact

- **Affected specs:** settings-management (new capability)
- **Affected code:** 12 files total (11 migrations + 1 expansion)
- **Benefits:**
  - Reduced code duplication (~22 lines of duplicated init code removed)
  - Single point of configuration for development vs production settings
  - Easier to add new settings in the future
  - Better testability through centralized access
  - Type-safe access reduces runtime errors
- **Risks:** Low - existing SettingsManager already works, we're just expanding its usage
- **Testing:** Verify all settings read/write operations work correctly after migration
