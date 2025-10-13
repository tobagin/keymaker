# Add Multi-Account Support (Phase 7)

## Why

Users often have multiple accounts per cloud provider (e.g., personal and work GitHub accounts, multiple AWS IAM users, multiple Azure organizations). Currently, KeyMaker only supports one account per provider. This proposal adds multi-account support, allowing users to connect and switch between multiple accounts for each provider.

This is a **cross-cutting architectural change** that affects all provider implementations (Phases 1-6).

## What Changes

- Extend CloudProvider interface to support multiple accounts
- Add account management UI: list, add, remove, switch accounts
- Update token storage schema to support multiple tokens per provider
- Add account switcher dropdown in each provider card
- Update all provider implementations (GitHub, GitLab, Bitbucket, AWS, Azure, GCP) to support multi-account
- Add account labels/nicknames (e.g., "Personal GitHub", "Work GitHub")

**Dependencies**: Requires Phases 1-6 to maximize value (though can be implemented with fewer providers)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability (significant changes)
- **Affected code**:
  - `src/backend/cloud/CloudProvider.vala` - Interface changes for account context
  - `src/backend/cloud/CloudProviderManager.vala` - Account registry and switching
  - `src/backend/cloud/*Provider.vala` - All provider implementations updated
  - `src/ui/pages/CloudProvidersPage.vala` - Account switcher UI
  - `src/ui/dialogs/AccountManagerDialog.vala` - New account management dialog
  - Token storage schema - Support multiple tokens per provider
  - GSettings - Account preferences and active account tracking
- **Breaking changes**: **YES** - Token storage schema changes (migration required)
- **Migration**: Existing single-account tokens will be migrated to "Default Account"

## Breaking Changes

**Token Storage Schema**: Existing tokens will be migrated from single-account format to multi-account format. Migration happens automatically on first launch after upgrade.

**Before** (Phases 1-6):
```
service="keymaker-github", account="username"
```

**After** (Phase 7):
```
service="keymaker-github", account="username", account_id="<uuid>"
```

## Sequencing

**SHOULD complete Phases 1-6 (all providers) before starting Phase 7.**

Can be implemented with fewer providers, but maximum value comes from supporting multi-account across all providers.

## Complexity Warning

This is the most architecturally complex phase. It requires:
- Refactoring all provider implementations
- Token storage migration
- UI redesign for account management
- Careful UX design for account switching

Estimated effort: 2-3 weeks (compared to 1 week for single-provider phases).
