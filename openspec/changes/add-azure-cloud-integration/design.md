# Azure Cloud Integration - Design Document

## Overview

This design covers integration of **two distinct Azure SSH key management systems**:
1. **Azure DevOps** - Git repository SSH keys
2. **Azure Compute** - Virtual Machine SSH keys

Both systems are independent and require separate provider implementations.

## Architecture Decisions

### Two Separate Providers

**Decision**: Implement as two independent `CloudProvider` implementations

**Rationale**:
- Completely different authentication mechanisms (PAT vs OAuth)
- Different API endpoints and data models
- Different user workflows and requirements
- Allows independent implementation and maintenance
- Clear separation of concerns

**Alternative Considered**: Single "Azure" provider with mode selection
- Rejected: Too complex, violates single responsibility principle
- Would require significant conditional logic throughout

### Azure DevOps Provider Design

#### Authentication Architecture
```
User Input (PAT) → Validate → Store in Secret Service
                                    ↓
                              Test API call → Success/Fail
```

**PAT Authentication Flow**:
1. User provides:
   - Azure DevOps organization name (e.g., "mycompany")
   - Personal Access Token with `vso.ssh` scope
2. Validate PAT by making test API call to list keys
3. Store PAT in GNOME Secret Service with schema:
   - service: `ssher-azure-devops-pat`
   - account: organization name
4. Construct URLs as: `https://vssps.dev.azure.com/{organization}/_apis/ssh/publickeys`

#### API Request Pattern
```vala
// All requests use Basic authentication with PAT
var auth = "Basic " + Base64.encode(":".data + pat.data);
headers["Authorization"] = auth;
headers["Content-Type"] = "application/json";
headers["Accept"] = "application/json";

// API version is required in query string
var url = @"https://vssps.dev.azure.com/$organization/_apis/ssh/publickeys?api-version=7.1-preview.1";
```

#### Data Model
```json
// Azure DevOps SSH Key Response
{
  "id": "12345",
  "keyData": "ssh-rsa AAAAB3Nza...",
  "friendlyName": "MyKey",
  "createdDate": "2025-10-15T00:00:00Z",
  "isValid": true
}
```

**Mapping to CloudKeyMetadata**:
- id → key_id
- friendlyName → name
- keyData → public_key (extract fingerprint)
- createdDate → created_at

### Azure Compute Provider Design

#### Authentication Architecture
```
OAuth 2.0 Flow → Azure AD → Access Token
                              ↓
                      Store in Secret Service
                              ↓
                      Use for ARM API calls
```

**OAuth Flow**:
1. Redirect to Microsoft identity platform:
   ```
   https://login.microsoftonline.com/common/oauth2/v2.0/authorize
   ?client_id={client_id}
   &response_type=code
   &redirect_uri={redirect_uri}
   &response_mode=query
   &scope=https://management.azure.com/user_impersonation offline_access
   &state={state}
   ```
2. User authenticates with Microsoft account
3. Receive authorization code
4. Exchange for access token:
   ```
   POST https://login.microsoftonline.com/common/oauth2/v2.0/token
   ```
5. Store access and refresh tokens in Secret Service

#### Resource Hierarchy
```
Subscription
  └── Resource Group
        └── SSH Public Key Resource
```

**User Experience Decision**:
- **Option A**: Require user to input subscription ID, resource group, region
  - Pro: Simple, explicit
  - Con: Poor UX, requires Azure knowledge

- **Option B**: Auto-discover using Azure API
  - Pro: Better UX
  - Con: More API calls, complexity

**Chosen**: **Option B** - Auto-discover subscriptions and resource groups
- List subscriptions: `GET https://management.azure.com/subscriptions`
- List resource groups: `GET https://management.azure.com/subscriptions/{id}/resourceGroups`
- Present dropdowns in UI for user selection

## Security Considerations

### Azure DevOps PAT Security
- **Storage**: GNOME Secret Service (encrypted)
- **Scope**: Recommend minimum scope `vso.ssh` (read/write SSH keys only)
- **Rotation**: Warn users that PATs expire (configurable, typically 90 days)
- **Display**: Never log PAT in debug output
- **Transmission**: HTTPS only (enforce TLS)

### Azure Compute OAuth Security
- **Token Storage**: GNOME Secret Service
- **Refresh Tokens**: Implement automatic refresh before expiration
- **Scope**: Request minimum necessary: `https://management.azure.com/user_impersonation`
- **Token Revocation**: Implement disconnect/revoke flow
- **PKCE**: Use PKCE (Proof Key for Code Exchange) for OAuth flow

## Risks / Trade-offs

### Azure DevOps Risks
- **HIGH**: Unofficial API may change without notice
- **MEDIUM**: PAT token management (users must create tokens manually)
- **LOW**: Similar patterns to AWS, well-tested

### Azure Compute Risks
- **MEDIUM**: Complex OAuth flow with Azure AD
- **MEDIUM**: Resource hierarchy (subscription → resource group → key)
- **LOW**: Official API, stable and documented
