# GNOME HIG UI Audit

This document summarizes findings from a review of the Blueprint UI files against the GNOME Human Interface Guidelines (HIG). It highlights strengths, deviations, and actionable fixes with precise file references.

## Overview

- Scope: All files under `data/ui/*.blp` and relevant action accelerators in `src/application.vala`.
- Goal: Improve consistency, clarity, accessibility, and adherence to GNOME HIG patterns.

## Strengths

- Adwaita components used correctly (`Adw.HeaderBar`, `Adw.StatusPage`, `Adw.Preferences*`, `Adw.NavigationView`, `Adw.Clamp`).
- Dialogs follow primary-right/secondary-left action placement; destructive actions styled.
- Clear empty/progress states and logical preferences grouping.

## Key Findings & Recommendations

- Language and capitalization
  - Prefer sentence case for titles, labels, and button text.
  - Avoid parenthetical guidance in option labels; move guidance to subtitles/descriptions.

- Ellipses usage
  - Use a single ellipsis character (… U+2026) for actions that open another dialog or require further input.
  - Do not add ellipsis for actions that execute immediately.

- Controls density (row actions)
  - Reduce the number of icon-only buttons in list rows; keep the most common two and move others into an overflow menu (popover) per HIG minimalism guidance.

- Password inputs
  - Use `Adw.PasswordEntryRow` for secrets instead of `Adw.EntryRow` with `input-purpose`.

- Spacing grid
  - Stick to 12/24 px spacings; avoid 18 px margins to align with Adwaita metrics.

- Accessibility
  - Provide accessible names for icon-only buttons (programmatically if Blueprint lacks properties).
  - Ensure tooltips are present (they are) but do not rely on tooltips alone for a11y.

- Shortcuts window & accelerators
  - Prefer `Gtk.ShortcutsWindow` instead of a custom shortcuts dialog.
  - F1 is typically reserved for Help; avoid mapping F1 to About.

- Icons
  - Use appropriate symbolic icons (e.g., `key-symbolic` for keys). 32 px list row icons are visually heavy; 24 px works better in dense lists.

- Internationalization
  - Ensure user-facing strings are translatable; some strings in the shortcuts dialog are not wrapped in `_()`.

## Quick Fix Checklist (with file references)

- Sentence case and clearer phrasing
  - `data/ui/window.blp:17` — Header subtitle: replace “GUI for SSH key management tasks” with a concise sentence or remove subtitle.
  - `data/ui/key_list.blp:10` — “No SSH Keys Found” → “No SSH keys found”.
  - `data/ui/ssh_tunneling_dialog.blp:41` — “Create Your First Tunnel” → “Create your first tunnel”.
  - `data/ui/ssh_config_dialog.blp:24` — “Save Configuration” → “Save”.
  - `data/ui/restore_backup_dialog.blp:26` — “Restore Key(s)” → “Restore”.

- Ellipses character and intent
  - `data/ui/create_tunnel_dialog.blp:93` — “Select Key...” → “Select key…”.
  - `data/ui/ssh_config_dialog.blp:41` — “Search hosts...” → “Search hosts…”.
  - `data/ui/connection_diagnostics_dialog.blp:119` — If this opens a save dialog, change “Export Report” → “Export report…”.
  - `data/ui/create_backup_dialog.blp:81` — If this opens a date/time picker, change “Set Expiry Date” → “Set expiration date…”.

- Reduce row action clutter and ambiguous labels
  - `data/ui/key_row.blp:32–65` — Keep two primary actions (e.g., Details, Copy public key). Move “Copy to Server”, “Change Passphrase”, and “Delete” into a row menu. Also:
    - `data/ui/key_row.blp:48` — Tooltip “Copy to Server” → “Install on server…” (if it opens a dialog).

- Password fields and secrets
  - `data/ui/restore_backup_dialog.blp:75` — Use `Adw.PasswordEntryRow` instead of `Adw.EntryRow` for Passphrase.

- Spacing/margins
  - `data/ui/key_list.blp:26` — Margins at 18 px; switch to 12 or 24 for top/bottom/start/end to match Adwaita grid.

- Visual style classes and icon sizes
  - `data/ui/key_row.blp:15` — Icon `pixel-size: 32` → prefer 24 in list rows.
  - `data/ui/key_row.blp:13–17` — Replace `dialog-password-symbolic` with `key-symbolic` for key icon.
  - `data/ui/key_row.blp:16` and `:27` — Remove nonstandard style classes like `accent` and `pill`; keep defaults or use supported styles.

- Shortcuts window and translations
  - `data/ui/shortcuts_dialog.blp:5` and `:13` — Mark titles for translation: wrap with `_()`.
  - `data/ui/shortcuts_dialog.blp` — Consider replacing this custom dialog with `Gtk.ShortcutsWindow` for standard look/behavior.

- Accelerator mapping
  - `src/application.vala:165` — Avoid mapping F1 to About; reserve F1 for Help if present.

## Larger Improvements (follow-ups)

- Convert “Shortcuts” to `Gtk.ShortcutsWindow` with sections for Application, Navigation, etc., and bind to `app.shortcuts`.
- Introduce an overflow menu on key rows (e.g., `Gtk.MenuButton` in the suffix) to host secondary actions.
- Add accessible names programmatically for icon-only buttons in header bars and rows.
- Audit all button/row titles for sentence case and remove parenthetical guidance from option labels:
  - `data/ui/generate_dialog.blp:56,58,74` — Replace labels like “(Recommended)”/“(Not Recommended)” with guidance in subtitles (already present at `:52, :67`).

## Notes

- Many dialogs already follow HIG patterns well (primary/secondary actions, clear groups, `Adw.StatusPage` usage, clamped content widths).
- Most fixes are string-level or small widget substitutions and will not affect logic.

## Suggested Next Steps

1) Apply trivial text/ellipsis/password widget fixes (low risk).
2) Trim key row actions and add overflow menu (medium effort, high UX impact).
3) Migrate shortcuts dialog to `Gtk.ShortcutsWindow` (medium effort, consistency with GNOME apps).
4) Add accessible names to icon-only buttons via code.

