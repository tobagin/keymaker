# Known Hosts Management Specification

## ADDED Requirements

### Requirement: Known Hosts File Parsing
The system SHALL parse and load entries from the `~/.ssh/known_hosts` file, supporting all standard OpenSSH known_hosts formats including hashed hostnames, multiple host aliases, and various key types (RSA, ECDSA, Ed25519).

#### Scenario: Load known hosts file
- **WHEN** the known hosts manager is initialized
- **THEN** all entries from `~/.ssh/known_hosts` SHALL be parsed and loaded into memory
- **AND** parsing errors SHALL be logged without failing the entire load operation

#### Scenario: Handle hashed hostnames
- **WHEN** parsing entries with hashed hostnames (|1|...)
- **THEN** the system SHALL preserve the hashed format
- **AND** display a sanitized representation in the UI (e.g., "hashed:abc123...")

#### Scenario: Support multiple key types
- **WHEN** loading host entries
- **THEN** the system SHALL support ssh-rsa, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521, ssh-ed25519, and other standard SSH key types
- **AND** display the key type and fingerprint for each entry

### Requirement: View Known Hosts
The system SHALL provide a user interface to view all known hosts with their details including hostname/IP, key type, and fingerprint.

#### Scenario: Display known hosts list
- **WHEN** user navigates to the Known Hosts page
- **THEN** all known hosts SHALL be displayed in a list
- **AND** each entry SHALL show the hostname, key type, and fingerprint
- **AND** entries SHALL be sorted alphabetically by hostname

#### Scenario: Show empty state
- **WHEN** no known hosts exist
- **THEN** an empty state message SHALL be displayed
- **AND** the message SHALL indicate that known hosts will be added automatically when connecting to SSH servers

#### Scenario: Display host key details
- **WHEN** user selects a known host entry
- **THEN** detailed information SHALL be displayed including full hostname, IP addresses, key type, fingerprint (SHA256 and MD5), and date added if available

### Requirement: Remove Known Host Entries
The system SHALL allow users to remove individual known host entries from the known_hosts file.

#### Scenario: Remove single entry
- **WHEN** user selects a known host and clicks remove
- **THEN** a confirmation dialog SHALL be presented
- **AND** upon confirmation, the entry SHALL be removed from `~/.ssh/known_hosts`
- **AND** the UI SHALL be updated to reflect the removal
- **AND** a success toast notification SHALL be displayed

#### Scenario: Remove multiple entries
- **WHEN** user selects multiple known host entries and clicks remove
- **THEN** a confirmation dialog SHALL show the count of entries to be removed
- **AND** upon confirmation, all selected entries SHALL be removed atomically
- **AND** a success notification SHALL indicate the number of entries removed

#### Scenario: Handle removal errors
- **WHEN** removal fails due to file permissions or I/O errors
- **THEN** an error notification SHALL be displayed with the specific error message
- **AND** the UI SHALL remain in a consistent state

### Requirement: Identify Stale Entries
The system SHALL identify and flag potentially stale or invalid known host entries.

#### Scenario: Detect unreachable hosts
- **WHEN** analyzing known hosts
- **THEN** the system SHALL test connectivity to each host
- **AND** mark entries as "potentially stale" if the host is unreachable
- **AND** allow batch removal of all stale entries

#### Scenario: Identify duplicate entries
- **WHEN** multiple entries exist for the same hostname
- **THEN** duplicates SHALL be flagged in the UI
- **AND** users SHALL be offered to merge or remove duplicate entries

### Requirement: Handle Host Key Conflicts
The system SHALL detect and handle host key conflicts (when a host's key changes) with clear warnings and resolution options.

#### Scenario: Detect key conflict
- **WHEN** a connection attempt finds a different key than stored
- **THEN** a warning dialog SHALL be displayed
- **AND** the dialog SHALL show both the stored and presented fingerprints
- **AND** warn about potential man-in-the-middle attacks

#### Scenario: Resolve key conflict
- **WHEN** user chooses to update the host key
- **THEN** the old entry SHALL be removed
- **AND** the new key SHALL be added to known_hosts
- **AND** a backup of the old entry SHALL be logged for audit purposes

#### Scenario: Reject key conflict
- **WHEN** user chooses to reject the new key
- **THEN** the connection SHALL be aborted
- **AND** the original known_hosts entry SHALL remain unchanged

### Requirement: Verify Host Key Fingerprints
The system SHALL provide functionality to verify host key fingerprints against trusted sources.

#### Scenario: Manual verification
- **WHEN** user selects "verify fingerprint" for a host
- **THEN** the system SHALL display the fingerprint in multiple formats (SHA256, MD5)
- **AND** provide a text field to paste the expected fingerprint for comparison
- **AND** show a clear match/mismatch result

#### Scenario: Trusted source verification
- **WHEN** verifying common services (GitHub, GitLab, etc.)
- **THEN** the system SHALL compare against known good fingerprints
- **AND** display verification status (verified, unknown, mismatch)
- **AND** provide links to official fingerprint documentation

### Requirement: Import and Export Known Hosts
The system SHALL allow users to import and export known_hosts files.

#### Scenario: Export known hosts
- **WHEN** user clicks "Export Known Hosts"
- **THEN** a file chooser dialog SHALL be presented
- **AND** the current `~/.ssh/known_hosts` file SHALL be copied to the selected location
- **AND** a success notification SHALL confirm the export

#### Scenario: Import known hosts
- **WHEN** user clicks "Import Known Hosts"
- **THEN** a file chooser dialog SHALL be presented
- **AND** upon selection, the imported file SHALL be validated for correct format
- **AND** entries SHALL be merged with existing known_hosts (no duplicates)
- **AND** a summary dialog SHALL show how many entries were imported

#### Scenario: Handle import errors
- **WHEN** importing an invalid known_hosts file
- **THEN** an error dialog SHALL describe the validation failure
- **AND** no changes SHALL be made to the existing known_hosts file

### Requirement: Merge Duplicate Entries
The system SHALL provide functionality to merge duplicate known host entries for the same hostname.

#### Scenario: Detect mergeable duplicates
- **WHEN** multiple entries exist for the same hostname with different aliases or IPs
- **THEN** the system SHALL identify them as potential duplicates
- **AND** display them grouped in the UI

#### Scenario: Merge entries
- **WHEN** user selects duplicate entries and clicks merge
- **THEN** a dialog SHALL show the proposed merged entry
- **AND** allow user to select which aliases and IPs to keep
- **AND** replace all original entries with the merged entry in known_hosts
- **AND** display a success notification

### Requirement: Search and Filter
The system SHALL provide search and filter functionality for known hosts.

#### Scenario: Search by hostname
- **WHEN** user enters text in the search field
- **THEN** the known hosts list SHALL filter to show only entries matching the hostname or IP
- **AND** search SHALL be case-insensitive
- **AND** partial matches SHALL be included

#### Scenario: Filter by key type
- **WHEN** user selects a key type filter (RSA, ECDSA, Ed25519)
- **THEN** only entries with that key type SHALL be displayed
- **AND** the filter SHALL combine with search terms if both are active

#### Scenario: Filter by status
- **WHEN** user selects a status filter (stale, verified, conflict)
- **THEN** only entries matching that status SHALL be displayed
- **AND** the count of filtered entries SHALL be shown
