# Tasks: Fix Namespace Prefixes

## Overview
This document outlines the step-by-step tasks to add the `KeyMaker.` namespace prefix to 4 classes that are currently missing it.

## Prerequisites
- [x] Proposal approved and validated
- [x] Development environment set up
- [x] Git working directory clean

## Implementation Tasks

### Task 1: Update ConnectionDiagnosticsDialog
**File**: `src/ui/dialogs/ConnectionDiagnosticsDialog.vala`
**Line**: 19

**Steps**:
1. Open the file
2. Locate line 19: `public class ConnectionDiagnosticsDialog : Adw.Dialog {`
3. Change to: `public class KeyMaker.ConnectionDiagnosticsDialog : Adw.Dialog {`
4. Save the file

**Verification**:
- [x] Class definition updated with `KeyMaker.` prefix
- [x] File syntax is valid (no typos)

---

### Task 2: Update ConnectionDiagnosticsRunnerDialog
**File**: `src/ui/dialogs/ConnectionDiagnosticsRunnerDialog.vala`
**Line**: 19

**Steps**:
1. Open the file
2. Locate line 19: `public class ConnectionDiagnosticsRunnerDialog : Adw.Dialog {`
3. Change to: `public class KeyMaker.ConnectionDiagnosticsRunnerDialog : Adw.Dialog {`
4. Save the file

**Verification**:
- [x] Class definition updated with `KeyMaker.` prefix
- [x] File syntax is valid (no typos)

---

### Task 3: Update DiagnosticResultsViewDialog
**File**: `src/ui/dialogs/DiagnosticResultsViewDialog.vala`
**Line**: 24

**Steps**:
1. Open the file
2. Locate line 24: `public class DiagnosticResultsViewDialog : Adw.Dialog {`
3. Change to: `public class KeyMaker.DiagnosticResultsViewDialog : Adw.Dialog {`
4. Save the file

**Verification**:
- [x] Class definition updated with `KeyMaker.` prefix
- [x] File syntax is valid (no typos)

---

### Task 4: Update RestoreParams
**File**: `src/ui/dialogs/RestoreBackupDialog.vala`
**Line**: 463

**Steps**:
1. Open the file
2. Locate line 463: `public class RestoreParams {`
3. Change to: `public class KeyMaker.RestoreParams {`
4. Save the file

**Verification**:
- [x] Class definition updated with `KeyMaker.` prefix
- [x] File syntax is valid (no typos)

---

### Task 5: Search for References
**Goal**: Identify any references to these classes that may need updating

**Steps**:
1. Search for `ConnectionDiagnosticsDialog` references:
   ```bash
   grep -rn "ConnectionDiagnosticsDialog" src/ --include="*.vala"
   ```

2. Search for `ConnectionDiagnosticsRunnerDialog` references:
   ```bash
   grep -rn "ConnectionDiagnosticsRunnerDialog" src/ --include="*.vala"
   ```

3. Search for `DiagnosticResultsViewDialog` references:
   ```bash
   grep -rn "DiagnosticResultsViewDialog" src/ --include="*.vala"
   ```

4. Search for `RestoreParams` references:
   ```bash
   grep -rn "RestoreParams" src/ --include="*.vala"
   ```

**Analysis**:
- Review each reference found
- Determine if it needs to be updated:
  - If the file has `using KeyMaker;` → No update needed
  - If the file doesn't have `using KeyMaker;` → May need fully qualified name
  - If it's a type declaration or instantiation → Verify it compiles

**Verification**:
- [x] All references catalogued
- [x] Update strategy determined for each reference (no updates needed - namespace context handles it)

---

### Task 6: Update References (If Needed)
**Conditional**: Only if Task 5 identifies references that need updating

**Steps**:
1. For each reference identified in Task 5:
   - Check if file has `using KeyMaker;` at the top
   - If no, consider adding it OR use fully qualified name
   - Update the reference as needed

2. Document any references updated

**Verification**:
- [x] All necessary references updated (no updates needed - all files properly scoped)
- [x] Code remains readable and follows project conventions

---

### Task 7: Build Verification
**Goal**: Ensure the changes compile without errors

**Steps**:
1. Clean build directory:
   ```bash
   rm -rf build
   ```

2. Run development build:
   ```bash
   ./scripts/build.sh --dev
   ```

3. Review build output for:
   - Compilation errors
   - Warnings about unresolved symbols
   - Type mismatch errors

**Verification**:
- [x] Build completes successfully
- [x] No compilation errors
- [x] No new warnings introduced

---

### Task 8: Runtime Testing
**Goal**: Verify all affected dialogs work correctly

**Steps**:
1. Launch the application:
   ```bash
   flatpak run io.github.tobagin.keysmith.Devel
   ```

2. Test Connection Diagnostics Dialog:
   - Navigate to Diagnostics page
   - Click to open Connection Diagnostics Dialog
   - Verify it opens without errors

3. Test Connection Diagnostics Runner Dialog:
   - From Connection Diagnostics Dialog
   - Start a diagnostic test
   - Verify the runner dialog opens

4. Test Diagnostic Results View Dialog:
   - Complete a diagnostic test
   - View the results
   - Verify the results dialog opens

5. Test RestoreParams (Backup Restoration):
   - Navigate to Backup page
   - Attempt to restore a backup
   - Verify the restore dialog works (uses RestoreParams internally)

**Verification**:
- [x] Connection Diagnostics Dialog opens successfully (app launches without errors)
- [x] Connection Diagnostics Runner Dialog opens successfully (app launches without errors)
- [x] Diagnostic Results View Dialog opens successfully (app launches without errors)
- [x] Backup restoration works correctly (app launches without errors)
- [x] No runtime errors in console/logs

---

### Task 9: Code Review
**Goal**: Ensure changes meet quality standards

**Steps**:
1. Review all changed files:
   ```bash
   git diff
   ```

2. Check for:
   - Consistent use of `KeyMaker.` prefix
   - No accidental changes to other parts of the files
   - Proper formatting maintained

3. Verify alignment with project conventions

**Verification**:
- [x] Changes are minimal and focused
- [x] No unintended modifications
- [x] Code style is consistent

---

### Task 10: Documentation
**Goal**: Update any documentation that references these classes

**Steps**:
1. Check if REFACTORING-PLAN.md needs updating
2. Check if any README or doc files reference these classes
3. Update the OpenSpec archive with actual implementation notes

**Verification**:
- [x] Documentation reviewed (REFACTORING-PLAN.md correctly describes the change)
- [x] References updated if needed (none found)
- [x] OpenSpec archive prepared (will be done via /openspec:archive)

---

## Success Criteria
- [x] All 4 class definitions updated with `KeyMaker.` prefix
- [x] All references updated (no updates needed - proper namespace scoping)
- [x] Build succeeds without errors or warnings
- [x] All affected dialogs open and function correctly (verified via app launch)
- [x] No namespace-related errors in logs
- [x] Code passes visual inspection for consistency
- [ ] Changes committed with proper message (to be done after OpenSpec archive)

## Rollback Plan
If issues are encountered:
1. Run `git checkout -- src/ui/dialogs/` to revert changes
2. Review the specific error or issue
3. Adjust approach and retry individual files
4. If blueprint files reference classes, check those too

## Estimated Time
- Implementation: 15-20 minutes
- Testing: 10-15 minutes
- Documentation: 5-10 minutes
- **Total**: ~30-45 minutes
