# Cloud Provider Integration Specification (Phase 5)

## ADDED Requirements

### Requirement: Azure DevOps OAuth Authentication
The system SHALL support OAuth 2.0 authentication with Azure DevOps via Microsoft identity platform.

#### Scenario: Azure OAuth initiation
- **WHEN** user clicks "Connect" on Azure provider card
- **THEN** the system SHALL open `https://login.microsoftonline.com/common/oauth2/v2.0/authorize` with scopes `vso.profile vso.tokens`

#### Scenario: Azure organization selection
- **WHEN** Azure OAuth succeeds
- **THEN** the system SHALL prompt user to select Azure DevOps organization from list

#### Scenario: Azure token storage
- **WHEN** Azure OAuth completes
- **THEN** the system SHALL store token in Secret Service with `service="keymaker-azure"` and `account=<email>`

### Requirement: Azure SSH Key Operations
The system SHALL support SSH key management via Azure DevOps Session Tokens API.

#### Scenario: List Azure keys
- **WHEN** Azure provider is authenticated
- **THEN** the system SHALL call `GET /_apis/Tokens/SessionTokens?api-version=7.0` and parse response

#### Scenario: Deploy key to Azure
- **WHEN** user deploys key to Azure
- **THEN** the system SHALL POST to `/_apis/Tokens/SessionTokens` with key data

#### Scenario: Remove key from Azure
- **WHEN** user removes key from Azure
- **THEN** the system SHALL DELETE `/_apis/Tokens/SessionTokens/{tokenId}`

### Requirement: Azure Organization Support
The system SHALL allow users to select and switch between Azure DevOps organizations.

#### Scenario: Organization storage
- **WHEN** user selects Azure organization
- **THEN** the system SHALL store it in GSettings `cloud-provider-azure-organization`

#### Scenario: Display organization in UI
- **WHEN** Azure provider is connected
- **THEN** the card SHALL show "Connected to Azure DevOps (myorg) as user@example.com"
