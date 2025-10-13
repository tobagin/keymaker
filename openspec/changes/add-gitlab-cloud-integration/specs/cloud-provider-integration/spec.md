# Cloud Provider Integration Specification (Phase 2)

## MODIFIED Requirements

### Requirement: Cloud Provider Interface
The system SHALL support multiple cloud provider implementations including GitHub and GitLab.

#### Scenario: GitLab provider registration
- **WHEN** application starts
- **THEN** the system SHALL register GitLabProvider with CloudProviderManager and assign CloudProviderType.GITLAB

#### Scenario: Provider enumeration
- **WHEN** user views Cloud Providers page
- **THEN** the system SHALL display both GitHub and GitLab provider cards

## ADDED Requirements

### Requirement: GitLab OAuth Authentication
The system SHALL support OAuth 2.0 authentication with GitLab.com and self-hosted GitLab instances.

#### Scenario: GitLab.com authentication
- **WHEN** user clicks "Connect" on GitLab.com (default instance)
- **THEN** the system SHALL use default OAuth app credentials and open GitLab OAuth authorization URL

#### Scenario: Self-hosted instance URL configuration
- **WHEN** user clicks "Configure Instance" for GitLab
- **THEN** the system SHALL show a dialog to enter custom GitLab instance URL (e.g., https://gitlab.mycompany.com)

#### Scenario: Self-hosted OAuth app setup
- **WHEN** user connects to self-hosted GitLab instance
- **THEN** the system SHALL prompt for OAuth Client ID and Secret with instructions to register at instance's `/oauth/applications`

#### Scenario: Instance URL validation
- **WHEN** user enters custom GitLab instance URL
- **THEN** the system SHALL validate it's a valid HTTPS URL and call `/api/v4/version` to verify it's a GitLab instance

#### Scenario: Minimum version check
- **WHEN** connecting to GitLab instance with version < 13.0
- **THEN** the system SHALL display warning "GitLab 13.0+ required. Your instance (v12.x) may not be compatible."

### Requirement: GitLab SSH Key Operations
The system SHALL support listing, deploying, and removing SSH keys on GitLab instances.

#### Scenario: List GitLab keys
- **WHEN** GitLab provider is authenticated
- **THEN** the system SHALL call `GET /api/v4/user/keys` and display key ID, title, key type, fingerprint, and created_at date

#### Scenario: Deploy key to GitLab
- **WHEN** user deploys a key to GitLab
- **THEN** the system SHALL POST to `/api/v4/user/keys` with JSON payload `{"title": "...", "key": "ssh-rsa AAA..."}`

#### Scenario: Remove key from GitLab
- **WHEN** user removes a key from GitLab
- **THEN** the system SHALL DELETE `/api/v4/user/keys/:id` with key ID

#### Scenario: GitLab rate limit headers
- **WHEN** receiving GitLab API response
- **THEN** the system SHALL extract `RateLimit-Remaining` and `RateLimit-Reset` headers (different from GitHub's `X-RateLimit-*`)

### Requirement: Self-Hosted Instance Configuration
The system SHALL allow users to configure and connect to self-hosted GitLab instances.

#### Scenario: Store instance URL in settings
- **WHEN** user configures custom GitLab instance URL
- **THEN** the system SHALL save it to GSettings key `cloud-provider-gitlab-instance-url`

#### Scenario: Store custom OAuth credentials
- **WHEN** user provides OAuth Client ID and Secret for self-hosted instance
- **THEN** the system SHALL store them in Secret Service with schema attributes `service="keymaker-gitlab-oauth"` and `instance=<url>`

#### Scenario: Display instance in UI
- **WHEN** connected to self-hosted GitLab instance
- **THEN** the provider card SHALL show "Connected to gitlab.mycompany.com as username" instead of "Connected to GitLab as username"

#### Scenario: SSL certificate validation toggle
- **WHEN** user enables "Allow self-signed certificates" preference for GitLab
- **THEN** the system SHALL show security warning "This is insecure. Only enable for trusted self-hosted instances." and set libsoup's `ssl-strict` to false

### Requirement: GitLab API Compatibility
The system SHALL adapt to GitLab API differences from GitHub API.

#### Scenario: API base path
- **WHEN** making GitLab API requests
- **THEN** all endpoints SHALL be prefixed with `/api/v4/` (e.g., `/api/v4/user/keys`)

#### Scenario: OAuth token scope
- **WHEN** requesting GitLab OAuth authorization
- **THEN** the system SHALL request scopes `read_user api` for user key management

#### Scenario: Key response format parsing
- **WHEN** parsing GitLab key list response
- **THEN** the system SHALL extract `id`, `title`, `key`, `created_at` fields (GitLab does not provide `last_used` field like GitHub)

#### Scenario: Error response format
- **WHEN** GitLab API returns error (4xx/5xx)
- **THEN** the system SHALL parse GitLab's error format `{"message": "...", "error": "..."}` and display user-friendly message

### Requirement: Cloud Providers Page GitLab Integration
The system SHALL display GitLab provider card on Cloud Providers page below GitHub card.

#### Scenario: GitLab card placement
- **WHEN** user views Cloud Providers page
- **THEN** GitLab provider card SHALL appear below GitHub card with title "GitLab"

#### Scenario: Instance URL display
- **WHEN** GitLab provider is configured
- **THEN** the card SHALL show configured instance URL: "Instance: gitlab.com" or "Instance: gitlab.mycompany.com"

#### Scenario: Configure Instance button
- **WHEN** GitLab provider is not connected
- **THEN** the card SHALL show two buttons: "Configure Instance" and "Connect"

#### Scenario: Self-hosted connection flow
- **WHEN** user clicks "Configure Instance" then "Connect" on self-hosted GitLab
- **THEN** the system SHALL use custom instance URL and OAuth credentials for authentication

### Requirement: Token Storage for Multiple Providers
The system SHALL store tokens for both GitHub and GitLab separately in Secret Service.

#### Scenario: GitLab token storage
- **WHEN** GitLab OAuth succeeds
- **THEN** the system SHALL store token with schema attributes `service="keymaker-gitlab"`, `account=<username>`, `instance=<url>`

#### Scenario: Token retrieval by provider
- **WHEN** making GitLab API request
- **THEN** the system SHALL retrieve token using `service="keymaker-gitlab"` (not GitHub's `service="keymaker-github"`)

#### Scenario: Independent disconnection
- **WHEN** user disconnects GitLab provider
- **THEN** GitHub provider SHALL remain connected (tokens are independent)

### Requirement: OAuth Callback Server Reuse
The system SHALL reuse the OAuth callback server from Phase 1 for GitLab authentication.

#### Scenario: GitLab OAuth callback handling
- **WHEN** GitLab redirects to `http://localhost:8765/callback?code=...`
- **THEN** the callback server SHALL detect provider context (GitLab vs GitHub) and exchange code using GitLab token endpoint

#### Scenario: Provider-specific state parameter
- **WHEN** initiating GitLab OAuth flow
- **THEN** the system SHALL include `state` parameter with value `gitlab:<instance_url>` to identify provider in callback

### Requirement: Error Handling for Self-Hosted Instances
The system SHALL provide clear error messages for self-hosted GitLab instance failures.

#### Scenario: Invalid instance URL
- **WHEN** user enters non-GitLab URL (e.g., `https://github.com`)
- **THEN** the system SHALL display error "This does not appear to be a GitLab instance. API version check failed."

#### Scenario: Unreachable instance
- **WHEN** custom instance URL is unreachable (DNS error, firewall)
- **THEN** the system SHALL display error "Cannot connect to gitlab.mycompany.com. Check URL and network connection."

#### Scenario: OAuth redirect mismatch
- **WHEN** GitLab OAuth callback fails due to redirect URI not whitelisted
- **THEN** the system SHALL display error "OAuth failed. Ensure http://localhost:8765/callback is whitelisted in your GitLab OAuth application settings."

#### Scenario: Insufficient OAuth scopes
- **WHEN** GitLab API returns 403 due to insufficient token scopes
- **THEN** the system SHALL display error "Token lacks required permissions. Reconnect GitLab with 'api' and 'read_user' scopes."
