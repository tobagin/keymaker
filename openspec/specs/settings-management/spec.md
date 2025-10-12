# settings-management Specification

## Purpose
Defines the centralized settings management system that provides type-safe, consolidated access to all application configuration through the SettingsManager class.

## Requirements

### Requirement: Centralized Settings Access
The application SHALL provide a centralized SettingsManager class that is the single point of access for all GLib.Settings instances.

**Rationale**: Eliminates code duplication, provides type-safe access, and simplifies testing by consolidating settings instantiation logic.

#### Scenario: Settings Manager provides singleton access
- **GIVEN** any component in the application needs to access settings
- **WHEN** the component accesses settings
- **THEN** it SHALL use `SettingsManager.app` for main settings or `SettingsManager.tunneling` for tunneling settings
- **AND** SHALL NOT create new GLib.Settings instances directly

#### Scenario: Development vs Production schema selection
- **GIVEN** the application is compiled in development mode
- **WHEN** SettingsManager is accessed
- **THEN** it SHALL automatically use the development schema ID (`io.github.tobagin.keysmith.Devel`)
- **AND** no client code SHALL contain `#if DEVELOPMENT` conditionals for Settings instantiation

#### Scenario: Production schema usage
- **GIVEN** the application is compiled in production mode
- **WHEN** SettingsManager is accessed
- **THEN** it SHALL automatically use the production schema ID (`io.github.tobagin.keysmith`)
- **AND** all settings SHALL persist to the production schema path

### Requirement: Type-Safe Property Access
SettingsManager SHALL provide type-safe property accessors for all settings keys defined in the GSettings schema.

**Rationale**: Compile-time type checking prevents runtime errors from incorrect types, and properties provide cleaner syntax than string-based access.

#### Scenario: Window state properties
- **GIVEN** a component needs to read or write window dimensions
- **WHEN** accessing window state settings
- **THEN** the component SHALL use:
  - `SettingsManager.window_width` (int property)
  - `SettingsManager.window_height` (int property)
  - `SettingsManager.window_maximized` (bool property)
- **AND** properties SHALL enforce correct types at compile time

#### Scenario: Key generation default properties
- **GIVEN** a component needs key generation defaults
- **WHEN** accessing default settings
- **THEN** the component SHALL use:
  - `SettingsManager.default_key_type` (string property)
  - `SettingsManager.default_rsa_bits` (int property)
  - `SettingsManager.default_ecdsa_curve` (int property)
  - `SettingsManager.default_comment` (string property)
  - `SettingsManager.use_passphrase_by_default` (bool property)

#### Scenario: UI preference properties
- **GIVEN** a component needs UI preference settings
- **WHEN** accessing UI preferences
- **THEN** the component SHALL use:
  - `SettingsManager.auto_refresh_interval` (int property)
  - `SettingsManager.show_fingerprints` (bool property)
  - `SettingsManager.confirm_deletions` (bool property)
  - `SettingsManager.theme` (string property)
  - `SettingsManager.preferred_terminal` (string property)

#### Scenario: Diagnostics settings properties
- **GIVEN** a component needs diagnostics configuration
- **WHEN** accessing diagnostics settings
- **THEN** the component SHALL use:
  - `SettingsManager.auto_run_diagnostics` (bool property)
  - `SettingsManager.diagnostics_retention_days` (int property)

#### Scenario: Complex type access via methods
- **GIVEN** a component needs complex variant-type settings
- **WHEN** accessing rotation plans, key mappings, or tunnel configurations
- **THEN** the component SHALL use convenience methods:
  - `SettingsManager.get_rotation_plans()` / `SettingsManager.set_rotation_plans(variant)`
  - `SettingsManager.get_key_service_mappings()` / `SettingsManager.set_key_service_mappings(variant)`
  - `SettingsManager.get_tunnel_configurations()` / `SettingsManager.set_tunnel_configurations(variant)`
- **OR** direct access via `SettingsManager.app.get_value("key-name")`

### Requirement: Settings Convenience Methods
SettingsManager SHALL provide convenience methods for common multi-property operations.

**Rationale**: Grouping related operations reduces boilerplate and ensures atomic updates of related settings.

#### Scenario: Save window state atomically
- **GIVEN** a window is being closed or resized
- **WHEN** saving window state
- **THEN** `SettingsManager.save_window_state(width, height, maximized)` SHALL save all three properties
- **AND** SHALL use a single method call instead of three separate property sets

