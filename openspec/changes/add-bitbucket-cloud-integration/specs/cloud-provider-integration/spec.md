# Cloud Provider Integration Specification (Phase 3)

## ADDED Requirements

### Requirement: Bitbucket OAuth Authentication
The system SHALL support OAuth 2.0 authentication with Bitbucket Cloud (bitbucket.org).

#### Scenario: Bitbucket connection initiation
- **WHEN** user clicks "Connect" on Bitbucket provider card
- **THEN** the system SHALL use Bitbucket OAuth app credentials and open `https://bitbucket.org/site/oauth2/authorize` with scopes `account ssh-key:write`

#### Scenario: Bitbucket OAuth callback
- **WHEN** Bitbucket redirects to `http://localhost:8765/callback?code=...`
- **THEN** the system SHALL exchange code at `https://bitbucket.org/site/oauth2/access_token` for access token

#### Scenario: Bitbucket token storage
- **WHEN** Bitbucket OAuth succeeds
- **THEN** the system SHALL store token in Secret Service with schema attributes `service="keymaker-bitbucket"` and `account=<username>`

#### Scenario: Bitbucket user info retrieval
- **WHEN** Bitbucket authentication completes
- **THEN** the system SHALL call `GET /2.0/user` to retrieve username and display_name

### Requirement: Bitbucket SSH Key Operations
The system SHALL support listing, deploying, and removing SSH keys on Bitbucket Cloud.

#### Scenario: List Bitbucket keys
- **WHEN** Bitbucket provider is authenticated
- **THEN** the system SHALL call `GET /2.0/user/ssh-keys` and parse paginated response

#### Scenario: Handle Bitbucket pagination
- **WHEN** Bitbucket returns `next` URL in response
- **THEN** the system SHALL follow pagination links until all keys are retrieved or 100 keys are reached

#### Scenario: Parse Bitbucket key response
- **WHEN** parsing Bitbucket key list
- **THEN** the system SHALL extract `uuid` (key ID), `label` (title), `key` (public key content), `created_on` from `values` array

#### Scenario: Deploy key to Bitbucket
- **WHEN** user deploys a key to Bitbucket
- **THEN** the system SHALL POST to `/2.0/user/ssh-keys` with JSON payload `{"label": "...", "key": "ssh-rsa AAA..."}`

#### Scenario: Remove key from Bitbucket
- **WHEN** user removes a key from Bitbucket
- **THEN** the system SHALL DELETE `/2.0/user/ssh-keys/{uuid}` with key UUID

#### Scenario: Handle UUID-based key IDs
- **WHEN** storing Bitbucket key IDs internally
- **THEN** the system SHALL preserve full UUID format `{12345678-1234-1234-1234-123456789abc}`

### Requirement: Bitbucket API Compatibility
The system SHALL adapt to Bitbucket REST API 2.0 differences from GitHub/GitLab APIs.

#### Scenario: API base URL
- **WHEN** making Bitbucket API requests
- **THEN** all endpoints SHALL use base URL `https://api.bitbucket.org/2.0/`

#### Scenario: Pagination response format
- **WHEN** receiving Bitbucket API response
- **THEN** the system SHALL check for `pagelen`, `values`, `next` fields and iterate pagination if needed

#### Scenario: No last used timestamp
- **WHEN** displaying Bitbucket keys in UI
- **THEN** the "Last Used" column SHALL show "Not available" (Bitbucket doesn't provide this field)

#### Scenario: Rate limit headers
- **WHEN** receiving Bitbucket API response
- **THEN** the system SHALL extract `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers

#### Scenario: Error response format
- **WHEN** Bitbucket API returns error (4xx/5xx)
- **THEN** the system SHALL parse Bitbucket's error format `{"type": "error", "error": {"message": "..."}}` and display user-friendly message

### Requirement: Cloud Providers Page Bitbucket Integration
The system SHALL display Bitbucket provider card on Cloud Providers page.

#### Scenario: Bitbucket card placement
- **WHEN** user views Cloud Providers page
- **THEN** Bitbucket provider card SHALL appear below GitLab card (or GitHub if GitLab not present) with title "Bitbucket"

#### Scenario: Connection status display
- **WHEN** Bitbucket provider is connected
- **THEN** the card SHALL show "Connected to Bitbucket as <username>"

#### Scenario: Connect button
- **WHEN** Bitbucket provider is not connected
- **THEN** the card SHALL show "Connect" button to initiate OAuth

#### Scenario: Key list display
- **WHEN** Bitbucket keys are loaded
- **THEN** the system SHALL display label, key type, fingerprint, created date (no last used date)

### Requirement: Bitbucket Pagination Progress
The system SHALL indicate progress when loading keys from paginated Bitbucket API.

#### Scenario: Show pagination progress
- **WHEN** fetching keys with pagination (more than 10 keys)
- **THEN** the system SHALL display progress indicator: "Loading keys... (<count> loaded)"

#### Scenario: Pagination limit
- **WHEN** user has more than 100 keys on Bitbucket
- **THEN** the system SHALL stop pagination at 100 keys and show warning "Showing first 100 keys only"

### Requirement: Bitbucket Rate Limit Handling
The system SHALL track and display Bitbucket API rate limit status.

#### Scenario: Rate limit tracking
- **WHEN** receiving Bitbucket API responses
- **THEN** the system SHALL extract `X-RateLimit-Remaining` (60/minute for authenticated users) and cache it

#### Scenario: Rate limit display
- **WHEN** Bitbucket provider is connected
- **THEN** the provider card SHALL show "API requests remaining: <count> (resets in <time>)"

#### Scenario: Rate limit exhaustion
- **WHEN** rate limit reaches 0
- **THEN** the system SHALL disable refresh/deploy buttons and show error "Bitbucket rate limit reached. Try again in <time>."

### Requirement: Independent Provider Lifecycle
The system SHALL allow Bitbucket to coexist with GitHub and GitLab providers independently.

#### Scenario: Multiple providers connected
- **WHEN** GitHub, GitLab, and Bitbucket are all connected
- **THEN** each provider SHALL maintain independent tokens, cache, and UI state

#### Scenario: Bitbucket disconnection
- **WHEN** user disconnects Bitbucket provider
- **THEN** GitHub and GitLab providers SHALL remain unaffected
