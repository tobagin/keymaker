# Design: Organize Blueprint Files

## Architecture

### Current State
Flat directory structure with all UI definition files:
```
data/ui/
└── [38 .blp files in root]
    ├── *_dialog.blp (29 files)
    ├── *_page.blp (6 files)
    ├── key_list.blp, key_row.blp (2 files)
    └── window.blp (1 file)
```

### Target State
Organized subdirectory structure mirroring Vala source:
```
data/ui/
├── dialogs/           [29 files]
│   └── *_dialog.blp
├── pages/             [6 files]
│   └── *_page.blp
├── widgets/           [2 files]
│   ├── key_list.blp
│   └── key_row.blp
└── window.blp         [1 file - stays in root]
```

## Design Decisions

### 1. Directory Structure

**Decision**: Use three subdirectories: `dialogs/`, `pages/`, `widgets/`

**Rationale**:
- **Mirrors Vala Structure**: `src/ui/` already uses this exact organization
- **Clear Categories**: Each file type has an obvious home
- **Scalability**: Structure supports 100+ UI files without reorganization
- **Conventions**: Follows GNOME/GTK application best practices

**File Classification**:
| Category | Pattern | Count | Example |
|----------|---------|-------|---------|
| Dialogs | `*_dialog.blp` | 29 | `generate_dialog.blp` |
| Pages | `*_page.blp` | 6 | `keys_page.blp` |
| Widgets | Custom components | 2 | `key_list.blp` |
| Root | Main application window | 1 | `window.blp` |

### 2. File Movement Strategy

**Decision**: Use `git mv` for all file moves

**Before**:
```bash
# WRONG - loses git history
mv data/ui/generate_dialog.blp data/ui/dialogs/
git add data/ui/dialogs/generate_dialog.blp
```

**After**:
```bash
# CORRECT - preserves git history
git mv data/ui/generate_dialog.blp data/ui/dialogs/
```

**Benefits**:
- Git tracks file renames automatically
- `git log --follow` shows complete history
- `git blame` continues to work across moves
- Easier to bisect issues across reorganization

### 3. Build System Integration

**Decision**: Update meson.build to use subdirectory paths

The Blueprint compilation likely works like this:
```meson
# Current (assumed)
blueprints = files(
  'add_key_to_agent_dialog.blp',
  'generate_dialog.blp',
  # ... all 38 files listed
)

# After reorganization
blueprints = files(
  'dialogs/add_key_to_agent_dialog.blp',
  'dialogs/generate_dialog.blp',
  # ... updated paths
)

# Or using globs (if supported)
dialog_blueprints = files('dialogs/*.blp')
page_blueprints = files('pages/*.blp')
widget_blueprints = files('widgets/*.blp')
```

**Investigation Needed**:
- Check current meson.build structure
- Determine if globs are used or explicit file lists
- Verify blueprint-compiler output path handling

### 4. Resource Loading

**Decision**: Maintain resource path compatibility

GTK applications load UI templates via GResource:
```vala
// Vala code with @Template annotation
[GtkTemplate (ui = "/org/gnome/keysmith/ui/generate_dialog.ui")]
public class GenerateDialog : Adw.Dialog {
    // ...
}
```

The resource path is defined by:
1. **Blueprint file** → Compiles to → **.ui file**
2. **.ui file** → Packaged into → **GResource bundle**
3. **GResource prefix** → Defines → **Runtime path**

**Verification Required**:
- Current resource prefix (likely `/org/gnome/keysmith/ui/` or similar)
- Whether subdirectories in source become subdirectories in GResource
- If `@Template` annotations need updating

**Potential Scenarios**:

**Scenario A: Paths stay flat in GResource**
```
Source: data/ui/dialogs/generate_dialog.blp
Compile: data/ui/generate_dialog.ui
Resource: /org/gnome/keysmith/ui/generate_dialog.ui
Vala: No changes needed ✓
```

