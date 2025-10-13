# Add GitLab Cloud Integration (Phase 2)

## Why

With GitHub integration complete (Phase 1), users working with GitLab.com or self-hosted GitLab instances need the same seamless SSH key management experience. GitLab is widely used in enterprise environments and open-source projects, making it a high-priority addition.

This proposal extends the cloud provider infrastructure established in Phase 1 to support GitLab, including both GitLab.com and self-hosted instances.

## What Changes

- Add GitLab OAuth 2.0 authentication flow (similar to GitHub)
- Implement `GitLabProvider` class following the `CloudProvider` interface
- Add GitLab-specific API endpoints:
  - List SSH keys (`GET /api/v4/user/keys`)
  - Deploy keys (`POST /api/v4/user/keys`)
  - Remove keys (`DELETE /api/v4/user/keys/:id`)
- Add support for self-hosted GitLab instances (custom base URL)
- Update Cloud Providers page UI to show GitLab card
- Add GitLab authentication dialog
- Reuse key deployment and removal dialogs (provider-agnostic)

**Dependencies**: Reuses libsoup-3.0 from Phase 1 (no new dependencies)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/GitLabProvider.vala` - New provider implementation
  - `src/backend/cloud/CloudProviderType.vala` - Add GITLAB enum value
  - `src/backend/cloud/CloudProviderManager.vala` - Register GitLab provider
  - `src/ui/pages/CloudProvidersPage.vala` - Add GitLab card to UI
  - `src/ui/dialogs/GitLabAuthDialog.vala` - GitLab OAuth flow
  - `data/ui/dialogs/gitlab_instance_config_dialog.blp` - Self-hosted instance URL input
  - GSettings schema - Add GitLab-specific keys
- **Dependencies on Phase 1**: Requires Phase 1 (GitHub integration) to be complete
- **Code reuse**: ~70% of Phase 1 infrastructure is reused (CloudProvider interface, token storage, HTTP client, UI dialogs)

## Breaking Changes

None. This is purely additive.

## Sequencing

**MUST complete Phase 1 (GitHub integration) before starting Phase 2.**

Phase 2 validates that the `CloudProvider` abstraction works for multiple providers with similar OAuth flows.
