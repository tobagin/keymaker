# Cloud Provider Integration Specification (Phase 8)

## ADDED Requirements

### Requirement: Key Sync Status Detection
The system SHALL analyze local and cloud keys to determine sync status.

#### Scenario: Fingerprint-based matching
- **WHEN** comparing local and cloud keys
- **THEN** the system SHALL compute SHA256 fingerprints and match keys regardless of filename or comment differences

#### Scenario: Synced state detection
- **WHEN** local key and cloud key have matching fingerprints
- **THEN** the system SHALL mark key as "Synced" with green ✓ badge

#### Scenario: Local-only state detection
- **WHEN** local key fingerprint not found in cloud key list
- **THEN** the system SHALL mark key as "Local-only" with blue ↑ badge labeled "Upload"

#### Scenario: Cloud-only state detection
- **WHEN** cloud key fingerprint not found in local keys
- **THEN** the system SHALL mark key as "Cloud-only" with orange ↓ badge labeled "Import"

#### Scenario: Conflict state detection
- **WHEN** local and cloud keys have same filename but different fingerprints
- **THEN** the system SHALL mark key as "Conflict" with red ⚠ badge

### Requirement: Import Key from Cloud
The system SHALL allow users to import public keys from cloud to local `~/.ssh/` directory.

#### Scenario: Import initiation
- **WHEN** user clicks "Import" on cloud-only key
- **THEN** the system SHALL download public key from cloud provider API

#### Scenario: Private key validation
- **WHEN** importing public key
- **THEN** the system SHALL search `~/.ssh/` for corresponding private key with matching fingerprint

#### Scenario: Import with private key present
- **WHEN** private key with matching fingerprint is found
- **THEN** the system SHALL save public key to `~/.ssh/<keyname>.pub` and update sync status to "Synced"

#### Scenario: Import without private key
- **WHEN** private key with matching fingerprint is NOT found
- **THEN** the system SHALL show warning "Cannot import: Private key not found locally. This key cannot be used for authentication." and abort import

#### Scenario: Import filename conflict
- **WHEN** importing public key with filename that already exists locally (different fingerprint)
- **THEN** the system SHALL prompt user to rename imported key (e.g., `work_key_github.pub`) or cancel

### Requirement: Conflict Resolution
The system SHALL provide conflict resolution UI when local and cloud keys have same name but different fingerprints.

#### Scenario: Conflict dialog display
- **WHEN** user clicks conflict badge
- **THEN** the system SHALL show dialog comparing local and cloud keys side-by-side with fingerprints, creation dates

#### Scenario: Keep Local resolution
- **WHEN** user selects "Keep Local" in conflict dialog
- **THEN** the system SHALL upload local key to cloud, overwriting cloud key

#### Scenario: Keep Cloud resolution
- **WHEN** user selects "Keep Cloud" in conflict dialog
- **THEN** the system SHALL rename local key to `<name>.old.pub` and import cloud key

#### Scenario: Keep Both resolution
- **WHEN** user selects "Keep Both" in conflict dialog
- **THEN** the system SHALL import cloud key with renamed filename (e.g., `<name>_github.pub`) preserving local key

### Requirement: Sync Manager
The system SHALL provide SyncManager class to orchestrate sync operations across providers.

#### Scenario: Sync status analysis
- **WHEN** `SyncManager.analyze(provider, account)` is called
- **THEN** the system SHALL return SyncStatus object containing synced, local_only, cloud_only, and conflicts lists

#### Scenario: Import operation
- **WHEN** `SyncManager.import_key(provider, cloud_key_id)` is called
- **THEN** the system SHALL download public key, validate private key, and save to `~/.ssh/`

#### Scenario: Upload operation
- **WHEN** `SyncManager.upload_key(provider, local_key_path)` is called
- **THEN** the system SHALL deploy local public key to cloud using existing deploy_key() logic

### Requirement: Sync All Operation
The system SHALL provide batch sync capability to reconcile all keys at once.

#### Scenario: Sync All summary display
- **WHEN** user clicks "Sync All" button
- **THEN** the system SHALL show summary dialog: "5 synced, 2 local-only, 1 cloud-only, 1 conflict"

#### Scenario: Sync All execution
- **WHEN** user confirms "Sync All"
- **THEN** the system SHALL upload all local-only keys, prompt for each cloud-only key import, and prompt for each conflict resolution

