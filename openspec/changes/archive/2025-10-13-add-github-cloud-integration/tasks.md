# Implementation Tasks

## 1. Add Dependencies and Build Configuration

- [ ] 1.1 Add libsoup-3.0 dependency to meson.build
- [ ] 1.2 Add libsecret-1 dependency to meson.build (for Secret Service)
- [ ] 1.3 Update minimum GNOME version documentation if needed
- [ ] 1.4 Test build with new dependencies on clean system

## 2. Create Backend Infrastructure

- [ ] 2.1 Create `src/backend/cloud/` directory structure
- [ ] 2.2 Implement `CloudProviderType.vala` enum (GITHUB, GITLAB, AWS, etc.)
- [ ] 2.3 Implement `CloudProvider.vala` interface with async methods
- [ ] 2.4 Implement `CloudKeyMetadata.vala` data model (id, title, fingerprint, type, last_used)
- [ ] 2.5 Implement `CloudProviderManager.vala` singleton for provider registry
- [ ] 2.6 Update `src/meson.build` to include new backend files

## 3. Implement GitHub OAuth Flow

- [ ] 3.1 Create `src/backend/cloud/GitHubOAuthServer.vala` - Local HTTP callback server
- [ ] 3.2 Implement server binding to `127.0.0.1:8765`
- [ ] 3.3 Implement OAuth callback handler (`/callback?code=...`)
- [ ] 3.4 Implement authorization code exchange for access token
- [ ] 3.5 Implement automatic server shutdown after callback or 60s timeout
- [ ] 3.6 Add error handling for port conflicts and network failures

## 4. Implement GitHub Provider Backend

- [ ] 4.1 Create `src/backend/cloud/GitHubProvider.vala` implementing `CloudProvider` interface
- [ ] 4.2 Implement `authenticate()` - Launch OAuth flow with libsoup
- [ ] 4.3 Implement `list_keys()` - Fetch from GitHub API `/user/keys`
- [ ] 4.4 Implement `deploy_key(public_key, title)` - POST to `/user/keys`
- [ ] 4.5 Implement `remove_key(key_id)` - DELETE to `/user/keys/:id`
- [ ] 4.6 Implement `is_authenticated()` - Check Secret Service for valid token
- [ ] 4.7 Implement `get_provider_name()` - Return "GitHub"
- [ ] 4.8 Add rate limit tracking (extract X-RateLimit-* headers)

## 5. Implement Secure Token Storage

- [ ] 5.1 Create Secret Service schema for KeyMaker cloud tokens
- [ ] 5.2 Implement `store_token(provider, username, token)` helper
- [ ] 5.3 Implement `retrieve_token(provider, username)` helper
- [ ] 5.4 Implement `delete_token(provider, username)` helper
- [ ] 5.5 Add token validation on app startup

## 6. Implement HTTP Client Utilities

- [ ] 6.1 Create `src/backend/cloud/HttpClient.vala` wrapper around libsoup
- [ ] 6.2 Implement async GET request helper
- [ ] 6.3 Implement async POST request helper
- [ ] 6.4 Implement async DELETE request helper
- [ ] 6.5 Add standard headers (User-Agent, Accept, Authorization)
- [ ] 6.6 Add 30-second timeout for all requests
- [ ] 6.7 Add JSON response parsing with error handling

## 7. Implement Key Metadata Caching

- [ ] 7.1 Add GSettings schema keys for cloud provider cache
- [ ] 7.2 Implement cache write: serialize key list to JSON in GSettings
- [ ] 7.3 Implement cache read: deserialize JSON from GSettings
- [ ] 7.4 Add cache timestamp tracking for expiration (24 hours)
- [ ] 7.5 Implement cache invalidation on deploy/remove operations

## 8. Create Cloud Providers Page UI

- [ ] 8.1 Create `data/ui/pages/cloud_providers_page.blp` Blueprint file
- [ ] 8.2 Design page layout: provider card + key list + action buttons
- [ ] 8.3 Create `src/ui/pages/CloudProvidersPage.vala`
- [ ] 8.4 Implement provider connection status display
- [ ] 8.5 Implement key list view with columns (Title, Type, Fingerprint, Last Used)
- [ ] 8.6 Add "Connect", "Disconnect", "Refresh" buttons
- [ ] 8.7 Add "Deploy Key to GitHub..." button
- [ ] 8.8 Add empty state message for no keys
- [ ] 8.9 Add loading state spinner during API calls
- [ ] 8.10 Update `data/ui/meson.build` to include new Blueprint file

## 9. Create GitHub Authentication Dialog

- [ ] 9.1 Create `data/ui/dialogs/github_auth_dialog.blp` Blueprint file
- [ ] 9.2 Create `src/ui/dialogs/GitHubAuthDialog.vala`
- [ ] 9.3 Implement dialog with instructions: "Opening GitHub in your browser..."
- [ ] 9.4 Add cancel button to abort OAuth flow
- [ ] 9.5 Show success message after authentication
- [ ] 9.6 Show error message if authentication fails
- [ ] 9.7 Update `data/ui/meson.build` to include new Blueprint file

## 10. Create Key Deployment Dialog

