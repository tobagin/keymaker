# Cloud Provider Integration Roadmap

This document provides an overview of all 8 phases for implementing cloud provider integration in KeyMaker (Feature 2 from REFACTORING-PLAN.md). Each phase has a complete OpenSpec proposal ready for implementation.

## 🎯 Vision

Transform KeyMaker from a local SSH key manager into a comprehensive cloud-integrated key management platform, supporting GitHub, GitLab, Bitbucket, AWS, Azure, and GCP with multi-account support and two-way synchronization.

## 📊 Phase Overview

| Phase | Feature | Effort | Dependencies | Status |
|-------|---------|--------|--------------|--------|
| **1** | GitHub Integration | 1-2 weeks | None | ✅ Proposed |
| **2** | GitLab Integration | 1 week | Phase 1 | ✅ Proposed |
| **3** | Bitbucket Integration | 1 week | Phase 1 | ✅ Proposed |
| **4** | AWS IAM Integration | 2 weeks | Phase 1 | ✅ Proposed |
| **5** | Azure DevOps Integration | 1 week | Phase 1 | ✅ Proposed |
| **6** | GCP Integration | 1 week | Phase 1 | ✅ Proposed |
| **7** | Multi-Account Support | 2-3 weeks | Phases 1-6 | ✅ Proposed |
| **8** | Two-Way Sync | 2-3 weeks | Phase 1, Phase 7 recommended | ✅ Proposed |

**Total Estimated Effort**: 11-15 weeks (3-4 months)

---

## Phase 1: GitHub Integration (Foundation)

### Location
`openspec/changes/add-github-cloud-integration/`

### Summary
Establishes the foundational cloud provider architecture with GitHub as the reference implementation. Includes OAuth 2.0 authentication, SSH key operations (list, deploy, remove), and secure token storage.

### Key Deliverables
- CloudProvider interface (extensible for future providers)
- GitHub OAuth flow with system browser
- libsoup-3.0 HTTP client integration
- Secret Service token storage
- New "Cloud Providers" page in UI
- Rate limit handling and error management

### Why Start Here?
- GitHub is the most popular Git hosting platform
- OAuth 2.0 pattern reused by GitLab, Bitbucket, Azure, GCP
- Validates architecture before expanding to other providers

### Files
- `proposal.md` - Why, what, impact
- `design.md` - Technical architecture, OAuth flow, decisions
- `specs/cloud-provider-integration/spec.md` - 14 requirements, 48 scenarios
- `tasks.md` - 100 implementation tasks

---

## Phase 2: GitLab Integration

### Location
`openspec/changes/add-gitlab-cloud-integration/`

### Summary
Extends cloud provider support to GitLab.com and self-hosted GitLab instances. Validates that the CloudProvider interface works for multiple OAuth providers.

### Key Differentiators
- Self-hosted instance support (custom base URLs)
- Custom OAuth app registration for self-hosted
- GitLab API v4 compatibility
- SSL certificate validation toggle (for self-signed certs)

### Code Reuse
~70% reuse from Phase 1 (CloudProvider interface, token storage, HTTP client, UI dialogs)

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 14 implementation tasks

---

## Phase 3: Bitbucket Integration

### Location
`openspec/changes/add-bitbucket-cloud-integration/`

### Summary
Adds Bitbucket Cloud (bitbucket.org) support. Bitbucket Server (self-hosted) is explicitly excluded due to different API.

### Key Differentiators
- Bitbucket REST API 2.0 (pagination model)
- Cursor-based pagination (10 keys per page)
- UUID-based key IDs (not integer IDs)
- No "last used" timestamp (API limitation)

### Code Reuse
~80% reuse from Phase 1

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 14 implementation tasks

---

## Phase 4: AWS IAM Integration (API Key Authentication)

### Location
`openspec/changes/add-aws-cloud-integration/`

