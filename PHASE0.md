# Phase 0 Progress Summary

This document maps actual code changes against the items in CODEX-PLAN.md and marks what’s completed, partially done, or pending. File references point to concrete evidence in the repo.

**Legend**
- Completed: implemented and in use
- Partial: implemented in places, needs further adoption or cleanup
- Pending: not started or no evidence

## High‑Priority Fixes

- Completed: Async key scanning on UI thread is non‑blocking
  - Initial scan scheduled off the activation path: `src/application.vala:113`
  - Window refresh uses async + `Cancellable`: `src/ui/window.vala:156`, `src/ui/window.vala:169`
  - Async scanner implementation in one place: `src/backend/key-scanner.vala:108`

- Completed: QR restore robustness (path safety + parent dir + perms)
  - Central helpers for SSH dir and perms: `src/utils/filesystem.vala:9`, `src/utils/filesystem.vala:17`, `src/utils/filesystem.vala:26`, `src/utils/filesystem.vala:30`
  - Safe filename sanitization: `src/utils/filesystem.vala:35`
  - Restore flow uses helpers and sanitization, avoids path traversal, enforces perms: `src/backend/emergency-vault.vala:619`, `src/backend/emergency-vault.vala:620`, `src/backend/emergency-vault.vala:623`, `src/backend/emergency-vault.vala:648`

- Partial: Single source of truth for SSH directory and permissions
  - Utility exists and is used in several places: `src/backend/ssh-operations.vala:30`, `src/backend/ssh-operations.vala:108`, `src/backend/emergency-vault.vala:619`
  - Still uses hardcoded octal/hex perms in some modules (needs cleanup): `src/backend/ssh-config.vala:121`, `src/backend/ssh-config.vala:135`, `src/application.vala:400`

## Consolidation Into Single Sources of Truth

- Partial: Key scanning consolidation
  - Main UI path uses `KeyScanner.scan_ssh_directory_with_cancellable`: `src/ui/window.vala:169`
  - Legacy synchronous fallback still present and can be removed: `src/ui/window.vala:229`

- Partial: Subprocess execution helpers
  - `KeyMaker.Command` exists: `src/utils/command.vala:1`
  - Adopted in async fingerprint path only (more modules still call `SubprocessLauncher` directly): `src/backend/ssh-operations.vala:220`

- Pending: SSH key metadata parsing unified module
  - No `SSHOperations.Metadata` consolidation yet; parsing logic still repeated across sync/async functions in `src/backend/ssh-operations.vala`

- Partial: Settings schema and keys centralization
  - Separate tunneling schema is declared: `data/io.github.tobagin.keysmith.gschema.xml.in:53`
  - No `KeyMaker.Settings` wrapper; multiple direct `new Settings(...)` usages remain: `src/application.vala:63`, `src/ui/window.vala:45`, `src/ui/key-row.vala:57`, etc.

## Large‑File Decomposition

- Pending: Split Emergency Vault mega‑file
  - Monolithic file still present: `src/backend/emergency-vault.vala:1`

## Build & Packaging Hygiene

- Pending: Blueprint compiler portability
  - Hardcoded `--typelib-path` remains: `data/ui/meson.build:14`, `data/ui/meson.build:42`

- Pending: i18n domain consistency
  - Project sets `GETTEXT_PACKAGE` from project name: `meson.build:43`, `src/config.vala.in:19`
  - Schema declares `gettext-domain="keymaker"` (mismatch): `data/io.github.tobagin.keysmith.gschema.xml.in:1`

## Error Handling & Logging

- Pending: Central logging utility and normalized error mapping
  - No `KeyMaker.Log` utility yet; mixed `debug()/warning()/print()` usage across codebase

## Testing Strategy

- Pending: Unit tests for logic (KeyScanner, metadata parsing, vault helpers)
  - Only metadata validation tests (desktop/metainfo lint) are wired: `data/meson.build:21`, `data/meson.build:54`

## Performance Opportunities

- Pending: Metadata caching and batched UI updates beyond current async pass

## Security & Privacy

- Partial: Safer file permission handling
  - Helpers added and used in key write/restore paths: `src/utils/filesystem.vala:26`, `src/utils/filesystem.vala:30`, `src/backend/emergency-vault.vala:705`
  - Additional streaming/zeroing and warnings for QR backups not yet implemented (per plan)

## Documentation & Developer Experience

- Completed: README build steps align with repo
  - `scripts/build.sh` exists and matches README instructions: `scripts/build.sh:1`, `README.md:265`

- Pending: Architecture and contributing docs
  - No `docs/architecture.md` or `CONTRIBUTING.md` found

---

Notes and suggested next quick wins
- Remove `Window.load_keys_simple()` and references to fully complete scanning consolidation.
- Replace remaining raw `Posix.chmod(0x180/0x1C0)` and direct `~/.ssh` path assembly with `KeyMaker.Filesystem` calls.
- Expand `KeyMaker.Command` usage to all subprocess sites (`ssh-operations`, vault QR decode, diagnostics, tunneling).
- Fix i18n domain mismatch in the schema to match `Config.GETTEXT_PACKAGE`.
- Make `data/ui/meson.build`’s typelib path configurable/detected instead of hardcoded.
