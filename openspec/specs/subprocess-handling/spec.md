# subprocess-handling Specification

## Purpose
TBD - created by archiving change consolidate-subprocess-calls. Update Purpose after archive.
## Requirements
### Requirement: Centralized Subprocess Execution
All subprocess execution in the application SHALL use the `KeyMaker.Command` utility instead of direct `Subprocess` or `SubprocessLauncher` usage, except for explicitly documented exceptions.

**Rationale**: Centralized subprocess handling ensures consistent error handling, timeout management, output capture, and security patterns across the entire codebase.

#### Scenario: Connection diagnostics uses Command utility
- **GIVEN** the connection diagnostics feature needs to run SSH commands
- **WHEN** executing SSH diagnostic tests
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()`
- **AND** SHALL NOT use `new Subprocess.newv()` directly

#### Scenario: Emergency vault QR operations use Command utility
- **GIVEN** the emergency vault needs to run zbar commands for QR codes
- **WHEN** generating or scanning QR codes
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()`
- **AND** SHALL NOT use `new Subprocess.newv()` directly

#### Scenario: SSH key metadata extraction uses Command utility
- **GIVEN** SSH key operations need to extract key metadata
- **WHEN** running ssh-keygen to extract public key or metadata
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()`
- **AND** SHALL NOT use `new Subprocess.newv()` directly

#### Scenario: Only approved files use raw subprocess APIs
- **GIVEN** the codebase is fully migrated to Command utility
- **WHEN** searching for raw subprocess usage with `rg "SubprocessLauncher|Subprocess\.newv" src/`
- **THEN** matches SHALL only appear in:
  - `src/utils/Command.vala` (implements the utility)
  - `src/utils/ConnectionPool.vala` (connection pool management)
  - Documented exceptions in design documentation

### Requirement: Timeout Protection for Finite Operations
All subprocess operations that are expected to complete within a bounded time SHALL use timeout protection to prevent indefinite hangs.

**Rationale**: Network failures, corrupted files, or system issues can cause subprocesses to hang indefinitely, freezing the UI and requiring force-kill.

#### Scenario: Connection diagnostics times out on unreachable host
- **GIVEN** a connection diagnostic test is running against an unreachable SSH host
- **WHEN** 10 seconds have elapsed
- **THEN** the subprocess SHALL be terminated
- **AND** a `KeyMakerError.OPERATION_FAILED` SHALL be thrown
- **AND** the error message SHALL indicate a timeout occurred

#### Scenario: QR code operations timeout on long processing
- **GIVEN** a QR code generation or scanning operation is running
- **WHEN** 15 seconds have elapsed without completion
- **THEN** the subprocess SHALL be terminated
- **AND** a `KeyMakerError.OPERATION_FAILED` SHALL be thrown
- **AND** the error message SHALL indicate a timeout occurred

#### Scenario: ssh-keygen times out on corrupted key
- **GIVEN** ssh-keygen is extracting metadata from a potentially corrupted key
- **WHEN** 5 seconds have elapsed without completion
- **THEN** the subprocess SHALL be terminated
- **AND** a `KeyMakerError.OPERATION_FAILED` SHALL be thrown
- **AND** the error message SHALL indicate a timeout or key processing failure

### Requirement: Consistent Error Handling Pattern
All subprocess operations SHALL use the `KeyMakerError` exception types for error reporting, providing consistent error handling across the application.

**Rationale**: Consistent error types allow UI code to implement uniform error handling, improve user experience, and simplify error recovery logic.

#### Scenario: Subprocess failure throws KeyMakerError.OPERATION_FAILED
- **GIVEN** a subprocess command fails with non-zero exit status
- **WHEN** the Command utility processes the result
- **THEN** it SHALL throw `KeyMakerError.OPERATION_FAILED`
- **AND** the error message SHALL include stderr output from the command
- **AND** the exit status SHALL be available for diagnostic purposes

#### Scenario: User cancellation throws KeyMakerError.OPERATION_CANCELLED
- **GIVEN** a subprocess operation is running with a cancellable token
- **WHEN** the user cancels the operation
- **THEN** the subprocess SHALL be terminated
- **AND** a `KeyMakerError.OPERATION_CANCELLED` SHALL be thrown
- **AND** cleanup SHALL be performed gracefully

#### Scenario: Subprocess timeout throws KeyMakerError.OPERATION_FAILED
- **GIVEN** a subprocess operation with timeout protection
- **WHEN** the timeout duration expires before completion
- **THEN** the subprocess SHALL be force-terminated
- **AND** a `KeyMakerError.OPERATION_FAILED` SHALL be thrown
- **AND** the error message SHALL indicate timeout as the cause

### Requirement: Standardized Output Capture
All subprocess operations SHALL return output using the `KeyMaker.Command.Result` structure, providing consistent access to exit status, stdout, and stderr.

**Rationale**: Standardized result structures eliminate duplicate output parsing code and ensure consistent handling of command results.

#### Scenario: Command result provides exit status
- **GIVEN** a subprocess command has been executed via Command utility
- **WHEN** the command completes
- **THEN** the result SHALL contain the exit status as an integer
- **AND** the exit status SHALL match the subprocess's actual exit code

#### Scenario: Command result provides stdout content
- **GIVEN** a subprocess command writes to stdout
- **WHEN** the command completes
- **THEN** the result SHALL contain all stdout content as a string
- **AND** line endings SHALL be preserved
- **AND** the content SHALL be complete (no truncation)

#### Scenario: Command result provides stderr content
- **GIVEN** a subprocess command writes to stderr
- **WHEN** the command completes (successfully or with error)
- **THEN** the result SHALL contain all stderr content as a string
- **AND** the content SHALL be available even if exit status is 0
- **AND** the content SHALL be complete (no truncation)

### Requirement: Documented Exceptions for Special Cases
Long-running background processes or operations requiring specialized subprocess handling SHALL be documented as approved exceptions to the centralized Command utility requirement.

**Rationale**: Some use cases (e.g., SSH tunnels that run indefinitely) may not fit the standard Command utility pattern and require direct subprocess management.

#### Scenario: SSH tunnel process is documented exception
- **GIVEN** the SSH tunneling feature creates long-running background processes
- **WHEN** reviewing subprocess usage in `ActiveTunnel.vala`
- **THEN** direct `Subprocess` usage SHALL be documented in design.md as an approved exception
- **AND** the rationale SHALL explain why Command utility is not suitable
- **AND** future enhancements (e.g., `Command.run_background()`) SHALL be noted

#### Scenario: stdin-interactive processes are documented exceptions
- **GIVEN** a subprocess operation requires interactive stdin communication
- **WHEN** Command utility does not support stdin interaction
- **THEN** direct `Subprocess` usage SHALL be documented in design.md as an approved exception
- **AND** the limitation SHALL be noted for future Command utility enhancements
- **AND** the operation SHALL still follow best practices for error handling

### Requirement: ConnectionDiagnostics Subprocess Execution
Connection diagnostic tests SHALL use the centralized `KeyMaker.Command` utility with appropriate timeout protection instead of direct subprocess management.

**Rationale**: Diagnostic tests can hang on network failures; centralized handling ensures consistent timeout behavior.

#### Scenario: Port forwarding test uses Command utility
- **GIVEN** connection diagnostics is testing SSH port forwarding capability
- **WHEN** executing the SSH port forwarding test command
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()` with 10-second timeout
- **AND** SHALL NOT use `new Subprocess.newv()` directly at line 799

