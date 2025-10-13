# Cloud Provider Integration Specification

## ADDED Requirements

### Requirement: Cloud Provider Interface
The system SHALL define an abstract `CloudProvider` interface that all cloud provider implementations must implement.

#### Scenario: Interface defines required operations
- **WHEN** implementing a new cloud provider backend
- **THEN** the provider MUST implement `authenticate()`, `list_keys()`, `deploy_key()`, `remove_key()`, `is_authenticated()`, and `get_provider_name()` methods

#### Scenario: Provider type enumeration
- **WHEN** registering a cloud provider
- **THEN** the system SHALL assign it a unique `CloudProviderType` enum value (e.g., GITHUB, GITLAB, AWS)

### Requirement: GitHub OAuth Authentication
The system SHALL support OAuth 2.0 authentication with GitHub using the authorization code flow.

#### Scenario: User initiates GitHub connection
- **WHEN** user clicks "Connect GitHub" button
- **THEN** the system SHALL start a local HTTP server on `localhost:8765` and open the GitHub OAuth authorization URL in the system default browser

#### Scenario: OAuth callback handling
- **WHEN** GitHub redirects to `http://localhost:8765/callback?code=<auth_code>`
- **THEN** the system SHALL exchange the authorization code for an access token and store it securely in Secret Service

#### Scenario: Token validation on startup
- **WHEN** the application starts and a GitHub token exists in Secret Service
- **THEN** the system SHALL validate the token with a lightweight API call (e.g., `/user` endpoint)

#### Scenario: Token expiration handling
- **WHEN** a GitHub API call returns 401 Unauthorized
- **THEN** the system SHALL mark the account as disconnected and prompt the user to re-authenticate

### Requirement: Secure Token Storage
The system SHALL store OAuth tokens and API credentials in GNOME Secret Service, not in plaintext configuration files.

#### Scenario: Token storage after successful authentication
- **WHEN** OAuth authentication succeeds
- **THEN** the system SHALL store the access token in Secret Service with schema attributes `service="keymaker-github"` and `account=<username>`

#### Scenario: Token retrieval for API calls
- **WHEN** making a GitHub API request
- **THEN** the system SHALL retrieve the token from Secret Service using the schema and current username

#### Scenario: Token deletion on disconnect
- **WHEN** user clicks "Disconnect GitHub" button
- **THEN** the system SHALL remove the token from Secret Service and clear any cached data

### Requirement: GitHub SSH Key Listing
The system SHALL fetch and display SSH keys associated with the authenticated GitHub account.

#### Scenario: Successful key list retrieval
- **WHEN** user navigates to Cloud Providers page and GitHub is authenticated
- **THEN** the system SHALL call GitHub API `/user/keys` endpoint and display key title, fingerprint, key type, and last used date

#### Scenario: Empty key list handling
- **WHEN** GitHub account has no SSH keys
- **THEN** the system SHALL display an empty state message "No SSH keys found on GitHub. Deploy a key to get started."

#### Scenario: API rate limit exceeded
- **WHEN** GitHub API returns 403 with `X-RateLimit-Remaining: 0`
- **THEN** the system SHALL display an error banner "GitHub API rate limit reached. Resets at <reset_time>." and disable refresh button until reset time

### Requirement: Deploy Public Key to GitHub
The system SHALL allow users to upload local public SSH keys to their GitHub account.

#### Scenario: User selects key for deployment
- **WHEN** user clicks "Deploy Key to GitHub" button and selects a local public key
- **THEN** the system SHALL show a confirmation dialog with key fingerprint, key type, and security warning

#### Scenario: Security warning acknowledgment
- **WHEN** confirmation dialog is shown
- **THEN** the dialog SHALL display "This public key will be uploaded to GitHub. Anyone with GitHub access can see it." with a checkbox "Don't show this again for GitHub"

