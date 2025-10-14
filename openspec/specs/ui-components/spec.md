# ui-components Specification

## Purpose
TBD - created by archiving change complete-backup-features. Update Purpose after archive.
## Requirements
### Requirement: Toast Notification System
The system SHALL display toast notifications for user feedback across all dialogs.

#### Scenario: Toast displays in GenerateDialog
- **GIVEN** GenerateDialog is open
- **WHEN** key generation completes successfully
- **THEN** system SHALL display toast notification
- **AND** toast SHALL show success message
- **AND** toast SHALL auto-dismiss after 5 seconds
- **AND** toast SHALL appear at bottom of dialog

#### Scenario: Toast overlay properly initialized
- **GIVEN** any dialog using toast notifications
- **WHEN** dialog is constructed
- **THEN** Adw.ToastOverlay SHALL be initialized
- **AND** toast_overlay SHALL be added to widget hierarchy
- **AND** toast_overlay SHALL wrap dialog content
- **AND** toast methods SHALL be accessible

#### Scenario: Display toast with custom message
- **GIVEN** any component with toast support
- **WHEN** `show_toast(message)` is called
- **THEN** system SHALL create Adw.Toast with message
- **AND** SHALL add toast to overlay
- **AND** SHALL set timeout to 5 seconds
- **AND** toast SHALL be visible and readable

#### Scenario: Multiple toasts queue correctly
- **GIVEN** multiple toast notifications triggered in quick succession
- **WHEN** toasts are added to overlay
- **THEN** system SHALL queue toasts
- **AND** SHALL display one toast at a time
- **AND** SHALL maintain chronological order
- **AND** previous toast SHALL complete before showing next

### Requirement: Backup Details Dialog Component
The system SHALL provide a reusable dialog component for displaying backup details.

#### Scenario: Dialog displays all required fields
- **GIVEN** BackupDetailsDialog is instantiated with RegularBackupEntry
- **WHEN** dialog is presented
- **THEN** dialog SHALL display backup name as title
- **AND** SHALL show creation date in human-readable format
- **AND** SHALL show file size with appropriate units (KB, MB, GB)
- **AND** SHALL show count of keys included
- **AND** SHALL show backup type
- **AND** SHALL show encryption status
- **AND** SHALL show checksum

#### Scenario: Dialog shows cloud sync status
- **GIVEN** backup is cloud sync type
- **WHEN** dialog displays information
- **THEN** dialog SHALL show cloud provider name
- **AND** SHALL show last sync timestamp
- **AND** SHALL indicate if backup needs syncing
- **AND** SHALL provide "Sync Now" action if applicable

#### Scenario: Dialog lists included keys
- **GIVEN** backup contains multiple keys
- **WHEN** viewing keys section
- **THEN** dialog SHALL display scrollable list of key fingerprints
- **AND** SHALL show key type for each entry
- **AND** SHALL indicate if key exists in current ~/.ssh directory
- **AND** SHALL use monospace font for fingerprints

#### Scenario: Dialog action buttons work correctly
- **GIVEN** BackupDetailsDialog is open
- **WHEN** user clicks action buttons
- **THEN** "Restore" button SHALL trigger restore workflow
- **AND** "Delete" button SHALL trigger deletion confirmation
- **AND** "Close" button SHALL dismiss dialog
- **AND** dialog SHALL properly clean up resources on close

### Requirement: Emergency Backup Details Dialog Component
The system SHALL provide a specialized dialog for emergency backup details with security information.

#### Scenario: Dialog displays emergency-specific fields
- **GIVEN** EmergencyBackupDetailsDialog is instantiated with EmergencyBackupEntry
- **WHEN** dialog is presented
- **THEN** dialog SHALL display backup name as title
- **AND** SHALL show creation date
- **AND** SHALL show backup type (QR, Shamir, Time-lock)
- **AND** SHALL display appropriate security warnings

#### Scenario: QR backup shows security warning
- **GIVEN** emergency backup uses QR code method
- **WHEN** viewing details
- **THEN** dialog SHALL display prominent warning banner
- **AND** warning SHALL explain unencrypted nature
- **AND** warning SHALL use destructive appearance (red/orange)
- **AND** warning SHALL recommend secure storage practices

#### Scenario: Shamir backup shows threshold details
- **GIVEN** emergency backup uses Shamir secret sharing
- **WHEN** viewing details
- **THEN** dialog SHALL display M-of-N threshold clearly
- **AND** SHALL explain how many shares needed
- **AND** SHALL list total shares created
- **AND** SHALL show share distribution if tracked

