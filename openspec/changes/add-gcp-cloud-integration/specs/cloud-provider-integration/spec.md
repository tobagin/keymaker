# Cloud Provider Integration Specification (Phase 6)

## ADDED Requirements

### Requirement: GCP OAuth Authentication
The system SHALL support OAuth 2.0 authentication with Google Cloud Platform.

#### Scenario: GCP OAuth initiation
- **WHEN** user clicks "Connect" on GCP provider card
- **THEN** the system SHALL open Google OAuth with scope `https://www.googleapis.com/auth/cloud-platform`

#### Scenario: GCP project selection
- **WHEN** GCP OAuth succeeds
- **THEN** the system SHALL optionally prompt for GCP project ID

#### Scenario: GCP token storage
- **WHEN** GCP OAuth completes
- **THEN** the system SHALL store token in Secret Service with `service="keymaker-gcp"`

### Requirement: GCP OS Login SSH Key Operations
The system SHALL support SSH key management via GCP OS Login API.

#### Scenario: List GCP keys
- **WHEN** GCP provider is authenticated
- **THEN** the system SHALL call `GET /v1/users/{user}/sshPublicKeys` and parse response

#### Scenario: Deploy key to GCP
- **WHEN** user deploys key to GCP
- **THEN** the system SHALL POST to `/v1/users/{user}:importSshPublicKey` with key data

#### Scenario: Remove key from GCP
- **WHEN** user removes key from GCP
- **THEN** the system SHALL DELETE `/v1/users/{user}/sshPublicKeys/{fingerprint}`

### Requirement: GCP OS Login Detection
The system SHALL detect if OS Login API is enabled and guide users to enable it if necessary.

#### Scenario: OS Login not enabled
- **WHEN** OS Login API returns "API not enabled" error
- **THEN** the system SHALL display instructions to enable OS Login in GCP Console
