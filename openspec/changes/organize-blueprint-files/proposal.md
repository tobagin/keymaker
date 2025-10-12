# Organize Blueprint Files into Subdirectories

## Overview
Reorganize the 38 Blueprint UI definition files from a flat structure in `data/ui/` into logical subdirectories (`dialogs/`, `pages/`, `widgets/`) to mirror the Vala source code structure and improve project organization.

## Problem Statement
Currently, all 38 Blueprint (`.blp`) files are located in a single flat directory `data/ui/`, which creates several issues:

- **Poor Organization**: All UI files are mixed together with no logical grouping
- **Hard to Navigate**: Developers must scan through 38 files to find the right one
- **Inconsistent with Vala Structure**: Vala code is organized into `src/ui/dialogs/`, `src/ui/pages/`, and `src/ui/widgets/`, but Blueprint files don't follow this structure
- **Scalability**: As the project grows, the flat structure becomes increasingly unwieldy
- **Difficult Maintenance**: Related files (Vala + Blueprint) are structurally separated, making changes harder

### Current State
```
data/ui/
├── add_key_to_agent_dialog.blp
├── add_target_dialog.blp
├── backup_center_dialog.blp
├── backup_page.blp
├── change_passphrase_dialog.blp
├── ... (34 more files in flat structure)
└── window.blp
```

### Vala Structure (for reference)
```
src/ui/
├── dialogs/        # 29+ dialog files
├── pages/          # 6 page files
├── widgets/        # Widget files
├── Window.vala
├── KeyList.vala
└── KeyRow.vala
```

## Why
This reorganization improves project maintainability and developer experience:
- **Consistency**: Blueprint structure mirrors Vala structure
- **Discoverability**: Easy to find related files (e.g., `src/ui/dialogs/GenerateDialog.vala` ↔ `data/ui/dialogs/generate_dialog.blp`)
- **Maintainability**: Logical grouping makes it easier to manage UI changes
- **Scalability**: Structure supports future growth without clutter
- **Code Quality**: Follows established project conventions for organization

## What Changes
### Directory Structure
Create new subdirectories and move Blueprint files:

```
data/ui/
├── dialogs/           # NEW - 29 dialog Blueprint files
│   ├── add_key_to_agent_dialog.blp
│   ├── add_target_dialog.blp
│   ├── backup_center_dialog.blp
│   ├── change_passphrase_dialog.blp
│   ├── connection_diagnostics_dialog.blp
│   ├── connection_diagnostics_runner_dialog.blp
│   ├── connection_test_dialog.blp
│   ├── copy_id_dialog.blp
│   ├── create_backup_dialog.blp
│   ├── create_tunnel_dialog.blp
│   ├── diagnostic_configuration_dialog.blp
│   ├── diagnostic_html_report_dialog.blp
│   ├── diagnostic_results_view_dialog.blp
│   ├── diagnostic_type_selection_dialog.blp
│   ├── emergency_vault_dialog.blp
│   ├── generate_dialog.blp
│   ├── key_details_dialog.blp
│   ├── key_rotation_dialog.blp
│   ├── key_service_mapping_dialog.blp
│   ├── plan_details_dialog.blp
│   ├── preferences_dialog.blp
│   ├── restore_backup_dialog.blp
│   ├── rotation_plan_editor_dialog.blp
│   ├── shortcuts_dialog.blp
│   ├── ssh_agent_dialog.blp
│   ├── ssh_config_dialog.blp
│   ├── ssh_host_edit_dialog.blp
│   ├── ssh_tunneling_dialog.blp
│   └── terminal_dialog.blp
├── pages/             # NEW - 6 page Blueprint files
│   ├── backup_page.blp
│   ├── diagnostics_page.blp
│   ├── hosts_page.blp
│   ├── keys_page.blp
│   ├── rotation_page.blp
│   └── tunnels_page.blp
├── widgets/           # NEW - 2 widget Blueprint files
│   ├── key_list.blp
│   └── key_row.blp
└── window.blp         # STAYS in root (main window)
```

