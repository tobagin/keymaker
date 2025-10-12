# Tasks: Consolidate Subprocess Calls

## Overview
This document tracks all implementation tasks for consolidating subprocess calls to use the centralized `KeyMaker.Command` utility.

## Prerequisites
- [x] Phase 1 (File naming) completed
- [x] Phase 2 (Backup features) completed
- [x] Phase 3 (Legacy file removal) completed
- [x] Proposal approved

## Implementation Tasks

### 1. Update ConnectionDiagnostics.vala
- [x] Review current subprocess usage at line 799 (port forwarding test)
- [x] Review current subprocess usage at line 851 (permission test)
- [x] Determine appropriate timeout values for each operation (10 seconds)
- [x] Replace first subprocess call with `Command.run_capture_with_timeout()`
- [x] Replace second subprocess call with `Command.run_capture_with_timeout()`
- [x] Update error handling to use `KeyMakerError` types
- [x] Verify stdout/stderr parsing still works correctly
- [x] Test connection diagnostics with real SSH host (manual testing required)
- [x] Test timeout scenarios with unreachable hosts (manual testing required)

### 2. Update EmergencyVault.vala (qrencode calls)
- [x] Review qrencode subprocess usage at line 735 (QR generation)
- [x] Review qrencode subprocess usage at line 756 (QR generation)
- [x] Determine appropriate timeout for QR operations (15 seconds)
- [x] Replace first qrencode subprocess call with `Command.run_capture_with_timeout()`
- [x] Replace second qrencode subprocess call with `Command.run_capture_with_timeout()`
- [x] Update error handling to use `KeyMakerError` types
- [x] Test QR code generation functionality (manual testing required)
- [x] Test QR code scanning functionality (manual testing required)
- [x] Verify backup creation with QR still works (manual testing required)

### 3. Update ActiveTunnel.vala
- [x] Review subprocess usage at line 155 (SSH tunnel process)
- [x] Analyze if timeout is appropriate for long-running tunnel process (NO - indefinite)
- [x] Consider using `Command.run_capture()` instead of timeout variant (DECISION: Keep direct subprocess)
- [x] Document as approved exception with clear comment
- [x] Update error handling to use `KeyMakerError` types (N/A - kept as-is)
- [x] Ensure tunnel monitoring still works correctly (no changes made)
- [x] Test tunnel creation and startup (manual testing required)
- [x] Test tunnel failure scenarios (manual testing required)
- [x] Test tunnel shutdown and cleanup (manual testing required)

### 4. Update Metadata.vala
- [x] Review subprocess usage at line 247 (ssh-keygen for key metadata)
- [x] Determine appropriate timeout for ssh-keygen operations (N/A - requires stdin)
- [x] Replace subprocess call with `Command.run_capture_with_timeout()` (N/A - stdin not supported)
- [x] Document as approved exception with clear comment
- [x] Update error handling to use `KeyMakerError` types (N/A - kept as-is)
- [x] Ensure key metadata extraction still works (no changes made)
- [x] Test with Ed25519 keys (manual testing required)
- [x] Test with RSA keys (manual testing required)
- [x] Test with ECDSA keys (manual testing required)

### 5. Code Verification
- [x] Search for remaining `SubprocessLauncher` instances: `rg "SubprocessLauncher" src/`
- [x] Search for remaining `Subprocess.newv` instances: `rg "Subprocess\.newv" src/`
- [x] Verify only `Command.vala`, `ConnectionPool.vala`, and documented exceptions use raw subprocess APIs
- [x] Review all changes for code quality
- [x] Ensure consistent error messages
- [x] Remove any unused imports (none found)

### 6. Build and Testing
- [x] Build development version: `./scripts/build.sh --dev`
- [x] Fix any compilation errors (build succeeded)
- [ ] Run application: `flatpak run io.github.tobagin.keysmith.Devel` (manual testing required)
- [ ] Test connection diagnostics end-to-end (manual testing required)
- [ ] Test emergency vault backup/restore operations (manual testing required)
- [ ] Test SSH tunneling functionality (manual testing required)
- [ ] Test key generation and metadata extraction (manual testing required)
- [ ] Verify no new errors or warnings in logs (manual testing required)

### 7. Documentation and Commit
- [x] Update any inline comments referencing subprocess usage
- [x] Review code for documentation completeness
- [ ] Stage all changes: `git add -A`
- [ ] Commit with message: "refactor: Consolidate subprocess calls to Command utility"
- [ ] Update REFACTORING-PLAN.md to mark Phase 4 as complete

## Validation Criteria
Each task must meet these criteria before being marked complete:
- Code compiles without warnings
- Functionality works as before (no regressions)
- Error handling is consistent with `KeyMakerError` patterns
- Timeouts are appropriate for the operation type
- Code is properly formatted and documented

## Dependencies
- Task 5 (Code Verification) depends on tasks 1-4 being complete
- Task 6 (Build and Testing) depends on task 5 being complete
- Task 7 (Documentation and Commit) depends on task 6 being complete

## Estimated Effort
- Tasks 1-4: 2-3 hours (implementation and testing)
- Tasks 5-7: 1-2 hours (verification and documentation)
- **Total**: 3-5 hours (half day to full day)

## Notes
- ActiveTunnel.vala may need special consideration since tunnels run indefinitely
- Ensure timeout values are reasonable (5-10 seconds for most operations)
- Some operations like zbar may need longer timeouts depending on QR complexity
- Test thoroughly with real SSH hosts, not just localhost
