# Security Warnings Design Document

## Context

KeyMaker provides multiple emergency backup methods including QR codes, which store private keys as unencrypted base64-encoded data. While this enables emergency recovery without requiring a passphrase, it poses a security risk if users don't understand the implications. Users could inadvertently expose their private keys by:

- Storing QR codes in insecure locations (cloud photo storage, screenshots)
- Displaying QR codes on screen where they could be photographed
- Printing QR codes without proper physical security

The current implementation provides no warning about these risks. Phase 7 of the refactoring plan mandates adding prominent security warnings as a HIGH priority user safety improvement.

Additionally, there's a configuration inconsistency where the GSchema file declares `gettext-domain="keysmith"` and the meson.build sets `GETTEXT_PACKAGE` to `keysmith` (project name), which are consistent but should be verified.

### Stakeholders
- **End Users**: Need clear security guidance
- **Security-conscious organizations**: Require compliance with security best practices
- **Developers**: Need maintainable warning system

### Constraints
- Must not break existing backup/restore workflows
- Cannot remove QR backup feature (legitimate use cases exist)
- Must integrate with existing Adw.Dialog patterns
- Warnings must be shown every time (not dismissible permanently)

## Goals / Non-Goals

### Goals
1. **Inform users** about QR backup security risks before creation
2. **Provide visual indicators** in UI to distinguish secure vs insecure backup types
3. **Display warnings** in backup details when viewing existing QR backups
4. **Verify i18n configuration** consistency across project files
5. **Establish pattern** for future security warnings

### Non-Goals
1. Encrypt QR codes (defeats emergency recovery purpose)
2. Remove QR backup feature entirely
3. Modify existing backup file formats
4. Add authentication requirements for QR backup creation
5. Implement "don't show again" checkbox for security warnings

## Decisions

### Decision 1: Dialog-Based Warning Flow

**What**: Use Adw.MessageDialog with destructive action styling for QR backup warnings

