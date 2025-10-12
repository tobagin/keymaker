# code-structure Specification Delta

## ADDED Requirements

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

## Notes

**Scope of Change:**
- This change removes 2 files totaling 2,920 lines of dead code
- No functional changes to the application
- No API changes or migrations required
- Zero risk of breaking existing functionality (files not used anywhere)

**Historical Context:**
- These files were renamed from kebab-case to PascalCase during Phase 1 refactoring
- They remained after the newer implementations (EmergencyVault, KeyRotationDialog) superseded them
- They are referenced in documentation as examples of legacy code to be removed

**Verification:**
- Files confirmed not in meson.build
- Grep search confirms no imports in codebase
- Only references are in REFACTORING-PLAN.md documenting their obsolescence
