# Design: GitHub Cloud Integration

## Context

KeyMaker is a GNOME application for managing SSH keys locally. Users frequently need to upload public keys to cloud platforms like GitHub, GitLab, and AWS. Currently, this is done manually through web interfaces.

This design establishes the foundation for cloud provider integration, starting with GitHub as the reference implementation. The architecture must support multiple providers, each with different authentication mechanisms (OAuth, API keys, IAM credentials).

### Stakeholders
- End users who manage keys for multiple cloud platforms
- Future contributors adding new cloud providers
- Security-conscious users concerned about token storage

### Constraints
- Must use native GNOME libraries (libsoup, GSettings, Secret Service)
- Must work offline gracefully (cached data, clear error messages)
- Must follow existing KeyMaker patterns (backend/UI separation, subprocess handling)
- OAuth flows require system browser (no embedded WebView for security)

## Goals / Non-Goals

### Goals
- Enable GitHub SSH key management from KeyMaker
- Establish extensible architecture for future cloud providers
- Secure token storage using GNOME Secret Service
- Clear error handling for network failures and API limits
- User-friendly OAuth flow with system browser

### Non-Goals (for Phase 1)
- Multi-account support per provider (single GitHub account only)
- Two-way sync with conflict resolution (one-way deploy for now)
- GitLab, AWS, Azure, GCP integration (future phases)
- Private key upload (only public keys should ever be sent to cloud)
- Automatic key rotation on cloud platforms

## Decisions

### 1. HTTP Client: libsoup-3.0

**Decision**: Use libsoup-3.0 for all HTTP operations.

**Rationale**:
- Native GNOME library with async/await support in Vala
- Well-integrated with GLib event loop
- Built-in OAuth support and session management
- Already used by many GNOME applications (Evolution, Epiphany)
- Better than alternatives:
  - `curl` subprocess: Awkward async handling, no OAuth helpers
  - `gio-2.0 HTTP`: Lower-level, requires more boilerplate
  - Third-party libraries: Not GNOME-native

**Trade-offs**: Adds ~500KB dependency, but worth it for developer ergonomics and maintainability.

### 2. OAuth Flow: System Browser with Callback Server

**Decision**: Open OAuth authorization URL in system browser, run local HTTP server on `localhost:8765` to receive callback.

**Rationale**:
- Recommended OAuth best practice (no embedded browser vulnerabilities)
- Avoids WebKitGTK dependency for embedded views
- User sees actual GitHub domain (phishing protection)
- Works with hardware 2FA keys (U2F/WebAuthn)

**Flow**:
1. User clicks "Connect GitHub" in KeyMaker
2. KeyMaker starts local HTTP server on `localhost:8765`
3. KeyMaker opens `https://github.com/login/oauth/authorize?...` in default browser
4. User authenticates with GitHub
5. GitHub redirects to `http://localhost:8765/callback?code=...`
6. KeyMaker exchanges code for access token
7. KeyMaker stores token in Secret Service
8. HTTP server shuts down

**Alternative Considered**: Device flow (manual code entry). Rejected because it's slower and more error-prone for desktop users.

### 3. Token Storage: GNOME Secret Service

**Decision**: Store OAuth tokens in Secret Service (libsecret), not GSettings.

**Rationale**:
- Secret Service encrypts credentials with user's login keyring
- GSettings is plaintext XML (insecure for tokens)
- Follows GNOME HIG guidelines for credential storage
- Other GNOME apps (Evolution, Epiphany) use this pattern

**Implementation**:
```vala
// Store token
Secret.password_store_sync(
    SECRET_SCHEMA,
    Secret.COLLECTION_DEFAULT,
    "GitHub OAuth Token",
    token,
    null,
    "service", "keymaker-github",
    "account", username
);

// Retrieve token
string? token = Secret.password_lookup_sync(
    SECRET_SCHEMA,
    null,
    "service", "keymaker-github",
    "account", username
);
```

### 4. Architecture: Provider Interface Pattern

**Decision**: Define abstract `CloudProvider` interface that all providers implement.

**Rationale**:
- Enables adding new providers without modifying existing code
- Centralizes common logic (error handling, rate limiting)
- Makes testing easier (mock providers)

**Structure**:
```
src/backend/cloud/
├── CloudProvider.vala          # Interface
├── CloudProviderType.vala      # Enum (GITHUB, GITLAB, AWS, ...)
├── GitHubProvider.vala         # GitHub implementation
├── CloudKeyMetadata.vala       # Data model
└── CloudProviderManager.vala   # Registry and factory
```

**Interface**:
```vala
public interface CloudProvider : Object {
    public abstract async bool authenticate() throws Error;
    public abstract async Gee.List<CloudKeyMetadata> list_keys() throws Error;
    public abstract async void deploy_key(string public_key, string title) throws Error;
    public abstract async void remove_key(string key_id) throws Error;
    public abstract bool is_authenticated();
    public abstract string get_provider_name();
}
```

### 5. UI Integration: New "Cloud Providers" Page

