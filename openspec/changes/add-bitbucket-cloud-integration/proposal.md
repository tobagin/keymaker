# Add Bitbucket Cloud Integration (Phase 3)

## Why

With GitHub and GitLab support complete, Bitbucket is the third major Git hosting platform that needs integration. Bitbucket is popular in enterprise environments using Atlassian tools (Jira, Confluence) and supports both personal and workspace SSH keys.

This proposal adds Bitbucket Cloud integration (bitbucket.org). Bitbucket Server (self-hosted) is NOT included in Phase 3 and may be added in a future phase if requested.

## What Changes

- Add Bitbucket OAuth 2.0 authentication flow
- Implement `BitbucketProvider` class following the `CloudProvider` interface
- Add Bitbucket-specific API endpoints (REST API 2.0):
  - List SSH keys (`GET /2.0/user/ssh-keys`)
  - Deploy keys (`POST /2.0/user/ssh-keys`)
  - Remove keys (`DELETE /2.0/user/ssh-keys/{key_id}`)
- Update Cloud Providers page UI to show Bitbucket card
- Reuse existing authentication and key management dialogs

**Dependencies**: Reuses libsoup-3.0 from Phase 1 (no new dependencies)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/BitbucketProvider.vala` - New provider implementation
  - `src/backend/cloud/CloudProviderType.vala` - Add BITBUCKET enum value
  - `src/backend/cloud/CloudProviderManager.vala` - Register Bitbucket provider
  - `src/ui/pages/CloudProvidersPage.vala` - Add Bitbucket card to UI
  - `src/ui/dialogs/BitbucketAuthDialog.vala` - Bitbucket OAuth flow
  - GSettings schema - Add Bitbucket-specific keys
- **Dependencies on previous phases**: Requires Phase 1 (GitHub) to be complete; Phase 2 (GitLab) is recommended but not required
- **Code reuse**: ~80% of Phase 1 infrastructure is reused

## Breaking Changes

None. This is purely additive.

## Sequencing

**MUST complete Phase 1 before starting Phase 3.**
Phase 2 (GitLab) is recommended but not strictly required.

## Scope Limitation

This phase covers **Bitbucket Cloud only** (bitbucket.org). Bitbucket Server (self-hosted) is excluded due to different API and authentication mechanisms. If demand exists, Bitbucket Server can be added in Phase 9.