#### Scenario: Load window state atomically
- **GIVEN** a window is being initialized
- **WHEN** loading window state
- **THEN** `SettingsManager.get_window_state(out width, out height, out maximized)` SHALL retrieve all three properties
- **AND** SHALL use a single method call instead of three separate property gets

#### Scenario: Reset all settings to defaults
- **GIVEN** a user requests settings reset
- **WHEN** calling `SettingsManager.reset_to_defaults()`
- **THEN** all settings in both main and tunneling schemas SHALL be reset to schema defaults
- **AND** SHALL iterate through all keys in both schemas

#### Scenario: Apply pending settings
- **GIVEN** settings have been modified
- **WHEN** calling `SettingsManager.apply_settings()`
- **THEN** `GLib.Settings.sync()` SHALL be called to flush all pending writes
- **AND** settings SHALL be immediately persisted to disk

### Requirement: No Direct Settings Instantiation
Application code outside of SettingsManager SHALL NOT instantiate GLib.Settings objects directly.

**Rationale**: Enforces single responsibility and prevents fragmented settings access patterns.

#### Scenario: Backend services use SettingsManager
- **GIVEN** backend services need settings access (TotpManager, BackupManager, EmergencyVault)
- **WHEN** accessing settings
- **THEN** they SHALL use `SettingsManager` static properties or methods
- **AND** SHALL NOT create `new Settings()` instances

#### Scenario: UI components use SettingsManager
- **GIVEN** UI components need settings access (Window, KeysPage, HostsPage, PreferencesDialog, GenerateDialog, KeyRow)
- **WHEN** accessing settings
- **THEN** they SHALL use `SettingsManager` static properties or methods
- **AND** SHALL NOT create `new Settings()` instances

#### Scenario: Model classes use SettingsManager
- **GIVEN** model classes need settings access (KeyServiceMapping)
- **WHEN** accessing settings
- **THEN** they SHALL use `SettingsManager` static properties or methods
- **AND** SHALL NOT create `new Settings()` instances

#### Scenario: Application class uses SettingsManager
- **GIVEN** the main Application class needs settings access
- **WHEN** accessing settings
- **THEN** it SHALL use `SettingsManager` static properties or methods
- **AND** SHALL NOT create `new Settings()` instances

### Requirement: Lazy Initialization
SettingsManager SHALL use lazy initialization for GLib.Settings instances.

**Rationale**: Avoids unnecessary Settings object creation if certain features aren't used, and defers initialization until Config.APP_ID is available.

#### Scenario: Main settings lazy initialization
- **GIVEN** SettingsManager has not been accessed yet
- **WHEN** `SettingsManager.app` is accessed for the first time
- **THEN** a GLib.Settings instance SHALL be created with `Config.APP_ID`
- **AND** the instance SHALL be cached for subsequent accesses

#### Scenario: Tunneling settings lazy initialization
- **GIVEN** SettingsManager tunneling settings have not been accessed yet
- **WHEN** `SettingsManager.tunneling` is accessed for the first time
- **THEN** a GLib.Settings instance SHALL be created with `Config.APP_ID + ".tunneling"`
- **AND** the instance SHALL be cached for subsequent accesses

#### Scenario: Cached instance reuse
- **GIVEN** SettingsManager.app has been accessed previously
- **WHEN** SettingsManager.app is accessed again
- **THEN** the cached GLib.Settings instance SHALL be returned
- **AND** no new Settings object SHALL be created

### Requirement: Settings Key Constants
SettingsManager SHALL define string constants for all settings keys to prevent typos and enable IDE autocomplete.

**Rationale**: String literals are error-prone; constants provide compile-time safety and better developer experience.

#### Scenario: Main schema key constants
- **GIVEN** code needs to reference settings keys
- **WHEN** using SettingsManager
- **THEN** key constants SHALL be available in `SettingsManager.Keys` class
- **AND** SHALL include constants for all 16 main schema keys

#### Scenario: Tunneling schema key constants
- **GIVEN** code needs to reference tunneling settings keys
- **WHEN** using SettingsManager
- **THEN** key constants SHALL be available in `SettingsManager.TunnelingKeys` class
- **AND** SHALL include constants for all tunneling schema keys

#### Scenario: Direct access with constants
- **GIVEN** a component needs direct Settings access for a specific reason
- **WHEN** calling Settings methods directly
- **THEN** the component SHOULD use `SettingsManager.Keys.WINDOW_WIDTH` instead of `"window-width"`
- **AND** typos SHALL be caught at compile time
