# Key Maker – Codex Refactor & Improvement Plan

This plan proposes targeted refactors, modularization, and quality improvements for the Key Maker codebase (Vala + GTK4/Libadwaita). It focuses on: correctness, UX responsiveness, maintainability, testability, and long‑term architectural stability.

Scope balances surgical changes in critical paths with a roadmap for larger structural work. Each area includes goals, suggested changes, risks, and acceptance criteria.

---

## 1) High‑Priority Fixes (Stability & UX)

1.1 Prevent UI stalls from synchronous work
- Problem: Sync filesystem and subprocess calls on the UI thread (e.g., key scanning and `ssh-keygen` invocations) can block the interface.
- Actions:
  - Replace `Window.load_keys_simple()` scanning path with `KeyScanner.scan_ssh_directory_with_cancellable()` and call it from an idle/async context with a `Cancellable`.
  - Ensure all `ssh-keygen`/`ssh-add` subprocess calls that can take >100ms are executed in async variants or via a shared async runner with timeouts.
- Acceptance:
  - Refreshing keys never blocks UI for >50ms.
  - Cancelling a scan stops work within 250ms.

1.2 QR restore robustness (Emergency Vault)
- Problem: Logs show restore failures due to unexpected paths or missing parent dirs when restoring from QR backups.
- Actions:
  - Enforce path‑safe filenames (no separators or illegal chars) and length limits when generating destination names; treat base name as a literal filename portion, never a path.
  - Before copying, ensure the destination parent exists (and permissions are set) even if base name sanitization succeeds.
  - Centralize “write SSH key to ~/.ssh with correct perms” in a single helper used by all restore flows (QR, archive, time‑locked).
- Acceptance:
  - Restores succeed with arbitrary comments/display names that previously produced nested paths.
  - Unit test simulating display names with separators passes.

1.3 Single source of truth for SSH directory and permissions
- Problem: Repeated literals `0x180` (0600) and `0x1C0` (0700) and SSH dir path assembly scattered across files.
- Actions:
  - Introduce `KeyMaker.Filesystem` utility with: `ssh_dir()`, `ensure_ssh_dir()`, `chmod_private()`, `chmod_public()`, and constants for perms.
- Acceptance:
  - No hardcoded permission hex/octal constants outside the utility.
  - All code writing keys calls `ensure_ssh_dir()` first.

---

## 2) Consolidation Into Single Sources of Truth

2.1 Key scanning & metadata extraction
- Problem: Window implements its own file iteration and metadata; there is also `KeyScanner` that does the same (sync/async).
- Actions:
  - Remove the bespoke scanning in `Window` and adopt `KeyScanner` exclusively.
  - Ensure `KeyScanner` provides all fields the UI needs (fingerprint, type, bit size, comment, timestamps) in one pass.
- Acceptance:
  - Only `KeyScanner` performs directory scanning or key metadata extraction.

2.2 Subprocess execution helpers
- Problem: Repeated boilerplate for `SubprocessLauncher`, `spawnv`, read stdout/stderr, parse results, handle timeouts.
- Actions:
  - Add `KeyMaker.Command` (utility) exposing `run(argv, timeout?)`, `run_capture(argv, timeout?)`, and helpers for `read_line(s)` with standardized error mapping.
  - Update `ssh-operations`, `ssh-agent`, `connection-diagnostics`, `emergency-vault` (QR decode via zbar) to use it.
- Acceptance:
  - No direct `SubprocessLauncher` usage outside the command utility.
  - All subprocess errors map to `KeyMakerError.SUBPROCESS_FAILED` with consistent messaging.

2.3 SSH key metadata parsing
- Problem: Fingerprint/type/bit‑size parsing logic repeated across sync/async functions.
- Actions:
  - Consolidate parsing into `SSHOperations.Metadata` (internal module) with a single parser used by both sync/async variants.
  - Consider caching results per file mtime to avoid repeated `ssh-keygen -lf` calls during a single refresh.
- Acceptance:
  - One parser codepath for type/fingerprint/bitsize. Easy to unit test.

2.4 Settings schema and keys
- Problem: Multiple modules hand‑roll `Settings` instantiation; tunneling uses a separate schema ID not declared.
- Actions:
  - Centralize access through `KeyMaker.Settings` wrapper returning app settings (`Config.APP_ID`) and namespaced keys; add a dedicated (declared) schema for tunneling if needed or store under existing schema keys with a prefix (e.g., `tunneling/*`).
- Acceptance:
  - No raw construction of `Settings` with undeclared schema IDs.
  - All code receives settings via one helper/factory.

---

## 3) Large‑File Decomposition (Maintainability)

