# Known Hosts Management Design

## Context

The `~/.ssh/known_hosts` file is a critical security component in SSH that stores fingerprints of previously connected servers. When a user connects to an SSH server, the client verifies the server's host key against this file to prevent man-in-the-middle attacks. However, managing this file is currently a manual process requiring users to:

- Edit the file with a text editor to remove stale entries
- Manually verify fingerprints against trusted sources
- Handle key conflicts when servers change their keys (common during reinstalls)
- Deal with duplicate entries for the same host

This feature adds graphical management capabilities to KeyMaker, improving both security (easier verification) and usability (no manual file editing).

**Stakeholders:** End users managing SSH connections, system administrators

**Constraints:**
- Must preserve OpenSSH known_hosts format compatibility
- Cannot break existing SSH client behavior
- Must handle file permissions correctly (~/.ssh/known_hosts is user-specific)
- Should work with both hashed and plain hostname formats

## Goals / Non-Goals

**Goals:**
- Provide read/write access to known_hosts file with full format support
- Enable visual verification of host key fingerprints
- Simplify handling of key conflicts and stale entries
- Support import/export for backup and migration scenarios
- Maintain compatibility with OpenSSH known_hosts format

**Non-Goals:**
- Modifying SSH connection behavior (only managing known_hosts)
- Implementing custom host verification algorithms (use OpenSSH standards)
- Supporting non-standard known_hosts formats
- Real-time monitoring of known_hosts changes by other applications

## Decisions

### Decision 1: File Format Handling
**What:** Use line-by-line parsing with format detection per entry (plain vs hashed)

**Why:** The known_hosts file can contain mixed formats (some entries hashed, some plain). Line-by-line parsing is most compatible with OpenSSH behavior and allows preserving unknown formats.

**Alternatives considered:**
- Using libssh for parsing: Rejected due to additional dependency and potential format incompatibilities
- Regex-based parsing: Rejected due to complexity with edge cases and harder maintenance

**Implementation:**
```vala
// Parse each line independently
foreach (string line in lines) {
    if (line.has_prefix("|1|")) {
        // Hashed format: |1|salt|hash hostname
        parse_hashed_entry(line);
    } else if (line.has_prefix("#")) {
        // Comment line - preserve but skip
        continue;
    } else {
        // Plain format: hostname[,hostname,...] keytype key [comment]
        parse_plain_entry(line);
    }
}
```

### Decision 2: Fingerprint Verification Architecture
**What:** Maintain a local database of known good fingerprints for popular services + manual verification

**Why:** Users need quick verification for common services (GitHub, GitLab) but also ability to verify against any trusted source.

**Alternatives considered:**
- Online fingerprint API: Rejected due to privacy concerns and dependency on external service
- DNS-based verification (SSHFP records): Considered for future enhancement but not MVP

**Implementation:**
```vala
// Static database of trusted fingerprints
private static HashTable<string, string[]> TRUSTED_FINGERPRINTS = {
    "github.com": {
        "SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8",
        "SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s" // ECDSA
    },
    // ... more services
};
```

### Decision 3: Stale Entry Detection
**What:** Async connectivity testing with timeout, marked as "potentially stale" (not auto-removed)

**Why:** A host being unreachable doesn't always mean the entry is invalid (could be temporary network issue, firewall). Users should decide whether to remove.

**Alternatives considered:**
- Auto-removal after N days unreachable: Rejected as too aggressive
- No stale detection: Rejected as users requested this feature

**Implementation:**
- Background async check on page load
- 5-second timeout per host
- Visual indicator (⚠️ icon) for unreachable hosts
- Batch "Remove All Stale" action with confirmation

### Decision 4: Conflict Resolution UI
**What:** Modal dialog showing old and new fingerprints side-by-side with explicit user action required

**Why:** Host key changes are rare and often indicate a security issue. Users must be alerted and make an informed decision.

**Implementation:**
```
╔═══════════════════════════════════════╗
║   ⚠️ HOST KEY VERIFICATION FAILED     ║
║                                       ║
║  The host key for github.com has     ║
║  changed. This could indicate a       ║
║  man-in-the-middle attack!            ║
║                                       ║
║  Old fingerprint (stored):            ║
║  SHA256:nThbg6kXUpJWGl7E1IGO...       ║
║                                       ║
║  New fingerprint (presented):         ║
║  SHA256:xYz789AbCdEfGhIjKlMn...       ║
║                                       ║
║  [Update Key]  [Cancel Connection]    ║
╚═══════════════════════════════════════╝
```

### Decision 5: Import/Export Behavior
**What:** Import merges entries (no duplicates), export creates complete copy

**Why:** Users may want to consolidate known_hosts from multiple machines or backup before changes.

**Merge logic:**
- If hostname + key type match: keep existing (already verified)
- If hostname matches but key differs: import as separate entry (user can review)
- Track import source in memory for session (for undo)

## Risks / Trade-offs

### Risk: File Corruption
- **Risk:** Parsing/writing bugs could corrupt known_hosts file
- **Mitigation:**
  - Create automatic backup before any write operation (`.known_hosts.backup`)
  - Validate entire file after write
  - Provide emergency restore function

### Risk: Race Conditions
- **Risk:** OpenSSH or other tools modifying known_hosts while we're reading/writing
- **Mitigation:**
  - Use file locking (flock) during write operations
  - Reload before any write to catch external changes
  - Warn user if file was modified externally

### Risk: Performance with Large Files
- **Risk:** Parsing/display could be slow with 1000+ entries
- **Mitigation:**
  - Async loading with progress indicator
  - Lazy rendering in UI (virtual list if needed)
  - Background stale detection (don't block UI)

### Trade-off: Hashed Hostname Display
- **Trade-off:** Hashed hostnames can't be shown in plain text (security feature)
- **Decision:** Display as "hashed:abc..." with tooltip explaining why
- **Impact:** Users can't search hashed entries by hostname, must use fingerprint

## Migration Plan

**Not applicable** - This is a new feature with no existing data migration needed.

**Compatibility:**
- Feature is additive, no breaking changes
- Existing known_hosts files work unchanged
- Can be disabled/ignored if users prefer manual management

**Rollout:**
1. Ship feature in beta release for testing
2. Gather user feedback on stale detection accuracy
3. Expand trusted fingerprints database based on usage
4. Consider adding to setup wizard in future release

## Open Questions

1. **Should we support known_hosts.d directory format?**
   - Some systems use `~/.ssh/known_hosts.d/` for modular configs
   - Decision: Track for future enhancement, focus on single file for MVP

2. **Integration with SSH connection flow?**
   - Should KeyMaker auto-verify keys when making connections through the app?
   - Decision: Yes, but as separate enhancement after MVP (see connection dialog integration)

3. **Backup retention policy?**
   - How many automatic backups to keep?
   - Decision: Keep last 5 backups with timestamps, auto-cleanup older

4. **Certificate-based host keys (ssh-*-cert-v01)?**
   - Should we support certificate validation?
   - Decision: Display cert info if present, but no validation in MVP (future enhancement)
