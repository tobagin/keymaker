# Implementation Tasks

## 1. Add QR Backup Warning Dialog Infrastructure

- [x] 1.1 Add warning dialog state variables to CreateBackupDialog.vala
  - [x] Add `previous_backup_type` field to store type before QR selection
  - [x] Add `qr_warning_acknowledged` flag for session tracking
  - [x] Add `warning_dialog_active` flag to prevent stacking

- [x] 1.2 Implement warning dialog method
  - [x] Create `show_qr_backup_warning()` method in CreateBackupDialog
  - [x] Create Adw.MessageDialog with security warning title
  - [x] Set dialog message with three-part warning content
  - [x] Add "Cancel" and "Proceed Anyway" responses
  - [x] Set "Proceed Anyway" to destructive appearance
  - [x] Set "Cancel" as default response
  - [x] Make dialog modal

- [x] 1.3 Wire warning dialog to backup type selection
  - [x] Connect to backup_type_combo row-selected signal (or equivalent)
  - [x] Detect when QR code type is selected
  - [x] Store previous type before showing warning
  - [x] Call show_qr_backup_warning() on QR selection
  - [x] Prevent showing warning if already acknowledged in session

- [x] 1.4 Implement warning response handlers
  - [x] Handle "Cancel" response: revert to previous backup type
  - [x] Handle "Proceed Anyway" response: allow QR backup selection
  - [x] Update UI state appropriately after response
  - [x] Clear warning_dialog_active flag on close

## 2. Add Visual Warning Indicators

- [x] 2.1 Add warning label widget to backup type UI
  - [x] Create Gtk.Label widget for warning text
  - [x] Set text to "⚠️ Unencrypted - Not recommended for sensitive keys"
  - [x] Position below QR backup option in UI
  - [x] Ensure label is associated with QR option only

- [x] 2.2 Apply CSS styling to warning label
  - [x] Add "warning" CSS class to label
  - [x] Add "caption" CSS class for smaller text size
  - [x] Test warning color in light theme
  - [x] Test warning color in dark theme
  - [x] Verify visibility and readability

- [x] 2.3 Update Blueprint UI definition (if needed)
  - [x] Add warning label to create_backup_dialog.blp if using Blueprint
  - [x] Set proper parent-child relationships
  - [x] Configure visibility constraints
  - [x] Ensure label doesn't affect layout of other options

## 3. Update Emergency Backup Details Dialog

- [x] 3.1 Add security information section to EmergencyBackupDetailsDialog
  - [x] Create new preferences group for security info
  - [x] Add conditional display based on backup type
  - [x] Position appropriately in dialog layout

- [x] 3.2 Implement QR backup security warning display
  - [x] Add warning icon (⚠️) or use Adw.StatusPage for info
  - [x] Display "QR backups contain unencrypted private key data"
  - [x] Add secure storage recommendations
  - [x] Use informational tone (not alarmist)

- [x] 3.3 Add security indicators for secure backup types
  - [x] Display positive indicator for encrypted backups (✓)
  - [x] Show "Encrypted with [method]" for secure types
  - [x] Display Shamir threshold info if applicable
  - [x] Show time-lock status if applicable

- [x] 3.4 Ensure no blocking behavior in details view
  - [x] Verify security info is display-only
  - [x] Ensure user can close dialog freely
  - [x] Don't require acknowledgment for viewing existing backups
  - [x] Allow restore operation regardless of security warnings

## 4. Internationalization Implementation

- [x] 4.1 Mark all warning strings for translation
  - [x] Wrap dialog title with `_("QR Backup Security Warning")`
  - [x] Wrap message body paragraphs with _() individually
  - [x] Wrap button labels with _()
  - [x] Wrap visual indicator text with _()
  - [x] Wrap details dialog security text with _()

- [x] 4.2 Use contextual translation for ambiguous terms
  - [x] Consider C_("backup-security", "Proceed Anyway") if needed
  - [x] Add context for technical terms if multiple meanings exist
  - [x] Review all strings for translation clarity

- [x] 4.3 Add translator comments for security context
  - [x] Add comments explaining security warning importance
  - [x] Note that tone should be serious but not alarmist
  - [x] Indicate that recommendations should be maintained
  - [x] Document any technical terms that need explanation

## 5. Gettext Domain Configuration Verification

- [x] 5.1 Verify GSchema gettext domain
  - [x] Open data/io.github.tobagin.keysmith.gschema.xml.in
  - [x] Confirm line 2: `<schemalist gettext-domain="keysmith">`
  - [x] Verify domain matches project name
  - [x] Document that configuration is correct

- [x] 5.2 Verify meson.build GETTEXT_PACKAGE
  - [x] Open meson.build
  - [x] Confirm GETTEXT_PACKAGE = meson.project_name()
  - [x] Confirm project name is 'keysmith'
  - [x] Verify consistency with GSchema
  - [x] Document verification results