**Why**:
- Forces user acknowledgment (can't be missed)
- Follows GNOME HIG patterns
- Clearly distinguishes secure vs dangerous actions
- Standard dialog patterns users recognize

**Alternatives considered**:
- Toast notifications → Too subtle, easily missed
- Inline banner warnings → Can be scrolled past
- One-time preference → Users forget security implications

### Decision 2: Warning Trigger Points

**What**: Show warnings at these points:
1. When QR backup type is selected in CreateBackupDialog (before creation)
2. When viewing details of an existing QR backup (informational)
3. Visual indicator in backup type selector (always visible)

**Why**:
- Prevents creation without informed consent
- Reminds users of risk when reviewing existing backups
- Persistent visual cue guides users toward secure options

**Alternatives considered**:
- Only warn on creation → Doesn't help when reviewing existing backups
- Warn on restore → Too late, backup already created
- Warn on both select and create → Redundant, annoys users

### Decision 3: Visual Indicator Design

**What**: Add "⚠️ Unencrypted - Not recommended for sensitive keys" label below QR option with warning styling

**Why**:
- Uses standard emoji icon (cross-platform)
- Clear, actionable language
- Doesn't block UI but highly visible
- Consistent with GTK/Adwaita CSS classes

**Alternatives considered**:
- Red text only → Too aggressive, poor accessibility
- Icon only → Ambiguous meaning
- Hide QR option → Removes legitimate use case

### Decision 4: Dialog Flow Pattern

**What**: Two-button warning dialog:
- "Cancel" (default, safe action)
- "Proceed Anyway" (destructive appearance)

**Why**:
- Makes safe choice the default
- Destructive styling signals danger
- Two clear options without confusion
- Follows GNOME HIG recommendations

**Pattern**:
```vala
private void on_qr_backup_type_selected() {
    var warning_dialog = new Adw.MessageDialog(
        this,
        _("QR Backup Security Warning"),
        _("QR backups store your private keys as unencrypted base64 data...")
    );
    warning_dialog.add_response("cancel", _("Cancel"));
    warning_dialog.add_response("proceed", _("Proceed Anyway"));
    warning_dialog.set_response_appearance("proceed", Adw.ResponseAppearance.DESTRUCTIVE);
    warning_dialog.set_default_response("cancel");

    warning_dialog.response.connect((response) => {
        if (response == "proceed") {
            // User accepted risk, continue with QR backup
            actually_select_qr_backup_type();
        } else {
            // Revert to previous safe selection
            reset_backup_type_to_encrypted();
        }
    });

    warning_dialog.present();
}
```

### Decision 5: Warning Message Content

**What**: Three-part warning message:
1. **Risk statement**: "QR backups store your private keys as unencrypted base64 data."
2. **Threat explanation**: "Anyone who gains access to the QR code can read your private key."
3. **Recommendation**: "For maximum security, use encrypted archive backups instead."

**Why**:
- States facts clearly without technical jargon
- Explains actual threat (not just "insecure")
- Provides actionable alternative
- Balances brevity with completeness

### Decision 6: i18n Domain Verification Approach

**What**: Verify consistency between:
- `data/io.github.tobagin.keysmith.gschema.xml.in:2` declares `gettext-domain="keysmith"`
- `meson.build:45` sets `GETTEXT_PACKAGE` to `meson.project_name()` which is `'keysmith'`
- These are consistent - document this verification

**Why**:
- Current configuration is actually correct
- Schema domain matches project name
- No changes needed, only verification
- Prevents future mismatches

## Risks / Trade-offs

### Risk 1: Warning Fatigue
**Risk**: Users become desensitized to warnings and click through automatically

**Mitigation**:
- Only warn for genuinely dangerous operations (QR backups)
- Use destructive appearance to signal severity
- Keep message concise and actionable
- Default to safe action (Cancel)

**Trade-off**: Some friction added to legitimate QR backup use cases, but user safety prioritized

### Risk 2: User Confusion
**Risk**: Users may not understand technical terms like "base64" or "encrypted archive"

**Mitigation**:
- Use plain language: "unencrypted" vs "encrypted"
- Focus on consequences: "anyone can read your private key"
- Provide clear alternative: "use encrypted archive instead"
- Add help documentation link (future enhancement)

**Trade-off**: Slight verbosity vs absolute clarity, erring toward clarity

### Risk 3: Existing QR Backups
**Risk**: Users with existing QR backups may panic when seeing warnings in details view

**Mitigation**:
- Informational tone in details view (not alarmist)
- No action required from user for existing backups
- Explain secure storage recommendations
- Don't suggest deleting existing backups

**Trade-off**: Must balance awareness without causing alarm

## Migration Plan

### Phase 1: Add Warning Infrastructure (Day 1)
1. Create warning dialog in CreateBackupDialog
2. Wire up to backup type selection signal
3. Add state management for type selection reversion

### Phase 2: Add Visual Indicators (Day 1)
1. Add warning label widget to backup type selector
2. Apply CSS classes for warning styling
3. Test with different themes (light/dark)

### Phase 3: Update Details Dialogs (Day 2)
1. Add security information section to EmergencyBackupDetailsDialog
2. Display appropriate warnings for QR backup type
3. Keep informational (not blocking) in details view

### Phase 4: i18n Verification (Day 2)
1. Verify gettext-domain in schema matches GETTEXT_PACKAGE
2. Document findings
3. Add comments to prevent future mismatches
4. Test string extraction: `ninja -C build keysmith-pot`

### Testing Strategy
- Manual testing of warning dialog flow
- Test cancellation reverts backup type
- Test proceeding allows QR backup creation
- Test visual indicators appear correctly
- Test details dialog shows warnings
- Verify strings appear in .pot file
- Test with existing QR backups

### Rollback
No rollback needed - purely additive:
- Warnings don't block existing functionality
- QR backups still work identically
- No data migration required
- Can remove warnings without side effects

## Open Questions

1. **Should warnings be translated?**
   - Yes, all user-facing strings must use `_()` for gettext
   - Security warnings are critical for all languages

2. **Should we add a "Learn More" link?**
   - Future enhancement, not in scope for Phase 7
   - Could link to documentation about backup security
   - Would require documentation to be written first

3. **Should encrypted archives be the default selection?**
   - Current proposal: Just add warnings
   - Future consideration: Change default backup type
   - Needs UX research to determine best default

4. **Should we add warnings for other backup types?**
   - Shamir secret sharing is secure
   - Time-lock is secure (temporarily)
   - Encrypted archives are secure
   - Only QR codes need warnings currently

5. **Should we add telemetry to track warning dismissals?**
   - Out of scope for Phase 7
   - Privacy implications need consideration
   - No analytics framework currently exists
