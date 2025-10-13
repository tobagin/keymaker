# Design: GitLab Cloud Integration

## Context

Phase 1 established the `CloudProvider` interface and GitHub integration. GitLab has a similar API and OAuth flow, making it an ideal candidate to validate the abstraction's extensibility.

**Key Difference from GitHub**: GitLab supports self-hosted instances, so users need to specify a custom base URL (e.g., `https://gitlab.mycompany.com`).

## Goals / Non-Goals

### Goals
- Support GitLab.com (default) and self-hosted GitLab instances
- Reuse existing CloudProvider infrastructure
- Validate provider abstraction works for multiple OAuth providers
- Maintain feature parity with GitHub integration

### Non-Goals
- GitLab-specific features (merge request integration, CI/CD, etc.)
- GitLab group/project deploy keys (only user keys)
- Multi-account support (deferred to Phase 7)

## Decisions

### 1. Self-Hosted Instance Support

**Decision**: Allow users to configure custom GitLab instance URL in preferences.

**Implementation**:
- Add GSettings key: `cloud-provider-gitlab-instance-url` (default: `https://gitlab.com`)
- Add "Configure Instance" button next to "Connect" button in UI
- Show instance URL in provider card: "Connected to gitlab.mycompany.com as username"

**Rationale**: GitLab's self-hosted model is core to its value proposition. Many enterprises run their own instances.

### 2. OAuth App Registration

**Decision**: Provide default OAuth credentials for GitLab.com, require custom OAuth app for self-hosted instances.

**Rationale**:
- GitLab.com: Can ship with pre-registered OAuth app (like GitHub)
- Self-hosted: Admin must register OAuth app (no way around this)

**User Flow for Self-Hosted**:
1. User enters instance URL
2. KeyMaker shows instructions: "Register an OAuth application at https://gitlab.mycompany.com/oauth/applications"
3. User provides Client ID and Secret
4. KeyMaker stores credentials in Secret Service

### 3. API Differences from GitHub

GitLab API v4 differences:
- Endpoint prefix: `/api/v4/` (GitHub uses no prefix)
- Key list: `/api/v4/user/keys` (same structure as GitHub)
- Deploy key: POST `/api/v4/user/keys` with `{"title": "...", "key": "..."}`
- Remove key: DELETE `/api/v4/user/keys/:id`
- Rate limit headers: `RateLimit-Remaining` (not `X-RateLimit-Remaining`)

**Decision**: Abstract these differences in `GitLabProvider` class. No changes needed to interface.

### 4. Token Scopes

**Decision**: Request `read_user` + `api` scopes.

**Rationale**:
- `read_user`: Get authenticated user info
- `api`: Full API access (GitLab's scope model is coarser than GitHub)

**Alternative Considered**: Request only `read_api` + `write_repository`. Rejected because it doesn't cover user key management.

## Risks / Trade-offs

### Risk 1: Self-Hosted Instance Compatibility
**Risk**: Older GitLab versions might have different API schemas.

**Mitigation**:
- Document minimum GitLab version (13.0+, released 2020)
- Add API version detection: Call `/api/v4/version` on connect
- Show warning if version < 13.0

### Risk 2: OAuth Callback URL Whitelist
**Risk**: Self-hosted admins must whitelist `http://localhost:8765/callback` in OAuth app.

**Mitigation**:
- Clear instructions in setup dialog
- Show common error message if redirect fails: "Ensure http://localhost:8765/callback is whitelisted"

### Risk 3: SSL Certificate Validation
**Risk**: Self-hosted instances might use self-signed certificates.

**Mitigation**:
- Add preference: "Allow self-signed certificates (insecure)"
- Show security warning if enabled
- Default: OFF (secure by default)

## Migration Plan

N/A - Additive feature, no existing data.

## Open Questions

1. **Should we support GitLab project/group deploy keys?**
   - Decision: No, Phase 2 focuses on user keys only. Project keys could be Phase 9.

2. **Should we detect GitLab instance version and adapt API calls?**
   - Decision: Yes, call `/api/v4/version` on connect. Fail gracefully if version < 13.0.

3. **Should we allow multiple self-hosted instances?**
   - Decision: Not in Phase 2. Phase 7 (multi-account) will enable this.
