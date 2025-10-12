# Tasks: Organize Blueprint Files

## Overview
This document tracks all implementation tasks for reorganizing Blueprint files into subdirectories.

## Prerequisites
- [x] All previous refactoring phases completed
- [ ] Proposal approved

## Implementation Tasks

### 1. Preparation
- [ ] Create new subdirectories: `data/ui/dialogs/`, `data/ui/pages/`, `data/ui/widgets/`
- [ ] Verify all 38 Blueprint files exist in current location
- [ ] Create backup list of all files before moving
- [ ] Document current meson.build structure

### 2. Move Dialog Files (29 files)
- [ ] Move `add_key_to_agent_dialog.blp` to `dialogs/`
- [ ] Move `add_target_dialog.blp` to `dialogs/`
- [ ] Move `backup_center_dialog.blp` to `dialogs/`
- [ ] Move `change_passphrase_dialog.blp` to `dialogs/`
- [ ] Move `connection_diagnostics_dialog.blp` to `dialogs/`
- [ ] Move `connection_diagnostics_runner_dialog.blp` to `dialogs/`
- [ ] Move `connection_test_dialog.blp` to `dialogs/`
- [ ] Move `copy_id_dialog.blp` to `dialogs/`
- [ ] Move `create_backup_dialog.blp` to `dialogs/`
- [ ] Move `create_tunnel_dialog.blp` to `dialogs/`
- [ ] Move `diagnostic_configuration_dialog.blp` to `dialogs/`
- [ ] Move `diagnostic_html_report_dialog.blp` to `dialogs/`
- [ ] Move `diagnostic_results_view_dialog.blp` to `dialogs/`
- [ ] Move `diagnostic_type_selection_dialog.blp` to `dialogs/`
- [ ] Move `emergency_vault_dialog.blp` to `dialogs/`
- [ ] Move `generate_dialog.blp` to `dialogs/`
- [ ] Move `key_details_dialog.blp` to `dialogs/`
- [ ] Move `key_rotation_dialog.blp` to `dialogs/`
- [ ] Move `key_service_mapping_dialog.blp` to `dialogs/`
- [ ] Move `plan_details_dialog.blp` to `dialogs/`
- [ ] Move `preferences_dialog.blp` to `dialogs/`
- [ ] Move `restore_backup_dialog.blp` to `dialogs/`
- [ ] Move `rotation_plan_editor_dialog.blp` to `dialogs/`
- [ ] Move `shortcuts_dialog.blp` to `dialogs/`
- [ ] Move `ssh_agent_dialog.blp` to `dialogs/`
- [ ] Move `ssh_config_dialog.blp` to `dialogs/`
- [ ] Move `ssh_host_edit_dialog.blp` to `dialogs/`
- [ ] Move `ssh_tunneling_dialog.blp` to `dialogs/`
- [ ] Move `terminal_dialog.blp` to `dialogs/`

### 3. Move Page Files (6 files)
- [ ] Move `backup_page.blp` to `pages/`
- [ ] Move `diagnostics_page.blp` to `pages/`
- [ ] Move `hosts_page.blp` to `pages/`
- [ ] Move `keys_page.blp` to `pages/`
- [ ] Move `rotation_page.blp` to `pages/`
- [ ] Move `tunnels_page.blp` to `pages/`

### 4. Move Widget Files (2 files)
- [ ] Move `key_list.blp` to `widgets/`
- [ ] Move `key_row.blp` to `widgets/`

### 5. Update Build Configuration
- [ ] Review current `data/meson.build` Blueprint compilation rules
- [ ] Update blueprint-compiler input paths to use new subdirectories
- [ ] Update blueprint-compiler output paths if needed
- [ ] Verify resource file paths in `data/keysmith.gresource.xml.in`
- [ ] Update any hardcoded paths in build files

### 6. Update Vala Template References (if needed)
- [ ] Search for `@Template` annotations: `rg "@Template" src/ui/`
- [ ] Check if any use hardcoded resource paths
- [ ] Update paths to reference new subdirectory structure
- [ ] Verify `using Gtk` template bindings still work

### 7. Verification
- [ ] Verify exactly 38 files moved (29 dialogs + 6 pages + 2 widgets + 1 window stays)
- [ ] Confirm `window.blp` remains in `data/ui/`
- [ ] Confirm no `.blp` files remain in old `data/ui/` root (except window.blp)
- [ ] List all files in new directories to verify

### 8. Build and Testing
- [ ] Clean build directory: `rm -rf build`
- [ ] Build development version: `./scripts/build.sh --dev`
- [ ] Fix any blueprint-compiler errors
- [ ] Fix any resource loading errors
- [ ] Verify no missing file warnings

### 9. Runtime Testing
- [ ] Launch application: `flatpak run io.github.tobagin.keysmith.Devel`
- [ ] Test dialog loading (open a few dialogs from each category)
- [ ] Test page navigation (visit all pages)
- [ ] Test widget rendering (verify key list and rows display)
- [ ] Check console for resource loading errors
- [ ] Verify UI appearance is unchanged

### 10. Documentation and Commit
- [ ] Update any documentation referencing file locations
- [ ] Review all changes for completeness
- [ ] Stage all changes: `git add -A`
- [ ] Commit with message: "refactor: Organize Blueprint files into subdirectories"
- [ ] Verify git history preserved with: `git log --follow data/ui/dialogs/generate_dialog.blp`

## Validation Criteria
Each task must meet these criteria before being marked complete:
- Files moved using `git mv` to preserve history
- Build compiles without errors or warnings
- Application runs without resource loading issues
- All UI components load and display correctly
- No Blueprint files left in wrong location

## Dependencies
- Task 5 (Update Build Config) depends on tasks 1-4 (file moves) being complete
- Task 8 (Build and Testing) depends on task 5 being complete
- Task 9 (Runtime Testing) depends on task 8 being complete
- Task 10 (Documentation) depends on task 9 being complete

## File Counts for Verification
- **Dialogs**: 29 files ending in `*_dialog.blp`
- **Pages**: 6 files ending in `*_page.blp`
- **Widgets**: 2 files (`key_list.blp`, `key_row.blp`)
- **Root**: 1 file (`window.blp`) should remain in `data/ui/`
- **Total**: 38 Blueprint files

## Estimated Effort
- Tasks 1-4: 1 hour (preparation and file moves)
- Task 5: 1-2 hours (build system updates)
- Task 6: 30 minutes (Vala template verification)
- Tasks 7-9: 1 hour (verification and testing)
- Task 10: 30 minutes (documentation and commit)
- **Total**: 4-5 hours (half day)

## Notes
- Use `git mv` for all file moves to preserve git history
- The meson.build file likely uses globs or lists - update accordingly
- Blueprint compiler generates .ui files - output path structure may need adjustment
- GResource system packs files - verify resource://org/gnome/... paths still work
- Test thoroughly before committing - UI bugs are immediately visible to users
