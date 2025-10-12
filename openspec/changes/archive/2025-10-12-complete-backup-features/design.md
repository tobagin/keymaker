# Design Document: Complete Backup Features

## Context

Phase 2 of KeyMaker refactoring addresses 8 incomplete TODO items in backup management UI and a broken toast notification system. The application already has robust backend services (BackupManager, EmergencyVault) but lacks complete UI implementation for several user-facing features.

**Current State:**
- BackupManager supports individual backup operations but lacks bulk deletion
- EmergencyVault has authentication methods but no bulk operations
- BackupPage and BackupCenterDialog have identical TODO items (code duplication)
- Toast overlay is commented out in GenerateDialog, preventing user feedback
- No details dialogs exist for viewing backup metadata

**Stakeholders:**
- End users: Need complete backup management capabilities
- Developers: Need to maintain consistency between BackupPage and BackupCenterDialog
- Security: Require proper authentication for emergency backup operations

## Goals / Non-Goals

**Goals:**
- Complete all 8 TODO items in BackupPage and BackupCenterDialog
- Fix toast notification system in GenerateDialog
- Add comprehensive backup details viewing
- Implement secure authentication for emergency backup deletion
- Maintain code consistency between BackupPage and BackupCenterDialog
- Follow Adwaita design guidelines for all dialogs
- Ensure accessibility standards are met

**Non-Goals:**
- Redesigning existing backup workflows (only completing incomplete features)
- Adding new backup types or methods
- Changing backup file formats or storage locations
- Implementing backup scheduling or automation
- Adding backup encryption algorithm changes
- Performance optimization (unless regressions occur)

## Decisions

### Decision 1: Three New Dialog Classes
**What:** Create BackupDetailsDialog, EmergencyBackupDetailsDialog, and EmergencyBackupAuthDialog as separate classes.

**Why:**
- Separation of concerns: Each dialog has distinct purpose and data
- Reusability: Can be used from both BackupPage and BackupCenterDialog
- Maintainability: Easier to test and modify independently
- Follows single-responsibility principle

**Alternatives considered:**
- **Single polymorphic details dialog:** Rejected because emergency and regular backups have significantly different metadata and actions
- **Inline details in existing dialogs:** Rejected because it would clutter BackupPage and BackupCenterDialog

### Decision 2: Add Bulk Operations to Backend Services
**What:** Add `remove_all_regular_backups()` to BackupManager and `remove_all_emergency_backups(passphrase)` to EmergencyVault.

**Why:**
- Atomic operations: Ensures consistency during bulk deletions
- Error handling: Centralized handling of partial failures
- Signal emission: Proper notification of status changes
- Authentication: Verifies credentials before any deletion occurs

**Alternatives considered:**
- **UI-level iteration:** Rejected because it would scatter error handling and not be atomic
- **Generic bulk delete utility:** Rejected because regular and emergency backups need different logic

### Decision 3: Refactor Shared Code into BackupHelpers Utility
**What:** Extract common patterns from BackupPage and BackupCenterDialog into static helper methods.

**Why:**
- DRY principle: Eliminate duplicated code
- Consistency: Ensures both locations behave identically
- Maintenance: Single location to fix bugs or add features
- Testing: Easier to unit test isolated helpers

**Refactored patterns:**
- Confirmation dialog creation
- Error message formatting
- Metadata display formatting
- File size formatting
- Date/time formatting

### Decision 4: Fix Toast by Ensuring Proper Widget Hierarchy
**What:** Verify Adw.ToastOverlay is properly initialized and contains dialog content.

**Why:**
- Toast must be in widget tree to display
- Common issue when widget hierarchy changes during refactoring
- Simple fix: ensure overlay wraps content before window shows

**Implementation:**
```vala
// In GenerateDialog constructor
toast_overlay = new Adw.ToastOverlay ();
toast_overlay.child = content_box;  // Wrap actual content
this.child = toast_overlay;         // Set as dialog child
```

### Decision 5: Rate Limiting with Exponential Backoff
**What:** Implement rate limiting after 3 failed authentication attempts with 30-second cooldown.

**Why:**
- Security: Prevents brute-force attacks on emergency backups
- User experience: Clear feedback about lockout status
- Industry standard: Common pattern in authentication systems

**Parameters:**
- Failed attempt threshold: 3 attempts
- Initial cooldown: 30 seconds
- Reset on success: Counter resets to 0

**Alternatives considered:**
- **Progressive delays:** Rejected as overly complex for this use case
- **Permanent lockout:** Rejected as too harsh (user may have multiple passphrases to try)
- **IP-based limiting:** Not applicable (desktop application)

### Decision 6: Real-Time Countdown for Time-Locked Backups
**What:** Use GLib.Timeout to update countdown display every second.

**Why:**
- User experience: Visual feedback of time remaining
- Accuracy: Shows precise time until unlock
- Engagement: User can see progress

**Implementation:**
```vala
private uint timeout_id;

private bool update_countdown () {
    var remaining = calculate_remaining_time (backup.unlock_time);
    countdown_label.label = format_time_remaining (remaining);

    if (remaining <= 0) {
        countdown_label.label = "UNLOCKED";
        status_icon.icon_name = "emblem-ok-symbolic";
        return Source.REMOVE;  // Stop timer
    }

    return Source.CONTINUE;  // Keep running
}

// In dialog present
timeout_id = Timeout.add_seconds (1, update_countdown);

// In dialog close
if (timeout_id > 0) {
    Source.remove (timeout_id);
}
```

### Decision 7: Security Warnings for QR Backups
**What:** Display prominent warning banner in EmergencyBackupDetailsDialog for QR backups.