#### Scenario: Time-lock shows countdown timer
- **GIVEN** emergency backup uses time-lock method
- **WHEN** viewing details
- **THEN** dialog SHALL display real-time countdown
- **AND** countdown SHALL update every second
- **AND** SHALL show remaining time in appropriate units (days, hours, minutes)
- **AND** SHALL indicate "UNLOCKED" when time expires
- **AND** SHALL show original lock duration for reference

#### Scenario: Dialog updates dynamically
- **GIVEN** EmergencyBackupDetailsDialog is open with time-locked backup
- **WHEN** countdown reaches zero
- **THEN** dialog SHALL update to show unlocked status
- **AND** SHALL change countdown display to "UNLOCKED"
- **AND** SHALL update action button states if applicable

### Requirement: Authentication Dialog Component
The system SHALL provide a secure authentication dialog for emergency backup operations.

#### Scenario: Dialog presents secure input
- **GIVEN** EmergencyBackupAuthDialog is instantiated
- **WHEN** dialog is presented
- **THEN** dialog SHALL show passphrase entry field
- **AND** entry field SHALL use password mode (masked input)
- **AND** dialog SHALL show "Show Password" toggle option
- **AND** dialog SHALL display backup name being accessed

#### Scenario: Dialog shows destructive warning
- **GIVEN** authentication is for deletion operation
- **WHEN** dialog is displayed
- **THEN** dialog SHALL show warning banner
- **AND** warning SHALL state operation is irreversible
- **AND** warning SHALL use destructive appearance
- **AND** warning SHALL be impossible to miss

#### Scenario: Rate limiting UI feedback
- **GIVEN** user has exceeded failed attempt limit
- **WHEN** cooldown is active
- **THEN** dialog SHALL disable submit button
- **AND** SHALL display cooldown timer
- **AND** SHALL update remaining seconds in real-time
- **AND** SHALL re-enable submission when cooldown expires

#### Scenario: Failed attempt feedback
- **GIVEN** user submits incorrect credentials
- **WHEN** authentication fails
- **THEN** dialog SHALL show error message
- **AND** SHALL keep input field focused
- **AND** SHALL clear password field for security
- **AND** SHALL increment visible attempt counter
- **AND** SHALL add shake animation to dialog

#### Scenario: Successful authentication flow
- **GIVEN** user submits correct credentials
- **WHEN** authentication succeeds
- **THEN** dialog SHALL close immediately
- **AND** SHALL trigger success callback
- **AND** SHALL clear sensitive data from memory
- **AND** SHALL NOT display success message (operation proceeds silently)

### Requirement: Dialog Consistency and Accessibility
All custom dialogs SHALL follow Adwaita design guidelines and accessibility standards.

#### Scenario: Dialogs use consistent styling
- **GIVEN** any custom dialog component
- **WHEN** dialog is displayed
- **THEN** dialog SHALL use Adw.Dialog as base
- **AND** SHALL follow Adwaita spacing guidelines
- **AND** SHALL use system font and colors
- **AND** SHALL respond to dark mode preferences

#### Scenario: Dialogs support keyboard navigation
- **GIVEN** any custom dialog is open
- **WHEN** user presses Tab key
- **THEN** focus SHALL move through interactive elements in logical order
- **AND** Escape key SHALL close dialog (unless confirmation required)
- **AND** Enter key SHALL activate default button
- **AND** all buttons SHALL be keyboard accessible

#### Scenario: Dialogs support screen readers
- **GIVEN** any custom dialog is open
- **WHEN** using screen reader software
- **THEN** dialog title SHALL be announced
- **AND** all form fields SHALL have proper labels
- **AND** error messages SHALL be associated with relevant fields
- **AND** action buttons SHALL have descriptive accessible names

#### Scenario: Dialogs adapt to screen size
- **GIVEN** any custom dialog
- **WHEN** displayed on different screen sizes
- **THEN** dialog SHALL use responsive layout
- **AND** SHALL scroll content if needed
- **AND** SHALL maintain minimum readable size
- **AND** SHALL not exceed maximum width on large screens

### Requirement: Dialog Resource Management
Dialogs SHALL properly manage resources and prevent memory leaks.

#### Scenario: Dialog cleans up on close
- **GIVEN** any custom dialog is open
- **WHEN** dialog is closed by any method
- **THEN** dialog SHALL disconnect all signal handlers
- **AND** SHALL clear sensitive data (passwords)
- **AND** SHALL stop any active timers (countdowns)
- **AND** SHALL release references to large objects

