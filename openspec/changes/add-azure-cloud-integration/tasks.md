# Azure Cloud Integration - Implementation Tasks

**Note**: This phase includes TWO independent providers: Azure DevOps (PAT-based) and Azure Compute (OAuth-based).

## Phase 1: Azure DevOps Provider (~4-6 hours)

### Backend
- [ ] 1.1 Add `AZURE_DEVOPS` to CloudProviderType enum
- [ ] 1.2 Create `src/backend/cloud/AzureDevOpsProvider.vala` (~400 lines)
- [ ] 1.3 Implement PAT authentication (Basic auth)
- [ ] 1.4 Implement API calls: list_keys(), deploy_key(), remove_key()
- [ ] 1.5 Use endpoint: `https://vssps.dev.azure.com/{org}/_apis/ssh/publickeys`
- [ ] 1.6 Store PAT in Secret Service
- [ ] 1.7 Add error handling for Azure DevOps errors

### UI
- [ ] 1.8 Create `AzureDevOpsCredentialsDialog.vala` (~200 lines)
- [ ] 1.9 Create `azure_devops_credentials_dialog.blp`
- [ ] 1.10 Add organization name + PAT input fields
- [ ] 1.11 Add "Azure DevOps" to CloudProvidersPage
- [ ] 1.12 Add icon support: `azure-devops-colour`

### Testing
- [ ] 1.13 Test with real Azure DevOps organization
- [ ] 1.14 Test multi-account (multiple organizations)
- [ ] 1.15 Test reconnect after restart

## Phase 2: Azure Compute Provider (~6-8 hours)

### Backend
- [ ] 2.1 Add `AZURE_COMPUTE` to CloudProviderType enum
- [ ] 2.2 Create `src/backend/cloud/AzureComputeProvider.vala` (~600 lines)
- [ ] 2.3 Implement OAuth 2.0 with Microsoft identity platform
- [ ] 2.4 Request scope: `https://management.azure.com/user_impersonation`
- [ ] 2.5 Implement ARM API calls for SSH keys
- [ ] 2.6 Add subscription/resource group discovery
- [ ] 2.7 Implement token refresh logic
- [ ] 2.8 Store OAuth tokens in Secret Service

### UI
- [ ] 2.9 Create `AzureComputeSetupDialog.vala` (~300 lines)
- [ ] 2.10 Create `azure_compute_setup_dialog.blp`
- [ ] 2.11 Add OAuth "Connect with Microsoft" button
- [ ] 2.12 Add subscription/resource group/region dropdowns
- [ ] 2.13 Auto-populate dropdowns from Azure API
- [ ] 2.14 Add "Azure Compute" to CloudProvidersPage
- [ ] 2.15 Add icon support: `azure-compute-colour`

### Testing
- [ ] 2.16 Test OAuth flow end-to-end
- [ ] 2.17 Test subscription selection
- [ ] 2.18 Test token refresh
- [ ] 2.19 Test with real Azure subscription

## Phase 3: Integration & Polish (~2 hours)

### Build System
- [ ] 3.1 Update `src/meson.build` with new provider files
- [ ] 3.2 Update `data/ui/meson.build` with dialog blueprints
- [ ] 3.3 Update `keysmith.gresource.xml.in`
- [ ] 3.4 Install both icons in `data/icons/meson.build`

### UI Integration
- [ ] 3.5 Handle both provider types in CloudAccountSection
- [ ] 3.6 Update get_provider_icon() for both
- [ ] 3.7 Update get_provider_username() for both
- [ ] 3.8 Test both providers work alongside GitHub/GitLab/AWS

### Settings
- [ ] 3.9 Add GSettings for Azure DevOps (organization)
- [ ] 3.10 Add GSettings for Azure Compute (subscription, resource_group, region)
- [ ] 3.11 Update JSON storage format to include Azure metadata

### Testing & Docs
- [ ] 3.12 Integration test: All 5 providers (GitHub, GitLab, AWS, Azure DevOps, Azure Compute)
- [ ] 3.13 Test multi-account for both Azure providers
- [ ] 3.14 Update README with Azure support
- [ ] 3.15 Add PAT creation guide for Azure DevOps
- [ ] 3.16 Add OAuth setup guide for Azure Compute

## Implementation Notes

**Recommended Order**: Azure DevOps → Azure Compute
- Azure DevOps is simpler (PAT-based, similar to AWS)
- Azure Compute is more complex (OAuth + resource hierarchy)
- Both can be parallelized if desired

**Total Estimate**: 12-16 hours for both providers

**Dependencies**:
- ✅ GitHub OAuth patterns (for Azure Compute)
- ✅ AWS API key patterns (for Azure DevOps)
- ✅ Icons already added
