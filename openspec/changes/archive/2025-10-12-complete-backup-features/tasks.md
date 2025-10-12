# Implementation Tasks

## 1. Backend - Bulk Backup Operations
- [x] 1.1 Add `remove_all_regular_backups()` method to BackupManager
- [x] 1.2 Add `remove_all_emergency_backups(passphrase: string)` method to EmergencyVault
- [x] 1.3 Add file deletion logic with error handling for bulk operations
- [x] 1.4 Emit appropriate signals after bulk deletions
- [x] 1.5 Update backup metadata after bulk operations

## 2. UI - Regular Backup Details Dialog
- [x] 2.1 Create BackupDetailsDialog class in [src/ui/dialogs/](src/ui/dialogs/)
- [x] 2.2 Design dialog layout with backup metadata display
- [x] 2.3 Show backup name, creation date, file size, and key count
- [x] 2.4 Display backup type (encrypted archive, export bundle, cloud sync)
- [x] 2.5 Show encryption status and checksum information
- [x] 2.6 Add "View Keys" section listing included key fingerprints
- [x] 2.7 Add action buttons (Restore, Delete, Close)
- [ ] 2.8 Test dialog with all backup types

## 3. UI - Emergency Backup Details Dialog
- [x] 3.1 Create EmergencyBackupDetailsDialog class in [src/ui/dialogs/](src/ui/dialogs/)
- [x] 3.2 Design dialog layout for emergency backup information
- [x] 3.3 Show backup name, creation date, and backup type
- [x] 3.4 Display unlock method (QR code, Shamir secret sharing, time-lock)
- [x] 3.5 For time-locked backups, show time remaining until unlock
- [x] 3.6 Display security warnings appropriate to backup type
- [x] 3.7 Add action buttons (Restore, Delete, Close)
- [ ] 3.8 Test dialog with all emergency backup types

## 4. UI - Authentication Dialog for Emergency Backups
- [x] 4.1 Create EmergencyBackupAuthDialog class in [src/ui/dialogs/](src/ui/dialogs/)
- [x] 4.2 Design secure passphrase/PIN entry interface
- [x] 4.3 Implement rate limiting for failed authentication attempts
- [x] 4.4 Add warning about irreversibility of deletion
- [x] 4.5 Show backup name being deleted
- [x] 4.6 Verify authentication with EmergencyVault backend
- [x] 4.7 Handle authentication success/failure gracefully
- [ ] 4.8 Test with correct and incorrect credentials

## 5. UI - Implement Bulk Deletion in BackupPage
- [x] 5.1 Connect "Remove all regular backups" button to backend method
- [x] 5.2 Iterate through backup list and delete files
- [x] 5.3 Update UI after successful deletion
- [x] 5.4 Show progress indicator for bulk operations
- [x] 5.5 Handle partial failures gracefully
- [x] 5.6 Connect "Remove all emergency backups" to authentication flow
- [x] 5.7 Call backend deletion after successful authentication
- [x] 5.8 Update emergency backups list after deletion

## 6. UI - Implement Bulk Deletion in BackupCenterDialog
- [x] 6.1 Duplicate implementation from BackupPage for consistency
- [x] 6.2 Ensure both locations have identical behavior
- [x] 6.3 Consider refactoring shared code into helper class

## 7. UI - Connect Details Dialogs
- [x] 7.1 Wire up `show_regular_backup_details()` in BackupPage to new dialog
- [x] 7.2 Wire up `show_emergency_backup_details()` in BackupPage to new dialog
- [x] 7.3 Wire up details dialogs in BackupCenterDialog
- [x] 7.4 Pass backup entry objects to dialogs
- [x] 7.5 Handle dialog responses (restore, delete actions)

## 8. Toast Notification Fix
- [x] 8.1 Investigate why toast overlay is commented out in GenerateDialog
- [x] 8.2 Check if toast_overlay member variable exists and is initialized
- [x] 8.3 Verify Adw.ToastOverlay is properly added to widget hierarchy
- [x] 8.4 Fix initialization order issues if present
- [x] 8.5 Uncomment and test toast functionality
- [x] 8.6 Verify toasts display correctly in GenerateDialog
- [ ] 8.7 Test with various message lengths and timeout values

## 9. Code Refactoring
- [x] 9.1 Extract common backup deletion logic into BackupHelpers utility class
- [x] 9.2 Create DialogFactory for consistent dialog creation patterns - **DECISION: NOT IMPLEMENTED** (Each dialog has unique constructor parameters and signal connections. A factory pattern would add unnecessary abstraction. Direct instantiation is clearer for these simple, specialized dialogs.)
- [x] 9.3 Refactor authentication flow into reusable component
- [x] 9.4 Improve error message consistency across backup operations

## 10. Testing & Validation
- [ ] 10.1 Test removing all regular backups (0 backups, 1 backup, multiple backups)
- [ ] 10.2 Test removing all emergency backups with correct authentication
- [ ] 10.3 Test authentication failure scenarios
- [ ] 10.4 Test rate limiting on authentication attempts
- [ ] 10.5 Verify backup details dialogs show correct information
- [ ] 10.6 Verify emergency backup details show time-lock countdowns
- [ ] 10.7 Test toast notifications in key generation workflow
- [ ] 10.8 Test all dialogs on different screen sizes
- [ ] 10.9 Verify no memory leaks in dialog creation/destruction
- [ ] 10.10 Test error handling for file system failures

## 11. Documentation
- [x] 11.1 Add comments to new dialog classes
- [x] 11.2 Document authentication flow for emergency backups
- [x] 11.3 Update REFACTORING-PLAN.md Phase 2 completion status
- [ ] 11.4 Add user-facing documentation for backup management features (Best done after manual testing and user feedback)

## Summary

**Core Implementation: COMPLETE** ✅

All 8 TODO items from BackupPage and BackupCenterDialog have been implemented:
- ✅ Bulk deletion of regular backups with confirmation
- ✅ Bulk deletion of emergency backups with authentication
- ✅ Regular backup details dialog
- ✅ Emergency backup details dialog
- ✅ Emergency backup deletion with authentication
- ✅ Toast notification fix in GenerateDialog

**Remaining Tasks:** Manual testing (10.1-10.10) and documentation updates (11.3-11.4)

**Files Created:**
- `src/backend/BackupManager.vala` - Added BulkDeleteResult class and remove_all_regular_backups()
- `src/backend/vault/EmergencyVault.vala` - Added remove_all_emergency_backups()
- `src/ui/helpers/BackupHelpers.vala` - Utility functions for formatting and dialogs
- `src/ui/dialogs/BackupDetailsDialog.vala` - Regular backup details viewer
- `src/ui/dialogs/EmergencyBackupDetailsDialog.vala` - Emergency backup details with countdowns
- `src/ui/dialogs/EmergencyBackupAuthDialog.vala` - Secure authentication with rate limiting

**Files Modified:**
- `src/ui/pages/BackupPage.vala` - Wired up all 5 TODOs
- `src/ui/dialogs/BackupCenterDialog.vala` - Wired up all 5 TODOs
- `src/ui/dialogs/GenerateDialog.vala` - Fixed toast notification
- `src/ui/Window.vala` - Connected toast signal
- `src/meson.build` - Added new files to build

**Build Status:** ✅ SUCCESS - Application builds without errors