**Scenario B: Paths mirror subdirectories**
```
Source: data/ui/dialogs/generate_dialog.blp
Compile: data/ui/dialogs/generate_dialog.ui
Resource: /org/gnome/keysmith/ui/dialogs/generate_dialog.ui
Vala: Update @Template path ✗ (requires code changes)
```

**Preferred**: Scenario A (no Vala changes)
We can configure meson to flatten output paths even though source uses subdirectories.

### 5. Window.blp Location

**Decision**: Keep `window.blp` in `data/ui/` root

**Rationale**:
- Main application window is special (not a dialog/page/widget)
- `Window.vala` is in `src/ui/` root, not in a subdirectory
- Single file doesn't need its own subdirectory
- Clear distinction: root = main window, subdirs = components

## Implementation Details

### Step 1: Create Directories
```bash
mkdir -p data/ui/dialogs
mkdir -p data/ui/pages
mkdir -p data/ui/widgets
```

### Step 2: Move Dialog Files
```bash
# Automated approach
for file in data/ui/*_dialog.blp; do
    git mv "$file" data/ui/dialogs/
done
```

**Files to move** (29 dialogs):
- add_key_to_agent_dialog.blp
- add_target_dialog.blp
- backup_center_dialog.blp
- change_passphrase_dialog.blp
- connection_diagnostics_dialog.blp
- connection_diagnostics_runner_dialog.blp
- connection_test_dialog.blp
- copy_id_dialog.blp
- create_backup_dialog.blp
- create_tunnel_dialog.blp
- diagnostic_configuration_dialog.blp
- diagnostic_html_report_dialog.blp
- diagnostic_results_view_dialog.blp
- diagnostic_type_selection_dialog.blp
- emergency_vault_dialog.blp
- generate_dialog.blp
- key_details_dialog.blp
- key_rotation_dialog.blp
- key_service_mapping_dialog.blp
- plan_details_dialog.blp
- preferences_dialog.blp
- restore_backup_dialog.blp
- rotation_plan_editor_dialog.blp
- shortcuts_dialog.blp
- ssh_agent_dialog.blp
- ssh_config_dialog.blp
- ssh_host_edit_dialog.blp
- ssh_tunneling_dialog.blp
- terminal_dialog.blp

### Step 3: Move Page Files
```bash
for file in data/ui/*_page.blp; do
    git mv "$file" data/ui/pages/
done
```

**Files to move** (6 pages):
- backup_page.blp
- diagnostics_page.blp
- hosts_page.blp
- keys_page.blp
- rotation_page.blp
- tunnels_page.blp

### Step 4: Move Widget Files
```bash
git mv data/ui/key_list.blp data/ui/widgets/
git mv data/ui/key_row.blp data/ui/widgets/
```

**Files to move** (2 widgets):
- key_list.blp
- key_row.blp

### Step 5: Update Meson Build

Need to examine `data/meson.build` to understand current structure:

```meson
# Example of what we might find and need to update:

# BEFORE
blueprints = files(
  'ui/add_key_to_agent_dialog.blp',
  'ui/generate_dialog.blp',
  # ... (all 38 files)
)

# AFTER
blueprints = files(
  'ui/dialogs/add_key_to_agent_dialog.blp',
  'ui/dialogs/generate_dialog.blp',
  # ... (all files with new paths)
)

# Or potentially:
dialog_blueprints = run_command('find', 'ui/dialogs', '-name', '*.blp').stdout().strip().split('\n')
page_blueprints = run_command('find', 'ui/pages', '-name', '*.blp').stdout().strip().split('\n')
# ... etc
```

## Testing Strategy

### Pre-Move Verification
1. Count files: `ls data/ui/*.blp | wc -l` (should be 38)
2. List all files: `ls -1 data/ui/*.blp > /tmp/before.txt`
3. Note current build output: `./scripts/build.sh --dev 2>&1 | tee /tmp/build-before.log`

### Post-Move Verification
1. Count files in subdirs:
   ```bash
   ls data/ui/dialogs/*.blp | wc -l  # should be 29
   ls data/ui/pages/*.blp | wc -l    # should be 6
   ls data/ui/widgets/*.blp | wc -l  # should be 2
   ls data/ui/window.blp | wc -l     # should be 1
   ```