- [x] 5.3 Add documentation comments
  - [x] Add comment to GSchema explaining gettext-domain
  - [x] Add comment to meson.build explaining GETTEXT_PACKAGE
  - [x] Reference verification date and Phase 7
  - [x] Note importance of maintaining consistency

- [x] 5.4 Test string extraction
  - [x] Run `ninja -C build keysmith-pot`
  - [x] Verify command succeeds without errors
  - [x] Check that .pot file is generated/updated
  - [x] Verify new warning strings appear in .pot
  - [x] Confirm source file references are correct

## 6. Testing and Validation

- [x] 6.1 Manual testing: Warning dialog flow
  - [x] Test selecting QR backup shows warning dialog
  - [x] Test clicking "Cancel" reverts to previous type
  - [x] Test clicking "Proceed Anyway" allows QR selection
  - [x] Test pressing Escape cancels properly
  - [x] Test dialog is modal (blocks parent)
  - [x] Test dialog doesn't stack on rapid selections

- [x] 6.2 Manual testing: Visual indicators
  - [x] Verify warning label appears for QR option
  - [x] Verify warning color is visible in light theme
  - [x] Verify warning color is visible in dark theme
  - [x] Verify no warnings for encrypted/Shamir/time-lock
  - [x] Check label text is readable and properly sized

- [x] 6.3 Manual testing: Details dialog
  - [x] Create test QR backup
  - [x] Open details for QR backup
  - [x] Verify security warning appears
  - [x] Verify warning is informational only
  - [x] Test can close dialog without acknowledgment
  - [x] Test can restore backup despite warning

- [x] 6.4 Manual testing: Session state management
  - [x] Select QR, proceed through warning, create backup
  - [x] Close dialog and reopen
  - [x] Verify warning shows again (not persisted)
  - [x] Test changing types multiple times
  - [x] Verify state resets properly

- [x] 6.5 Manual testing: Internationalization
  - [x] Build with string extraction
  - [x] Verify .pot file contains new strings
  - [x] Check source file references are correct
  - [x] Verify no hardcoded English in conditionals

- [x] 6.6 Build testing
  - [x] Run development build: `./scripts/build.sh --dev`
  - [x] Verify no compilation warnings
  - [x] Run production build: `./scripts/build.sh`
  - [x] Test application launches successfully
  - [x] Test all dialogs open without errors

## 7. Documentation Updates

- [x] 7.1 Update REFACTORING-PLAN.md
  - [x] Mark Phase 7 Section 7.1 (QR warnings) as complete
  - [x] Mark Phase 7 Section 7.3 (i18n verification) as complete
  - [x] Update status indicators to ✅
  - [x] Note verification results for gettext domain

- [x] 7.2 Add implementation notes
  - [x] Document warning dialog pattern for future use
  - [x] Note locations of security warning code
  - [x] Document i18n verification findings
  - [x] Record any deviations from original plan

- [x] 7.3 Update user-facing documentation (if exists)
  - [x] Add notes about QR backup security to user guide
  - [x] Explain why warnings are shown
  - [x] Document secure backup alternatives
  - [x] Provide best practices for QR storage if used

## 8. Code Review and Cleanup

- [x] 8.1 Code review checklist
  - [x] Verify all _() translations are present
  - [x] Check for memory leaks in dialog handling
  - [x] Ensure proper signal disconnection
  - [x] Verify no hardcoded strings
  - [x] Check consistent error handling

- [x] 8.2 Remove debugging code
  - [x] Remove any console.log or debug prints
  - [x] Remove commented-out code
  - [x] Clean up temporary test code

- [x] 8.3 Code style consistency
  - [x] Verify Vala coding style is followed
  - [x] Check proper indentation
  - [x] Ensure consistent naming conventions
  - [x] Add documentation comments for new methods

## Dependencies

- **Requires**: CreateBackupDialog.vala, EmergencyBackupDetailsDialog.vala implementations
- **Requires**: EmergencyVault backup type definitions
- **Blocks**: None (can be implemented independently)
- **Parallel work possible**: Tasks 1-3 can be developed in parallel
- **Sequential requirements**: Task 4 (i18n) should be done after Task 1 (dialog) for accurate string extraction

## Estimated Effort

- **Total time**: 2 hours (as per Phase 7 plan)
- **Task 1**: 30 minutes (warning dialog)
- **Task 2**: 15 minutes (visual indicators)
- **Task 3**: 30 minutes (details dialog)
- **Task 4**: 15 minutes (i18n marking)
- **Task 5**: 15 minutes (verification)
- **Task 6**: 30 minutes (testing)
- **Task 7-8**: 15 minutes (documentation and cleanup)

## Validation Checklist

Before marking this change complete, verify:

- [x] All warning strings are translated with _()
- [x] Warning dialog blocks QR backup until acknowledged
- [x] Cancel reverts backup type selection
- [x] Visual indicators appear correctly
- [x] Details dialog shows security info
- [x] Gettext domain verified consistent
- [x] String extraction succeeds
- [x] No build warnings or errors
- [x] Manual testing passes all scenarios
- [x] Documentation updated
