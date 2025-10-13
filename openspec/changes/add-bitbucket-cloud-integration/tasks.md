# Implementation Tasks

## 1. Backend Infrastructure Updates

- [ ] 1.1 Add `BITBUCKET` to `CloudProviderType` enum
- [ ] 1.2 Register BitbucketProvider in CloudProviderManager
- [ ] 1.3 Update `src/meson.build` to include Bitbucket source files

## 2. Implement Bitbucket Provider Backend

- [ ] 2.1 Create `src/backend/cloud/BitbucketProvider.vala` implementing CloudProvider interface
- [ ] 2.2 Implement `authenticate()` with Bitbucket OAuth flow
- [ ] 2.3 Implement `list_keys()` - GET /2.0/user/ssh-keys with pagination
- [ ] 2.4 Implement `deploy_key()` - POST /2.0/user/ssh-keys
- [ ] 2.5 Implement `remove_key()` - DELETE /2.0/user/ssh-keys/{uuid}
- [ ] 2.6 Implement `is_authenticated()` - Check Secret Service for Bitbucket token
- [ ] 2.7 Implement `get_provider_name()` - Return "Bitbucket"
- [ ] 2.8 Add API base URL: `https://api.bitbucket.org/2.0/`

## 3. Implement Bitbucket Pagination

- [ ] 3.1 Create pagination helper method to follow `next` URLs
- [ ] 3.2 Parse Bitbucket response format: `{pagelen, values, next}`
- [ ] 3.3 Implement pagination loop (max 100 keys)
- [ ] 3.4 Add progress indicator for multi-page loads
- [ ] 3.5 Handle pagination timeout (30 seconds total)

## 4. OAuth Flow Implementation

- [ ] 4.1 Update OAuth callback server to handle Bitbucket provider
- [ ] 4.2 Implement Bitbucket OAuth endpoints: /site/oauth2/authorize, /site/oauth2/access_token
- [ ] 4.3 Request OAuth scopes: `account`, `ssh-key:write`
- [ ] 4.4 Add state parameter with provider identifier: `bitbucket`
- [ ] 4.5 Retrieve username via GET /2.0/user

## 5. Token Storage

- [ ] 5.1 Store Bitbucket tokens with service="keymaker-bitbucket"
- [ ] 5.2 Implement provider-specific token retrieval
- [ ] 5.3 Ensure independent lifecycle from GitHub/GitLab

## 6. API Response Parsing

- [ ] 6.1 Parse Bitbucket key object: `uuid`, `label`, `key`, `created_on`
- [ ] 6.2 Handle UUID-based key IDs (preserve full format)
- [ ] 6.3 Parse error response format: `{type: "error", error: {message: "..."}}`
- [ ] 6.4 Extract rate limit headers: X-RateLimit-Remaining, X-RateLimit-Reset

## 7. Update Cloud Providers Page UI

- [ ] 7.1 Add Bitbucket provider card to CloudProvidersPage
- [ ] 7.2 Place below GitLab card (or GitHub if GitLab not present)
- [ ] 7.3 Display connection status: "Connected to Bitbucket as <username>"
- [ ] 7.4 Add "Connect" button
- [ ] 7.5 Show key list with columns: Label, Type, Fingerprint, Created Date
- [ ] 7.6 Display "Last Used: Not available" (Bitbucket doesn't provide this)
- [ ] 7.7 Show pagination progress: "Loading keys... (25 loaded)"

## 8. Create Bitbucket Authentication Dialog

- [ ] 8.1 Create `src/ui/dialogs/BitbucketAuthDialog.vala`
- [ ] 8.2 Reuse generic OAuth dialog pattern from GitHub/GitLab
- [ ] 8.3 Display "Opening Bitbucket in your browser..." message
- [ ] 8.4 Handle OAuth success/failure

## 9. Error Handling

- [ ] 9.1 Add error: "Bitbucket rate limit reached"
- [ ] 9.2 Add error: "OAuth failed" with Bitbucket-specific messages
- [ ] 9.3 Add error: "Pagination timed out (showing partial results)"
- [ ] 9.4 Add warning: "Showing first 100 keys only" (if more exist)
- [ ] 9.5 Handle network errors gracefully

## 10. GSettings Schema Updates

- [ ] 10.1 Add `cloud-provider-bitbucket-connected` boolean key
- [ ] 10.2 Add `cloud-provider-bitbucket-username` string key
- [ ] 10.3 Update `data/io.github.tobagin.keysmith.gschema.xml.in`

## 11. Internationalization

- [ ] 11.1 Mark all Bitbucket UI strings with _() for translation
- [ ] 11.2 Add i18n for "Bitbucket", "Connected to Bitbucket", error messages
- [ ] 11.3 Update po/POTFILES with new Bitbucket files

## 12. Testing

- [ ] 12.1 Test Bitbucket.org authentication
- [ ] 12.2 Test key operations (list, deploy, remove)
- [ ] 12.3 Test pagination with account that has 15+ keys
- [ ] 12.4 Test 100-key pagination limit
- [ ] 12.5 Test UUID-based key ID handling
- [ ] 12.6 Test rate limiting (make 60+ requests)
- [ ] 12.7 Test GitHub + GitLab + Bitbucket all connected simultaneously
- [ ] 12.8 Test independent disconnection
- [ ] 12.9 Test offline mode with cached Bitbucket keys
- [ ] 12.10 Test "Last Used: Not available" display

## 13. Documentation

- [ ] 13.1 Update README with Bitbucket support
- [ ] 13.2 Document Bitbucket Cloud limitation (not Bitbucket Server)
- [ ] 13.3 Document "Last Used" field not available for Bitbucket
- [ ] 13.4 Add Bitbucket OAuth app registration instructions

## 14. Final Review

- [ ] 14.1 Verify CloudProvider interface unchanged (no Bitbucket-specific leaks)
- [ ] 14.2 Test with all three providers connected
- [ ] 14.3 Verify pagination performance (no UI freezing)
- [ ] 14.4 Run production build
- [ ] 14.5 Update OpenSpec tasks.md to mark all items complete
