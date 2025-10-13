# Design: Bitbucket Cloud Integration

## Context

Bitbucket uses OAuth 2.0 like GitHub and GitLab, but has some API differences:
- REST API 2.0 uses different endpoint paths
- Rate limiting is less restrictive (60 requests/minute for authenticated users)
- Response format uses `pagelen`, `next`, `values` pagination (not simple arrays)
- SSH key management API is simpler (no separate deploy keys for repos)

## Goals / Non-Goals

### Goals
- Support Bitbucket Cloud (bitbucket.org) SSH key management
- Maintain feature parity with GitHub/GitLab integrations
- Handle Bitbucket's pagination model

### Non-Goals
- Bitbucket Server (self-hosted) support (different API entirely)
- Workspace-level deploy keys (only user keys)
- Repository-level deploy keys
- Bitbucket Pipelines integration

## Decisions

### 1. API Version: REST API 2.0

**Decision**: Use Bitbucket Cloud REST API 2.0.

**Rationale**:
- Current stable API (1.0 is deprecated)
- Well-documented SSH key endpoints
- OAuth 2.0 compatible

**Endpoints**:
- Base URL: `https://api.bitbucket.org/2.0/`
- List keys: `GET /2.0/user/ssh-keys`
- Deploy key: `POST /2.0/user/ssh-keys`
- Remove key: `DELETE /2.0/user/ssh-keys/{key_id}`
- User info: `GET /2.0/user`

### 2. OAuth Scopes

**Decision**: Request `account` and `ssh-key:write` scopes.

**Rationale**:
- `account`: Read user profile (username, email)
- `ssh-key:write`: Full SSH key management (includes read access)

**Alternative Considered**: Request `ssh-key:read` + `ssh-key:write` separately. Rejected because `:write` includes `:read`.

### 3. Pagination Handling

**Decision**: Implement pagination helper for Bitbucket's cursor-based pagination.

**Bitbucket Response Format**:
```json
{
  "pagelen": 10,
  "values": [ /* key objects */ ],
  "page": 1,
  "size": 25,
  "next": "https://api.bitbucket.org/2.0/user/ssh-keys?page=2"
}
```

**Implementation**:
- Extract `values` array for key list
- Follow `next` URL if present (for users with 10+ keys)
- Limit to 100 keys total (pagination stops after 10 pages)

### 4. Key ID Format

**Decision**: Use Bitbucket's UUID-based key IDs.

**Rationale**: Bitbucket uses UUIDs like `{12345678-1234-1234-1234-123456789abc}` instead of integer IDs. Store as-is.

### 5. Rate Limiting

**Decision**: Parse Bitbucket rate limit headers: `X-RateLimit-Remaining`, `X-RateLimit-Reset`.

**Rationale**: Similar to GitHub's headers (Phase 1 code can be reused with minor changes).

## Risks / Trade-offs

### Risk 1: Pagination Performance
**Risk**: Users with many keys (50+) require multiple API calls.

**Mitigation**:
- Cache paginated results
- Show loading progress: "Loading keys... (25 of 50+)"
- Limit to 100 keys max

### Risk 2: UUID Key IDs
**Risk**: UUIDs are verbose (36 characters) and harder to debug.

**Mitigation**:
- Store full UUID internally
- Display truncated UUID in debug logs: `{12345678...}`

### Risk 3: No "Last Used" Timestamp
**Risk**: Bitbucket API doesn't provide `last_used` field like GitHub.

**Mitigation**:
- Display "Last used: Not available" in UI
- Document this limitation

## Migration Plan

N/A - Additive feature, no existing data.

## Open Questions

1. **Should we support Bitbucket Server in the future?**
   - Decision: Defer to Phase 9 if user demand exists. API is completely different (not just URL change).

2. **Should we handle workspace-level keys?**
   - Decision: No, Phase 3 focuses on user-level keys only.
