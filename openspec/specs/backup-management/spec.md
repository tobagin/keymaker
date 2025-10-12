# backup-management Specification

## Purpose
TBD - created by archiving change complete-backup-features. Update Purpose after archive.
## Requirements
### Requirement: Bulk Regular Backup Deletion
The system SHALL provide functionality to delete all regular backups in a single operation.

#### Scenario: Remove all regular backups with confirmation
- **GIVEN** user has multiple regular backups
- **WHEN** user selects "Remove all regular backups"
- **THEN** system SHALL display confirmation dialog
- **AND** SHALL list count of backups to be deleted
- **AND** SHALL warn that operation cannot be undone

#### Scenario: Successfully remove all regular backups
- **GIVEN** user confirms deletion of all regular backups
- **WHEN** deletion operation executes
- **THEN** system SHALL delete all regular backup files from filesystem
- **AND** SHALL update backup metadata
- **AND** SHALL refresh backup list UI
- **AND** SHALL display success toast notification

#### Scenario: Handle partial deletion failures
- **GIVEN** user confirms deletion of all regular backups
- **WHEN** some backup files fail to delete due to permissions or locks
- **THEN** system SHALL delete all accessible backups
- **AND** SHALL report which backups could not be deleted
- **AND** SHALL display error dialog with specific failure details

### Requirement: Bulk Emergency Backup Deletion with Authentication
The system SHALL require authentication before deleting all emergency backups.

#### Scenario: Request to delete all emergency backups
- **GIVEN** user has multiple emergency backups
- **WHEN** user selects "Remove all emergency backups"
- **THEN** system SHALL display warning dialog
- **AND** SHALL explain authentication requirement
- **AND** SHALL provide option to cancel or continue

#### Scenario: Authenticate for bulk emergency deletion
- **GIVEN** user chooses to continue with deletion
- **WHEN** authentication dialog is presented
- **THEN** system SHALL prompt for passphrase or PIN
- **AND** SHALL display backup count to be deleted
- **AND** SHALL warn about irreversibility
- **AND** SHALL implement rate limiting after 3 failed attempts

#### Scenario: Successfully delete all emergency backups
- **GIVEN** user provides correct authentication
- **WHEN** deletion operation executes
- **THEN** system SHALL verify authentication with EmergencyVault
- **AND** SHALL delete all emergency backup files
- **AND** SHALL update vault metadata
- **AND** SHALL refresh emergency backups list
- **AND** SHALL display success toast notification

#### Scenario: Failed authentication for deletion
- **GIVEN** user provides incorrect authentication
- **WHEN** authentication is verified
- **THEN** system SHALL display error message
- **AND** SHALL NOT delete any backups
- **AND** SHALL increment failed attempt counter
- **AND** SHALL enforce rate limiting after threshold

### Requirement: Regular Backup Details View
The system SHALL display comprehensive details for regular backups.

#### Scenario: View regular backup metadata
- **GIVEN** user selects a regular backup
- **WHEN** user clicks "View Details"
- **THEN** system SHALL display backup details dialog
- **AND** SHALL show backup name
- **AND** SHALL show creation date and time
- **AND** SHALL show file size in human-readable format
- **AND** SHALL show count of keys included in backup

#### Scenario: View backup type and encryption status
- **GIVEN** backup details dialog is open
- **WHEN** viewing backup information
- **THEN** system SHALL display backup type (encrypted archive, export bundle, or cloud sync)
- **AND** SHALL indicate whether backup is encrypted
- **AND** SHALL show checksum for integrity verification
- **AND** SHALL display cloud provider if applicable

#### Scenario: View included keys list
- **GIVEN** backup details dialog is open
- **WHEN** viewing backup contents
- **THEN** system SHALL list all key fingerprints included in backup
- **AND** SHALL show key type for each fingerprint
- **AND** SHALL indicate if key still exists in ~/.ssh

#### Scenario: Restore from details dialog
- **GIVEN** backup details dialog is open
- **WHEN** user clicks "Restore" button
- **THEN** system SHALL launch restore backup dialog
- **AND** SHALL pre-populate with selected backup
- **AND** SHALL close details dialog

#### Scenario: Delete from details dialog
- **GIVEN** backup details dialog is open
- **WHEN** user clicks "Delete" button
- **THEN** system SHALL display confirmation dialog
- **AND** SHALL proceed with single backup deletion on confirmation

### Requirement: Emergency Backup Details View
The system SHALL display comprehensive details for emergency backups including security method information.

