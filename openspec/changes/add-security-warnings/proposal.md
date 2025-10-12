# Add Security Warnings for QR Backups and Fix i18n Domain

## Why

KeyMaker's QR backup feature stores private keys as unencrypted base64 data, presenting a significant security risk if users are unaware. Currently, the UI provides no warning about this when users select QR backup as their emergency backup method. Additionally, there's an inconsistency in the gettext domain configuration that could affect internationalization.

According to the refactoring plan (Phase 7), these security enhancements are HIGH priority for user safety.

## What Changes

- **Add prominent security warnings** when users select QR backup method in CreateBackupDialog
- **Add visual warning indicators** in backup selection UI for unencrypted backup types
- **Display security information** in emergency backup details dialogs
- **Fix gettext domain mismatch** between GSchema file (`keysmith`) and project expectations
- **Verify i18n consistency** across all configuration files

**BREAKING**: None - these are additive security improvements

## Impact

- **Affected specs**:
  - `security-warnings` (NEW) - QR backup warning system
  - `i18n-configuration` (NEW) - Internationalization domain consistency
  - `backup-management` - Extended with security warning requirements
  - `ui-components` - Extended with warning dialog patterns

- **Affected code**:
  - `src/ui/dialogs/CreateBackupDialog.vala` - Add QR warning dialog and visual indicators
  - `src/ui/dialogs/EmergencyBackupDetailsDialog.vala` - Display security warnings for QR backups
  - `src/ui/dialogs/EmergencyVaultDialog.vala` - May need warning UI updates
  - `data/io.github.tobagin.keysmith.gschema.xml.in` - Verify gettext domain
  - `meson.build` - Verify GETTEXT_PACKAGE configuration

- **User Experience**:
  - Users will see clear warnings before creating QR backups
  - Better informed decision-making about backup security
  - No changes to existing backup functionality
  - Existing QR backups continue to work without modification

## Dependencies

- Requires existing EmergencyVault and CreateBackupDialog implementations
- Should be implemented after Phase 5 (namespace fixes) and Phase 6 (settings centralization)
- Can be implemented independently of other Phase 7 components

## Alternatives Considered

1. **Disable QR backups entirely** - Rejected because some users may need them for legitimate use cases
2. **Encrypt QR codes** - Rejected because it defeats the purpose of QR emergency recovery (would need passphrase)
3. **Silent warnings (no dialogs)** - Rejected because users might miss subtle UI indicators
4. **Make warnings dismissible permanently** - Rejected because security warnings should be shown every time
