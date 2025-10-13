# Known Hosts Management Proposal

## Why

Currently, KeyMaker lacks functionality to manage the `~/.ssh/known_hosts` file, which stores fingerprints of SSH servers users have connected to. Users must manually edit this file to remove stale/invalid entries, handle key conflicts, or verify host key fingerprints. This creates security risks (accepting unverified keys) and usability issues (connection failures due to outdated entries).

Adding known hosts management will improve security by helping users verify host keys against trusted sources and prevent man-in-the-middle attacks. It will also enhance usability by providing a graphical interface to manage known hosts entries.

## What Changes

- **NEW** Known Hosts Management backend (`KnownHostsManager.vala`) - Parser and manager for `~/.ssh/known_hosts` file
- **NEW** Known Hosts Page (`KnownHostsPage.vala`) - UI page for viewing and managing known hosts
- **NEW** Host Key Verification Dialog (`HostKeyVerificationDialog.vala`) - Dialog for verifying host key fingerprints
- View all known hosts with their fingerprints and key types
- Remove individual or stale/invalid known host entries
- Handle host key conflicts gracefully with clear warnings
- Verify host key fingerprints against trusted sources
- Import/export known hosts files
- Merge duplicate entries for the same host

## Impact

- **Affected specs:** New capability `known-hosts-management`
- **Affected code:**
  - New backend: `src/backend/KnownHostsManager.vala`
  - New UI page: `src/ui/pages/KnownHostsPage.vala`
  - New dialog: `src/ui/dialogs/HostKeyVerificationDialog.vala`
  - Main window navigation: `src/ui/MainWindow.vala` (add new page)
  - Build system: `meson.build` files (add new source files)
- **Dependencies:** None - uses existing Vala/GLib facilities
- **User impact:** Positive - new security and management features with no breaking changes
