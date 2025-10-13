# Implementation Tasks

## 1. Backend Infrastructure Updates

- [ ] 1.1 Add `GITLAB` to `CloudProviderType` enum
- [ ] 1.2 Register GitLabProvider in CloudProviderManager
- [ ] 1.3 Update `src/meson.build` to include GitLab source files

## 2. Implement GitLab Provider Backend

- [ ] 2.1 Create `src/backend/cloud/GitLabProvider.vala` implementing CloudProvider interface
- [ ] 2.2 Implement `authenticate()` with GitLab OAuth flow
- [ ] 2.3 Implement `list_keys()` - GET /api/v4/user/keys
- [ ] 2.4 Implement `deploy_key()` - POST /api/v4/user/keys
- [ ] 2.5 Implement `remove_key()` - DELETE /api/v4/user/keys/:id
- [ ] 2.6 Implement `is_authenticated()` - Check Secret Service for GitLab token
- [ ] 2.7 Implement `get_provider_name()` - Return "GitLab"
- [ ] 2.8 Add API base path prefix logic (/api/v4/)
- [ ] 2.9 Adapt rate limit header parsing (RateLimit-* vs X-RateLimit-*)

## 3. Self-Hosted Instance Support

- [ ] 3.1 Add GSettings key `cloud-provider-gitlab-instance-url` (default: "https://gitlab.com")
- [ ] 3.2 Add instance URL configuration dialog
- [ ] 3.3 Implement instance URL validation (HTTPS, valid domain)
- [ ] 3.4 Implement GitLab version check via /api/v4/version
- [ ] 3.5 Display warning for GitLab version < 13.0
- [ ] 3.6 Store custom OAuth credentials in Secret Service per instance
- [ ] 3.7 Add "Allow self-signed certificates" preference
- [ ] 3.8 Implement SSL strict mode toggle in libsoup session

## 4. OAuth Flow Enhancements

- [ ] 4.1 Update OAuth callback server to handle GitLab provider
- [ ] 4.2 Add state parameter with provider identifier (gitlab:<instance_url>)
- [ ] 4.3 Implement GitLab token exchange endpoint (/oauth/token)
- [ ] 4.4 Request GitLab OAuth scopes: read_user, api
- [ ] 4.5 Handle provider-specific OAuth errors

## 5. Token Storage for Multiple Providers

- [ ] 5.1 Update token storage schema to include provider type
- [ ] 5.2 Store GitLab tokens with service="keymaker-gitlab"
- [ ] 5.3 Store instance URL as schema attribute
- [ ] 5.4 Implement provider-aware token retrieval
- [ ] 5.5 Ensure independent token lifecycle (disconnect one, keep other)

## 6. Update Cloud Providers Page UI

- [ ] 6.1 Add GitLab provider card to CloudProvidersPage
- [ ] 6.2 Display instance URL: "Instance: gitlab.com" or custom URL
- [ ] 6.3 Add "Configure Instance" button
- [ ] 6.4 Add "Connect" button (reuse GitHub dialog pattern)
- [ ] 6.5 Display connection status: "Connected to <instance> as <username>"
- [ ] 6.6 Show GitLab card below GitHub card

## 7. Create GitLab-Specific Dialogs

- [ ] 7.1 Create `data/ui/dialogs/gitlab_instance_config_dialog.blp`
- [ ] 7.2 Create `src/ui/dialogs/GitLabInstanceConfigDialog.vala`
- [ ] 7.3 Add instance URL text entry field
- [ ] 7.4 Add OAuth Client ID and Secret fields (for self-hosted)
- [ ] 7.5 Add validation: HTTPS check, format check
- [ ] 7.6 Add "Test Connection" button (calls /api/v4/version)
- [ ] 7.7 Show setup instructions with link to /oauth/applications
- [ ] 7.8 Create `src/ui/dialogs/GitLabAuthDialog.vala` (reuse GitHub pattern)
- [ ] 7.9 Update `data/ui/meson.build` to include new Blueprint files

## 8. API Compatibility Layer

- [ ] 8.1 Abstract API endpoint construction in GitLabProvider
- [ ] 8.2 Handle GitLab error response format {"message": "...", "error": "..."}
- [ ] 8.3 Parse GitLab key response (no last_used field)
- [ ] 8.4 Handle GitLab-specific HTTP status codes
- [ ] 8.5 Add GitLab API version detection logic

## 9. Error Handling for Self-Hosted

- [ ] 9.1 Add error: "Not a GitLab instance" (version check fails)
- [ ] 9.2 Add error: "Cannot connect to instance" (network error)
- [ ] 9.3 Add error: "OAuth redirect URI not whitelisted"
- [ ] 9.4 Add error: "Insufficient OAuth scopes"
- [ ] 9.5 Add error: "Self-signed certificate rejected" (if SSL strict enabled)
- [ ] 9.6 Log all self-hosted instance errors for debugging

## 10. GSettings Schema Updates

- [ ] 10.1 Add `cloud-provider-gitlab-instance-url` string key
- [ ] 10.2 Add `cloud-provider-gitlab-connected` boolean key
- [ ] 10.3 Add `cloud-provider-gitlab-username` string key
- [ ] 10.4 Add `cloud-provider-gitlab-allow-self-signed` boolean key (default: false)
- [ ] 10.5 Update `data/io.github.tobagin.keysmith.gschema.xml.in`

## 11. Internationalization

- [ ] 11.1 Mark all GitLab UI strings with _() for translation
- [ ] 11.2 Add i18n for "GitLab", "Configure Instance", error messages
- [ ] 11.3 Update po/POTFILES with new GitLab files

## 12. Testing

- [ ] 12.1 Test GitLab.com authentication
- [ ] 12.2 Test key operations on GitLab.com (list, deploy, remove)
- [ ] 12.3 Test self-hosted GitLab instance connection
- [ ] 12.4 Test custom OAuth app setup for self-hosted
- [ ] 12.5 Test instance URL validation (invalid URLs, non-GitLab URLs)
- [ ] 12.6 Test GitLab version detection (old vs new versions)
- [ ] 12.7 Test self-signed certificate handling
- [ ] 12.8 Test GitHub + GitLab both connected simultaneously
- [ ] 12.9 Test independent disconnection (disconnect one, keep other)
- [ ] 12.10 Test offline mode with cached GitLab keys
- [ ] 12.11 Test OAuth redirect URI mismatch error
- [ ] 12.12 Test GitLab rate limiting

## 13. Documentation

- [ ] 13.1 Update README with GitLab support
- [ ] 13.2 Document self-hosted GitLab setup process
- [ ] 13.3 Document OAuth app registration steps
- [ ] 13.4 Add troubleshooting guide for self-hosted instances
- [ ] 13.5 Document minimum GitLab version requirement (13.0+)

## 14. Final Review

- [ ] 14.1 Verify CloudProvider interface still clean (no GitLab-specific leaks)
- [ ] 14.2 Ensure code reuse from Phase 1 (HTTP client, token storage, dialogs)
- [ ] 14.3 Test with both providers connected and switching between them
- [ ] 14.4 Run production build
- [ ] 14.5 Update OpenSpec tasks.md to mark all items complete
