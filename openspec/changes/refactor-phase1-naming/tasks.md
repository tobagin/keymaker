# Implementation Tasks

## 1. Pre-Flight Checks
- [ ] 1.1 Verify no pending uncommitted changes in working directory
- [ ] 1.2 Create feature branch `refactor/phase-1-naming` from current branch
- [ ] 1.3 Document current file count (verify ~75 Vala files to rename)
- [ ] 1.4 Backup current working state (git stash or commit)

## 2. Create Automated Renaming Script
- [ ] 2.1 Create `scripts/rename_vala_files.sh` with all git mv commands
- [ ] 2.2 Add root level renames (application.vala)
- [ ] 2.3 Add models/ directory renames (4 files)
- [ ] 2.4 Add backend/ root directory renames (7 files)
- [ ] 2.5 Add backend/ subdirectory moves and renames:
  - [ ] ssh_operations/ (4 files: main + 3 submodules)
  - [ ] rotation/ (6 files: main + 5 submodules)
  - [ ] tunneling/ (4 files: main + 3 submodules)
  - [ ] vault/ (3 files: main + 2 submodules)
  - [ ] diagnostics/ (1 file: main)
- [ ] 2.6 Add ui/ root directory renames (3 files: window, key-list, key-row)
- [ ] 2.7 Add ui/pages/ directory renames (6 files)
- [ ] 2.8 Add ui/widgets/ directory moves and renames (2 files)
- [ ] 2.9 Add ui/dialogs/ directory renames (32 files)
- [ ] 2.10 Add utils/ directory renames (7 files)
- [ ] 2.11 Make script executable: `chmod +x scripts/rename_vala_files.sh`
- [ ] 2.12 Review script for completeness against file list

## 3. Execute File Renames
- [ ] 3.1 Run `./scripts/rename_vala_files.sh` and capture output
- [ ] 3.2 Verify script completed without errors
- [ ] 3.3 Check git status shows all renames staged
- [ ] 3.4 Verify expected file count matches (~75 renames)
- [ ] 3.5 Spot-check 5-10 files to confirm correct naming:
  - [ ] Root: Application.vala exists
  - [ ] Models: SshKey.vala exists
  - [ ] Backend: KeyScanner.vala exists
  - [ ] UI: GenerateDialog.vala exists
  - [ ] Utils: Command.vala exists

## 4. Update Build System
- [ ] 4.1 Locate all meson.build files:
  - [ ] Find with: `find . -name "meson.build" -type f`
- [ ] 4.2 Update `src/meson.build` with new filenames
- [ ] 4.3 Update `src/models/meson.build` (if exists)
- [ ] 4.4 Update `src/backend/meson.build` (if exists)
- [ ] 4.5 Update `src/ui/meson.build` (if exists)
- [ ] 4.6 Update `src/utils/meson.build` (if exists)
- [ ] 4.7 Search for any hardcoded references: `grep -r "kebab-case" meson.build`
- [ ] 4.8 Stage all meson.build changes

## 5. Testing & Validation
- [ ] 5.1 Clean previous build: `rm -rf _build/ _inst/`
- [ ] 5.2 Run development build: `./scripts/build.sh --dev`
- [ ] 5.3 Verify build succeeds with no warnings
- [ ] 5.4 Launch application: `flatpak run io.github.tobagin.keysmith.Devel`
- [ ] 5.5 Perform smoke tests:
  - [ ] Application launches without errors
  - [ ] Main window displays correctly
  - [ ] Navigate through all pages (Keys, Hosts, Diagnostics, Rotation, Tunnels, Backup)
  - [ ] Open at least 3 different dialogs
  - [ ] Exit cleanly
- [ ] 5.6 Run production build: `./scripts/build.sh`
- [ ] 5.7 Verify production build succeeds

## 6. Git Commit
- [ ] 6.1 Review staged changes: `git status`
- [ ] 6.2 Verify all renames use git mv (check for additions/deletions pairs)
- [ ] 6.3 Commit with descriptive message:
  ```
  refactor: Rename all Vala files to PascalCase convention

  - Renamed ~75 Vala files from kebab-case to PascalCase
  - Moved main organizational files into subdirectories
  - Updated all meson.build files to reference new names
  - Blueprint files remain unchanged (already correct snake_case)
  - Git history preserved using git mv

  Phase 1 of comprehensive refactoring plan.
  Establishes foundation for future refactoring phases.
  ```
- [ ] 6.4 Push branch to remote: `git push -u origin refactor/phase-1-naming`

## 7. Documentation
- [ ] 7.1 Mark Phase 1 as complete in REFACTORING-PLAN.md
- [ ] 7.2 Document any deviations from plan
- [ ] 7.3 Note any unexpected issues encountered
- [ ] 7.4 Update completion date in plan

## 8. Post-Completion Verification
- [ ] 8.1 Verify `git log --follow` works for renamed files
- [ ] 8.2 Check no broken imports or references remain
- [ ] 8.3 Confirm no kebab-case .vala files exist: `find src -name "*-*.vala"`
- [ ] 8.4 Run final smoke test on fresh install

## Notes
- All tasks must be completed sequentially
- Do not proceed to next section until all tasks in current section pass
- If any test fails, fix issue before continuing
- Keep script for potential rollback reference
