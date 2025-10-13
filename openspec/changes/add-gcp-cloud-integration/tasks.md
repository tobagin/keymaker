# Implementation Tasks

## 1. Backend Infrastructure
- [ ] 1.1 Add `GCP` to CloudProviderType enum
- [ ] 1.2 Create `src/backend/cloud/GCPProvider.vala`
- [ ] 1.3 Register GCPProvider in CloudProviderManager

## 2. OAuth Implementation
- [ ] 2.1 Implement Google OAuth 2.0 flow
- [ ] 2.2 Request scope: https://www.googleapis.com/auth/cloud-platform
- [ ] 2.3 Handle OAuth callback and token exchange

## 3. OS Login API Integration
- [ ] 3.1 Implement list_keys() - GET /v1/users/{user}/sshPublicKeys
- [ ] 3.2 Implement deploy_key() - POST /v1/users/{user}:importSshPublicKey
- [ ] 3.3 Implement remove_key() - DELETE /v1/users/{user}/sshPublicKeys/{fingerprint}
- [ ] 3.4 Parse GCP API JSON responses

## 4. OS Login Detection
- [ ] 4.1 Detect "API not enabled" errors
- [ ] 4.2 Show setup instructions with link to GCP Console
- [ ] 4.3 Add retry after user enables OS Login

## 5. UI Integration
- [ ] 5.1 Add GCP provider card to CloudProvidersPage
- [ ] 5.2 Create GCPAuthDialog
- [ ] 5.3 Display connection status

## 6. Testing
- [ ] 6.1 Test Google OAuth flow
- [ ] 6.2 Test key operations
- [ ] 6.3 Test OS Login detection
- [ ] 6.4 Test with all providers connected

## 7. Documentation
- [ ] 7.1 Update README with GCP support
- [ ] 7.2 Document OS Login API enablement
- [ ] 7.3 Add Google OAuth app registration guide
