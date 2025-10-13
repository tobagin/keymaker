# Implementation Tasks

## 1. Core Infrastructure Changes

- [ ] 1.1 Add UUID generation utility using GLib.Uuid
- [ ] 1.2 Define AccountInfo data model (id, label, username, created_at, last_used)
- [ ] 1.3 Update CloudProvider interface to add account context parameters
- [ ] 1.4 Update CloudProviderManager to support account registry

## 2. Token Storage Schema Updates

- [ ] 2.1 Add `account_id` attribute to Secret Service schema
- [ ] 2.2 Update token storage helper to include account_id
- [ ] 2.3 Update token retrieval helper to lookup by account_id
- [ ] 2.4 Update token deletion helper to remove by account_id

## 3. GSettings Schema Extensions

- [ ] 3.1 Add `cloud-provider-<provider>-accounts` array keys
- [ ] 3.2 Add `cloud-provider-<provider>-active-account` string keys
- [ ] 3.3 Add `cloud-provider-migration-completed` boolean key
- [ ] 3.4 Update `data/io.github.tobagin.keysmith.gschema.xml.in`

## 4. Migration Implementation

- [ ] 4.1 Create migration module `src/backend/cloud/AccountMigration.vala`
- [ ] 4.2 Implement old format detection
- [ ] 4.3 Implement UUID generation for existing accounts
- [ ] 4.4 Implement account entry creation in GSettings
- [ ] 4.5 Implement Secret Service token update with account_id
- [ ] 4.6 Implement migration failure fallback
- [ ] 4.7 Run migration on app startup (before loading providers)
- [ ] 4.8 Log migration status and errors

## 5. Update All Provider Implementations

- [ ] 5.1 Update GitHubProvider for multi-account
- [ ] 5.2 Update GitLabProvider for multi-account
- [ ] 5.3 Update BitbucketProvider for multi-account
- [ ] 5.4 Update AWSProvider for multi-account
- [ ] 5.5 Update AzureProvider for multi-account
- [ ] 5.6 Update GCPProvider for multi-account
- [ ] 5.7 Implement list_accounts() for all providers
- [ ] 5.8 Implement switch_account() for all providers

## 6. Account Switcher UI

- [ ] 6.1 Add account dropdown widget to provider card header
- [ ] 6.2 Populate dropdown with accounts for current provider
- [ ] 6.3 Implement account selection handler
- [ ] 6.4 Add "+ Add Account" menu item
- [ ] 6.5 Add "Manage Accounts..." menu item
- [ ] 6.6 Hide dropdown when only one account exists
- [ ] 6.7 Update key list view when account switches

## 7. Account Manager Dialog

- [ ] 7.1 Create `data/ui/dialogs/account_manager_dialog.blp`
- [ ] 7.2 Create `src/ui/dialogs/AccountManagerDialog.vala`
- [ ] 7.3 Implement account list view grouped by provider
- [ ] 7.4 Add "Rename" button with label editor
- [ ] 7.5 Add "Remove" button with confirmation dialog
- [ ] 7.6 Display last used timestamp (relative time)
- [ ] 7.7 Update `data/ui/meson.build` to include new Blueprint file

## 8. Account Labeling

- [ ] 8.1 Implement auto-label generation per provider
- [ ] 8.2 Implement label uniqueness validation
- [ ] 8.3 Add rename account functionality
- [ ] 8.4 Store custom labels in GSettings

## 9. Active Account Tracking

- [ ] 9.1 Store active account UUID when switching
- [ ] 9.2 Restore active account on app startup
- [ ] 9.3 Update active account timestamp on use

## 10. Account Limit Enforcement

- [ ] 10.1 Count accounts per provider
- [ ] 10.2 Disable "+ Add Account" when limit reached
- [ ] 10.3 Show warning dialog if attempting to exceed limit

## 11. Performance Optimization

- [ ] 11.1 Implement lazy key loading (only active account)
- [ ] 11.2 Cache account metadata in memory
- [ ] 11.3 Optimize dropdown population (no API calls)

## 12. Error Handling

- [ ] 12.1 Scope errors to specific account
- [ ] 12.2 Handle per-account token expiration
- [ ] 12.3 Show account-specific error messages

## 13. Testing

- [ ] 13.1 Test migration from Phase 1-6 single-account format
- [ ] 13.2 Test adding multiple accounts per provider
- [ ] 13.3 Test account switching (UI updates correctly)
- [ ] 13.4 Test account renaming
- [ ] 13.5 Test account removal
- [ ] 13.6 Test account limit enforcement (10 accounts)
- [ ] 13.7 Test migration failure fallback
- [ ] 13.8 Test with 2 GitHub + 2 GitLab + 2 AWS accounts simultaneously
- [ ] 13.9 Test active account persistence across app restarts
- [ ] 13.10 Test independent account lifecycle (disconnect one, keep others)

## 14. Documentation

- [ ] 14.1 Update README with multi-account support
- [ ] 14.2 Document migration process
- [ ] 14.3 Document account management features
- [ ] 14.4 Add user guide: "Managing Multiple Cloud Accounts"
- [ ] 14.5 Document 10-account limit and rationale

## 15. Internationalization

- [ ] 15.1 Mark all multi-account UI strings with _()
- [ ] 15.2 Add i18n for "Add Account", "Manage Accounts", "Rename", "Remove"
- [ ] 15.3 Update po/POTFILES

## 16. Final Review

- [ ] 16.1 Verify migration works on GNOME 43, 44, 45
- [ ] 16.2 Test performance with 10 accounts per provider (60 total accounts)
- [ ] 16.3 Verify no breaking changes for single-account users
- [ ] 16.4 Audit Secret Service schema changes
- [ ] 16.5 Run production build
- [ ] 16.6 Update OpenSpec tasks.md to mark all items complete