3.1 Split `src/backend/emergency-vault.vala` (~mega‑file)
- Goals: separate concerns (metadata, archive, QR, Shamir, time‑lock, I/O) and isolate risky code.
- Proposed structure (`src/backend/vault/`):
  - `vault-core.vala`: EmergencyVault facade, public API, orchestrates flows.
  - `backup-entry.vala`: `BackupEntry` (data class) + helpers.
  - `qr-backup.vala`: encode/decode + zbar wrapper + multi‑QR combiner.
  - `archive-backup.vala`: plaintext/encrypted archive pack/unpack.
  - `shamir-backup.vala`: share generation/validation.
  - `time-locked-backup.vala`: unlock checks + wrapper.
  - `vault-metadata-store.vala`: persistence to `backups.json` (and future migration to GSettings or keyfile).
  - `vault-io.vala`: shared I/O for writing keys, sanitizing filenames, setting permissions.
- Risks: moving types requires updating imports and templates; keep namespaces consistent.
- Acceptance:
  - Emergency vault logic fits into focused files (<400 LOC each), with clean interfaces.

3.2 Split `src/backend/ssh-operations.vala`
- Goals: separate generation, metadata parsing, and destructive ops.
- Suggested split:
  - `ssh-operations/generation.vala`
  - `ssh-operations/metadata.vala`
  - `ssh-operations/mutate.vala` (delete, chmod, passphrase change if added)
- Acceptance: Each file <350 LOC; shared subprocess helper used.

3.3 Split `src/backend/key-rotation.vala`
- Goals: Strategy pattern per stage; easier testing of stages.
- Suggested split:
  - `rotation/plan.vala` (data types)
  - `rotation/runner.vala` (execute stages)
  - `rotation/deploy.vala` (ssh-copy-id and verify)
  - `rotation/rollback.vala`
- Acceptance: Stage functions are ≤150 LOC and unit testable.

3.4 Tunneling under namespace + split
- Problem: `ssh-tunneling.vala` defines top‑level enums/classes and does a lot.
- Actions:
  - Move into `namespace KeyMaker` and split into `tunneling/configuration.vala`, `tunneling/active-tunnel.vala`, `tunneling/manager.vala`.
  - Add settings persistence with a declared GSettings schema or reuse app schema keys.
- Acceptance: Separate modules; manager is ≤250 LOC.

---

## 4) API/Platform Modernization & Deprecation Pass

- GTK/Libadwaita:
  - Already using `Adw.AboutDialog` and `Adw.MessageDialog`. Continue migrating any remaining `Gtk.MessageDialog` usages (none found) to Adw where applicable.
  - Validate `activate_default()`/focus hacks in `Application.show_about_with_release_notes()`; prefer explicit tab navigation or signal when the widget is valid to trigger.

- Collections:
  - Code mixes `GenericArray<T>` while linking `gee-0.8`. Consider standardizing on `Gee.ArrayList<T>` for clarity and safer iteration (unless `GenericArray` is intentionally chosen for C interop/perf). If switching, do it gradually per module.

- Blueprint compilation:
  - `data/ui/meson.build` uses a hardcoded `--typelib-path`. Make it optional/portable or derive it from `girepository` dependency to avoid host‑specific assumptions.

- i18n domain consistency:
  - `data/io.github.tobagin.keysmith.gschema.xml.in` declares `gettext-domain="keymaker"` while Meson sets `GETTEXT_PACKAGE` to project name `keysmith`. Align domain to `Config.GETTEXT_PACKAGE` to avoid mismatches.

Acceptance:
  - No deprecation warnings at build; i18n domain is consistent across schema, code and Meson summary.

---

## 5) Error Handling & Logging

- Introduce `KeyMaker.Log` utility with helpers: `debug(fmt, ...)`, `info`, `warn`, `error`, optionally forward to GLib structured logging with categories (`KEYMAKER_*`).
- Replace `print()`/`warning()` scatter with unified logging; include operation IDs (e.g., restore run id) for vault flows.
- Normalize `KeyMakerError` mapping per subsystem (Operations, Vault, Agent, Config, Rotation, Tunneling, Diagnostics) to improve UX messages.

Acceptance: One logging import; consistent error text for common failure modes.

---

## 6) Testing Strategy (Incremental)

- Add Meson test targets targeting logic (no GUI):
  - `KeyScanner` against a temp dir with synthetic keys (fixture). Avoid `~/.ssh` in tests.
  - `SSHOperations.Metadata` parser with canned `ssh-keygen -lf` outputs (inject via seam; or small wrapper to inject stdout).
  - Vault filename sanitization and “write to ~/.ssh” helper using a temporary fake SSH dir.
  - QR data split/merge logic (pure functions) without invoking zbar.

- Later stages:
  - Diagnostics parsing (stderr → reason) from sample logs.
  - Rotation: dry‑run mode test verifying command composition.

Acceptance: CI runs unit tests headless; no touching real user state.

---

## 7) Performance Opportunities

- Cache metadata per file mtime during a refresh to avoid 3 separate `ssh-keygen -lf` calls per key (type + fingerprint + bits). Parse once → store tuple.
- Batch UI updates: collect models then update the list in one pass to reduce churn with `Gtk.ListBox`.
- Prefer async reading for large files; limit public key read to first line.

Acceptance: Refresh time reduced proportionally to number of keys; no visible UI jank.

---

## 8) Security & Privacy

