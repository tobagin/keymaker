# Refactor Phase 1: File Naming Standardization

## Why

The codebase currently has ~75 Vala files using inconsistent `kebab-case.vala` naming (e.g., `key-scanner.vala`, `ssh-agent.vala`) instead of the standard `PascalCase.vala` convention used in most Vala projects. This creates confusion for contributors and violates Vala community conventions. Blueprint files correctly use `snake_case.blp` and require no changes.

This is the foundation phase that must be completed before other refactoring work, as it affects all future development and file references.

## What Changes

- Rename ~75 Vala files from `kebab-case.vala` to `PascalCase.vala`
- Move main organizational files (e.g., `ssh-operations.vala`, `key-rotation.vala`) into their respective subdirectories with proper names
- Update all `meson.build` files to reference new filenames
- Blueprint files remain unchanged (already correct with `snake_case.blp`)
- Preserve git history using `git mv` for all renames

### File Categories Affected:
- **Root level**: `application.vala` → `Application.vala`
- **Models** (4 files): All model classes
- **Backend** (7 root + 20 subfolder files): Core backend logic
- **UI** (3 root + 6 pages + 32 dialogs + 2 widgets): All UI components
- **Utils** (7 files): Utility classes

### Example Renames:
- `src/models/ssh-key.vala` → `src/models/SshKey.vala`
- `src/backend/key-scanner.vala` → `src/backend/KeyScanner.vala`
- `src/ui/dialogs/generate-dialog.vala` → `src/ui/dialogs/GenerateDialog.vala`
- `src/utils/command.vala` → `src/utils/Command.vala`

## Impact

### Affected Specs:
- **code-structure**: Establishes consistent file naming conventions
- **build-system**: Updates build configuration to reference renamed files

### Affected Code:
- All `meson.build` files in:
  - `src/meson.build` (main build file)
  - `src/models/meson.build` (if exists)
  - `src/backend/meson.build` (if exists)
  - `src/ui/meson.build` (if exists)
  - `src/utils/meson.build` (if exists)
- No code logic changes required (git mv preserves file contents)
- No Blueprint files affected (already correct)

### Migration Path:
- Single automated script performs all renames
- Git history preserved via `git mv`
- Build system updates in same commit
- No API or behavior changes

### Risks:
- **LOW**: Merge conflicts with concurrent PRs (mitigated by completing quickly)
- **LOW**: Build errors if meson.build updates incomplete (mitigated by testing)
- **NONE**: Runtime behavior (no code logic changes)

### Dependencies:
- No external dependencies
- Blocks all other refactoring phases (foundation work)

### Testing:
- Development build: `./scripts/build.sh --dev`
- Production build: `./scripts/build.sh`
- Runtime smoke test: Launch application and verify basic functionality
