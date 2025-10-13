# Cloud Provider Integration Specification (Phase 7)

## MODIFIED Requirements

### Requirement: Cloud Provider Interface
The system SHALL support multiple accounts per cloud provider with account management capabilities.

#### Scenario: Multiple account registration
- **WHEN** user connects second account for same provider
- **THEN** the system SHALL assign unique UUID and store independently from first account

#### Scenario: Account switching
- **WHEN** user selects different account from dropdown
- **THEN** the system SHALL load that account's keys and update UI

## ADDED Requirements

### Requirement: Account Identification and Storage
The system SHALL assign unique UUIDs to each connected cloud account and store account metadata.

#### Scenario: UUID generation
- **WHEN** new account is connected
- **THEN** the system SHALL generate UUID v4 and use as account identifier

#### Scenario: Account metadata storage
- **WHEN** account is connected
- **THEN** the system SHALL store account info in GSettings array: id, label, username, created_at, last_used

#### Scenario: Token storage with account ID
- **WHEN** storing OAuth token or credentials
- **THEN** the system SHALL include `account_id` attribute in Secret Service entry

### Requirement: Active Account Tracking
The system SHALL track active account per provider and restore on app restart.

#### Scenario: Active account persistence
- **WHEN** user switches account
- **THEN** the system SHALL store active account UUID in GSettings `cloud-provider-<provider>-active-account`

#### Scenario: Active account restoration
- **WHEN** app starts
- **THEN** the system SHALL load last active account for each provider and display its keys

### Requirement: Account Switcher UI
The system SHALL provide account switcher dropdown in each provider card.

#### Scenario: Account dropdown display
- **WHEN** provider has multiple accounts
- **THEN** the card SHALL show dropdown "Account: [label ▾]" in header

#### Scenario: Single account simplification
- **WHEN** provider has only one account
- **THEN** the dropdown SHALL be hidden and label shown as plain text

#### Scenario: Add account option
- **WHEN** user opens account dropdown
- **THEN** the dropdown SHALL include "+ Add Account" option at bottom to connect new account

#### Scenario: Manage accounts option
- **WHEN** user opens account dropdown
- **THEN** the dropdown SHALL include "Manage Accounts..." option to open AccountManagerDialog

### Requirement: Account Labeling
The system SHALL auto-generate account labels with option for user customization.

#### Scenario: Auto-generated labels
- **WHEN** account is connected
- **THEN** the system SHALL generate label in format "<Provider> (<username>)" (e.g., "GitHub (tobagin)")

#### Scenario: Custom label assignment
- **WHEN** user renames account
- **THEN** the system SHALL update label in GSettings and UI

#### Scenario: Label uniqueness validation
- **WHEN** user sets custom label
- **THEN** the system SHALL warn if label already exists for same provider

### Requirement: Account Management Dialog
The system SHALL provide dedicated dialog for managing all cloud accounts.

#### Scenario: List all accounts
- **WHEN** Account Manager dialog opens
- **THEN** the system SHALL display all accounts grouped by provider with labels, usernames, and last used timestamps

#### Scenario: Rename account
- **WHEN** user clicks "Rename" button
- **THEN** the system SHALL show text entry to edit account label

#### Scenario: Remove account
- **WHEN** user clicks "Remove" button
- **THEN** the system SHALL show confirmation dialog and delete account data including tokens

#### Scenario: Last used timestamp display
- **WHEN** displaying account in manager
- **THEN** the system SHALL show relative time "Last used: 2 hours ago" or "Never used"

### Requirement: Token Storage Migration
The system SHALL automatically migrate single-account tokens to multi-account format on first launch after Phase 7 upgrade.

#### Scenario: Detect old token format
- **WHEN** app starts after Phase 7 upgrade
- **THEN** the system SHALL check for `account_id` attribute in Secret Service tokens

#### Scenario: Migrate existing tokens
- **WHEN** old format tokens are found
- **THEN** the system SHALL generate UUID, create account entry, update token with `account_id`, and set as active

#### Scenario: Default account labeling
- **WHEN** migrating old token
- **THEN** the system SHALL label account as "Default Account"

#### Scenario: Migration completion marker
- **WHEN** migration succeeds
- **THEN** the system SHALL set GSettings `cloud-provider-migration-completed = true`

#### Scenario: Migration failure fallback
- **WHEN** migration fails due to Secret Service error
- **THEN** the system SHALL disable Phase 7 features and continue using old format

### Requirement: Multi-Account Provider Interface
The system SHALL extend CloudProvider interface to support account context in all operations.

#### Scenario: Account context in authentication
- **WHEN** `authenticate()` is called
- **THEN** the method SHALL accept optional `account_label` parameter for labeling new account

#### Scenario: Account context in key operations
- **WHEN** `list_keys()`, `deploy_key()`, or `remove_key()` is called
- **THEN** the methods SHALL accept `account_id` parameter to specify target account

#### Scenario: List accounts capability
- **WHEN** `list_accounts()` is called
- **THEN** the provider SHALL return all connected accounts with id, label, username, created_at, last_used

#### Scenario: Switch account capability
- **WHEN** `switch_account(account_id)` is called
- **THEN** the provider SHALL load account context and update active account

### Requirement: Account Limit and Performance
The system SHALL limit accounts per provider to maintain performance and usability.

#### Scenario: Account limit enforcement
- **WHEN** user attempts to connect 11th account to same provider
- **THEN** the system SHALL display warning "Maximum 10 accounts per provider. Remove an account before adding more."

#### Scenario: Lazy key loading
- **WHEN** switching accounts
- **THEN** the system SHALL only fetch key list for active account (not all accounts)

#### Scenario: Cached account metadata
- **WHEN** displaying account dropdown
- **THEN** the system SHALL use cached username/label from GSettings without API calls

### Requirement: Independent Account Lifecycle
The system SHALL manage each account independently without affecting other accounts.

#### Scenario: Disconnect one account
- **WHEN** user disconnects or removes one account
- **THEN** other accounts for same provider SHALL remain connected and functional

#### Scenario: Token expiration per account
- **WHEN** one account's token expires
- **THEN** only that account SHALL show "Disconnected" status, not all accounts

#### Scenario: Per-account error handling
- **WHEN** API call fails for one account
- **THEN** error SHALL be scoped to that account, not affect other accounts
