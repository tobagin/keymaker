# Implementation Tasks

## 1. Backend Infrastructure
- [x] 1.1 Add `GCP` to CloudProviderType enum
- [x] 1.2 Create `src/backend/cloud/GCPProvider.vala`
- [x] 1.3 Register GCPProvider in CloudProviderManager

## 2. OAuth Implementation
- [x] 2.1 Implement Google OAuth 2.0 flow
- [x] 2.2 Request scope: https://www.googleapis.com/auth/cloud-platform
- [x] 2.3 Handle OAuth callback and token exchange

## 3. OS Login API Integration
- [x] 3.1 Implement list_keys() - GET /v1/users/{user}/sshPublicKeys
- [x] 3.2 Implement deploy_key() - POST /v1/users/{user}:importSshPublicKey
- [x] 3.3 Implement remove_key() - DELETE /v1/users/{user}/sshPublicKeys/{fingerprint}
- [x] 3.4 Parse GCP API JSON responses

## 4. OS Login Detection
- [x] 4.1 Detect "API not enabled" errors
- [x] 4.2 Show setup instructions with link to GCP Console
- [x] 4.3 Add retry after user enables OS Login

## 5. UI Integration
- [x] 5.1 Add GCP provider card to CloudProvidersPage
- [x] 5.2 Create GCPAuthDialog
- [x] 5.3 Display connection status

## 6. Token Refresh Implementation
- [x] 6.1 Store refresh token during authentication
- [x] 6.2 Load refresh token on app startup
- [x] 6.3 Implement refresh_access_token() method
- [x] 6.4 Auto-refresh on 401 errors in list_keys()
- [x] 6.5 Auto-refresh on load if validation fails
- [x] 6.6 Update disconnect() to not delete tokens from storage

## 7. Testing
- [ ] 7.1 Test Google OAuth flow
- [ ] 7.2 Test key operations
- [ ] 7.3 Test OS Login detection
- [ ] 7.4 Test with all providers connected
- [ ] 7.5 Test token refresh after expiration

## 8. Documentation
- [ ] 8.1 Update README with GCP support
- [ ] 8.2 Document OS Login API enablement
- [ ] 8.3 Add Google OAuth app registration guide