- Minimize exposure of private key bytes in memory (Vault code):
  - When possible, stream copy instead of loading entire file content; zero sensitive buffers after use.
  - Document that vault QR backups store base64 private key data unencrypted; add explicit UI warnings and encourage encrypted archive when possible.

- Shell safety:
  - Continue using `spawnv/newv` over shell strings; where string building is used (tunnel command), keep `Shell.parse_argv()` and sanitize inputs.

Acceptance: Reviewed codepaths handling private keys; explicit warnings present for QR backups.

---

## 9) Documentation & Developer Experience

- README
  - Ensure build instructions match repository (the referenced `./scripts/build.sh` should exist or update docs to Meson/Flatpak steps present).
  - Add quick dev run via Meson (non‑Flatpak) if supported.

- Internal docs
  - Add `docs/architecture.md` summarizing modules and data flow.
  - Add `CONTRIBUTING.md` conventions (coding style, async, logging, tests).

Acceptance: Onboarding a new contributor requires ≤30 minutes to build and find key modules.

---

## 10) Proposed Module Map (After Refactor)

```
src/
  application.vala
  main.vala
  config.vala (generated)
  utils/
    filesystem.vala
    command.vala
    log.vala
  backend/
    ssh-operations/
      generation.vala
      metadata.vala
      mutate.vala
    key-scanner.vala
    ssh-agent.vala
    ssh-config/
      parser.vala
      writer.vala
    rotation/
      plan.vala
      runner.vala
      deploy.vala
      rollback.vala
    diagnostics/
      runner.vala
      parser.vala
    tunneling/
      configuration.vala
      active-tunnel.vala
      manager.vala
    vault/
      vault-core.vala
      backup-entry.vala
      qr-backup.vala
      archive-backup.vala
      shamir-backup.vala
      time-locked-backup.vala
      vault-io.vala
      vault-metadata-store.vala
  ui/
    window.vala (uses KeyScanner async)
    key-list.vala
    key-row.vala
    dialogs/* (unchanged API; internals trimmed)
```

---

## 11) Roadmap (Phased)

Phase 0 – Safety & UX quick wins (1–2 days)
- Replace `Window.load_keys_simple()` with `KeyScanner.scan_ssh_directory_with_cancellable()`.
- Add `utils/filesystem.vala` and replace scattered chmod/paths.
- Add `utils/command.vala` and migrate one hotspot (fingerprint/type) to prove pattern.
- Harden vault restore path naming + ensure parent dirs; add targeted tests.

Phase 1 – Vault & Operations decomposition (1–2 weeks)
- Split `emergency-vault.vala` into vault/* files; introduce `vault-io` and metadata store.
- Split `ssh-operations.vala` into generation/metadata/mutate.
- Normalize logging and error messages; introduce `utils/log.vala`.

Phase 2 – Settings & Tunneling (3–5 days)
- Create settings wrapper; align schema IDs; add tunneling storage.
- Port tunneling into namespace + split into configuration/active/manager.

Phase 3 – Tests & Performance (ongoing)
- Add Meson tests for scanner, metadata parsing, vault IO, QR combiner.
- Introduce metadata caching and batched UI updates.

---

## 12) Acceptance Criteria Checklist

- [ ] Key list refresh is cancelable and non‑blocking.
- [ ] One codepath for key scanning/metadata; Window uses it.
- [ ] No hardcoded chmod constants scattered; central utility in place.
- [ ] Vault restore does not create nested/invalid paths; tests cover sanitization.
- [ ] `ssh-operations` and `emergency-vault` split into focused files.
- [ ] Subprocess runs use a single helper; consistent error mapping.
- [ ] i18n domain consistent (`GETTEXT_PACKAGE`).
- [ ] At least 4 headless tests in CI for core logic.

---

## 13) Risks & Mitigations

- Refactor churn can introduce regressions → incremental merges with tests; maintain API surfaces for UI.
- Platform nuances for blueprint compiler `--typelib-path` → gate with detection and fallbacks.
- Changing settings schema requires migration → keep keys under existing schema unless unavoidable; add migration step if new schema is introduced.

---

## 14) File/Code Pointers (for first passes)

- Replace scanning in: `src/ui/window.vala`
- Use scanner only: `src/backend/key-scanner.vala`
- Consolidate subprocess patterns across:
  - `src/backend/ssh-operations.vala`
  - `src/backend/ssh-agent.vala`
  - `src/backend/connection-diagnostics.vala`
  - `src/backend/emergency-vault.vala` (QR decode via zbar)
- Large file split target:
  - `src/backend/emergency-vault.vala`
  - `src/backend/ssh-operations.vala`
  - `src/backend/key-rotation.vala`
- Settings/schema:
  - `data/io.github.tobagin.keysmith.gschema.xml.in`
  - Usages: `src/ui/*`, `src/backend/*`
- Blueprint build portability:
  - `data/ui/meson.build`

---

If you want, I can start with Phase 0 now (Window → KeyScanner, utilities for filesystem/command, and vault restore hardening), and send a focused PR for review.