#### Scenario: Successful key deployment
- **WHEN** user confirms deployment and GitHub API returns 201 Created
- **THEN** the system SHALL refresh the key list and show a toast notification "Key deployed to GitHub successfully"

#### Scenario: Duplicate key rejection
- **WHEN** GitHub API returns 422 Unprocessable Entity with error "key is already in use"
- **THEN** the system SHALL display error dialog "This key already exists on GitHub" without retrying

#### Scenario: Key title extraction from comment
- **WHEN** deploying a key with a comment (e.g., `ssh-rsa AAAA... user@host`)
- **THEN** the system SHALL use the comment (`user@host`) as the GitHub key title

#### Scenario: Key title fallback for keys without comments
- **WHEN** deploying a key with no comment
- **THEN** the system SHALL generate a title in the format "KeyMaker Key (YYYY-MM-DD HH:MM)"

### Requirement: Remove Key from GitHub
The system SHALL allow users to delete SSH keys from their GitHub account.

#### Scenario: User initiates key removal
- **WHEN** user selects a GitHub key and clicks "Remove from GitHub" button
- **THEN** the system SHALL show a confirmation dialog "Remove key '<title>' from GitHub? This cannot be undone."

#### Scenario: Successful key removal
- **WHEN** user confirms removal and GitHub API returns 204 No Content
- **THEN** the system SHALL remove the key from the local list and show a toast notification "Key removed from GitHub"

#### Scenario: Key removal failure for non-existent key
- **WHEN** GitHub API returns 404 Not Found during key removal
- **THEN** the system SHALL display error "Key not found on GitHub (may have been removed elsewhere)" and refresh the key list

### Requirement: Cloud Providers Page UI
The system SHALL provide a dedicated "Cloud Providers" page in the main navigation sidebar.

#### Scenario: Navigation sidebar placement
- **WHEN** user views the main window sidebar
- **THEN** the "Cloud Providers" navigation item SHALL appear between "Keys" and "Hosts" items

#### Scenario: Provider connection status display
- **WHEN** user navigates to Cloud Providers page
- **THEN** the page SHALL show GitHub provider card with connection status: "Connected as <username>" or "Not connected"

#### Scenario: Connect button availability
- **WHEN** GitHub provider is not connected
- **THEN** the provider card SHALL display a "Connect" button that initiates OAuth flow

#### Scenario: Disconnect and refresh buttons
- **WHEN** GitHub provider is connected
- **THEN** the provider card SHALL display "Disconnect" and "Refresh" buttons

#### Scenario: Key list display
- **WHEN** GitHub provider is connected and keys are loaded
- **THEN** the page SHALL display a scrollable list of keys with columns: Title, Type (RSA/Ed25519/ECDSA), Fingerprint (SHA256), Last Used

#### Scenario: Deploy key button
- **WHEN** GitHub provider is connected
- **THEN** the page SHALL display a "Deploy Key to GitHub..." button at the bottom

### Requirement: Offline Mode Graceful Degradation
The system SHALL handle network failures gracefully without crashing or hanging.

#### Scenario: Network unreachable during authentication
- **WHEN** OAuth callback server is running but GitHub API is unreachable (network error, DNS failure)
- **THEN** the system SHALL display error banner "Unable to connect to GitHub. Check your internet connection." and keep the "Connect" button enabled for retry

#### Scenario: Network unreachable during key list fetch
- **WHEN** user is authenticated but GitHub API call fails due to network error
- **THEN** the system SHALL display cached key list (if available) with an info banner "Showing cached data. Unable to refresh." and a "Retry" button

#### Scenario: Timeout handling
- **WHEN** GitHub API request takes longer than 30 seconds
- **THEN** the system SHALL cancel the request and display error "Request timed out. GitHub may be experiencing issues."

### Requirement: Error Reporting and Logging
The system SHALL provide clear error messages for all failure scenarios and log technical details for debugging.

#### Scenario: User-facing error messages
- **WHEN** any GitHub operation fails
- **THEN** the system SHALL display a user-friendly error message (no raw HTTP codes or JSON) with actionable next steps

