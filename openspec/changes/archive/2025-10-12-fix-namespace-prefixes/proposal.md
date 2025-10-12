# Fix Namespace Prefixes for Dialog Classes

## Overview
Add the `KeyMaker.` namespace prefix to 4 dialog classes that are currently missing it, ensuring consistency across all classes in the project.

## Problem Statement
Currently, 4 classes in the codebase are missing the `KeyMaker.` namespace prefix, which creates inconsistency:

1. **ConnectionDiagnosticsDialog** (should be `KeyMaker.ConnectionDiagnosticsDialog`)
2. **ConnectionDiagnosticsRunnerDialog** (should be `KeyMaker.ConnectionDiagnosticsRunnerDialog`)
3. **DiagnosticResultsViewDialog** (should be `KeyMaker.DiagnosticResultsViewDialog`)
4. **RestoreParams** (should be `KeyMaker.RestoreParams`)

### Current State
```vala
// src/ui/dialogs/ConnectionDiagnosticsDialog.vala
public class ConnectionDiagnosticsDialog : Adw.Dialog {
    // ...
}

// src/ui/dialogs/ConnectionDiagnosticsRunnerDialog.vala
public class ConnectionDiagnosticsRunnerDialog : Adw.Dialog {
    // ...
}

// src/ui/dialogs/DiagnosticResultsViewDialog.vala
public class DiagnosticResultsViewDialog : Adw.Dialog {
    // ...
}

// src/ui/dialogs/RestoreBackupDialog.vala (line 463)
public class RestoreParams {
    // ...
}
```

### Target State
```vala
// All classes with KeyMaker namespace
public class KeyMaker.ConnectionDiagnosticsDialog : Adw.Dialog { }
public class KeyMaker.ConnectionDiagnosticsRunnerDialog : Adw.Dialog { }
public class KeyMaker.DiagnosticResultsViewDialog : Adw.Dialog { }
public class KeyMaker.RestoreParams { }
```

## Why
This change is essential for:
- **Consistency**: All other classes use the `KeyMaker.` prefix
- **Namespace Management**: Prevents naming conflicts with other libraries
- **Code Quality**: Follows established project conventions
- **Maintainability**: Makes the codebase more uniform and predictable
- **Type Safety**: Explicit namespacing reduces ambiguity

## What Changes
### Class Definitions (4 files)
1. **src/ui/dialogs/ConnectionDiagnosticsDialog.vala** (line 19)
   - Change: `public class ConnectionDiagnosticsDialog` → `public class KeyMaker.ConnectionDiagnosticsDialog`

2. **src/ui/dialogs/ConnectionDiagnosticsRunnerDialog.vala** (line 19)
   - Change: `public class ConnectionDiagnosticsRunnerDialog` → `public class KeyMaker.ConnectionDiagnosticsRunnerDialog`

3. **src/ui/dialogs/DiagnosticResultsViewDialog.vala** (line 24)
   - Change: `public class DiagnosticResultsViewDialog` → `public class KeyMaker.DiagnosticResultsViewDialog`

4. **src/ui/dialogs/RestoreBackupDialog.vala** (line 463)
   - Change: `public class RestoreParams` → `public class KeyMaker.RestoreParams`

### References to Update
Search for and update any references to these classes across the codebase:
- References to `ConnectionDiagnosticsDialog` → `KeyMaker.ConnectionDiagnosticsDialog`
- References to `ConnectionDiagnosticsRunnerDialog` → `KeyMaker.ConnectionDiagnosticsRunnerDialog`
- References to `DiagnosticResultsViewDialog` → `KeyMaker.DiagnosticResultsViewDialog`
- References to `RestoreParams` → `KeyMaker.RestoreParams`

## Motivation
The project has established a convention where all classes use the `KeyMaker.` namespace prefix:
- 28 out of 32 dialog classes already use `KeyMaker.` prefix
- All backend classes use `KeyMaker.` prefix
- All model classes use `KeyMaker.` prefix
- All utility classes use `KeyMaker.` prefix

These 4 missing prefixes are the last inconsistencies in the entire codebase. Fixing them completes the namespace standardization effort started in earlier phases.

## Proposed Solution
### Step 1: Update Class Definitions
Use exact string replacement to add the `KeyMaker.` prefix to each class declaration.

### Step 2: Search for References
```bash
grep -r "ConnectionDiagnosticsDialog" src/
grep -r "ConnectionDiagnosticsRunnerDialog" src/
grep -r "DiagnosticResultsViewDialog" src/
grep -r "RestoreParams" src/
```

### Step 3: Update References
Update any references found to use the fully qualified name. Note that:
- If files already have `using KeyMaker;`, references may not need updates
- If files don't have `using KeyMaker;`, add fully qualified names

### Step 4: Verify Build
```bash
./scripts/build.sh --dev
```

## Impact Analysis
### Files Affected: 4-8
- **4 class definition files**: Guaranteed to be updated
- **0-4 reference files**: May need updates depending on usage patterns

### Benefits
- **100% namespace consistency**: All classes now follow the same convention
- **Reduced ambiguity**: Clear which classes belong to KeyMaker
- **Better IDE support**: Auto-completion works more reliably
- **Future-proof**: Prevents conflicts if similar class names appear in dependencies

### Risks
- **Low risk**: This is a straightforward rename operation
- **Build breakage**: Incorrect references would cause compilation errors (easy to spot)
- **Runtime issues**: Vala's type system ensures correct references at compile time

### Mitigation
- Use exact string matching to avoid false positives
- Test build immediately after each change
- Verify all dialogs open correctly in the application
- Check that no `using` statements need adjustment

## Testing Strategy
### Build Verification
1. Clean build: `rm -rf build && ./scripts/build.sh --dev`
2. Verify no compilation errors
3. Check for any unresolved symbol warnings

### Runtime Verification
1. Launch application: `flatpak run io.github.tobagin.keysmith.Devel`
2. Test each affected dialog:
   - Connection Diagnostics Dialog (from Diagnostics page)
   - Connection Diagnostics Runner Dialog (from diagnostics)
   - Diagnostic Results View Dialog (from diagnostics history)
   - Restore Backup (from Backup page - tests RestoreParams)
3. Verify no runtime errors in logs

### Regression Testing
- [ ] Connection diagnostics can be opened
- [ ] Diagnostics can be executed
- [ ] Diagnostic results can be viewed
- [ ] Backup restoration works correctly
- [ ] RestoreParams is used correctly in backup restoration flow

## Success Criteria
- [ ] All 4 class definitions updated with `KeyMaker.` prefix
- [ ] All references updated (if any exist)
- [ ] Build succeeds without errors or warnings
- [ ] All affected dialogs open and function correctly
- [ ] No namespace-related errors in logs
- [ ] Code passes visual inspection for consistency

## Related Changes
- Part of Phase 5 of the KeyMaker Refactoring Plan (REFACTORING-PLAN.md)
- Complements Phase 1 (file naming) and Phase 4 (subprocess consolidation)
- Aligns with `code-structure` specification

## References
- [REFACTORING-PLAN.md](/home/tobagin/Projects/keymaker/REFACTORING-PLAN.md) - Lines 570-622 (Phase 5)
- Code Structure Specification - Namespace conventions
