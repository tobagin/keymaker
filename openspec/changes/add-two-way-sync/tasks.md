# Implementation Tasks

## 1. Sync Manager Core

- [ ] 1.1 Create `src/backend/cloud/SyncManager.vala` class
- [ ] 1.2 Define SyncStatus data model (synced, local_only, cloud_only, conflicts)
- [ ] 1.3 Define KeySyncState model (key info + sync status)
- [ ] 1.4 Implement analyze() method (compare local and cloud keys)
- [ ] 1.5 Implement import_key() method
- [ ] 1.6 Implement upload_key() method
- [ ] 1.7 Implement sync_all() method

## 2. Fingerprint Comparison Logic

- [ ] 2.1 Create `src/backend/cloud/KeyComparator.vala` utility
- [ ] 2.2 Implement compute_fingerprint() for local keys (call ssh-keygen -l)
- [ ] 2.3 Implement fingerprint matching (local vs cloud)
- [ ] 2.4 Implement sync state determination (synced, local-only, cloud-only, conflict)
- [ ] 2.5 Handle edge cases (malformed keys, missing files)

## 3. Import Key Operation

- [ ] 3.1 Implement download_public_key() from cloud provider API
- [ ] 3.2 Implement search_private_key_by_fingerprint() in ~/.ssh/
- [ ] 3.3 Implement save_public_key_to_local(filename, content)
- [ ] 3.4 Add filename conflict detection (same name, different fingerprint)
- [ ] 3.5 Add rename prompt for import conflicts
- [ ] 3.6 Show warning when private key not found

## 4. Conflict Resolution Dialog

- [ ] 4.1 Create `data/ui/dialogs/conflict_resolution_dialog.blp`
- [ ] 4.2 Create `src/ui/dialogs/ConflictResolutionDialog.vala`
- [ ] 4.3 Display side-by-side comparison (local vs cloud)
- [ ] 4.4 Show fingerprints, creation dates, file sizes
- [ ] 4.5 Implement "Keep Local" action (upload local, overwrite cloud)
- [ ] 4.6 Implement "Keep Cloud" action (backup local, import cloud)
- [ ] 4.7 Implement "Keep Both" action (rename cloud import)
- [ ] 4.8 Update `data/ui/meson.build`

## 5. Import Key Dialog

- [ ] 5.1 Create `data/ui/dialogs/import_key_dialog.blp`
- [ ] 5.2 Create `src/ui/dialogs/ImportKeyDialog.vala`
- [ ] 5.3 Show key details (title, fingerprint, upload date)
- [ ] 5.4 Show private key status ("Found" or "Not found")
- [ ] 5.5 Add filename input (pre-filled with cloud key name)
- [ ] 5.6 Add "Import" and "Cancel" buttons
- [ ] 5.7 Show success/error messages
- [ ] 5.8 Update `data/ui/meson.build`

## 6. Sync Status Badges in UI

- [ ] 6.1 Add badge widget to key list rows
- [ ] 6.2 Implement badge rendering (✓ 🆙 ↓ ⚠)
- [ ] 6.3 Color badges (green, blue, orange, red)
- [ ] 6.4 Make badges clickable (trigger corresponding action)
- [ ] 6.5 Add tooltips ("Click to upload", "Click to import", "Click to resolve")

## 7. Sync All Operation

- [ ] 7.1 Create "Sync All" button in provider card toolbar
- [ ] 7.2 Implement sync summary dialog (show counts)
- [ ] 7.3 Implement batch upload for local-only keys
- [ ] 7.4 Implement batch import prompts for cloud-only keys
- [ ] 7.5 Implement conflict resolution prompts (one by one)
- [ ] 7.6 Show progress indicator during sync
- [ ] 7.7 Show completion summary with results

## 8. Sync History Tracking

- [ ] 8.1 Add GSettings schema `cloud-sync-history` (JSON object)
- [ ] 8.2 Record timestamp on every sync operation
- [ ] 8.3 Record sync direction (upload/import)
- [ ] 8.4 Display "Last synced: X ago" in tooltip
- [ ] 8.5 Persist history across app restarts

## 9. Automatic Sync Detection