### Summary
First non-OAuth provider. Uses AWS Access Key ID + Secret Access Key authentication with AWS Signature Version 4 request signing.

### Key Differentiators
- **API key authentication** (not OAuth)
- Manual AWS Signature V4 implementation (no AWS SDK)
- IAM SSH public keys (not EC2 key pairs)
- 5 keys per IAM user limit
- Region selection support

### Architectural Significance
Validates that CloudProvider interface works for both OAuth AND API key authentication patterns.

### Security Considerations
- AWS credentials grant broad account access
- Never log credentials (even in debug mode)
- Recommend IAM users with limited permissions
- Show security warnings before storing credentials

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 16 implementation tasks (includes signature V4 implementation and unit tests)

---

## Phase 5: Azure DevOps Integration

### Location
`openspec/changes/add-azure-cloud-integration/`

### Summary
Adds Azure DevOps support using Microsoft identity platform OAuth 2.0.

### Key Differentiators
- Microsoft OAuth (different from GitHub/GitLab)
- Azure DevOps organization selection
- Session Tokens API (different from other providers)

### Code Reuse
~75% reuse from OAuth providers

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 7 implementation tasks

---

## Phase 6: GCP Integration

### Location
`openspec/changes/add-gcp-cloud-integration/`

### Summary
Adds Google Cloud Platform support using Google OAuth 2.0 and OS Login API.

### Key Differentiators
- Google OAuth with cloud-platform scope
- OS Login API (centralizes SSH access across GCP VMs)
- OS Login API enablement detection (guide users to enable if needed)
- GCP project selection (optional)

### Code Reuse
~75% reuse from OAuth providers

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 7 implementation tasks

---

## Phase 7: Multi-Account Support (Architectural Evolution)

### Location
`openspec/changes/add-multi-account-support/`

### Summary
**Major architectural change**: Enables multiple accounts per provider (e.g., personal + work GitHub, multiple AWS IAM users). Requires refactoring all Phase 1-6 provider implementations.

### Key Features
- UUID-based account identification
- Account switcher dropdown in UI
- Account labeling/renaming
- Independent account lifecycle
- Automatic token migration from single-account format

### Breaking Changes
**YES** - Token storage schema changes. Existing single-account tokens are automatically migrated to "Default Account" on first launch.

### Complexity Warning
Most complex phase. Requires:
- Refactoring all 6 provider implementations
- Token storage migration
- UI redesign for account management
- Account Manager dialog

### Estimated Effort
2-3 weeks (compared to 1 week for single-provider phases)

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 16 implementation tasks

---

## Phase 8: Two-Way Sync (Advanced Feature)

### Location
`openspec/changes/add-two-way-sync/`

### Summary
Transforms KeyMaker from a deployment tool to a synchronization manager. Adds ability to import cloud keys to local, detect conflicts, and provide sync status indicators.

### Key Features
- Sync status detection (synced, local-only, cloud-only, conflict)
- Import public keys from cloud (with private key validation)
- Conflict resolution dialog (Keep Local, Keep Cloud, Keep Both)
- "Sync All" batch operation
- Sync history tracking
- Sync exclusion (ignore specific keys)

### Security Considerations
- **Critical**: Only public keys are imported (never private keys)
- Private key must exist locally for import to succeed
- Backups created before any destructive operation
- Never overwrite without confirmation

### Sync States
1. **Synced** ✓ - Key exists locally and in cloud with matching fingerprint
2. **Local-only** ↑ - Deploy to cloud
3. **Cloud-only** ↓ - Import from cloud
4. **Conflict** ⚠ - Same name, different fingerprint

### Complexity Warning
Complex UX requirements for conflict resolution, fingerprint matching, and safe import operations.

### Estimated Effort
2-3 weeks

### Files
- `proposal.md`, `design.md`, `specs/`, `tasks.md`
- 19 implementation tasks

---

## 🛠️ Implementation Strategy

### Recommended Order