#### Scenario: Sync All progress tracking
- **WHEN** Sync All is running
- **THEN** the system SHALL show progress indicator "Syncing... (5/9 keys processed)"

#### Scenario: Sync All completion
- **WHEN** Sync All completes
- **THEN** the system SHALL show summary: "Sync complete: 8/9 keys synced, 1 conflict needs manual resolution"

### Requirement: Sync Status UI Integration
The system SHALL display sync status badges in Cloud Providers page key list.

#### Scenario: Badge display on keys
- **WHEN** key list is displayed after sync analysis
- **THEN** each key SHALL show appropriate badge (✓ Synced, ↑ Upload, ↓ Import, ⚠ Conflict)

#### Scenario: Badge click action
- **WHEN** user clicks badge
- **THEN** the system SHALL perform corresponding action: upload for local-only, import for cloud-only, resolve for conflict

#### Scenario: Sync status refresh
- **WHEN** user clicks "Refresh" button on provider card
- **THEN** the system SHALL re-analyze sync status and update badges

#### Scenario: Hide badges when sync disabled
- **WHEN** user has disabled two-way sync in preferences
- **THEN** the system SHALL hide all sync badges and show keys without status indicators

### Requirement: Sync History Tracking
The system SHALL track sync history for each key.

#### Scenario: Record sync timestamp
- **WHEN** key is synced (uploaded or imported)
- **THEN** the system SHALL store timestamp and direction in GSettings `cloud-sync-history`

#### Scenario: Display last synced time
- **WHEN** user hovers over synced badge
- **THEN** tooltip SHALL show "Last synced: 2 hours ago (uploaded)" or "Last synced: 1 day ago (imported)"

#### Scenario: Sync history persistence
- **WHEN** app restarts
- **THEN** the system SHALL load sync history from GSettings and display last synced times

### Requirement: Automatic Sync Detection
The system SHALL automatically detect sync status without user intervention.

#### Scenario: Auto-detect on refresh
- **WHEN** user refreshes cloud key list
- **THEN** the system SHALL automatically analyze sync status and update badges

#### Scenario: Auto-detect on page load
- **WHEN** user navigates to Cloud Providers page
- **THEN** the system SHALL run sync analysis in background and show loading indicator

#### Scenario: Background analysis performance
- **WHEN** analyzing sync status for 50 keys
- **THEN** the operation SHALL complete within 1 second without blocking UI

### Requirement: Sync Exclusion
The system SHALL allow users to exclude specific keys from sync operations.

#### Scenario: Ignore key from sync
- **WHEN** user right-clicks key and selects "Don't sync this key"
- **THEN** the system SHALL add key to exclusion list and remove sync badge

#### Scenario: Unignore key
- **WHEN** user right-clicks ignored key and selects "Resume syncing"
- **THEN** the system SHALL remove key from exclusion list and re-analyze sync status

#### Scenario: Exclusion list persistence
- **WHEN** keys are ignored
- **THEN** the system SHALL store exclusion list in GSettings `cloud-sync-exclusions`

### Requirement: Sync Preferences
The system SHALL provide user preferences for sync behavior.

#### Scenario: Enable/disable two-way sync
- **WHEN** user toggles "Enable two-way sync" in preferences
- **THEN** the system SHALL show/hide sync badges and sync buttons

#### Scenario: Sync confirmation prompts
- **WHEN** user enables "Always confirm before syncing" preference
- **THEN** the system SHALL show confirmation dialog for every sync operation (upload, import, conflict)

#### Scenario: Automatic sync on refresh
- **WHEN** user enables "Auto-sync on refresh" preference (experimental)
- **THEN** the system SHALL automatically upload local-only keys and import cloud-only keys without prompts (conflicts still require manual resolution)

### Requirement: Security and Safety
The system SHALL ensure safe sync operations that never lose data.

#### Scenario: Never overwrite without confirmation
- **WHEN** sync operation would overwrite existing file
- **THEN** the system SHALL prompt user for confirmation with clear warning

#### Scenario: Backup before conflict resolution
- **WHEN** resolving conflict with "Keep Cloud" option
- **THEN** the system SHALL create backup of local key as `<name>.backup.YYYY-MM-DD.pub` before renaming

#### Scenario: Public key only downloads
- **WHEN** importing key from cloud
- **THEN** the system SHALL only download public key, never attempt to download private key

#### Scenario: Private key validation
- **WHEN** importing public key
- **THEN** the system SHALL verify private key exists and matches fingerprint before completing import