- [ ] 9.1 Run sync analysis automatically on page load
- [ ] 9.2 Run sync analysis on "Refresh" button click
- [ ] 9.3 Show background loading indicator during analysis
- [ ] 9.4 Cache analysis results (don't re-analyze on every UI update)
- [ ] 9.5 Invalidate cache after sync operations

## 10. Sync Exclusion Feature

- [ ] 10.1 Add right-click context menu on keys
- [ ] 10.2 Add "Don't sync this key" menu item
- [ ] 10.3 Add "Resume syncing" menu item (for ignored keys)
- [ ] 10.4 Store exclusion list in GSettings `cloud-sync-exclusions`
- [ ] 10.5 Filter excluded keys from sync analysis
- [ ] 10.6 Show excluded keys with different icon (no badge)

## 11. Sync Preferences

- [ ] 11.1 Add "Two-Way Sync" section in Preferences dialog
- [ ] 11.2 Add toggle: "Enable two-way sync" (default: on)
- [ ] 11.3 Add toggle: "Always confirm before syncing" (default: on)
- [ ] 11.4 Add toggle: "Auto-sync on refresh" (default: off, experimental)
- [ ] 11.5 Store preferences in GSettings
- [ ] 11.6 Apply preferences to sync behavior

## 12. Safety and Backup

- [ ] 12.1 Implement backup_file(path) utility (creates .backup.YYYY-MM-DD.pub)
- [ ] 12.2 Backup before "Keep Cloud" conflict resolution
- [ ] 12.3 Backup before overwriting any local file
- [ ] 12.4 Add confirmation dialogs for destructive operations
- [ ] 12.5 Never auto-delete files without user approval

## 13. Update All Providers

- [ ] 13.1 Add import_key() method to CloudProvider interface
- [ ] 13.2 Implement import_key() for GitHubProvider
- [ ] 13.3 Implement import_key() for GitLabProvider
- [ ] 13.4 Implement import_key() for BitbucketProvider
- [ ] 13.5 Implement import_key() for AWSProvider
- [ ] 13.6 Implement import_key() for AzureProvider
- [ ] 13.7 Implement import_key() for GCPProvider

## 14. Performance Optimization

- [ ] 14.1 Run sync analysis in background thread (async)
- [ ] 14.2 Cache fingerprints in memory
- [ ] 14.3 Batch API calls when possible
- [ ] 14.4 Add progress indicator for analysis of 50+ keys
- [ ] 14.5 Optimize fingerprint computation (cache ssh-keygen results)

## 15. Error Handling

- [ ] 15.1 Handle network errors during import
- [ ] 15.2 Handle file permission errors (can't write to ~/.ssh)
- [ ] 15.3 Handle corrupted key files (invalid format)
- [ ] 15.4 Handle private key not found (warn user)
- [ ] 15.5 Handle API errors during sync

## 16. Testing

- [ ] 16.1 Test sync analysis with matching keys (synced state)
- [ ] 16.2 Test sync analysis with local-only keys
- [ ] 16.3 Test sync analysis with cloud-only keys
- [ ] 16.4 Test conflict detection (same name, different fingerprint)
- [ ] 16.5 Test import with private key present
- [ ] 16.6 Test import without private key (warning shown)
- [ ] 16.7 Test import filename conflict (rename prompt)
- [ ] 16.8 Test "Keep Local" conflict resolution
- [ ] 16.9 Test "Keep Cloud" conflict resolution (backup created)
- [ ] 16.10 Test "Keep Both" conflict resolution (renamed import)
- [ ] 16.11 Test Sync All with mixed states
- [ ] 16.12 Test sync exclusion (ignored keys not synced)
- [ ] 16.13 Test sync history tracking
- [ ] 16.14 Test automatic sync detection on refresh
- [ ] 16.15 Test performance with 50+ keys

## 17. Documentation

- [ ] 17.1 Update README with two-way sync features
- [ ] 17.2 Document sync status badges meaning
- [ ] 17.3 Document conflict resolution options
- [ ] 17.4 Add user guide: "Synchronizing Keys Between Local and Cloud"
- [ ] 17.5 Explain private key requirement for import
- [ ] 17.6 Document sync preferences and exclusions

## 18. Internationalization

- [ ] 18.1 Mark all sync UI strings with _()
- [ ] 18.2 Add i18n for "Import", "Synced", "Conflict", "Keep Local", "Keep Cloud", "Keep Both"
- [ ] 18.3 Update po/POTFILES

## 19. Final Review

- [ ] 19.1 Verify no data loss in any conflict resolution
- [ ] 19.2 Verify backups created for all destructive operations
- [ ] 19.3 Test sync with all 6 providers (GitHub, GitLab, Bitbucket, AWS, Azure, GCP)
- [ ] 19.4 Verify performance (analysis completes within 1 second for 50 keys)
- [ ] 19.5 Run production build
- [ ] 19.6 Update OpenSpec tasks.md to mark all items complete