#### Scenario: Multiple dialog instances
- **GIVEN** dialog type supports multiple instances
- **WHEN** multiple instances are created
- **THEN** each instance SHALL be independent
- **AND** SHALL not interfere with other instances
- **AND** SHALL properly clean up when closed
- **AND** SHALL not cause memory leaks

### Requirement: Shared Backup Operation Helpers
The system SHALL provide reusable helper functions for common backup operations.

#### Scenario: Format backup metadata consistently
- **GIVEN** backup metadata to display
- **WHEN** formatting for UI display
- **THEN** helper SHALL format file sizes with appropriate units
- **AND** SHALL format dates in locale-aware manner
- **AND** SHALL format fingerprints with consistent spacing
- **AND** SHALL handle null/missing fields gracefully

#### Scenario: Common confirmation dialogs
- **GIVEN** backup deletion operation
- **WHEN** confirmation is needed
- **THEN** helper SHALL create consistent confirmation dialog
- **AND** dialog SHALL use destructive appearance for delete action
- **AND** dialog SHALL show affected item details
- **AND** dialog SHALL provide cancel option as default

#### Scenario: Error message consistency
- **GIVEN** backup operation fails
- **WHEN** displaying error to user
- **THEN** helper SHALL format error consistently
- **AND** SHALL provide actionable error messages
- **AND** SHALL include relevant details (filename, error reason)
- **AND** SHALL suggest remediation when possible


### Requirement: Application Window Title with SSHer
All application windows SHALL display "SSHer" as the application name in window titles and decorations.

**Context**: Implemented in change 2025-10-13-rename-app-to-ssher. Application rebranded from "Key Maker" to "SSHer".

#### Scenario: Main window displays SSHer title
- **GIVEN** the main application window
- **WHEN** application launches
- **THEN** window title SHALL display "SSHer"
- **AND** window decoration SHALL use Config.APP_NAME
- **AND** title bar SHALL show "SSHer" consistently

#### Scenario: Development build window title distinction
- **GIVEN** development build of the application
- **WHEN** application launches in development mode
- **THEN** window title SHALL display "SSHer (Devel)"
- **AND** users SHALL clearly identify development builds
- **AND** window decoration SHALL reflect development status

### Requirement: About Dialog Branding Update
The About dialog SHALL display "SSHer" as the application name with appropriate metadata.

**Context**: Part of 2025-10-13-rename-app-to-ssher change. Ensures consistent branding in About dialog.

#### Scenario: About dialog shows SSHer name
- **GIVEN** the About dialog implementation
- **WHEN** user opens About dialog
- **THEN** application name SHALL display as "SSHer"
- **AND** version information SHALL be preserved
- **AND** copyright notice SHALL reference "SSHer"
- **AND** description SHALL reference "SSHer" appropriately

#### Scenario: About dialog comments reference SSHer
- **GIVEN** About dialog configuration
- **WHEN** displaying application description
- **THEN** comments SHALL describe "SSHer" functionality
- **AND** description SHALL remain accurate and clear
- **AND** SHALL NOT reference "Key Maker"

### Requirement: Help and Documentation UI References
All help dialogs and documentation links SHALL reference "SSHer" consistently.

**Context**: Part of 2025-10-13-rename-app-to-ssher change. Ensures help content uses correct application name.

#### Scenario: Help dialog references SSHer
- **GIVEN** the Help dialog or help content
- **WHEN** user accesses help resources
- **THEN** application name SHALL be "SSHer"
- **AND** help text SHALL reference "SSHer" consistently
- **AND** documentation links SHALL point to correct resources

#### Scenario: Keyboard shortcuts dialog shows SSHer
- **GIVEN** the keyboard shortcuts dialog
- **WHEN** user opens shortcuts reference
- **THEN** dialog title SHALL reference "SSHer"
- **AND** shortcut descriptions SHALL use "SSHer" where applicable
- **AND** branding SHALL be consistent

### Requirement: Preferences and Settings UI
Preferences and settings dialogs SHALL reference "SSHer" in relevant contexts.

**Context**: Part of 2025-10-13-rename-app-to-ssher change. Ensures settings UI uses updated branding.

#### Scenario: Preferences dialog references SSHer
- **GIVEN** the preferences dialog
- **WHEN** user opens application preferences
- **THEN** dialog SHALL reference "SSHer" in appropriate contexts
- **AND** settings descriptions SHALL use consistent naming
- **AND** user SHALL recognize the application clearly

#### Scenario: Toast notifications use SSHer
- **GIVEN** toast notification messages
- **WHEN** application displays notifications
- **THEN** application name SHALL be "SSHer" where used
- **AND** notification text SHALL be consistent
- **AND** branding SHALL be professional
