# Add GitHub Cloud Integration (Phase 1)

## Why

KeyMaker currently only manages local SSH keys. Users who work with cloud platforms like GitHub need to manually copy and paste public keys through web interfaces, which is error-prone and tedious. This proposal adds direct GitHub integration to enable users to deploy, manage, and sync SSH keys directly from KeyMaker.

This is **Phase 1** of the broader Cloud Provider Integration feature from REFACTORING-PLAN.md. By starting with GitHub, we establish the architecture and patterns that will be reused for GitLab, Bitbucket, AWS, Azure, and GCP in future phases.

## What Changes

- Add GitHub OAuth 2.0 authentication flow using libsoup-3.0 HTTP client
- Add new "Cloud Providers" page in the main navigation sidebar
- Implement GitHub SSH key operations:
  - List all SSH keys associated with the authenticated GitHub account
  - Deploy local public keys to GitHub
  - Remove keys from GitHub
  - View key metadata (title, fingerprint, last used date)
- Add secure token storage using GSettings/Secret Service
- Add account management UI (connect/disconnect GitHub account)
- Add error handling for offline mode, rate limits, and API failures
- Add security warnings before deploying keys to cloud

**New Dependency**: libsoup-3.0 (GNOME HTTP client library)

## Impact

- **Affected specs**: Creates new `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/` - New directory for cloud provider backends
  - `src/ui/pages/CloudProvidersPage.vala` - New UI page
  - `src/ui/dialogs/GitHubAuthDialog.vala` - OAuth authentication flow
  - `src/ui/dialogs/CloudKeyDeployDialog.vala` - Key deployment dialogs
  - `meson.build` - Add libsoup-3.0 dependency
  - `data/ui/pages/` - New Blueprint files for cloud UI
- **Future extensibility**: This design enables adding other providers (GitLab, AWS, etc.) in follow-up phases

## Breaking Changes

None. This is a purely additive feature.

## Future Phases

- **Phase 2**: Add GitLab integration using the same architecture
- **Phase 3**: Add Bitbucket integration
- **Phase 4**: Add AWS IAM integration
- **Phase 5**: Add Azure DevOps integration
- **Phase 6**: Add GCP Cloud Identity integration
- **Phase 7**: Multi-account support per provider
- **Phase 8**: Two-way sync and conflict resolution
