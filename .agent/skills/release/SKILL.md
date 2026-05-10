---
name: Release
description: Create a new Keymaker release — analyze changes, bump version, update changelog/README/AppStream metadata, build, commit, tag, push, and create GitHub release
---

# Release Skill

Automates the release process for Keymaker (Vala/GTK4/libadwaita Flatpak app).

Project facts:
- App ID: `io.github.tobagin.keysmith` (note: dir is `keymaker`, app ID is `keysmith`)
- Build system: Meson (no Cargo, no lockfiles)
- Packaged as Flatpak via `flatpak-builder`
- Manifests: `packaging/io.github.tobagin.keysmith.yml` (prod) and `…Devel.yml` (dev)
- Version source of truth: `meson.build` line ~4 (`version: 'X.Y.Z'`)

## Workflow

### Step 1: Analyze changes since last release

```bash
git describe --tags --abbrev=0
git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges
git status --short
```

Categorize changes:
- ✨ **New Features** — user-visible additions
- 🎨 **UI Refinements** — visual/UX polish
- 🔧 **Changed** — behavior changes
- 🐛 **Fixed** — bug fixes
- 🏗️ **Maintenance** — metadata, docs, infra
- ❌ **Breaking** — triggers major bump

### Step 2: Determine version bump

[SemVer](https://semver.org/):
- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (x.Y.0): New features, backward compatible
- **PATCH** (x.y.Z): Bug fixes, metadata, backward compatible

Current version: `meson.build` line 4 (`version: 'X.Y.Z'`).

**Confirm version with user before proceeding.**

### Step 3: Update version in `meson.build`

Edit `meson.build` line ~4:

```meson
project(
    'keysmith',
    'vala', 'c',
    version: 'X.Y.Z',
    ...
)
```

### Step 4: Update `CHANGELOG.md`

Insert new section at the TOP (after the header block, before previous releases). Match existing emoji-grouped style — do NOT use `[Unreleased]` placeholder, this project appends directly:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### ✨ New Features
- **Feature**: Description.

### 🔧 Changed
- **Area**: Change description.

### 🐛 Fixed
- **Component**: Fix description.
```

Only include subsections that have entries. CHANGELOG can be more detailed/technical than README.

### Step 5: Update `README.md`

Replace the version header block (around lines 14-22):

```markdown
## 🎉 Version X.Y.Z - [Short Title]

**Keymaker X.Y.Z** brings [brief description].

### 🆕 What's New in X.Y.Z

- **Feature 1**: Brief user-facing description.
- **Feature 2**: Brief user-facing description.
```

Keep this section short and user-friendly — full detail lives in CHANGELOG.

### Step 6: Update `data/io.github.tobagin.keysmith.metainfo.xml.in`

Add a new `<release>` entry at the TOP of the `<releases>` section (currently around line 107, immediately after `<releases>` on line 106):

```xml
<release version="X.Y.Z" date="YYYY-MM-DD">
  <description>
    <p>Keymaker X.Y.Z [one-sentence summary].</p>
    <ul>
      <li>Change description 1</li>
      <li>Change description 2</li>
    </ul>
  </description>
</release>
```

Rules:
- No emojis in `<li>` items (AppStream validators reject them).
- Keep `<li>` entries concise — one short line each.
- Date format: `YYYY-MM-DD`.

### Step 7: Verify build

Run the dev flatpak build to catch syntax/resource errors before tagging:

```bash
./scripts/build.sh --dev
```

If the build fails, fix issues and re-run before continuing. Optionally smoke-test:

```bash
flatpak run io.github.tobagin.keysmith.Devel
```

### Step 8: Commit all changes

```bash
git add meson.build CHANGELOG.md README.md \
  data/io.github.tobagin.keysmith.metainfo.xml.in
git commit -m "Release vX.Y.Z"
```

Match existing commit-message style: short subject `Release vX.Y.Z` (see `git log --oneline` for prior releases). No `Co-Authored-By` trailer unless the user requests it.

### Step 9: Create and push annotated tag

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin HEAD --tags
```

Never force-push tags unless the user explicitly asks.

### Step 10: Create GitHub release

```bash
gh release create vX.Y.Z --generate-notes
```

Or pass `--notes-file` with curated notes derived from the CHANGELOG entry.

### Step 11: Verify

Report to user:
- Tag created: `git tag --list vX.Y.Z`
- Commit hash: `git rev-parse HEAD`
- Push success
- GitHub release URL (from `gh release view vX.Y.Z --json url -q .url`)
- Reminder: Flathub PR must be opened separately to ship the new version to users.

## File Locations

| File | Update | Purpose |
|------|--------|---------|
| `meson.build` | Line ~4 (`version:`) | Build system version (source of truth) |
| `CHANGELOG.md` | New section at top | Detailed release notes |
| `README.md` | Lines ~14-22 | User-facing highlights |
| `data/io.github.tobagin.keysmith.metainfo.xml.in` | Top of `<releases>` (line ~107) | AppStream metadata |

## Notes

- Always tag with `v` prefix: `vX.Y.Z`.
- Date format everywhere: `YYYY-MM-DD`.
- AppStream `<li>` entries: no emojis, one short line each.
- README "What's New": brief, user-friendly.
- CHANGELOG: more detailed, can include technical context.
- Flathub release is a separate workflow (PR to flathub/io.github.tobagin.keysmith) — out of scope for this skill.