**Why:**
- Security awareness: Users must understand QR codes are unencrypted
- Informed decisions: Users can choose more secure backup methods
- Risk mitigation: Clear documentation of security implications

**Warning text:**
> "⚠️ Security Warning: QR code backups contain unencrypted private keys. Anyone who scans this QR code can access your private keys. Store QR code images securely and never share them."

## Risks / Trade-offs

### Risk 1: Code Duplication Between BackupPage and BackupCenterDialog
**Risk:** Despite refactoring, some duplication may remain.

**Mitigation:**
- Extract maximum shared code into BackupHelpers
- Document which patterns must remain duplicated (e.g., signal connections)
- Consider longer-term refactoring to merge both into single component

**Trade-off:** Short-term duplication acceptable to avoid large refactoring during Phase 2.

### Risk 2: Toast Overlay Initialization Order
**Risk:** Toast may still not display if initialization order is wrong.

**Mitigation:**
- Add detailed debug logging during initialization
- Verify widget tree with GTK Inspector tool
- Test with minimal reproducer if issue persists
- Check Blueprint file integration (if dialog uses .blp)

**Fallback:** Use Adw.MessageDialog as temporary notification mechanism if toast cannot be fixed.

### Risk 3: Authentication Bypass via Filesystem Access
**Risk:** User with filesystem access can delete emergency backup files without authentication.

**Mitigation:**
- Document that authentication is UI-level security only
- Emergency vault directory uses 0700 permissions
- File encryption protects key contents
- Authentication prevents accidental deletion via UI

**Acceptance:** This is acceptable for desktop application. Users with filesystem access have full control regardless.

### Risk 4: Partial Deletion Failures
**Risk:** Bulk deletion may succeed for some backups but fail for others.

**Mitigation:**
- Collect all errors during iteration
- Report summary of successes and failures
- Provide detailed error dialog listing which backups failed and why
- Allow retry for failed deletions
- Never mark operation as "complete success" if any failures occurred

### Risk 5: Memory Leaks from Dialog Instances
**Risk:** Repeatedly opening details dialogs could leak memory.

**Mitigation:**
- Properly disconnect all signal handlers in dialog dispose
- Clear references to large objects (backup entries)
- Stop all timers (countdowns) when dialog closes
- Test with memory profiling tool (valgrind)
- Create dialogs as transient, not persistent

## Migration Plan

**No data migration required.** All changes are additive features completing existing functionality.

### Deployment Steps
1. Merge Phase 2 implementation
2. Build and test development flatpak
3. Run manual testing checklist (see REFACTORING-PLAN.md Phase 2)
4. Build production flatpak
5. Release as minor version bump

### Rollback Plan
If critical issues discovered:
1. Revert commit containing Phase 2 changes
2. Rebuild flatpak from previous commit
3. Deploy previous version
4. Document issues for future fix

### Backward Compatibility
- All changes are additive (no breaking API changes)
- Existing backup files remain compatible
- Settings schema unchanged
- No user data format changes

## Open Questions

### Q1: Should details dialogs be modal or non-modal?
**Options:**
- Modal: User must close before interacting with main window
- Non-modal: User can keep details open while working

**Recommendation:** Modal (use `Adw.Dialog.present(window)`)
**Rationale:** Details are typically viewed briefly before action. Modal prevents confusion about which backup is selected.

### Q2: Should bulk deletion show progress bar?
**Options:**
- Simple: Show spinner during operation
- Detailed: Show progress bar with count (X of N deleted)

**Recommendation:** Start simple with spinner. Add progress bar only if users report slow operations.
**Rationale:** Most users have <20 backups. Operation completes quickly.

### Q3: What happens to cloud backups during bulk deletion?
**Options:**
- Delete local copy only
- Delete from cloud provider also
- Ask user for each cloud backup

**Recommendation:** Delete local copy only. Add separate "Remove from Cloud" action in future.
**Rationale:** Cloud deletion is destructive and may require API calls. Safer to be conservative.

### Q4: Should authentication dialog support biometric auth?
**Options:**
- Yes: Add fingerprint/face ID support
- No: Passphrase only for now

**Recommendation:** No for Phase 2. Consider for future enhancement.
**Rationale:** Biometric auth adds complexity. Not critical for Phase 2 completion.

## Implementation Notes

### File Structure
```
src/ui/dialogs/
  ├── BackupDetailsDialog.vala          (NEW)
  ├── EmergencyBackupDetailsDialog.vala (NEW)
  └── EmergencyBackupAuthDialog.vala    (NEW)

src/ui/helpers/
  └── BackupHelpers.vala                 (NEW)

src/backend/
  ├── BackupManager.vala                 (MODIFIED - add bulk delete)
  └── vault/EmergencyVault.vala          (MODIFIED - add bulk delete)

src/ui/pages/
  └── BackupPage.vala                    (MODIFIED - wire up TODOs)

src/ui/dialogs/
  ├── BackupCenterDialog.vala            (MODIFIED - wire up TODOs)
  └── GenerateDialog.vala                (MODIFIED - fix toast)
```

### Testing Strategy
**Unit Tests:**
- BackupHelpers utility methods
- Metadata formatting functions
- Time calculation for countdowns

**Integration Tests:**
- Bulk deletion with mixed success/failure
- Authentication flow with rate limiting
- Toast display across multiple dialogs

**Manual Tests:**
- All dialog layouts on different screen sizes
- Keyboard navigation and accessibility
- Dark mode appearance
- Screen reader compatibility

### Documentation Updates
- Update [REFACTORING-PLAN.md](REFACTORING-PLAN.md) Phase 2 status
- Add comments to new dialog classes
- Document BackupHelpers utility
- Update user guide with new features
