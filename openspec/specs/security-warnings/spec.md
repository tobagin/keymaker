# security-warnings Specification

## Purpose

This specification defines the security warning system for QR backup operations in KeyMaker. QR backups store SSH private keys as unencrypted base64 data, presenting security risks if users are unaware. This specification ensures users receive clear warnings and visual indicators before creating QR backups and when viewing existing QR backup details.

Created from add-security-warnings change (2025-10-12).

## Requirements

### Requirement: QR Backup Security Warning Dialog
The system SHALL display a security warning dialog when users select QR backup as their emergency backup method, requiring explicit acknowledgment before proceeding.

#### Scenario: User selects QR backup type
- **GIVEN** user opens Create Backup Dialog
- **WHEN** user selects "QR Code" as backup type from dropdown
- **THEN** system SHALL display Adw.MessageDialog with security warning
- **AND** SHALL set dialog title to "QR Backup Security Warning"
- **AND** SHALL display message explaining unencrypted nature of QR backups
- **AND** SHALL provide "Cancel" and "Proceed Anyway" response options

#### Scenario: Warning message content
- **GIVEN** QR backup security warning dialog is displayed
- **WHEN** user reads the warning message
- **THEN** message SHALL state "QR backups store your private keys as unencrypted base64 data"
- **AND** SHALL explain "Anyone who gains access to the QR code can read your private key"
- **AND** SHALL recommend "For maximum security, use encrypted archive backups instead"
- **AND** SHALL ask "Do you want to proceed with QR backup?"

#### Scenario: Warning dialog styling and defaults
- **GIVEN** QR backup security warning dialog is displayed
- **WHEN** dialog is presented to user
- **THEN** "Proceed Anyway" button SHALL have destructive appearance (Adw.ResponseAppearance.DESTRUCTIVE)
- **AND** "Cancel" SHALL be the default response
- **AND** "Cancel" SHALL be the safe action highlighting
- **AND** dialog SHALL be modal (blocking parent dialog)

#### Scenario: User cancels QR backup selection
- **GIVEN** QR backup security warning dialog is displayed
- **WHEN** user clicks "Cancel" or presses Escape
- **THEN** system SHALL revert backup type selection to previously selected type
- **AND** SHALL close warning dialog
- **AND** SHALL NOT enable QR backup type
- **AND** SHALL return user to Create Backup Dialog

#### Scenario: User proceeds with QR backup
- **GIVEN** QR backup security warning dialog is displayed
- **WHEN** user clicks "Proceed Anyway"
- **THEN** system SHALL close warning dialog
- **AND** SHALL enable QR backup type selection
- **AND** SHALL allow user to continue with QR backup creation
- **AND** SHALL not show warning again during same dialog session

### Requirement: Visual Warning Indicators in Backup Type Selector
The system SHALL display persistent visual indicators to distinguish secure from insecure backup types in the backup type selection UI.

#### Scenario: Display warning label for QR backup option
- **GIVEN** Create Backup Dialog is open
- **WHEN** backup type dropdown is displayed
- **THEN** system SHALL show warning label below QR backup option
- **AND** label SHALL display "⚠️ Unencrypted - Not recommended for sensitive keys"
- **AND** label SHALL use CSS warning class for styling
- **AND** label SHALL use caption text size

#### Scenario: Visual indicator styling
- **GIVEN** warning label is displayed for QR backup
- **WHEN** UI renders the label
- **THEN** system SHALL apply "warning" CSS class
- **AND** SHALL apply "caption" CSS class for smaller text
- **AND** SHALL use system-defined warning color (typically amber/yellow)
- **AND** SHALL remain visible when option is selected or hovered

#### Scenario: No warning for secure backup types
- **GIVEN** backup type selector displays multiple options
- **WHEN** viewing encrypted archive, Shamir, or time-lock options
- **THEN** system SHALL NOT display warning labels
- **AND** SHALL present these options without visual warnings
- **AND** SHALL treat them as recommended choices

