# ui-components Specification Delta

## MODIFIED Requirements

### Requirement: Application Window Title with SSHer
All application windows SHALL display "SSHer" as the application name in window titles and decorations.

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