#### Tier 1: Foundation (Start Here)
1. **Phase 1** (GitHub) - MUST complete first
   - Establishes CloudProvider architecture
   - Validates OAuth pattern
   - Creates UI foundation

#### Tier 2: OAuth Providers (Can be parallelized)
2. **Phase 2** (GitLab) - Validates multi-provider architecture
3. **Phase 3** (Bitbucket) - Validates pagination handling

#### Tier 3: Non-OAuth Provider
4. **Phase 4** (AWS) - Validates API key authentication pattern

#### Tier 4: Additional OAuth Providers (Optional order)
5. **Phase 5** (Azure) - Enterprise users
6. **Phase 6** (GCP) - Cloud infrastructure users

#### Tier 5: Advanced Features
7. **Phase 7** (Multi-account) - After completing Phases 1-6 for maximum value
8. **Phase 8** (Two-way sync) - After Phase 1 minimum, Phase 7 recommended

### Alternative Minimal Path

If you want to deliver value faster:
1. **Phase 1** (GitHub)
2. **Phase 8** (Two-way sync for GitHub only)
3. **Phase 2-6** (Add other providers later)

This delivers two-way sync early for the most popular platform (GitHub).

---

## 📈 Value Progression

### After Phase 1
- Users can manage GitHub SSH keys from KeyMaker
- Deploy local keys to GitHub with one click
- View GitHub key metadata (last used, fingerprint)

### After Phases 1-6
- Users can manage keys across all major platforms
- Single unified interface for GitHub, GitLab, Bitbucket, AWS, Azure, GCP
- Support for both OAuth and API key authentication

### After Phase 7
- Users with multiple accounts (personal + work) fully supported
- Switch between accounts seamlessly
- Independent account lifecycle management

### After Phase 8
- Complete bidirectional synchronization
- Import cloud keys to local system
- Automatic conflict detection and resolution
- Unified view of sync status across all keys

---

## 🎯 Success Metrics

### Phase 1 (GitHub)
- ✅ Users can connect GitHub account via OAuth
- ✅ Users can list all GitHub SSH keys
- ✅ Users can deploy local keys to GitHub
- ✅ Users can remove keys from GitHub
- ✅ Offline mode works (cached data)

### Phases 2-6 (All Providers)
- ✅ All 6 cloud providers supported
- ✅ Consistent UX across all providers
- ✅ No provider-specific leaks in CloudProvider interface

### Phase 7 (Multi-Account)
- ✅ Users can connect 2+ accounts per provider
- ✅ Account switching is seamless (<1 second)
- ✅ Migration from single-account works 100%

### Phase 8 (Two-Way Sync)
- ✅ Sync status detection is accurate (fingerprint matching)
- ✅ Conflict resolution never loses data
- ✅ Import works correctly (validates private key)

---

## 🔧 Technical Architecture

### Core Components

#### CloudProvider Interface
```vala
public interface CloudProvider : Object {
    // Phase 1-6
    public abstract async bool authenticate() throws Error;
    public abstract async Gee.List<CloudKeyMetadata> list_keys() throws Error;
    public abstract async void deploy_key(string public_key, string title) throws Error;
    public abstract async void remove_key(string key_id) throws Error;

    // Phase 7 (Multi-Account)
    public abstract async Gee.List<AccountInfo> list_accounts() throws Error;
    public abstract async void switch_account(string account_id) throws Error;

    // Phase 8 (Two-Way Sync)
    public abstract async void import_key(string cloud_key_id) throws Error;
}
```

#### Provider Implementations
- `GitHubProvider` (OAuth)
- `GitLabProvider` (OAuth + self-hosted)
- `BitbucketProvider` (OAuth + pagination)
- `AWSProvider` (API keys + Signature V4)
- `AzureProvider` (Microsoft OAuth)
- `GCPProvider` (Google OAuth + OS Login)

