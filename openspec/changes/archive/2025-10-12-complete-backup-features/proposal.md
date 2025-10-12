# Complete Backup Management Features

## Why

Phase 2 of the KeyMaker refactoring plan addresses incomplete backup management functionality. Currently, there are 8 TODO items across two files ([BackupPage.vala:384-484](src/ui/pages/BackupPage.vala#L384-L484) and [BackupCenterDialog.vala:436-544](src/ui/dialogs/BackupCenterDialog.vala#L436-L544)) that prevent users from fully managing their SSH key backups. Additionally, the toast notification system in [GenerateDialog.vala:406](src/ui/dialogs/GenerateDialog.vala#L406) is commented out and non-functional.

These incomplete features affect critical user workflows:
- Users cannot bulk-delete regular backups
- Users cannot securely delete emergency backups with authentication
- Users cannot view detailed backup information before restore
- Users don't receive proper feedback for key generation operations

## What Changes

### Backup Management Features
- Implement "Remove all regular backups" with confirmation dialog
- Implement "Remove all emergency backups" with authentication flow
- Create backup details dialog showing metadata (date, size, key count, type)
- Create emergency backup details dialog with unlock method information
- Add authentication dialog for emergency backup deletion operations

### Toast Notification System
- Debug and fix commented-out toast overlay in GenerateDialog
- Ensure toasts display correctly across all dialogs
- Test toast notifications with various message types

### Code Quality
- Refactor shared backup management code between BackupPage and BackupCenterDialog
- Extract common dialog patterns into reusable helper methods
- Improve error handling and user feedback

## Impact

**Affected specs:**
- `backup-management` (new capability)
- `ui-components` (new capability)

**Affected code:**
- [src/ui/pages/BackupPage.vala](src/ui/pages/BackupPage.vala) - Lines 384-490
- [src/ui/dialogs/BackupCenterDialog.vala](src/ui/dialogs/BackupCenterDialog.vala) - Lines 436-546
- [src/ui/dialogs/GenerateDialog.vala](src/ui/dialogs/GenerateDialog.vala) - Line 406
- [src/backend/BackupManager.vala](src/backend/BackupManager.vala) - New methods for bulk operations
- [src/backend/vault/EmergencyVault.vala](src/backend/vault/EmergencyVault.vala) - Authentication methods

**Breaking changes:**
None - All changes are additive features completing existing TODO items.

**Migration requirements:**
None - No user data migration needed.

**Dependencies:**
- Requires Phase 1 (file naming standardization) to be completed
- Depends on existing BackupManager and EmergencyVault APIs
