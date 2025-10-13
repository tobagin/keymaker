# Implementation Tasks

## 1. Backend Infrastructure
- [ ] 1.1 Add `AZURE` to CloudProviderType enum
- [ ] 1.2 Create `src/backend/cloud/AzureProvider.vala`
- [ ] 1.3 Register AzureProvider in CloudProviderManager

## 2. OAuth Implementation
- [ ] 2.1 Implement Microsoft identity platform OAuth flow
- [ ] 2.2 Request scopes: vso.profile, vso.tokens
- [ ] 2.3 Handle OAuth callback and token exchange

## 3. Azure DevOps API Integration
- [ ] 3.1 Implement list_keys() - GET /_apis/Tokens/SessionTokens
- [ ] 3.2 Implement deploy_key() - POST /_apis/Tokens/SessionTokens
- [ ] 3.3 Implement remove_key() - DELETE /_apis/Tokens/SessionTokens/{id}
- [ ] 3.4 Parse Azure API JSON responses

## 4. Organization Management
- [ ] 4.1 Call /_apis/accounts to list user organizations
- [ ] 4.2 Create organization selection dialog
- [ ] 4.3 Store selected organization in GSettings
- [ ] 4.4 Display organization in provider card

## 5. UI Integration
- [ ] 5.1 Add Azure provider card to CloudProvidersPage
- [ ] 5.2 Create AzureAuthDialog
- [ ] 5.3 Display connection status with organization name

## 6. Testing
- [ ] 6.1 Test Azure OAuth flow
- [ ] 6.2 Test key operations
- [ ] 6.3 Test organization selection
- [ ] 6.4 Test with multiple providers connected

## 7. Documentation
- [ ] 7.1 Update README with Azure support
- [ ] 7.2 Document organization selection process
- [ ] 7.3 Add Azure OAuth app registration guide
