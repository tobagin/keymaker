# Design: Two-Way Sync

## Context

Phases 1-7 support deploying local keys to cloud. Phase 8 adds the reverse: detecting and optionally importing cloud keys to local system.

**Key Insight**: SSH keys are asymmetric. We can download **public keys** from cloud, but **private keys** must remain local. "Import" means:
- Download public key from cloud
- Save to `~/.ssh/<keyname>.pub` if private key exists
- If private key missing, warn user (can't use cloud key without private key)

## Goals / Non-Goals

### Goals
- Import cloud public keys to local `~/.ssh/`
- Detect sync status (local-only, cloud-only, synced)
- Handle conflicts (same fingerprint, different filename)
- Provide clear sync status UI
- Support manual and automatic sync

### Non-Goals
- Generate private keys from cloud public keys (impossible)
- Automatic sync without user approval (security risk)
- Cross-device sync (Phase 8 is local ↔ cloud, not device ↔ device)
- Sync to multiple clouds simultaneously (one cloud at a time)

## Decisions

### 1. Key Matching: Fingerprint Comparison

**Decision**: Match local and cloud keys by SSH fingerprint (SHA256).

**Rationale**:
- Fingerprint is cryptographically unique
- Filenames can differ (id_rsa.pub vs work_key.pub)
- Comments can differ (both are same key)

**Algorithm**:
```
1. Compute fingerprint of local key: ssh-keygen -l -f ~/.ssh/id_rsa.pub
2. Compare with cloud key fingerprint from API
3. If match: Keys are same (synced)
4. If no match: Keys are different (local-only or cloud-only)
```

### 2. Sync States

**Decision**: Define 4 sync states for each key.

**States**:
1. **Synced**: Key exists locally and in cloud with matching fingerprint
2. **Local-only**: Key exists locally but not in cloud
3. **Cloud-only**: Key exists in cloud but not locally
4. **Conflict**: Same filename but different fingerprints

**UI Indicators**:
- Synced: ✓ Green badge
- Local-only: ↑ Blue badge "Upload"
- Cloud-only: ↓ Orange badge "Import"
- Conflict: ⚠ Red badge "Conflict"

### 3. Import Operation

**Decision**: "Import" downloads public key and checks for corresponding private key.

**Import Flow**:
1. User clicks "Import" on cloud-only key
2. KeyMaker downloads public key from cloud
3. KeyMaker searches for private key with matching fingerprint in `~/.ssh/`
4. If found: Copy/link public key to `~/.ssh/<cloudkeyname>.pub`
5. If not found: Show warning "Private key not found. Cannot use this key for authentication."

**Why check for private key?**: Importing public key without private key is useless (can't authenticate). Better to warn user upfront.

### 4. Conflict Resolution

**Decision**: Prompt user with 3 options.

**Conflict Scenario**: Local `~/.ssh/work_key.pub` and cloud "work_key" have different fingerprints.

**Resolution Options**:
1. **Keep Local**: Overwrite cloud key with local key
2. **Keep Cloud**: Download cloud key, rename local key to `work_key.old.pub`
3. **Keep Both**: Rename cloud key on import (e.g., `work_key_github.pub`)

**UI**: Show side-by-side comparison:
```
┌─────────────────────────────────────┐
│ Conflict Detected: work_key         │
├─────────────────────────────────────┤
│ Local Key:                          │
│ Fingerprint: SHA256:abc123...       │
│ Created: 2025-09-01                 │
│                                     │
│ Cloud Key (GitHub):                 │
│ Fingerprint: SHA256:def456...       │
│ Uploaded: 2025-10-01                │
│                                     │
│ [Keep Local] [Keep Cloud] [Keep Both]│
└─────────────────────────────────────┘
```

### 5. Sync Manager Architecture

**Decision**: Create `SyncManager` orchestrator class.

**Responsibilities**:
- Compare local and cloud key lists
- Determine sync state for each key
- Execute sync operations (upload, import, conflict resolution)
- Track sync history

**API**:
```vala
public class SyncManager : Object {
    public async SyncStatus analyze(string provider_name, string account_id);
    public async void import_key(string provider_name, string cloud_key_id);
    public async void upload_key(string provider_name, string local_key_path);
    public async void sync_all(string provider_name);  // Reconcile everything
}

public class SyncStatus {
    public Gee.List<KeySyncState> synced;
    public Gee.List<KeySyncState> local_only;
    public Gee.List<KeySyncState> cloud_only;
    public Gee.List<KeySyncState> conflicts;
}
```

### 6. Sync All Operation

**Decision**: Provide "Sync All" button that reconciles all keys.

**Behavior**:
1. Analyze all keys (local and cloud)
2. Show summary: "5 synced, 2 local-only, 1 cloud-only, 1 conflict"
3. User clicks "Sync All"
4. Upload all local-only keys
5. Prompt for each cloud-only key: "Import this key?"
6. Prompt for each conflict: "Resolve conflict"
7. Show completion: "Sync complete: 8/9 keys synced, 1 conflict needs manual resolution"

**Manual Mode**: Allow users to selectively sync (click badges individually).

### 7. Automatic Sync Detection

**Decision**: Detect sync status automatically when refreshing key list.

**Behavior**:
- When user clicks "Refresh" on cloud provider
- SyncManager analyzes local and cloud keys
- UI updates badges (synced, local-only, cloud-only, conflict)
- No automatic actions (user must click badges to sync)

**Performance**: Fingerprint comparison is fast (~1ms per key). Analyzing 50 keys takes <50ms.

### 8. Sync History Tracking

**Decision**: Store last sync timestamp per key in GSettings.

**GSettings Schema**:
```json
{
  "cloud-sync-history": {
    "github-{account-id}": {
      "id_rsa": {
        "last_synced": "2025-10-13T14:30:00Z",
        "sync_direction": "upload"
      },
      "work_key": {
        "last_synced": "2025-10-12T09:15:00Z",
        "sync_direction": "import"
      }
    }
  }
}
```

**UI**: Show "Last synced: 2 hours ago" tooltip on synced badge.

## Risks / Trade-offs

### Risk 1: User Confusion About Private Keys
**Risk**: Users might think "import" downloads private keys (security misunderstanding).

**Mitigation**:
- Clear messaging: "Importing public key only. Private key remains on your device."
- Show warning if private key not found: "Cannot import: Private key missing locally."
- Documentation: Explain SSH key asymmetry

### Risk 2: Filename Conflicts
**Risk**: Cloud key named "work_key" but local file `work_key.pub` already exists with different fingerprint.

**Mitigation**:
- Detect conflict before import
- Offer renaming options (work_key_github.pub, work_key.old.pub)
- Never overwrite local files without confirmation

### Risk 3: Performance with Many Keys
**Risk**: Analyzing 100+ keys (local + cloud) might be slow.

**Mitigation**:
- Cache fingerprints in memory
- Perform analysis in background thread (async)
- Show progress indicator: "Analyzing keys... (50/100)"

### Risk 4: Sync State Staleness
**Risk**: User manually edits `~/.ssh/` files outside KeyMaker, sync state becomes stale.

**Mitigation**:
- Re-analyze on every refresh (don't cache sync state)
- Add manual "Refresh Sync Status" button
- Show last analysis timestamp: "Sync status as of 10 minutes ago"

## Migration Plan

N/A - Additive feature, no existing data.

## Open Questions

1. **Should we support automatic background sync?**
   - Decision: No, Phase 8 is manual only. Auto-sync can be Phase 15 if requested (requires careful UX).

2. **Should we support excluding keys from sync?**
   - Decision: Yes, add "Ignore" option (right-click key → "Don't sync this key"). Store in GSettings.

3. **Should we support bulk operations (select multiple keys, sync all)?**
   - Decision: Yes, add checkbox selection mode. "Sync All" operates on all keys unless specific keys selected.

4. **Should we show diff for conflicts (line-by-line public key comparison)?**
   - Decision: No, fingerprint is sufficient. Line-by-line diff is too technical for most users.

5. **Should we support syncing across multiple cloud providers (GitHub + GitLab)?**
   - Decision: No, Phase 8 syncs one provider at a time. Cross-provider sync (deploy key to GitHub AND GitLab) can be Phase 16.
