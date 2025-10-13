# Design: Multi-Account Support

## Context

Phase 7 is a major architectural evolution. Phases 1-6 assume one account per provider. Real-world users need multiple accounts:
- GitHub: Personal + Work
- AWS: Multiple IAM users for different projects
- GitLab: GitLab.com + self-hosted company instance
- Azure: Multiple organizations

This design enables multiple accounts per provider without breaking existing single-account users.

## Goals / Non-Goals

### Goals
- Support unlimited accounts per provider
- Allow users to add, remove, label, and switch between accounts
- Preserve existing single-account data (automatic migration)
- Minimal UI complexity (dropdown switcher, not tabs/pages)
- Independent account lifecycle (disconnect one, keep others)

### Non-Goals
- Cross-account key synchronization (deferred to Phase 8)
- Simultaneous multi-account operations (can only view one account at a time)
- Account-level permissions (all accounts have same capabilities)

## Decisions

### 1. Account Identification: UUIDs

**Decision**: Assign each connected account a unique UUID (v4).

**Rationale**:
- Username alone is insufficient (same username across providers)
- UUIDs enable stable references across account relabeling
- Used as lookup key in Secret Service

**Example**:
- Account 1: `{12345678-1234-1234-1234-123456789abc}` → "Personal GitHub (tobagin)"
- Account 2: `{87654321-4321-4321-4321-987654321def}` → "Work GitHub (tobagin-work)"

### 2. Account Storage Schema

**Decision**: Store accounts in GSettings array, tokens in Secret Service keyed by account UUID.

**GSettings** (`cloud-provider-<provider>-accounts`):
```json
[
  {
    "id": "{uuid-1}",
    "label": "Personal GitHub",
    "username": "tobagin",
    "created_at": "2025-10-13T12:34:56Z",
    "last_used": "2025-10-13T14:20:00Z"
  },
  {
    "id": "{uuid-2}",
    "label": "Work GitHub",
    "username": "tobagin-work",
    "created_at": "2025-10-12T09:00:00Z",
    "last_used": "2025-10-13T10:15:00Z"
  }
]
```

**Secret Service**:
```
service = "keymaker-github"
account_id = "{uuid-1}"
account = "tobagin"  # For backwards compat
token = "ghp_..."
```

### 3. Active Account Tracking

**Decision**: Store active account UUID per provider in GSettings.

**GSettings Keys**:
- `cloud-provider-github-active-account` = `"{uuid-1}"`
- `cloud-provider-gitlab-active-account` = `"{uuid-3}"`
- etc.

**Rationale**: Preserves user's last selected account across app restarts.

### 4. UI: Account Switcher Dropdown

**Decision**: Add dropdown in each provider card header: "Account: [Personal GitHub ▾]"

**Behavior**:
- Click dropdown → Show list of accounts for this provider
- Select account → Switch view to that account's keys
- "+ Add Account" option at bottom → Start OAuth flow for new account
- "Manage Accounts..." option → Open AccountManagerDialog

**Alternative Considered**: Separate page for each account. Rejected because it clutters navigation.

### 5. Account Labeling

**Decision**: Auto-generate labels (`"GitHub (username)"`) with option to rename.

**Auto-generated Labels**:
- GitHub: `"GitHub (username)"`
- GitLab (self-hosted): `"GitLab - gitlab.company.com (username)"`
- AWS: `"AWS (username) - us-east-1"`
- Azure: `"Azure DevOps (org/username)"`

**Rename Flow**:
- Right-click account in dropdown → "Rename..."
- Or: Open Manage Accounts dialog → Edit label

### 6. Migration Strategy

**Decision**: Automatic migration on first launch after Phase 7 upgrade.

**Migration Steps**:
1. Detect old token format (no `account_id` attribute)
2. Generate UUID for existing account
3. Create account entry in GSettings array
4. Update Secret Service entry with `account_id`
5. Set as active account
6. Label as "Default Account"

**Rollback**: If migration fails, Phase 7 features are disabled, old format still works.

### 7. CloudProvider Interface Changes

**Decision**: Add account context parameter to CloudProvider methods.

