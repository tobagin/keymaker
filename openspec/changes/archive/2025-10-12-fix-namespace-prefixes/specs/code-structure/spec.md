# code-structure Specification Delta

## Target Spec
- **Spec ID**: `code-structure`
- **Target File**: `/openspec/specs/code-structure/spec.md`

## ADDED Requirements

### Requirement: Namespace Prefix Convention
All classes in the KeyMaker codebase SHALL use the `KeyMaker.` namespace prefix in their class declarations.

**Rationale**: Explicit namespace prefixes prevent naming conflicts with other libraries, improve code clarity, enable better IDE support, and establish clear ownership of classes.

#### Scenario: Dialog class with namespace prefix
- **GIVEN** a dialog class named `GenerateDialog`
- **WHEN** declaring the class in Vala
- **THEN** the class declaration SHALL be `public class KeyMaker.GenerateDialog : Adw.Dialog {`
- **AND** shall NOT be `public class GenerateDialog : Adw.Dialog {`

#### Scenario: Backend service class with namespace prefix
- **GIVEN** a backend service class named `KeyScanner`
- **WHEN** declaring the class in Vala
- **THEN** the class declaration SHALL be `public class KeyMaker.KeyScanner {`
- **AND** shall NOT be `public class KeyScanner {`

#### Scenario: Model class with namespace prefix
- **GIVEN** a model class named `SshKey`
- **WHEN** declaring the class in Vala
- **THEN** the class declaration SHALL be `public class KeyMaker.SshKey : Object {`
- **AND** shall NOT be `public class SshKey : Object {`

#### Scenario: Utility class with namespace prefix
- **GIVEN** a utility class named `Command`
- **WHEN** declaring the class in Vala
- **THEN** the class declaration SHALL be `public class KeyMaker.Command {`
- **AND** shall NOT be `public class Command {`

#### Scenario: Helper class with namespace prefix
- **GIVEN** a helper class named `RestoreParams` used internally by a dialog
- **WHEN** declaring the class in Vala
- **THEN** the class declaration SHALL be `public class KeyMaker.RestoreParams {`
- **AND** shall NOT be `public class RestoreParams {`
- **AND** SHALL follow the same namespace convention regardless of class size or usage scope

#### Scenario: All dialog classes use namespace prefix
- **GIVEN** all dialog classes in `src/ui/dialogs/`
- **WHEN** auditing namespace prefixes
- **THEN** 100% of dialog classes SHALL use `KeyMaker.` prefix
- **AND** no dialog classes SHALL exist without the prefix

#### Scenario: Namespace prefix consistency check
- **GIVEN** a new class is being added to the codebase
- **WHEN** reviewing the class declaration
- **THEN** the class SHALL include the `KeyMaker.` namespace prefix
- **AND** SHALL follow the pattern `public class KeyMaker.ClassName`
- **AND** the file SHALL be named `ClassName.vala` (without the namespace prefix)

#### Scenario: ConnectionDiagnosticsDialog namespace
- **GIVEN** the `ConnectionDiagnosticsDialog` class in `src/ui/dialogs/ConnectionDiagnosticsDialog.vala`
- **WHEN** declaring the class
- **THEN** the class declaration SHALL be `public class KeyMaker.ConnectionDiagnosticsDialog : Adw.Dialog {`

#### Scenario: ConnectionDiagnosticsRunnerDialog namespace
- **GIVEN** the `ConnectionDiagnosticsRunnerDialog` class in `src/ui/dialogs/ConnectionDiagnosticsRunnerDialog.vala`
- **WHEN** declaring the class
- **THEN** the class declaration SHALL be `public class KeyMaker.ConnectionDiagnosticsRunnerDialog : Adw.Dialog {`

#### Scenario: DiagnosticResultsViewDialog namespace
- **GIVEN** the `DiagnosticResultsViewDialog` class in `src/ui/dialogs/DiagnosticResultsViewDialog.vala`
- **WHEN** declaring the class
- **THEN** the class declaration SHALL be `public class KeyMaker.DiagnosticResultsViewDialog : Adw.Dialog {`

#### Scenario: RestoreParams namespace
- **GIVEN** the `RestoreParams` helper class in `src/ui/dialogs/RestoreBackupDialog.vala`
- **WHEN** declaring the class
- **THEN** the class declaration SHALL be `public class KeyMaker.RestoreParams {`

### Requirement: Namespace and File Name Separation
File names SHALL NOT include the namespace prefix, only the class name.

**Rationale**: Namespace prefixes are language-level identifiers, while file names are filesystem identifiers. Keeping them separate maintains clarity and follows Vala conventions.

#### Scenario: File name without namespace
- **GIVEN** a class declared as `public class KeyMaker.GenerateDialog`
- **WHEN** naming the file
- **THEN** the file SHALL be named `GenerateDialog.vala`
- **AND** shall NOT be named `KeyMaker.GenerateDialog.vala` or `KeyMakerGenerateDialog.vala`

#### Scenario: Directory paths without namespace
- **GIVEN** a class declared as `public class KeyMaker.ConnectionDiagnosticsDialog`
- **WHEN** determining the file path
- **THEN** the path SHALL be `src/ui/dialogs/ConnectionDiagnosticsDialog.vala`
- **AND** shall NOT include `keymaker` in the path

## Why These Changes

These requirements codify the namespace convention that has been established throughout the KeyMaker codebase:
- 28 out of 32 dialog classes already use the prefix (87.5%)
- All backend, model, and utility classes use the prefix (100%)
- The 4 classes without prefixes are outliers that need to be corrected

By adding these requirements to the `code-structure` specification, we:
1. Document the established convention for future contributors
2. Provide clear guidance on namespace usage
3. Establish testable scenarios for compliance
4. Prevent future inconsistencies from being introduced

## Impact

This delta affects:
- **4 class definitions** that currently don't follow the convention
- **Future development** by establishing clear standards
- **Code reviews** by providing specification references
- **Documentation** by codifying implicit knowledge

## References
- Phase 5 of REFACTORING-PLAN.md (lines 570-622)
- Vala namespace documentation
- Existing KeyMaker codebase patterns