#### Scenario: Permission test uses Command utility
- **GIVEN** connection diagnostics is testing SSH server permissions
- **WHEN** executing the SSH permission test command
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()` with 10-second timeout
- **AND** SHALL NOT use `new Subprocess.newv()` directly at line 851

### Requirement: EmergencyVault QR Operations
QR code generation and scanning operations SHALL use the centralized `KeyMaker.Command` utility with appropriate timeout protection instead of direct subprocess management.

**Rationale**: zbar operations can hang on complex QR codes or missing dependencies; centralized handling ensures consistent timeout and error reporting.

#### Scenario: QR code generation uses Command utility
- **GIVEN** emergency vault is generating a QR code backup
- **WHEN** executing the zbar command to generate QR codes
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()` with 15-second timeout
- **AND** SHALL NOT use `new Subprocess.newv()` directly at line 735
- **AND** SHALL provide clear error message if zbar is not installed

#### Scenario: QR code scanning uses Command utility
- **GIVEN** emergency vault is scanning a QR code for restoration
- **WHEN** executing the zbar command to scan QR codes
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()` with 15-second timeout
- **AND** SHALL NOT use `new Subprocess.newv()` directly at line 756
- **AND** SHALL provide clear error message if zbar is not installed or scan fails

### Requirement: SSH Metadata Extraction
SSH key metadata extraction operations SHALL use the centralized `KeyMaker.Command` utility with appropriate timeout protection instead of direct subprocess management.

**Rationale**: ssh-keygen operations on corrupted or invalid keys can hang; centralized handling ensures consistent timeout behavior.

#### Scenario: Public key extraction uses Command utility
- **GIVEN** SSH operations needs to extract public key from private key
- **WHEN** executing ssh-keygen to extract public key
- **THEN** it SHALL use `KeyMaker.Command.run_capture_with_timeout()` with 5-second timeout
- **AND** SHALL NOT use `new Subprocess.newv()` directly at line 247
- **AND** SHALL handle stdin interaction if required by ssh-keygen

**Note**: If stdin interaction is required and Command utility doesn't support it yet, this SHALL be documented as an exception pending Command utility enhancement.

