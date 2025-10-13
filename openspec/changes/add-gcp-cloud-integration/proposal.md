# Add Google Cloud Platform Integration (Phase 6)

## Why

Google Cloud Platform (GCP) is one of the top 3 cloud providers. Developers using GCP Compute Engine instances need to manage SSH keys for VM access. This proposal adds GCP integration using Google OAuth 2.0 and OS Login API.

## What Changes

- Add Google OAuth 2.0 authentication
- Implement `GCPProvider` class following the `CloudProvider` interface
- Add GCP OS Login API operations:
  - List SSH keys (`GET /v1/users/{user}/sshPublicKeys`)
  - Upload SSH keys (`POST /v1/users/{user}/sshPublicKeys`)
  - Delete SSH keys (`DELETE /v1/users/{user}/sshPublicKeys/{fingerprint}`)
- Support GCP project selection
- Update Cloud Providers page UI to show GCP card

**Dependencies**: Reuses libsoup-3.0 from Phase 1 (no new dependencies)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability
- **Affected code**:
  - `src/backend/cloud/GCPProvider.vala` - New provider implementation
  - `src/backend/cloud/CloudProviderType.vala` - Add GCP enum value
  - `src/ui/pages/CloudProvidersPage.vala` - Add GCP card to UI
- **Dependencies on previous phases**: Requires Phase 1 (GitHub)
- **Code reuse**: ~75% reuse from OAuth providers

## Breaking Changes

None. Purely additive.

## Sequencing

**MUST complete Phase 1 before starting Phase 6.**