#### Scenario: View emergency backup basic information
- **GIVEN** user selects an emergency backup
- **WHEN** user clicks "View Details"
- **THEN** system SHALL display emergency backup details dialog
- **AND** SHALL show backup name
- **AND** SHALL show creation date and time
- **AND** SHALL show backup type (QR code, Shamir secret, or time-lock)

#### Scenario: View QR backup security warning
- **GIVEN** emergency backup uses QR code method
- **WHEN** viewing backup details
- **THEN** system SHALL display security warning
- **AND** SHALL explain that QR codes contain unencrypted private keys
- **AND** SHALL recommend secure storage of QR images

#### Scenario: View Shamir secret sharing details
- **GIVEN** emergency backup uses Shamir secret sharing
- **WHEN** viewing backup details
- **THEN** system SHALL display threshold information (M-of-N shares)
- **AND** SHALL indicate number of shares required for restoration
- **AND** SHALL show total number of shares created

#### Scenario: View time-lock countdown
- **GIVEN** emergency backup uses time-lock method
- **WHEN** viewing backup details
- **THEN** system SHALL calculate and display time remaining until unlock
- **AND** SHALL update countdown in real-time
- **AND** SHALL indicate if backup is currently unlocked
- **AND** SHALL show original lock duration

#### Scenario: Actions from emergency details dialog
- **GIVEN** emergency backup details dialog is open
- **WHEN** user interacts with action buttons
- **THEN** system SHALL provide "Restore" button
- **AND** SHALL provide "Delete" button
- **AND** SHALL provide "Close" button
- **AND** SHALL handle each action appropriately

### Requirement: Authentication Dialog for Emergency Operations
The system SHALL provide secure authentication for emergency backup deletion.

#### Scenario: Present authentication dialog
- **GIVEN** user initiates emergency backup deletion
- **WHEN** authentication dialog is displayed
- **THEN** system SHALL show secure passphrase entry field
- **AND** SHALL mask passphrase input
- **AND** SHALL display backup name being deleted
- **AND** SHALL show warning about irreversibility

#### Scenario: Rate limiting after failed attempts
- **GIVEN** user has failed authentication 3 times
- **WHEN** attempting another authentication
- **THEN** system SHALL impose 30-second cooldown period
- **AND** SHALL display remaining cooldown time
- **AND** SHALL disable authentication submission during cooldown

#### Scenario: Verify authentication credentials
- **GIVEN** user submits authentication credentials
- **WHEN** verification occurs
- **THEN** system SHALL validate against EmergencyVault
- **AND** SHALL use same authentication method as backup restoration
- **AND** SHALL clear credentials from memory immediately after verification

#### Scenario: Successful authentication flow
- **GIVEN** user provides correct authentication
- **WHEN** authentication succeeds
- **THEN** system SHALL proceed with deletion operation
- **AND** SHALL close authentication dialog
- **AND** SHALL reset failed attempt counter

#### Scenario: Failed authentication handling
- **GIVEN** user provides incorrect authentication
- **WHEN** authentication fails
- **THEN** system SHALL display error message
- **AND** SHALL increment failed attempt counter
- **AND** SHALL keep authentication dialog open
- **AND** SHALL allow retry unless rate limited

### Requirement: Backup Operations Integration
Backend services SHALL support bulk operations and detailed metadata retrieval.

#### Scenario: BackupManager provides bulk deletion
- **GIVEN** BackupManager is initialized
- **WHEN** `remove_all_regular_backups()` is called
- **THEN** BackupManager SHALL iterate through all regular backups
- **AND** SHALL delete each backup file from filesystem
- **AND** SHALL remove entries from metadata
- **AND** SHALL emit `backup_manager_status_changed` signal
- **AND** SHALL return count of successfully deleted backups

#### Scenario: EmergencyVault provides authenticated bulk deletion
- **GIVEN** EmergencyVault is initialized
- **WHEN** `remove_all_emergency_backups(passphrase)` is called with valid credentials
- **THEN** EmergencyVault SHALL verify passphrase
- **AND** SHALL delete all emergency backup files
- **AND** SHALL update vault metadata
- **AND** SHALL return success status

#### Scenario: Retrieve backup metadata for details view
- **GIVEN** a specific backup entry
- **WHEN** UI requests detailed information
- **THEN** system SHALL provide all stored metadata
- **AND** SHALL calculate derived information (time remaining for time-locks)
- **AND** SHALL validate file existence on filesystem