#### Scenario: Debug logging for API errors
- **WHEN** any GitHub API call fails
- **THEN** the system SHALL log the full HTTP response (status code, headers, body) to the application log for debugging

#### Scenario: Correlation ID for support requests
- **WHEN** a GitHub API error occurs
- **THEN** the system SHALL extract and log GitHub's `X-GitHub-Request-Id` header if present for support correlation

### Requirement: HTTP Client Implementation
The system SHALL use libsoup-3.0 for all HTTP requests to cloud provider APIs.

#### Scenario: Async/await request pattern
- **WHEN** making any GitHub API request
- **THEN** the system SHALL use Vala async methods with `Soup.Session` to avoid blocking the UI thread

#### Scenario: Request headers
- **WHEN** making authenticated GitHub API requests
- **THEN** the system SHALL include headers: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `User-Agent: KeyMaker/<version>`

#### Scenario: Response parsing
- **WHEN** GitHub API returns JSON response
- **THEN** the system SHALL parse it using `Json.Parser` and handle both success and error payloads

### Requirement: Dependency Management
The system SHALL declare libsoup-3.0 as a required dependency in the build system.

#### Scenario: Meson dependency declaration
- **WHEN** building KeyMaker
- **THEN** meson.build SHALL include `dependency('libsoup-3.0', version: '>= 3.0')` and fail the build if not found

#### Scenario: Runtime dependency check
- **WHEN** KeyMaker starts
- **THEN** the system SHALL verify libsoup is available and display error "Cloud provider features unavailable: libsoup-3.0 not found" if missing

### Requirement: GitHub API Rate Limit Monitoring
The system SHALL track and display GitHub API rate limit status to prevent quota exhaustion.

#### Scenario: Rate limit header extraction
- **WHEN** receiving any GitHub API response
- **THEN** the system SHALL extract `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers and cache them

#### Scenario: Rate limit status display
- **WHEN** user views Cloud Providers page with GitHub connected
- **THEN** the page SHALL display rate limit status: "API requests remaining: <count> (resets in <time>)"

#### Scenario: Proactive rate limit warning
- **WHEN** rate limit remaining count drops below 100
- **THEN** the system SHALL display a warning banner "GitHub API quota running low. Avoid unnecessary refreshes."

### Requirement: Key Metadata Caching
The system SHALL cache GitHub SSH key metadata locally to reduce API calls and support offline viewing.

#### Scenario: Cache storage location
- **WHEN** key list is successfully fetched from GitHub
- **THEN** the system SHALL store it in GSettings under key `cloud-provider-cache.github.keys` as JSON array

#### Scenario: Cache invalidation on deployment
- **WHEN** a key is deployed or removed
- **THEN** the system SHALL immediately fetch fresh data from GitHub and update the cache

#### Scenario: Cache expiration
- **WHEN** cached key list is older than 24 hours
- **THEN** the system SHALL show an info banner "Key list may be outdated. Click Refresh to update." but still display cached data

### Requirement: Security Best Practices
The system SHALL follow security best practices for OAuth and API credential handling.

#### Scenario: No credentials in version control
- **WHEN** GitHub OAuth client ID and secret are configured
- **THEN** they SHALL be stored in GSettings or environment variables, never hardcoded in source code

#### Scenario: HTTPS enforcement
- **WHEN** making any GitHub API request
- **THEN** the system SHALL only use HTTPS URLs and reject HTTP URLs

#### Scenario: Token scope restriction
- **WHEN** requesting GitHub OAuth authorization
- **THEN** the system SHALL request only the `write:public_key` scope (minimal required permission)

#### Scenario: Local callback server security
- **WHEN** OAuth callback server is running
- **THEN** it SHALL only bind to `127.0.0.1` (not `0.0.0.0`) and SHALL shut down within 60 seconds of receiving callback or on timeout
