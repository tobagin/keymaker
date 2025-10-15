# Add Azure Cloud Integration (Phase 5)

## Why

Microsoft Azure offers two distinct SSH key management systems that developers use:

1. **Azure DevOps** - For Git repository access (dev.azure.com)
2. **Azure Compute** - For Virtual Machine SSH access (Azure VMs and infrastructure)

Both are widely used in enterprise environments. Supporting both systems provides comprehensive Azure coverage for SSHer users.

## What Changes

This proposal adds **two separate cloud providers** to support both Azure systems:

### Azure DevOps Provider
- Personal Access Token (PAT) authentication with `vso.ssh` scope
- SSH key management via Azure DevOps REST API
- Operations:
  - List SSH keys: `GET https://vssps.dev.azure.com/{organization}/_apis/ssh/publickeys`
  - Add SSH keys: `POST https://vssps.dev.azure.com/{organization}/_apis/ssh/publickeys`
  - Delete SSH keys: `DELETE https://vssps.dev.azure.com/{organization}/_apis/ssh/publickeys/{keyId}`
- Organization-based (users specify their Azure DevOps organization)
- Similar to AWS (API key authentication) but uses PAT instead

### Azure Compute Provider
- OAuth 2.0 authentication with Microsoft identity platform (Azure AD)
- SSH key management via Azure Resource Manager API
- Operations:
  - List SSH keys: `GET https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Compute/sshPublicKeys`
  - Create SSH keys: `PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Compute/sshPublicKeys/{sshPublicKeyName}`
  - Delete SSH keys: `DELETE https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Compute/sshPublicKeys/{sshPublicKeyName}`
- Subscription and resource group based
- Similar to GitHub/GitLab (OAuth flow)

### UI Changes
- Add "Azure DevOps" option to provider selector
- Add "Azure Compute" option to provider selector
- Two distinct icons: `azure-devops-colour` and `azure-compute-colour`
- Both support multi-account (multiple organizations/subscriptions)

**Dependencies**: Reuses libsoup-3.0 and existing OAuth/API key patterns from previous phases

## Impact

- **Affected specs**: Adds requirements to `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/AzureDevOpsProvider.vala` - New PAT-based provider
  - `src/backend/cloud/AzureComputeProvider.vala` - New OAuth provider
  - `src/backend/cloud/CloudProviderType.vala` - Add AZURE_DEVOPS and AZURE_COMPUTE enums
  - `src/ui/pages/CloudProvidersPage.vala` - Add both Azure providers to UI
  - `src/ui/dialogs/AzureDevOpsCredentialsDialog.vala` - PAT input dialog
  - `src/ui/dialogs/AzureComputeAuthDialog.vala` - OAuth dialog (if needed)
  - GSettings schema - Add settings for both providers
- **Dependencies on previous phases**:
  - Requires Phase 1 (GitHub) for OAuth patterns
  - Requires Phase 4 (AWS) for API key/PAT patterns
- **Code reuse**:
  - Azure DevOps: ~70% reuse from AWS implementation (API key style)
  - Azure Compute: ~75% reuse from GitHub/GitLab (OAuth style)

## Breaking Changes

None. Purely additive.

## Sequencing

**MUST complete Phase 1 (GitHub) and Phase 4 (AWS) before starting Phase 5.**

Both Azure providers can be implemented in parallel since they're independent, but implementing Azure DevOps first is recommended as it's simpler (PAT-based, no OAuth flow).

## Implementation Strategy

### Recommended Order:
1. **Azure DevOps first** (simpler, PAT-based like AWS)
   - Similar complexity to AWS integration
   - Estimated: 4-6 hours
2. **Azure Compute second** (OAuth-based like GitHub)
   - More complex OAuth flow with Microsoft identity
   - Estimated: 6-8 hours

### Alternative: Implement in parallel
Both providers are independent and can be built simultaneously by different developers.

## Open Questions

1. **Azure DevOps API**: The SSH keys API (`_apis/ssh/publickeys`) is preview/undocumented. Should we:
   - Proceed with reverse-engineered API (current approach by community)
   - Wait for official documentation
   - Add disclaimer about unofficial API

2. **Azure Compute scopes**: What OAuth scopes are needed?
   - `https://management.azure.com/user_impersonation` (full access)
   - More granular scope if available

3. **Azure Compute complexity**: Users need to specify:
   - Subscription ID
   - Resource Group
   - Region
   Should we auto-discover these or require manual input?

## Risk Assessment

### Azure DevOps Risks:
- **HIGH**: Unofficial API may change without notice
- **MEDIUM**: PAT token management (users must create tokens manually)
- **LOW**: Similar patterns to AWS, well-tested

### Azure Compute Risks:
- **MEDIUM**: Complex OAuth flow with Azure AD
- **MEDIUM**: Resource hierarchy (subscription → resource group → key)
- **LOW**: Official API, stable and documented

## Success Criteria

- Users can add multiple Azure DevOps organizations
- Users can add multiple Azure Compute subscriptions
- All SSH key operations work (list, deploy, remove)
- Icons correctly distinguish between DevOps and Compute
- Credentials securely stored (PAT in Secret Service, OAuth tokens)
- Auto-reconnect on app restart for both providers
