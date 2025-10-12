# Build System Specification

## ADDED Requirements

### Requirement: Meson Build File Updates
All meson.build files SHALL reference source files using their correct `PascalCase.vala` names.

#### Scenario: Root meson.build references updated
- **GIVEN** the main `src/meson.build` file
- **WHEN** Vala files are renamed
- **THEN** all source file references SHALL use new `PascalCase.vala` names
- **AND** build SHALL succeed without errors

#### Scenario: Subdirectory meson.build references updated
- **GIVEN** subdirectory meson.build files (models, backend, ui, utils)
- **WHEN** Vala files in subdirectories are renamed
- **THEN** all source file references SHALL use new `PascalCase.vala` names
- **AND** no kebab-case references SHALL remain

#### Scenario: Development build succeeds
- **GIVEN** all files renamed and meson.build updated
- **WHEN** running `./scripts/build.sh --dev`
- **THEN** build SHALL complete successfully
- **AND** no compilation warnings SHALL be emitted
- **AND** flatpak package SHALL be created

#### Scenario: Production build succeeds
- **GIVEN** all files renamed and meson.build updated
- **WHEN** running `./scripts/build.sh`
- **THEN** build SHALL complete successfully
- **AND** no compilation warnings SHALL be emitted
- **AND** production flatpak package SHALL be created

### Requirement: Build System Validation
The build system SHALL validate that all referenced source files exist.

#### Scenario: Missing file detection
- **GIVEN** a meson.build file with incorrect filename reference
- **WHEN** running meson build
- **THEN** meson SHALL report error about missing file
- **AND** SHALL specify which file cannot be found

#### Scenario: Comprehensive file list
- **GIVEN** all source files in the project
- **WHEN** examining meson.build files
- **THEN** every `.vala` file SHALL be referenced in appropriate meson.build
- **AND** no orphaned source files SHALL exist

### Requirement: Build Script Compatibility
Build scripts SHALL work correctly with renamed files.

#### Scenario: Development build script execution
- **GIVEN** the `scripts/build.sh --dev` command
- **WHEN** executed after file renames
- **THEN** script SHALL complete without errors
- **AND** SHALL produce installable development flatpak
- **AND** flatpak SHALL launch with `flatpak run io.github.tobagin.keysmith.Devel`

#### Scenario: Production build script execution
- **GIVEN** the `scripts/build.sh` command
- **WHEN** executed after file renames
- **THEN** script SHALL complete without errors
- **AND** SHALL produce installable production flatpak

### Requirement: Clean Build Verification
After file renames, a clean build from scratch SHALL succeed.

#### Scenario: Fresh build directory
- **GIVEN** build artifacts removed (`rm -rf _build/ _inst/`)
- **WHEN** running build command
- **THEN** meson SHALL configure successfully
- **AND** compilation SHALL complete without errors
- **AND** all dependencies SHALL be resolved

#### Scenario: No stale references
- **GIVEN** a fresh build after renames
- **WHEN** examining build output
- **THEN** no references to old kebab-case filenames SHALL appear
- **AND** no "file not found" errors SHALL occur

### Requirement: Build Performance Maintained
File renames SHALL not negatively impact build performance.

#### Scenario: Build time unchanged
- **GIVEN** build times measured before renames
- **WHEN** measuring build times after renames
- **THEN** build time SHALL not increase significantly (within 5%)
- **AND** incremental builds SHALL still work correctly

#### Scenario: Dependency tracking preserved
- **GIVEN** incremental build capability
- **WHEN** modifying a single renamed file
- **THEN** only affected files SHALL be recompiled
- **AND** full rebuild SHALL not be required