#### Supporting Infrastructure
- `CloudProviderManager` - Provider registry
- `HttpClient` - libsoup-3.0 wrapper
- `SyncManager` - Two-way sync orchestration (Phase 8)
- `KeyComparator` - Fingerprint matching (Phase 8)
- `AccountMigration` - Single-to-multi account migration (Phase 7)

---

## 📚 Documentation

Each phase includes:
- **proposal.md** - Why, what, impact, breaking changes
- **design.md** - Technical decisions, architecture, trade-offs, risks
- **specs/cloud-provider-integration/spec.md** - Requirements and scenarios (OpenSpec format)
- **tasks.md** - Detailed implementation checklist

### Total Documentation
- **8 proposals** (~2,000 words each = 16,000 words)
- **8 design documents** (~2,500 words each = 20,000 words)
- **8 spec files** (~200 scenarios total)
- **8 task lists** (~600 tasks total)

All documents are ready for implementation **now**. No additional planning required.

---

## 🚀 Getting Started

### To Implement Phase 1 (GitHub)

1. Review the proposal:
   ```bash
   cat openspec/changes/add-github-cloud-integration/proposal.md
   ```

2. Read the design:
   ```bash
   cat openspec/changes/add-github-cloud-integration/design.md
   ```

3. Review the spec:
   ```bash
   cat openspec/changes/add-github-cloud-integration/specs/cloud-provider-integration/spec.md
   ```

4. Start working through tasks:
   ```bash
   cat openspec/changes/add-github-cloud-integration/tasks.md
   ```

5. Begin with task 1.1: "Add libsoup-3.0 dependency to meson.build"

### To Implement Any Other Phase

Same process as above. Just replace `add-github-cloud-integration` with the phase directory name:
- `add-gitlab-cloud-integration`
- `add-bitbucket-cloud-integration`
- `add-aws-cloud-integration`
- `add-azure-cloud-integration`
- `add-gcp-cloud-integration`
- `add-multi-account-support`
- `add-two-way-sync`

---

## 🎓 Key Learnings from This Planning

### Architecture Wins
1. **CloudProvider interface** enables clean provider abstraction
2. **OAuth pattern reuse** across 5 providers (GitHub, GitLab, Bitbucket, Azure, GCP)
3. **API key support** (AWS) proves interface is authentication-agnostic
4. **Multi-account from Day 1 design** would have saved Phase 7 refactor (lesson for next project)

### Complexity Hotspots
1. **Phase 4 (AWS)**: Signature V4 implementation is tricky but necessary
2. **Phase 7 (Multi-account)**: Token migration is high-risk (extensive testing required)
3. **Phase 8 (Two-way sync)**: Conflict resolution UX is critical (user confusion = data loss risk)

### Effort Distribution
- **OAuth providers** (GitHub, GitLab, Bitbucket, Azure, GCP): 1 week each = 5 weeks
- **API key provider** (AWS): 2 weeks
- **Architectural changes** (Multi-account, Two-way sync): 2-3 weeks each = 5-6 weeks
- **Total**: 11-15 weeks

### Dependencies Critical Path
```
Phase 1 (GitHub)
├── Phase 2 (GitLab)
├── Phase 3 (Bitbucket)
├── Phase 4 (AWS)
├── Phase 5 (Azure)
├── Phase 6 (GCP)
└── Phase 7 (Multi-Account) [requires all above for max value]
    └── Phase 8 (Two-Way Sync)
```

---

## 📞 Support

If you encounter issues during implementation:
1. Review the `design.md` for the relevant phase (explains decisions and trade-offs)
2. Check the `specs/` for exact requirements and scenarios
3. Refer to `tasks.md` for step-by-step guidance

---

## 🏆 Credits

All 8 phases planned and documented by Claude (Anthropic) using OpenSpec methodology.

Planning completed: October 13, 2025
Total planning time: ~2 hours
Total documentation: ~50,000 words
Total tasks defined: ~600

**Ready for implementation!** 🚀
