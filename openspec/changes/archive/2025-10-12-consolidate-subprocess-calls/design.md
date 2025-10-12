# Design: Consolidate Subprocess Calls

## Architecture

### Current State
The codebase has fragmented subprocess handling:
```
┌─────────────────────────────────────────────────────┐
│          Direct Subprocess Usage (4 files)          │
├─────────────────────────────────────────────────────┤
│ • ConnectionDiagnostics.vala (2 calls)              │
│ • EmergencyVault.vala (2 calls)                     │
│ • ActiveTunnel.vala (1 call)                        │
│ • Metadata.vala (1 call)                            │
└─────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    Different           Inconsistent         Manual I/O
    Error Handling      Timeout Behavior     Management
```

### Target State
Centralized subprocess handling through `Command` utility:
```
┌─────────────────────────────────────────────────────┐
│              All Application Code                   │
├─────────────────────────────────────────────────────┤
│ • ConnectionDiagnostics.vala                        │
│ • EmergencyVault.vala                               │
│ • ActiveTunnel.vala                                 │
│ • Metadata.vala                                     │
│ • ... (all other files)                             │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
         ┌──────────────────────────────────┐
         │   KeyMaker.Command (Utility)     │
         ├──────────────────────────────────┤
         │ • run_capture()                  │
         │ • run_capture_with_timeout()     │
         │ • Consistent error handling      │
         │ • Standardized I/O capture       │
         │ • Cancellation support           │
         └──────────────────────────────────┘
                           │
                           ▼
         ┌──────────────────────────────────┐
         │   GLib.Subprocess (System API)   │
         └──────────────────────────────────┘
```

## Design Decisions

### 1. Timeout Strategy

**Decision**: Use `run_capture_with_timeout()` for all finite operations, keep `run_capture()` for long-running processes.

**Rationale**:
- SSH diagnostics should timeout (prevent hangs on network issues)
- zbar operations should timeout (prevent UI freezes)
- ssh-keygen operations should timeout (prevent hangs on corrupted keys)
- SSH tunnel processes run indefinitely (no timeout, use `run_capture()`)

**Timeout Values**:
| Operation | Timeout | Justification |
|-----------|---------|---------------|
| Connection diagnostics | 10s | Network operations may be slow |
| zbar QR operations | 15s | QR processing can be intensive |
| ssh-keygen metadata | 5s | Fast local operation |
| SSH tunneling | none | Tunnel runs indefinitely |

### 2. Error Handling Approach

**Decision**: Map all subprocess errors to `KeyMakerError` types consistently.

**Before**:
```vala
try {
    var subprocess = new Subprocess.newv(...);
    yield subprocess.wait_async();
    // Various error checks
} catch (Error e) {
    // Generic error handling
}
```

**After**:
```vala
try {
    var result = yield Command.run_capture_with_timeout(cmd, timeout, cancellable);
    if (result.status != 0) {
        throw new KeyMakerError.OPERATION_FAILED(
            "Operation failed: %s", result.stderr
        );
    }
} catch (KeyMakerError.OPERATION_CANCELLED e) {
    // User cancelled - clean up gracefully
} catch (KeyMakerError.OPERATION_FAILED e) {
    // Command failed - show user-friendly error
}
```

**Benefits**:
- UI code can catch specific error types
- Consistent error messages across the application
- Easier to add error recovery logic
- Better logging and debugging

### 3. Output Handling Pattern

**Decision**: Use `Command.Result` struct consistently for all subprocess output.

**Pattern**:
```vala
var result = yield Command.run_capture_with_timeout(...);

// Success path
if (result.status == 0) {
    parse_stdout(result.stdout);
}

// Error path
else {
    show_error(result.stderr);
}
```

**Rationale**:
- Consistent access pattern across all code
- Clear separation of stdout/stderr
- Exit status readily available
- No manual stream reading required

### 4. File-Specific Considerations

#### ConnectionDiagnostics.vala
- **Calls**: 2 SSH diagnostic commands
- **Timeout**: 10 seconds (network operations)
- **Error Handling**: Map SSH errors to user-friendly diagnostic results
- **Special Case**: None

#### EmergencyVault.vala
- **Calls**: 2 zbar operations (generate/scan QR codes)
- **Timeout**: 15 seconds (QR processing can be slow)
- **Error Handling**: Show clear error if zbar not installed or fails
- **Special Case**: Check stderr for "not found" to detect missing zbar

#### ActiveTunnel.vala
- **Calls**: 1 SSH tunnel process
- **Timeout**: NONE (tunnel runs indefinitely)
- **Error Handling**: Monitor process, detect premature exit
- **Special Case**: Use `run_capture()` without timeout, implement separate monitoring

#### Metadata.vala
- **Calls**: 1 ssh-keygen operation
- **Timeout**: 5 seconds (local, fast operation)
- **Error Handling**: Parse stderr for specific ssh-keygen errors
- **Special Case**: Operation uses stdin pipe - ensure Command utility supports this

## Implementation Details

