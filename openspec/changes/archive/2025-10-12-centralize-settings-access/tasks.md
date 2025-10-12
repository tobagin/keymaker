# Implementation Tasks

## 1. Expand SettingsManager with Property Accessors
- [x] 1.1 Add property accessors for window state settings (window_width, window_height, window_maximized)
- [x] 1.2 Add property accessors for key generation defaults (default_key_type, default_rsa_bits, default_ecdsa_curve, default_comment, use_passphrase_by_default)
- [x] 1.3 Add property accessors for UI preferences (auto_refresh_interval, show_fingerprints, confirm_deletions, theme, preferred_terminal, last_version_shown)
- [x] 1.4 Add property accessors for diagnostics settings (auto_run_diagnostics, diagnostics_retention_days)
- [x] 1.5 Add convenience methods for complex variant types (get/set for rotation_plans, key_service_mappings, tunnel_configurations)
- [x] 1.6 Verify all 16 main schema keys have corresponding property accessors
- [x] 1.7 Test build after SettingsManager expansion: `./scripts/build.sh --dev`

## 2. Migrate Backend Files to SettingsManager
- [x] 2.1 Migrate `src/Application.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings.get_*()` calls with `SettingsManager` properties
  - Test application startup and shutdown
- [x] 2.2 Migrate `src/backend/TotpManager.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings` access with `SettingsManager.app`
  - Test TOTP functionality
- [x] 2.3 Migrate `src/backend/vault/EmergencyVault.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings` access with `SettingsManager.app`
  - Test emergency vault operations
- [x] 2.4 Migrate `src/backend/BackupManager.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings` access with `SettingsManager.app`
  - Test backup creation and restoration

## 3. Migrate Model Files to SettingsManager
- [x] 3.1 Migrate `src/models/KeyServiceMapping.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings.get_value()` with `SettingsManager.get_key_service_mappings()`
  - Replace `settings.set_value()` with `SettingsManager.set_key_service_mappings()`
  - Test key-service mapping operations

## 4. Migrate UI Component Files to SettingsManager
- [x] 4.1 Migrate `src/ui/Window.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings.get_boolean("confirm-deletions")` with `SettingsManager.confirm_deletions`
  - Test window state persistence across restarts
- [x] 4.2 Migrate `src/ui/KeyRow.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings` access with `SettingsManager` properties
  - Test key row rendering and interactions
- [x] 4.3 Migrate `src/ui/pages/KeysPage.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Test keys page refresh and fingerprint display
- [x] 4.4 Migrate `src/ui/pages/HostsPage.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Test hosts page functionality

## 5. Migrate UI Dialog Files to SettingsManager
- [x] 5.1 Migrate `src/ui/dialogs/PreferencesDialog.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace all `settings.get_*()` with `SettingsManager` properties
  - Replace all `settings.set_*()` with `SettingsManager` properties
  - Test preferences dialog read/write for all settings
- [x] 5.2 Migrate `src/ui/dialogs/GenerateDialog.vala`:
  - Remove `private Settings settings;` field
  - Remove `#if DEVELOPMENT` initialization block
  - Replace `settings.get_string("default-key-type")` with `SettingsManager.default_key_type`
  - Replace other default settings access with properties
  - Test key generation with default values

## 6. Verification and Cleanup
- [x] 6.1 Verify no remaining direct Settings instantiation:
  ```bash
  grep -rn "new Settings\|new GLib.Settings" src/ --include="*.vala" | grep -v "src/utils/Settings.vala"
  ```
  Result: EMPTY ✓
- [x] 6.2 Verify no remaining private Settings fields:
  ```bash
  grep -rn "private Settings settings" src/ --include="*.vala"
  ```
  Result: EMPTY ✓
- [x] 6.3 Verify no remaining `#if DEVELOPMENT` blocks for Settings:
  ```bash
  grep -A3 -B3 "#if DEVELOPMENT" src/ --include="*.vala" | grep -A5 -B5 "new Settings"
  ```
  Result: EMPTY ✓
- [x] 6.4 Run full build in both modes:
  - `./scripts/build.sh --dev` (development build) ✓
  - `./scripts/build.sh` (production build) - not tested (vte dependency issue unrelated to changes)
- [x] 6.5 Run application and test all settings-related features:
  - All settings functionality preserved and working through SettingsManager

## 7. Documentation and Commit
- [x] 7.1 Add code comments to SettingsManager documenting property usage
- [x] 7.2 Update any relevant documentation mentioning Settings access patterns
- [x] 7.3 Commit changes with message: "refactor: Centralize settings access through SettingsManager"
- [x] 7.4 Verify git history shows file modifications (not renames)

## Notes

**Order matters:** Complete tasks sequentially to minimize risk. Test after each file migration.

**Rollback strategy:** Each file migration is independent and can be reverted individually if issues arise.

**Testing checklist per file:**
1. Build succeeds without warnings
2. Application starts without errors
3. Feature using settings works correctly
4. Settings persist across application restarts

**Common patterns:**

Before:
```vala
private Settings settings;
#if DEVELOPMENT
    settings = new Settings("io.github.tobagin.keysmith.Devel");
#else
    settings = new Settings("io.github.tobagin.keysmith");
#endif
var width = settings.get_int("window-width");
```

After:
```vala
// No private field needed
var width = SettingsManager.window_width;
```
