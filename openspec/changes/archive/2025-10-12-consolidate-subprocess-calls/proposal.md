# Consolidate Subprocess Calls

## Overview
Standardize all subprocess execution across the codebase to use the centralized `KeyMaker.Command` utility instead of direct `Subprocess` or `SubprocessLauncher` usage.

## Problem Statement
Currently, multiple files across the codebase use raw `Subprocess` and `SubprocessLauncher` directly, leading to:
- **Inconsistent error handling**: Different files handle subprocess errors differently
- **Duplicate code**: Output capture and error handling logic is repeated
- **Missing timeouts**: Not all subprocess calls have timeout protection
- **Security concerns**: Inconsistent patterns increase the risk of subtle bugs
- **Maintenance burden**: Changes to subprocess behavior require updates in multiple places

### Current State
Files using raw subprocess calls:
1. `src/backend/diagnostics/ConnectionDiagnostics.vala` - 2 instances (lines 799, 851)
2. `src/backend/vault/EmergencyVault.vala` - 2 instances for zbar (lines 735, 756)
3. `src/backend/tunneling/ActiveTunnel.vala` - 1 instance (line 155)
4. `src/backend/ssh_operations/Metadata.vala` - 1 instance (line 247)

The `KeyMaker.Command` utility already exists and provides:
- Consistent error handling with `KeyMakerError.OPERATION_FAILED` and `KeyMakerError.OPERATION_CANCELLED`
- Timeout support via `run_capture_with_timeout()`
- Standardized output capture (stdout/stderr)
- Cancellation support
- Debug logging

## Why
This refactoring is part of Phase 4 of the comprehensive KeyMaker refactoring plan. It addresses:
- **Security**: Centralized subprocess handling reduces the attack surface
- **Maintainability**: Single source of truth for subprocess behavior
- **Reliability**: Consistent timeout and error handling prevents hangs
- **Code quality**: Eliminates duplicate code and improves consistency

## What Changes
- **ConnectionDiagnostics.vala**: Replace 2 direct subprocess calls with `Command.run_capture_with_timeout()` (10s timeout)
- **EmergencyVault.vala**: Replace 2 qrencode subprocess calls with `Command.run_capture_with_timeout()` (15s timeout)
- **ActiveTunnel.vala**: Document direct subprocess usage as approved exception (long-running process)
- **Metadata.vala**: Document direct subprocess usage as approved exception (requires stdin)
- **Error Handling**: Standardize to use `KeyMakerError.OPERATION_FAILED` and `KeyMakerError.OPERATION_CANCELLED`
- **New Spec**: Create `subprocess-handling` specification documenting the requirements

## Motivation
The current fragmented approach to subprocess execution creates several problems:
1. **Inconsistency**: Each file handles subprocess errors differently, leading to unpredictable behavior
2. **Code Duplication**: Output capture and error handling logic is repeated across 4 files (~150 LOC)
3. **Missing Protection**: Not all subprocess calls have timeout protection, leading to potential UI hangs
4. **Security Risk**: Multiple implementations increase the attack surface and risk of subtle bugs
5. **Maintenance Overhead**: Bug fixes or improvements must be applied in multiple places

By consolidating to a single `Command` utility, we gain:
- Single point of maintenance for subprocess behavior
- Consistent timeout protection across all operations
- Uniform error handling and reporting
- Reduced code size and complexity
- Easier testing and debugging

## Proposed Solution
Replace all direct subprocess usage with appropriate `KeyMaker.Command` methods:
- `Command.run_capture()` - For simple command execution
- `Command.run_capture_with_timeout()` - For commands that need timeout protection

### Migration Pattern
```vala
// OLD:
var subprocess = new Subprocess.newv(cmd, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
yield subprocess.wait_async(cancellable);
int status = subprocess.get_exit_status();
// ... manual stdout/stderr reading

// NEW:
var result = yield KeyMaker.Command.run_capture_with_timeout(
    cmd,
    5000,  // 5 second timeout
    cancellable
);

if (result.status == 0) {
    // Success - parse result.stdout
} else {
    // Error - show result.stderr
}
```

## Impact Analysis
### Files Modified: 4
1. **ConnectionDiagnostics.vala** - High impact, 2 subprocess calls
2. **EmergencyVault.vala** - Medium impact, 2 zbar subprocess calls
3. **ActiveTunnel.vala** - High impact, 1 critical subprocess call for SSH tunneling
4. **Metadata.vala** - Medium impact, 1 subprocess call for SSH key operations

### Benefits
- **Reduced LOC**: ~150 lines of duplicate subprocess handling code removed
- **Improved reliability**: All subprocess calls get timeout protection
- **Better error handling**: Consistent KeyMakerError exceptions
- **Enhanced security**: Single code path reduces vulnerability surface
- **Easier testing**: Mock Command utility once instead of testing multiple implementations

### Risks
- **Behavior changes**: Existing code may rely on specific subprocess behavior
- **Timeout issues**: New timeouts may be too short/long for some operations
- **Error handling changes**: Different error types may affect UI behavior

### Mitigation
- Carefully review each subprocess call's requirements
- Choose appropriate timeouts based on operation type
- Test all affected functionality thoroughly
- Maintain backward-compatible error handling where possible

## Testing Strategy
### Manual Testing Required
1. **Connection Diagnostics**:
   - Run full diagnostic suite against real SSH host
   - Test timeout scenarios (unreachable host)
   - Verify error messages are clear and actionable

2. **Emergency Vault**:
   - Test QR code generation with zbar
   - Test QR code scanning with zbar
   - Verify backup creation and restoration work

3. **SSH Tunneling**:
   - Create and start tunnels
   - Test tunnel failure scenarios
   - Verify tunnel monitoring and error reporting

4. **SSH Metadata**:
   - Generate keys and verify metadata extraction
   - Test with various key types (RSA, Ed25519, ECDSA)
   - Ensure key operations still work correctly

### Integration Points
- All functionality should continue to work exactly as before
- Error messages should remain user-friendly
- No new crashes or hangs should be introduced

## Success Criteria
- [ ] All direct `Subprocess` and `SubprocessLauncher` usage removed (except in `Command.vala` itself)
- [ ] All affected functionality tested and working
- [ ] Build succeeds without warnings
- [ ] No regressions in user-facing features
- [ ] Code passes review

## Related Changes
- Part of Phase 4 of the KeyMaker Refactoring Plan (REFACTORING-PLAN.md)
- Related to `code-structure` spec
- Follows after Phase 1 (file naming), Phase 2 (backup features), and Phase 3 (legacy file removal)

## References
- [REFACTORING-PLAN.md](/home/tobagin/Projects/keymaker/REFACTORING-PLAN.md) - Lines 520-567
- [src/utils/Command.vala](/home/tobagin/Projects/keymaker/src/utils/Command.vala) - Utility implementation