### Requirement: Security Information in Backup Details Dialog
The system SHALL display security information and warnings when users view details of existing QR backups.

#### Scenario: Display QR backup security information
- **GIVEN** user opens details dialog for an emergency backup
- **WHEN** backup type is QR code
- **THEN** system SHALL display security information section
- **AND** SHALL show warning icon (⚠️) or equivalent
- **AND** SHALL explain that QR contains unencrypted private key data
- **AND** SHALL recommend secure storage practices

#### Scenario: Security recommendation content
- **GIVEN** QR backup details dialog shows security information
- **WHEN** user reads the recommendations
- **THEN** system SHALL advise storing QR images securely
- **AND** SHALL warn against cloud photo storage without encryption
- **AND** SHALL suggest physical security for printed QR codes
- **AND** SHALL maintain informational tone (not alarmist)

#### Scenario: No blocking warnings in details view
- **GIVEN** user views details of existing QR backup
- **WHEN** security information is displayed
- **THEN** system SHALL NOT show blocking dialog
- **AND** SHALL NOT require acknowledgment
- **AND** SHALL allow user to close dialog freely
- **AND** SHALL allow restore operation to proceed if selected

#### Scenario: Security info for non-QR backups
- **GIVEN** user opens details dialog for encrypted/Shamir/time-lock backup
- **WHEN** viewing security information section
- **THEN** system SHALL display positive security indicator
- **AND** SHALL show that backup is encrypted or secure
- **AND** SHALL NOT display warnings
- **AND** MAY show security method details (e.g., "256-bit AES encryption")

### Requirement: Warning State Management
The system SHALL properly manage warning state and backup type selection during the warning flow.

#### Scenario: Remember previous selection for reversion
- **GIVEN** user has selected "Encrypted Archive" as backup type
- **WHEN** user changes selection to "QR Code"
- **THEN** system SHALL store previous selection ("Encrypted Archive")
- **AND** SHALL use stored value if user cancels warning
- **AND** SHALL clear stored value if user proceeds with warning

#### Scenario: Handle rapid selection changes
- **GIVEN** user rapidly changes backup type multiple times
- **WHEN** selecting QR code type
- **THEN** system SHALL show warning dialog only once
- **AND** SHALL not stack multiple warning dialogs
- **AND** SHALL ignore additional selection changes while warning is displayed

#### Scenario: Persist choice within dialog session
- **GIVEN** user has proceeded past QR backup warning
- **WHEN** user changes to different type then back to QR code
- **THEN** system SHALL show warning dialog again
- **AND** SHALL require new acknowledgment
- **AND** SHALL not assume previous acceptance applies

#### Scenario: Reset state on dialog close
- **GIVEN** user has completed or cancelled backup creation
- **WHEN** dialog is closed and later reopened
- **THEN** system SHALL reset all warning states
- **AND** SHALL show warnings again for QR selection
- **AND** SHALL not remember previous warning acknowledgments

### Requirement: Internationalization of Warning Messages
The system SHALL ensure all security warning messages are properly internationalized using gettext.

#### Scenario: Warning dialog text marked for translation
- **GIVEN** QR backup security warning is implemented
- **WHEN** code calls dialog creation methods
- **THEN** all user-visible strings SHALL be wrapped with `_()` gettext function
- **AND** SHALL include dialog title in translations
- **AND** SHALL include warning message body in translations
- **AND** SHALL include button labels in translations

#### Scenario: Context-aware translations
- **GIVEN** warning messages may have multiple meanings
- **WHEN** ambiguous terms are used (e.g., "proceed")
- **THEN** system SHOULD use C_() for context if needed
- **AND** SHALL ensure translators understand security context
- **AND** MAY include translator comments for clarity

#### Scenario: String extraction validation
- **GIVEN** warning strings are marked for translation
- **WHEN** running `ninja -C build keysmith-pot`
- **THEN** all warning strings SHALL appear in generated .pot file
- **AND** SHALL include proper source file references
- **AND** SHALL maintain correct gettext domain (keysmith)
