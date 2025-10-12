# code-structure Specification

## Purpose
TBD - created by archiving change refactor-phase1-naming. Update Purpose after archive.
## Requirements
### Requirement: Vala File Naming Convention
All Vala source files SHALL use `PascalCase.vala` naming convention, matching the class name defined within the file.

#### Scenario: Model class file naming
- **GIVEN** a model class named `SshKey`
- **WHEN** the file is created or renamed
- **THEN** the filename SHALL be `SshKey.vala`

#### Scenario: Backend service file naming
- **GIVEN** a backend service class named `KeyScanner`
- **WHEN** the file is created or renamed
- **THEN** the filename SHALL be `KeyScanner.vala`

#### Scenario: UI dialog file naming
- **GIVEN** a dialog class named `GenerateDialog`
- **WHEN** the file is created or renamed
- **THEN** the filename SHALL be `GenerateDialog.vala`

#### Scenario: Utility class file naming
- **GIVEN** a utility class named `Command`
- **WHEN** the file is created or renamed
- **THEN** the filename SHALL be `Command.vala`

### Requirement: Blueprint File Naming Convention
All Blueprint UI definition files SHALL use `snake_case.blp` naming convention.

#### Scenario: Blueprint file naming consistency
- **GIVEN** a dialog blueprint for "Add Key To Agent Dialog"
- **WHEN** the blueprint file is created
- **THEN** the filename SHALL be `add_key_to_agent_dialog.blp`

#### Scenario: Existing blueprint files unchanged
- **GIVEN** existing blueprint files using `snake_case.blp`
- **WHEN** Vala files are renamed
- **THEN** blueprint files SHALL remain unchanged

### Requirement: Directory Structure Organization
Main organizational Vala files SHALL be located in their respective subdirectories, not in parent directories.

#### Scenario: SSH operations main file location
- **GIVEN** the main SSH operations coordinator class
- **WHEN** organizing backend files
- **THEN** the file SHALL be located at `src/backend/ssh_operations/SshOperations.vala`
- **AND** shall NOT be at `src/backend/ssh-operations.vala`

#### Scenario: Key rotation main file location
- **GIVEN** the main key rotation coordinator class
- **WHEN** organizing backend files
- **THEN** the file SHALL be located at `src/backend/rotation/KeyRotation.vala`
- **AND** shall NOT be at `src/backend/key-rotation.vala`

#### Scenario: Tunneling main file location
- **GIVEN** the main SSH tunneling coordinator class
- **WHEN** organizing backend files
- **THEN** the file SHALL be located at `src/backend/tunneling/SshTunneling.vala`
- **AND** shall NOT be at `src/backend/ssh-tunneling.vala`

#### Scenario: Emergency vault main file location
- **GIVEN** the main emergency vault coordinator class
- **WHEN** organizing backend files
- **THEN** the file SHALL be located at `src/backend/vault/EmergencyVault.vala`
- **AND** shall NOT be at `src/backend/emergency-vault.vala`

#### Scenario: Connection diagnostics main file location
- **GIVEN** the main connection diagnostics coordinator class
- **WHEN** organizing backend files
- **THEN** the file SHALL be located at `src/backend/diagnostics/ConnectionDiagnostics.vala`
- **AND** shall NOT be at `src/backend/connection-diagnostics.vala`

### Requirement: Folder Naming Convention
All directory names SHALL use `snake_case` naming convention.

#### Scenario: Backend subdirectory naming
- **GIVEN** backend subdirectories
- **WHEN** organizing code structure
- **THEN** directories SHALL be named:
  - `ssh_operations/` (not `sshOperations/` or `ssh-operations/`)
  - `rotation/`
  - `tunneling/`
  - `vault/`
  - `diagnostics/`

#### Scenario: UI subdirectory naming
- **GIVEN** UI subdirectories
- **WHEN** organizing code structure
- **THEN** directories SHALL be named:
  - `ui/dialogs/`
  - `ui/pages/`
  - `ui/widgets/`

### Requirement: Git History Preservation
When renaming files, git history SHALL be preserved using proper git commands.

#### Scenario: File rename preserves history
- **GIVEN** a file to be renamed
- **WHEN** executing the rename operation
- **THEN** `git mv` SHALL be used (not `mv` + `git add`)
- **AND** git log with `--follow` SHALL show complete file history

#### Scenario: Batch renames preserve history
- **GIVEN** multiple files to rename in a script
- **WHEN** executing automated renames
- **THEN** each rename SHALL use `git mv` command
- **AND** all renames SHALL be committed together with descriptive message

### Requirement: Naming Convention Documentation
The codebase SHALL document naming conventions for contributors.

#### Scenario: Contributor can find naming rules
- **GIVEN** a new contributor to the project
- **WHEN** looking for file naming conventions
- **THEN** documentation SHALL specify:
  - Vala files use `PascalCase.vala`
  - Blueprint files use `snake_case.blp`
  - Directories use `snake_case`
  - Class names match file names for Vala files

### Requirement: Legacy File Removal
The codebase SHALL NOT contain obsolete files that are superseded by newer implementations and not referenced in the build system or active code.

**Rationale**: Dead code increases maintenance burden, confuses contributors, clutters navigation, and creates technical debt.

#### Scenario: EmergencyVaultOld.vala Removed
- **GIVEN** the file `src/backend/EmergencyVaultOld.vala` exists in the repository
- **AND** it is not referenced in `src/meson.build`
- **AND** it is not imported by any active source files
- **WHEN** the legacy cleanup is complete
- **THEN** the file SHALL be deleted from the repository
- **AND** the build SHALL succeed without errors
- **AND** no broken import references SHALL exist

#### Scenario: KeyRotationDialogOld.vala Removed
- **GIVEN** the file `src/ui/dialogs/KeyRotationDialogOld.vala` exists in the repository
- **AND** it is not referenced in `src/meson.build`
- **AND** it is not imported by any active source files
- **WHEN** the legacy cleanup is complete
- **THEN** the file SHALL be deleted from the repository
- **AND** the build SHALL succeed without errors
- **AND** no broken import references SHALL exist

### Requirement: Build System Integrity
Files present in the source tree SHALL be either included in the build system or explicitly documented as excluded/archived.

**Rationale**: Files not in the build system but present in the repository create confusion about whether they are intended to be part of the project.

#### Scenario: Build System References
- **GIVEN** files are being removed from the repository
- **WHEN** checking the build system configuration
- **THEN** the removed files SHALL NOT be listed in any meson.build files
- **AND** no build errors related to missing files SHALL occur

### Requirement: Clean Source Tree
The source directories SHALL contain only active, maintained code that serves a current purpose in the application.

**Rationale**: A clean source tree improves developer experience, IDE performance, and reduces cognitive overhead when navigating the codebase.

#### Scenario: Source Tree Clarity
- **GIVEN** developers navigating the codebase
- **WHEN** browsing the `src/backend/` directory
- **THEN** they SHALL NOT see obsolete EmergencyVaultOld.vala file
- **AND** the current EmergencyVault.vala implementation SHALL be clearly identifiable

#### Scenario: Dialog Directory Clarity
- **GIVEN** developers navigating the codebase
- **WHEN** browsing the `src/ui/dialogs/` directory
- **THEN** they SHALL NOT see obsolete KeyRotationDialogOld.vala file
- **AND** the current KeyRotationDialog.vala implementation SHALL be clearly identifiable

#### Scenario: Repository Size Reduction
- **GIVEN** the legacy files total approximately 2,920 lines of code
- **WHEN** the files are removed
- **THEN** the repository SHALL be reduced by this amount
- **AND** IDE indexing overhead SHALL be decreased

