# Add Azure DevOps Integration (Phase 5)

## Why

Azure DevOps is Microsoft's cloud platform for Git repositories, CI/CD pipelines, and project management. Many enterprise teams use Azure DevOps, and developers need to manage SSH keys for Azure Repos (Git repository hosting).

This proposal adds Azure DevOps integration using OAuth 2.0 with Microsoft identity platform.

## What Changes

- Add Azure DevOps OAuth 2.0 authentication using Microsoft identity platform
- Implement `AzureProvider` class following the `CloudProvider` interface
- Add Azure DevOps REST API SSH key operations:
  - List SSH keys (`GET https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens`)
  - Add SSH keys (`POST https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens`)
  - Delete SSH keys (`DELETE https://app.vssps.visualstudio.com/_apis/Tokens/SessionTokens/{tokenId}`)
- Support Azure DevOps organizations (e.g., `https://dev.azure.com/myorg`)
- Update Cloud Providers page UI to show Azure card

**Dependencies**: Reuses libsoup-3.0 from Phase 1 (no new dependencies)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/AzureProvider.vala` - New provider implementation
  - `src/backend/cloud/CloudProviderType.vala` - Add AZURE enum value
  - `src/ui/pages/CloudProvidersPage.vala` - Add Azure card to UI
  - `src/ui/dialogs/AzureAuthDialog.vala` - Azure OAuth flow
  - GSettings schema - Add Azure-specific keys
- **Dependencies on previous phases**: Requires Phase 1 (GitHub)
- **Code reuse**: ~75% reuse from OAuth providers (GitHub/GitLab/Bitbucket)

## Breaking Changes

None. Purely additive.

## Sequencing

**MUST complete Phase 1 before starting Phase 5.**
