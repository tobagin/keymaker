# Add Two-Way Sync (Phase 8)

## Why

Currently, KeyMaker supports one-way deployment (local → cloud). Users may have keys on cloud platforms that don't exist locally, or keys that were deleted locally but still exist in the cloud. This proposal adds two-way sync capabilities:
- **Import cloud keys** to local `~/.ssh/`
- **Detect conflicts** (same fingerprint, different location)
- **Sync status tracking** (local-only, cloud-only, synced, conflict)

This is an **advanced feature** that transforms KeyMaker from a deployment tool to a full synchronization manager.

## What Changes

- Add "Import from Cloud" button to deploy keys from cloud to local
- Add sync status indicators in UI (badges: "Local only", "Cloud only", "Synced", "Conflict")
- Implement key comparison logic (fingerprint matching)
- Add conflict resolution dialog
- Add sync history tracking (last synced timestamp)
- Add automatic sync detection on cloud key list refresh
- Add "Sync All" operation (reconcile local and cloud keys)

**Dependencies**: Requires Phase 1 (GitHub) minimum; benefits from Phases 2-6 (more providers)

## Impact

- **Affected specs**: Modifies `cloud-provider-integration` capability (major feature addition)
- **Affected code**:
  - `src/backend/cloud/SyncManager.vala` - New sync orchestration logic
  - `src/backend/cloud/KeyComparator.vala` - Fingerprint matching and conflict detection
  - `src/backend/cloud/*Provider.vala` - Add import_key() method to all providers
- `src/ui/pages/CloudProvidersPage.vala` - Sync status UI
  - `src/ui/dialogs/ConflictResolutionDialog.vala` - Conflict handling
  - `src/ui/dialogs/ImportKeyDialog.vala` - Import from cloud
  - GSettings - Sync preferences and history
- **Breaking changes**: None (purely additive)
- **Complexity**: High - requires careful UX design for conflict resolution

## Breaking Changes

None. Two-way sync is opt-in.

## Sequencing

**MUST complete Phase 1 (GitHub) before starting Phase 8.**
Phase 7 (multi-account) is recommended but not required.

## Complexity Warning

This is a **complex feature** requiring:
- Fingerprint-based key matching
- Conflict detection and resolution UI
- Safe import (don't overwrite local keys)
- Sync state management

Estimated effort: 2-3 weeks.

## Security Considerations

**Critical**: Importing keys from cloud means downloading **public keys only** (not private keys). Private keys never leave the local machine. The "import" operation:
1. Downloads public key from cloud
2. Checks if corresponding private key exists locally
3. If private key missing, shows warning: "Cannot import: Private key not found locally"
4. If private key exists, creates hard link or copies public key to `~/.ssh/`