2. Verify no files left: `ls data/ui/*.blp` (should only show window.blp)
3. Check git understands moves: `git status` (should show renames, not deletions+additions)

### Build Verification
```bash
rm -rf build/
./scripts/build.sh --dev
# Should succeed without errors
# Compare output to /tmp/build-before.log
```

### Runtime Verification Checklist
Test each category of UI:

**Dialogs** (sample each type):
- [ ] Generate Key Dialog (`generate_dialog.blp`)
- [ ] Preferences Dialog (`preferences_dialog.blp`)
- [ ] Connection Diagnostics Dialog (`connection_diagnostics_dialog.blp`)
- [ ] Backup Center Dialog (`backup_center_dialog.blp`)
- [ ] SSH Tunneling Dialog (`ssh_tunneling_dialog.blp`)

**Pages** (test all 6):
- [ ] Keys Page (`keys_page.blp`)
- [ ] Hosts Page (`hosts_page.blp`)
- [ ] Backup Page (`backup_page.blp`)
- [ ] Rotation Page (`rotation_page.blp`)
- [ ] Tunnels Page (`tunnels_page.blp`)
- [ ] Diagnostics Page (`diagnostics_page.blp`)

**Widgets**:
- [ ] Key List (`key_list.blp`)
- [ ] Key Row (`key_row.blp`)

**Main Window**:
- [ ] Application Window (`window.blp`)

### Git History Verification
```bash
# Verify history is preserved
git log --follow data/ui/dialogs/generate_dialog.blp

# Should show commits from before the move
# Should include: "refactor: Organize Blueprint files into subdirectories"
```

## Migration Risks and Mitigation

### Risk 1: Build Breaks Due to Path Changes
**Risk**: meson.build references might not update correctly

**Mitigation**:
- Read current meson.build before making changes
- Test build immediately after updating paths
- Keep old meson.build as reference
- Revert easily with git if build fails

### Risk 2: Resource Loading Fails at Runtime
**Risk**: GTK template loading might fail with new paths

**Mitigation**:
- Check if GResource paths change (inspect generated .gresource file)
- Test application immediately after build
- Verify each UI component loads (don't just check that app launches)
- Check console for "Failed to load resource" warnings

### Risk 3: Git History Lost
**Risk**: Using `mv` instead of `git mv` loses file history

**Mitigation**:
- Always use `git mv` for moves
- Verify with `git log --follow` after moving
- If history is lost, revert and redo with `git mv`

### Risk 4: Files Left in Wrong Location
**Risk**: Forgetting to move some files or moving to wrong subdirectory

**Mitigation**:
- Use file count verification (29 dialogs, 6 pages, 2 widgets)
- List files before and after
- Use script to automate moves (reduces human error)
- Double-check classification (is it really a dialog? page? widget?)

## Future Enhancements

### 1. Further Categorization
If dialogs grow beyond 29, consider sub-categorizing:
```
data/ui/dialogs/
├── backup/        # Backup-related dialogs
├── diagnostics/   # Diagnostic dialogs
├── keys/          # Key management dialogs
├── rotation/      # Rotation dialogs
└── ssh/           # SSH configuration dialogs
```

### 2. Shared Components
Extract common Blueprint patterns:
```
data/ui/
├── components/    # Reusable Blueprint templates
│   ├── button_row.blp
│   └── status_row.blp
```

### 3. Naming Conventions Documentation
Document in CONTRIBUTING.md:
- Dialog files: `{name}_dialog.blp` → `data/ui/dialogs/`
- Page files: `{name}_page.blp` → `data/ui/pages/`
- Widget files: `{name}.blp` → `data/ui/widgets/`
- Main window: `window.blp` → `data/ui/`

## References
- Meson build system: `data/meson.build`
- GResource specification: `data/keysmith.gresource.xml.in`
- Vala source structure: `src/ui/{dialogs,pages,widgets}/`
- Blueprint compiler documentation: https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/