- [ ] 10.1 Create `data/ui/dialogs/cloud_key_deploy_dialog.blp` Blueprint file
- [ ] 10.2 Create `src/ui/dialogs/CloudKeyDeployDialog.vala`
- [ ] 10.3 Add dropdown to select local public key from ~/.ssh
- [ ] 10.4 Display key fingerprint and type preview
- [ ] 10.5 Add security warning text with "Don't show again" checkbox
- [ ] 10.6 Save checkbox preference to GSettings
- [ ] 10.7 Handle deploy button click -> call GitHubProvider.deploy_key()
- [ ] 10.8 Show progress spinner during deployment
- [ ] 10.9 Show success toast notification
- [ ] 10.10 Update `data/ui/meson.build` to include new Blueprint file

## 11. Create Key Removal Confirmation Dialog

- [ ] 11.1 Create `data/ui/dialogs/cloud_key_remove_dialog.blp` Blueprint file
- [ ] 11.2 Create `src/ui/dialogs/CloudKeyRemoveDialog.vala`
- [ ] 11.3 Display key title and warning message
- [ ] 11.4 Add "Cancel" and "Remove" buttons
- [ ] 11.5 Style "Remove" button as destructive action
- [ ] 11.6 Handle remove button click -> call GitHubProvider.remove_key()
- [ ] 11.7 Update `data/ui/meson.build` to include new Blueprint file

## 12. Add Navigation Sidebar Integration

- [ ] 12.1 Update `data/ui/window.blp` to add "Cloud Providers" sidebar item
- [ ] 12.2 Place between "Keys" and "Hosts" items
- [ ] 12.3 Add icon for cloud providers (cloud icon from Adwaita icon theme)
- [ ] 12.4 Wire up navigation to CloudProvidersPage
- [ ] 12.5 Update `src/ui/Window.vala` to instantiate CloudProvidersPage

## 13. Implement Error Handling and User Feedback

- [ ] 13.1 Add error banner widget to CloudProvidersPage for network errors
- [ ] 13.2 Add info banner for cached data display
- [ ] 13.3 Add warning banner for low API quota
- [ ] 13.4 Implement toast notifications for success/error messages
- [ ] 13.5 Add debug logging for all GitHub API calls
- [ ] 13.6 Log X-GitHub-Request-Id header for support correlation

## 14. Implement Offline Mode Support

- [ ] 14.1 Detect network failures in HttpClient (catch GLib.Error)
- [ ] 14.2 Show cached key list when offline
- [ ] 14.3 Disable "Refresh" and "Deploy" buttons when offline
- [ ] 14.4 Add "Retry" button to error banners
- [ ] 14.5 Test graceful degradation with airplane mode

## 15. Add GSettings Schema Keys

- [ ] 15.1 Add `cloud-provider-github-connected` boolean key
- [ ] 15.2 Add `cloud-provider-github-username` string key
- [ ] 15.3 Add `cloud-provider-cache` dictionary key for JSON cache
- [ ] 15.4 Add `cloud-provider-show-deploy-warning` boolean key (default: true)
- [ ] 15.5 Update `data/io.github.tobagin.keysmith.gschema.xml.in`

## 16. Add Internationalization (i18n)

- [ ] 16.1 Mark all user-facing strings with `_()` for translation
- [ ] 16.2 Add i18n strings for Cloud Providers page
- [ ] 16.3 Add i18n strings for GitHub authentication dialog
- [ ] 16.4 Add i18n strings for key deployment dialog
- [ ] 16.5 Add i18n strings for error messages
- [ ] 16.6 Update po/POTFILES to include new files

## 17. Testing and Validation

- [ ] 17.1 Test OAuth flow with real GitHub account
- [ ] 17.2 Test key deployment with RSA, Ed25519, and ECDSA keys
- [ ] 17.3 Test key removal
- [ ] 17.4 Test offline mode (disconnect internet, verify cached data)
- [ ] 17.5 Test rate limit handling (make 100+ API calls)
- [ ] 17.6 Test token expiration (revoke token on GitHub, verify re-auth prompt)
- [ ] 17.7 Test with empty GitHub account (no keys)
- [ ] 17.8 Test duplicate key deployment (verify error message)
- [ ] 17.9 Test network timeout (slow/unreliable connection)
- [ ] 17.10 Test OAuth callback server port conflict (8765 already in use)

## 18. Documentation and Polish

- [ ] 18.1 Update README.md with cloud provider features
- [ ] 18.2 Document libsoup-3.0 dependency requirement
- [ ] 18.3 Add user guide section: "Connecting to GitHub"
- [ ] 18.4 Add user guide section: "Deploying Keys to Cloud"
- [ ] 18.5 Add developer documentation for CloudProvider interface
- [ ] 18.6 Add keyboard shortcuts for Cloud Providers page (if applicable)
- [ ] 18.7 Ensure all dialogs follow GNOME HIG guidelines

## 19. Build and Packaging

- [ ] 19.1 Test production build with `./scripts/build.sh`
- [ ] 19.2 Test development build with `./scripts/build.sh --dev`
- [ ] 19.3 Verify Flatpak build includes libsoup-3.0 runtime
- [ ] 19.4 Update Flatpak manifest if needed
- [ ] 19.5 Test installation from Flatpak

## 20. Final Review and Cleanup

- [ ] 20.1 Run code linter/formatter on all new files
- [ ] 20.2 Remove debug print statements
- [ ] 20.3 Review all TODO/FIXME comments in code
- [ ] 20.4 Verify no credentials or secrets in code
- [ ] 20.5 Update OpenSpec tasks.md to mark all items complete
