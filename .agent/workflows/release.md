---
description: How to release a new version of Keymaker
---

1. Bump version in `meson.build` (line ~4: `version: 'X.Y.Z'`).
2. Update `CHANGELOG.md` — new section at top, emoji-grouped (no `[Unreleased]`).
3. Update `README.md` version header (lines ~14-22).
4. Update `data/io.github.tobagin.keysmith.metainfo.xml.in` — `<release>` entry at top of `<releases>` (line ~107). No emojis in `<li>`.
5. Verify build:
   `./scripts/build.sh --dev`
6. Commit:
   `git add meson.build CHANGELOG.md README.md data/io.github.tobagin.keysmith.metainfo.xml.in`
   `git commit -m "Release vX.Y.Z"`
7. Tag:
   `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
8. Push:
   `git push origin HEAD --tags`
9. GitHub release:
   `gh release create vX.Y.Z --generate-notes`
10. Reminder: Flathub PR is separate.