### Build System Changes
- **data/meson.build**: Update blueprint-compiler references to use new paths
- **Resource paths**: Update GResource XML to reference new subdirectory structure
- **Vala template references**: Update any `@Gtk.Template` resource paths in Vala code

## Motivation
The flat structure was acceptable when the project was small, but with 38 Blueprint files:

1. **Developer Confusion**: New contributors struggle to find the right Blueprint file
2. **Merge Conflicts**: All files in one directory increases risk of conflicts
3. **IDE Performance**: Some IDEs slow down with many files in a single directory
4. **Maintenance Overhead**: No clear organization means no clear responsibility
5. **Refactoring Complexity**: Hard to identify which files are related

By organizing into subdirectories:
- Find files faster (know exactly where to look)
- Understand relationships between Vala and Blueprint files
- Maintain consistency with established project structure
- Support future growth without restructuring again

## Proposed Solution
Implement a three-phase approach:

### Phase 1: Prepare New Structure
1. Create subdirectories: `data/ui/dialogs/`, `data/ui/pages/`, `data/ui/widgets/`
2. Document the mapping of current → new paths

### Phase 2: Move Files
Use `git mv` to preserve file history:
```bash
# Dialogs (29 files)
git mv data/ui/*_dialog.blp data/ui/dialogs/

# Pages (6 files)
git mv data/ui/*_page.blp data/ui/pages/

# Widgets (2 files)
git mv data/ui/key_list.blp data/ui/widgets/
git mv data/ui/key_row.blp data/ui/widgets/

# window.blp stays in root
```

### Phase 3: Update References
1. Update `data/meson.build` to use new paths in blueprint-compiler calls
2. Update `data/keysmith.gresource.xml.in` if it hardcodes paths
3. Update Vala `@Template` annotations if they reference resource paths
4. Verify build succeeds

## Impact Analysis
### Files Affected: ~40
- **38 Blueprint files**: Moved to subdirectories
- **data/meson.build**: Updated to reference new paths
- **Potentially affected Vala files**: Any files using `@Template` with hardcoded resource paths

### Benefits
- **Improved Navigation**: 3 organized directories instead of 38 flat files
- **Better Developer Experience**: Intuitive structure, easy to find files
- **Consistency**: Matches Vala source organization
- **Future-Proof**: Structure scales well for more UI components
- **Git History**: Using `git mv` preserves complete file history

### Risks
- **Build Breakage**: Incorrect path updates could break compilation
- **Resource Loading**: Runtime issues if resource paths are wrong
- **Template Loading**: Vala templates might fail to load if paths are incorrect

### Mitigation
- Test build after each phase
- Verify all 38 files are accounted for
- Test application runtime to ensure UI loads correctly
- Use `git mv` to maintain file history
- Document the changes clearly in commit message

## Testing Strategy
### Build Verification
1. Clean build: `rm -rf build && ./scripts/build.sh --dev`
2. Verify all 38 Blueprint files compile without errors
3. Check for missing file warnings

### Runtime Verification
1. Launch application: `flatpak run io.github.tobagin.keysmith.Devel`
2. Test each UI component:
   - Open every dialog to ensure it loads
   - Navigate to every page
   - Verify widgets display correctly
3. Check console for resource loading errors

### Manual Checklist
- [ ] All Blueprint files moved successfully
- [ ] No Blueprint files left in old location
- [ ] Build succeeds without warnings
- [ ] Application launches successfully
- [ ] All dialogs open correctly
- [ ] All pages render correctly
- [ ] No resource loading errors in logs

## Success Criteria
- [ ] All 38 Blueprint files moved to appropriate subdirectories
- [ ] `window.blp` remains in root directory
- [ ] Build succeeds without errors or warnings
- [ ] Application runs without resource loading issues
- [ ] All UI components load and display correctly
- [ ] Git history preserved for all moved files
- [ ] Documentation updated if necessary

## Related Changes
- Complements previous refactoring phases (file naming, code structure)
- Aligns with `code-structure` and `build-system` specifications
- Improves project organization consistency

## References
- Vala source structure: `src/ui/{dialogs,pages,widgets}/`
- Current Blueprint location: `data/ui/*.blp`
- Meson build configuration: `data/meson.build`