### Step 1: ConnectionDiagnostics.vala
```vala
// BEFORE (line 799):
var subprocess = new Subprocess.newv (cmd_list.data,
    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
yield subprocess.wait_async (null);
// ... manual parsing

// AFTER:
var result = yield KeyMaker.Command.run_capture_with_timeout(
    cmd_list.data,
    10000,  // 10 second timeout
    null
);

if (result.status == 0) {
    // Parse success
} else {
    // Handle error
}
```

### Step 2: EmergencyVault.vala
```vala
// BEFORE (line 735):
var subprocess = new Subprocess.newv (cmd, SubprocessFlags.STDERR_PIPE);
yield subprocess.wait_async ();

if (subprocess.get_exit_status () != 0) {
    throw new KeyMakerError.OPERATION_FAILED ("zbar failed");
}

// AFTER:
var result = yield KeyMaker.Command.run_capture_with_timeout(
    cmd,
    15000,  // 15 second timeout
    null
);

if (result.status != 0) {
    throw new KeyMakerError.OPERATION_FAILED(
        "QR generation failed: %s", result.stderr
    );
}
```

### Step 3: ActiveTunnel.vala (Special Case)
```vala
// BEFORE (line 155):
process = new Subprocess.newv (cmd,
    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
process_id = (int)process.get_identifier();
// Monitor process...

// AFTER - Keep direct Subprocess usage or modify Command utility
// Option A: Keep as-is (long-running process)
// Option B: Add Command.run_background() method
// RECOMMENDED: Keep direct usage for now, add to future Command improvements
```

**Note**: ActiveTunnel.vala may need special consideration. The tunnel process runs indefinitely and needs to be monitored. We could:
1. Keep direct `Subprocess` usage (acceptable exception)
2. Add `Command.run_background()` method (future enhancement)

For this refactoring, we'll document ActiveTunnel.vala as an acceptable exception.

### Step 4: Metadata.vala
```vala
// BEFORE (line 247):
var subprocess = new Subprocess.newv (
    cmd,
    SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
);
// ... stdin interaction

// AFTER - Need to verify Command utility supports stdin
// If not supported, keep direct usage and document as exception
```

**Note**: This call uses `STDIN_PIPE`. Need to verify if `Command` utility supports stdin interaction. If not, this remains an exception.

## Testing Strategy

### Unit Test Scenarios
While the project doesn't have unit tests yet, these would be valuable test cases:

1. **Success case**: Command executes successfully, returns stdout
2. **Failure case**: Command fails, returns stderr and non-zero status
3. **Timeout case**: Command times out, throws `OPERATION_FAILED`
4. **Cancellation case**: User cancels, throws `OPERATION_CANCELLED`

### Integration Test Scenarios
1. Run full connection diagnostics suite
2. Create and restore emergency vault backups with QR
3. Create and manage SSH tunnels
4. Generate keys and verify metadata extraction

### Manual Test Checklist
- [ ] Connection diagnostic passes with real SSH host
- [ ] Connection diagnostic fails gracefully with unreachable host
- [ ] QR backup creation works
- [ ] QR backup scanning works
- [ ] Emergency vault operations complete successfully
- [ ] SSH tunnels start and run correctly
- [ ] SSH tunnels fail gracefully with clear errors
- [ ] Key generation and metadata extraction works
- [ ] All key types (Ed25519, RSA, ECDSA) work correctly

## Migration Risks and Mitigation

### Risk 1: Behavioral Changes
**Risk**: Command utility may handle edge cases differently than direct subprocess usage.

**Mitigation**:
- Review each subprocess call carefully
- Test edge cases explicitly
- Keep original behavior where possible
- Document any intentional behavior changes

### Risk 2: Timeout Too Short/Long
**Risk**: Chosen timeouts may not fit all environments.

**Mitigation**:
- Start with conservative (longer) timeouts
- Monitor user feedback
- Consider making timeouts configurable in future
- Document timeout rationale in code comments

### Risk 3: stdin/stdout Interaction
**Risk**: Some subprocess calls use stdin pipes, which Command utility may not support.

**Mitigation**:
- Check Command utility capabilities first
- If stdin not supported, document as acceptable exception
- Consider adding stdin support to Command utility in future

### Risk 4: Error Message Changes
**Risk**: Different error handling may produce different error messages.

**Mitigation**:
- Test error paths explicitly
- Ensure error messages remain user-friendly
- Update UI error handling if needed
- Keep diagnostic information in stderr

## Future Enhancements

### 1. Command Utility Improvements
- Add `run_background()` method for long-running processes like SSH tunnels
- Add stdin support for interactive commands
- Add progress reporting for long operations
- Add automatic retry logic for transient failures

### 2. Configuration
- Make timeouts configurable via settings
- Add debug mode to log all subprocess calls
- Add metrics collection for subprocess performance

### 3. Testing Infrastructure
- Add unit tests for Command utility
- Add integration tests for subprocess-heavy features
- Add timeout simulation tests

## References
- `src/utils/Command.vala` - Current Command utility implementation
- REFACTORING-PLAN.md Phase 4 - Original plan document