**Decision**: Add new sidebar navigation item "Cloud Providers" (between "Keys" and "Hosts").

**Rationale**:
- Keeps cloud operations separate from local key management
- Provides dedicated space for multi-provider management (future)
- Follows existing KeyMaker navigation patterns

**Layout**:
```
┌─────────────────────────────────────┐
│ Cloud Providers                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ GitHub                          │ │
│ │ Connected as: username          │ │
│ │ [Disconnect] [Refresh]          │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ GitHub SSH Keys (5)             │ │
│ ├─────────────────────────────────┤ │
│ │ work-laptop (RSA 4096)          │ │
│ │ home-desktop (Ed25519)          │ │
│ │ ...                             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Deploy Key to GitHub...]           │
└─────────────────────────────────────┘
```

### 6. Error Handling Strategy

**Decision**: Three-tier error handling:
1. **Network errors**: Show banner "Unable to connect to GitHub. Check your internet connection."
2. **Auth errors**: Prompt re-authentication with "GitHub session expired. Please reconnect."
3. **API errors**: Show specific error from GitHub API response

**Rationale**:
- Users need actionable error messages
- Offline mode should not crash or hang
- Rate limit errors need clear explanation (e.g., "GitHub API rate limit reached. Try again in 15 minutes.")

### 7. Security Warnings

**Decision**: Show confirmation dialog before deploying keys to cloud with:
- Key fingerprint
- Warning: "This public key will be uploaded to GitHub. Anyone with GitHub access can see it."
- Checkbox: "Don't show this again for GitHub"

**Rationale**:
- Users should be aware of what's being uploaded
- Public keys are safe to share, but users might not know this
- Aligns with KeyMaker's security-conscious design (QR backup warnings)

## Risks / Trade-offs

### Risk 1: OAuth App Registration Required
**Risk**: Users need to register a GitHub OAuth app to get client ID/secret.

**Mitigation**:
- Provide default client ID/secret in KeyMaker (for convenience)
- Allow users to bring their own OAuth app (advanced option in preferences)
- Document OAuth app creation in user guide

**Trade-off**: Default client ID means all users share the same OAuth app (rate limits apply globally). Acceptable for Phase 1; can improve in future.

### Risk 2: Token Revocation
**Risk**: If user revokes GitHub token externally (on GitHub.com), KeyMaker doesn't know until next API call fails.

**Mitigation**:
- Validate token on app startup (lightweight API call)
- Show "Disconnected" status if validation fails
- Prompt re-authentication automatically

**Trade-off**: Extra API call on startup, but worth it for UX.

### Risk 3: API Rate Limits
**Risk**: GitHub API has rate limits (5000 requests/hour for authenticated users).

**Mitigation**:
- Cache key list locally (refresh only on user action)
- Show rate limit status in UI ("4,234 requests remaining")
- Respect `X-RateLimit-Reset` header and disable UI until reset

**Trade-off**: Cached data might be stale. Acceptable; users can manually refresh.

### Risk 4: libsoup-3.0 Availability
**Risk**: libsoup-3.0 might not be available on all distros (older GNOME versions use libsoup-2.4).

**Mitigation**:
- Check meson.build dependency: `dependency('libsoup-3.0', version: '>= 3.0')`
- Fall back to libsoup-2.4 if needed (requires minor API changes)
- Document minimum GNOME version in README (GNOME 43+)

**Trade-off**: Increased maintenance burden for multi-version support. Phase 1 targets libsoup-3.0 only; can add fallback if user demand exists.

## Migration Plan

N/A - This is a new feature with no existing data to migrate.

## Open Questions

1. **Should we support GitHub Enterprise?**
   - Decision: Not in Phase 1. Add in future if requested (requires custom base URL setting).

2. **Should we sync key titles from local key comments?**
   - Decision: Yes. Extract comment from `~/.ssh/id_rsa.pub` and use as GitHub key title. Fallback to "KeyMaker Key (YYYY-MM-DD)" if no comment.

3. **Should we show key usage statistics from GitHub?**
   - Decision: Yes. GitHub API returns "last_used" timestamp. Display in UI as "Last used: 3 days ago".

4. **Should we auto-refresh key list in background?**
   - Decision: No. Manual refresh only (button + keyboard shortcut). Background polling wastes API quota and battery.

5. **Should we allow deploying multiple keys at once?**
   - Decision: Phase 1 supports single key deployment. Batch deployment in Phase 2 if needed.

## Implementation Phases

This design describes Phase 1 (GitHub only). Future phases:

- **Phase 2**: GitLab (reuse CloudProvider interface, add GitLabProvider)
- **Phase 3**: Bitbucket (similar OAuth flow)
- **Phase 4**: AWS IAM (different auth: API keys, not OAuth)
- **Phase 5**: Multi-account support (store multiple tokens per provider)
- **Phase 6**: Two-way sync (detect cloud-only keys, offer to import)

Phase 1 establishes the foundation. Each future phase should be a separate OpenSpec change proposal.