**Before** (Phase 1-6):
```vala
public interface CloudProvider : Object {
    public abstract async bool authenticate() throws Error;
    public abstract async Gee.List<CloudKeyMetadata> list_keys() throws Error;
    // ...
}
```

**After** (Phase 7):
```vala
public interface CloudProvider : Object {
    public abstract async bool authenticate(string? account_label = null) throws Error;
    public abstract async Gee.List<CloudKeyMetadata> list_keys(string account_id) throws Error;
    public abstract async Gee.List<AccountInfo> list_accounts() throws Error;
    public abstract async void switch_account(string account_id) throws Error;
    // ...
}
```

**Breaking Change**: All provider implementations must update.

### 8. Account Manager Dialog

**Decision**: Create dedicated dialog for account management.

**Features**:
- List all accounts across all providers
- Edit account labels
- Remove accounts (with confirmation)
- View last used timestamp
- Set default account per provider

**Layout**:
```
┌─────────────────────────────────────┐
│ Manage Cloud Accounts               │
├─────────────────────────────────────┤
│ GitHub                              │
│   □ Personal GitHub (tobagin)       │
│     Last used: 2 hours ago          │
│     [Rename] [Remove]               │
│   □ Work GitHub (tobagin-work)      │
│     Last used: Yesterday            │
│     [Rename] [Remove]               │
│                                     │
│ GitLab                              │
│   □ GitLab.com (tobagin)            │
│     Last used: 3 days ago           │
│     [Rename] [Remove]               │
│                                     │
│ AWS                                 │
│   □ AWS Personal (user-personal)    │
│     Last used: 1 week ago           │
│     [Rename] [Remove]               │
└─────────────────────────────────────┘
```

## Risks / Trade-offs

### Risk 1: Migration Failure
**Risk**: Token migration might fail for some users (corrupted Secret Service, permission issues).

**Mitigation**:
- Extensive testing on various GNOME versions
- Fallback: If migration fails, disable Phase 7 features, keep old format working
- Log migration errors for debugging

### Risk 2: UI Complexity
**Risk**: Account switcher might confuse users who only have one account.

**Mitigation**:
- Hide dropdown if only one account exists (show plain text instead)
- Clear onboarding: "You can add multiple accounts by clicking..."

### Risk 3: Performance with Many Accounts
**Risk**: Loading 10+ accounts might slow down UI.

**Mitigation**:
- Lazy load key lists (only fetch for active account)
- Cache account metadata (username, label) in GSettings
- Limit to 10 accounts per provider (show warning if reached)

### Risk 4: Token Rotation Confusion
**Risk**: Users might forget which account's token needs rotating.

**Mitigation**:
- Show last used timestamp per account
- Add optional reminder: "Account 'Work GitHub' hasn't been used in 90 days. Consider reviewing."

## Migration Plan

**Phase 1: Pre-Migration (before Phase 7 code runs)**
- Backup existing Secret Service tokens
- Log current token storage schema

**Phase 2: Migration (first launch after Phase 7)**
1. Check for `cloud-provider-<provider>-accounts` in GSettings
2. If missing, assume Phase 1-6 single-account format
3. For each provider:
   - Retrieve token from Secret Service (old format)
   - Generate UUID for account
   - Create account entry in GSettings
   - Update Secret Service with `account_id` attribute
   - Set as active account
4. Mark migration as complete: `cloud-provider-migration-completed = true`

**Phase 3: Post-Migration**
- All future operations use new format
- Old format is never written again

## Open Questions

1. **Should we support account sync across devices?**
   - Decision: No, Phase 7 is local-only. Cloud sync can be Phase 12 if requested.

2. **Should we allow duplicate usernames per provider (e.g., two "tobagin" GitHub accounts)?**
   - Decision: Yes, but require distinct labels to avoid confusion.

3. **Should we support account groups (e.g., "Work Accounts" containing Work GitHub + Work GitLab)?**
   - Decision: No, Phase 7 keeps accounts independent. Grouping can be Phase 13.

4. **Should we support account import/export?**
   - Decision: Not in Phase 7. Could be useful for backup/restore in Phase 14.
