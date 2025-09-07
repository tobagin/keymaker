/*
 * Key Maker - Rotation Plan Editor Dialog
 * 
 * Dialog for creating and editing rotation plans
 */

namespace KeyMaker {
    
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/rotation_plan_editor_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/rotation_plan_editor_dialog.ui")]
#endif
    public class RotationPlanEditorDialog : Adw.Dialog {
        
        [GtkChild] private unowned Adw.HeaderBar header_bar;
        [GtkChild] private unowned Adw.HeaderBar bottom_header_bar;
        [GtkChild] private unowned Gtk.Button save_button;
        
        [GtkChild] private unowned Adw.EntryRow plan_name_row;
        [GtkChild] private unowned Adw.EntryRow plan_description_row;
        [GtkChild] private unowned Adw.ComboRow old_key_selection_row;
        [GtkChild] private unowned Adw.ComboRow new_key_selection_row;
        [GtkChild] private unowned Adw.ComboRow existing_key_selection_row;
        [GtkChild] private unowned Adw.ComboRow reason_row;
        [GtkChild] private unowned Adw.EntryRow custom_reason_row;
        [GtkChild] private unowned Adw.SwitchRow keep_old_key_row;
        [GtkChild] private unowned Adw.SwitchRow enable_rollback_row;
        [GtkChild] private unowned Adw.ComboRow rollback_period_row;
        [GtkChild] private unowned Adw.PreferencesGroup targets_group;
        [GtkChild] private unowned Gtk.Button add_target_button;
        [GtkChild] private unowned Gtk.ListBox targets_list;
        [GtkChild] private unowned Adw.ActionRow targets_placeholder;
        [GtkChild] private unowned Gtk.Image old_key_icon;
        [GtkChild] private unowned Gtk.Image new_key_icon;
        
        public signal void plan_created (RotationPlan plan);
        public signal void plan_updated (RotationPlan plan);
        
        private RotationPlan? editing_plan = null;
        private GenericArray<SSHKey> available_keys;
        private SSHConfig? ssh_config;
        private GenericArray<RotationTarget> targets;
        private bool has_unsaved_changes = false;
        private RotationPlan? original_plan_state = null;
        private bool is_initializing = true;
        
        public RotationPlanEditorDialog (Gtk.Window? parent = null) {
            // Note: Parent setting handled by the code that presents the dialog
            
            // Common initialization
            available_keys = new GenericArray<SSHKey>();
            targets = new GenericArray<RotationTarget>();
            has_unsaved_changes = false;
            is_initializing = true;
            
            setup_ui();
            load_available_keys.begin();
            load_ssh_config.begin();
            
            // New plan specific initialization
            save_button.sensitive = false;
            can_close = true; // Allow closing by default when no changes
            
            // Complete initialization after a brief delay to allow async loading
            Timeout.add(100, () => {
                if (editing_plan == null) { // Only for new plans
                    is_initializing = false;
                    update_old_key_icon();
                    update_new_key_icon();
                    validate_form();
                }
                return false;
            });
        }
        
        public RotationPlanEditorDialog.edit_plan (RotationPlan plan, Gtk.Window? parent = null) {
            // Common initialization first
            available_keys = new GenericArray<SSHKey>();
            targets = new GenericArray<RotationTarget>();
            has_unsaved_changes = false;
            is_initializing = true;
            
            setup_ui();
            load_available_keys.begin();
            load_ssh_config.begin();
            
            // Edit mode specific initialization
            editing_plan = plan;
            original_plan_state = plan;
            title = _("Edit Rotation Plan");
            save_button.label = _("Save Changes");
            save_button.sensitive = false;
            can_close = true; // Allow closing by default when no changes
            
            // Populate data and complete initialization after async loading
            Timeout.add(150, () => {
                populate_plan_data();
                has_unsaved_changes = false;
                is_initializing = false;
                update_old_key_icon();
                update_new_key_icon();
                validate_form();
                return false;
            });
        }
        
        
        private void setup_ui () {
            setup_rotation_reasons();
            setup_rollback_periods();
            setup_key_generation_options();
            setup_signals();
        }
        
        private void setup_signals () {
            // Note: Button signal connections are handled by Blueprint callbacks
            
            // Validation and change tracking triggers
            plan_name_row.notify["text"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            plan_description_row.notify["text"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            old_key_selection_row.notify["selected"].connect(() => { 
                mark_as_changed(); 
                update_old_key_icon();
                validate_form(); 
            });
            new_key_selection_row.notify["selected"].connect(() => { 
                mark_as_changed(); 
                update_new_key_icon();
                validate_form(); 
            });
            existing_key_selection_row.notify["selected"].connect(() => { 
                mark_as_changed(); 
                update_new_key_icon();
                validate_form(); 
            });
            custom_reason_row.notify["text"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            keep_old_key_row.notify["active"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            enable_rollback_row.notify["active"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            rollback_period_row.notify["selected"].connect(() => { 
                mark_as_changed(); validate_form(); 
            });
            
            // Other signal connections
            reason_row.notify["selected"].connect(on_reason_selection_changed);
            new_key_selection_row.notify["selected"].connect(on_new_key_selection_changed);
            enable_rollback_row.notify["active"].connect(on_rollback_toggle);
            
            // Handle close attempts with unsaved changes
            close_attempt.connect(() => {
                if (has_unsaved_changes) {
                    show_unsaved_changes_dialog();
                }
            });
        }
        
        private void setup_rotation_reasons () {
            var reason_list = new Gtk.StringList (null);
            reason_list.append (_("Security compliance"));
            reason_list.append (_("Suspected compromise"));
            reason_list.append (_("Regular rotation policy"));
            reason_list.append (_("Key expiration"));
            reason_list.append (_("Algorithm upgrade"));
            reason_list.append (_("Employee departure"));
            reason_list.append (_("System migration"));
            reason_list.append (_("Custom reason"));
            
            reason_row.model = reason_list;
            reason_row.selected = 2; // Default to "Regular rotation policy"
        }
        
        private void setup_rollback_periods () {
            var period_list = new Gtk.StringList (null);
            period_list.append (_("1 Week"));
            period_list.append (_("1 Fortnight"));
            period_list.append (_("1 Month"));
            
            rollback_period_row.model = period_list;
            rollback_period_row.selected = 0; // Default to 1 week
        }
        
        private void setup_key_generation_options () {
            var new_key_list = new Gtk.StringList (null);
            new_key_list.append (_("Generate new ED25519 key"));
            new_key_list.append (_("Generate new RSA 4096 key"));
            new_key_list.append (_("Select existing key"));
            
            new_key_selection_row.model = new_key_list;
            new_key_selection_row.selected = 0; // Default to generate ED25519
        }
        
        private async void load_available_keys () {
            try {
                var key_scanner = new KeyScanner();
                var keys = yield KeyScanner.scan_ssh_directory();
                
                available_keys = keys;
                populate_key_selection();
                
            } catch (KeyMakerError e) {
                warning("Failed to load SSH keys: %s", e.message);
            }
        }
        
        private async void load_ssh_config () {
            try {
                ssh_config = new SSHConfig();
                yield ssh_config.load_config();
                
            } catch (KeyMakerError e) {
                warning("Failed to load SSH config: %s", e.message);
            }
        }
        
        private void populate_key_selection () {
            var key_list = new Gtk.StringList (null);
            
            for (int i = 0; i < available_keys.length; i++) {
                var key = available_keys[i];
                key_list.append (key.get_display_name());
            }
            
            old_key_selection_row.model = key_list;
            existing_key_selection_row.model = key_list;
            
            if (key_list.get_n_items() > 0) {
                old_key_selection_row.selected = 0;
            }
        }
        
        private void populate_plan_data () {
            if (editing_plan == null) return;
            
            plan_name_row.text = editing_plan.name;
            plan_description_row.text = editing_plan.description ?? "";
            
            // Find and select the old key
            for (int i = 0; i < available_keys.length; i++) {
                if (available_keys[i].fingerprint == editing_plan.old_key.fingerprint) {
                    old_key_selection_row.selected = i;
                    break;
                }
            }
            
            // Set rotation reason
            set_rotation_reason(editing_plan.rotation_reason);
            
            keep_old_key_row.active = editing_plan.keep_old_key;
            enable_rollback_row.active = editing_plan.enable_rollback;
            rollback_period_row.selected = (int)editing_plan.rollback_period;
            
            // Populate targets
            targets.remove_range(0, targets.length);
            for (int i = 0; i < editing_plan.targets.length; i++) {
                targets.add(editing_plan.targets[i]);
            }
            refresh_targets_list();
        }
        
        private void set_rotation_reason (string reason) {
            var reason_list = (Gtk.StringList) reason_row.model;
            bool found = false;
            
            for (uint i = 0; i < reason_list.get_n_items(); i++) {
                var item = reason_list.get_string(i);
                if (item == reason) {
                    reason_row.selected = (int) i;
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                reason_row.selected = 7; // Custom reason
                custom_reason_row.text = reason;
            }
        }
        
        private void on_reason_selection_changed () {
            bool is_custom = reason_row.selected == 7;
            custom_reason_row.visible = is_custom;
        }
        
        private void on_rollback_toggle () {
            rollback_period_row.sensitive = enable_rollback_row.active;
        }
        
        private void on_new_key_selection_changed () {
            // Show existing key selection when "Select existing key" is selected
            // "Select existing key" is at position 2 in the combo
            bool show_existing_keys = new_key_selection_row.selected == 2;
            existing_key_selection_row.visible = show_existing_keys;
        }
        
        private void validate_form () {
            // Don't validate during initialization
            if (is_initializing) {
                return;
            }
            
            bool valid = true;
            
            // Check if plan name is provided
            if (plan_name_row.text.strip().length == 0) {
                valid = false;
            }
            
            // Check if old key is selected
            if (old_key_selection_row.selected == Gtk.INVALID_LIST_POSITION) {
                valid = false;
            }
            
            // Check if we have targets
            if (targets.length == 0) {
                valid = false;
            }
            
            // Check custom reason if selected
            bool is_custom_reason = reason_row.selected == 7; // Assuming custom is at position 7
            if (is_custom_reason && custom_reason_row.text.strip().length == 0) {
                valid = false;
            }
            
            // Save button logic: must be valid AND have changes (except for new plans)
            bool should_enable = false;
            if (editing_plan != null) {
                // For editing existing plans: must be valid AND have changes
                should_enable = valid && has_unsaved_changes;
            } else {
                // For new plans: must be valid (changes assumed since it's a new plan)
                should_enable = valid;
            }
            
            save_button.sensitive = should_enable;
            
        }
        
        
        [GtkCallback]
        private void on_save_clicked () {
            if (editing_plan != null) {
                update_existing_plan();
                plan_updated(editing_plan);
            } else {
                var new_plan = create_new_plan();
                if (new_plan != null) {
                    plan_created(new_plan);
                }
            }
            has_unsaved_changes = false;
            can_close = true; // Allow closing after successful save
            base.close();
        }
        
        private void mark_as_changed () {
            // Don't mark as changed during initialization
            if (is_initializing) {
                return;
            }
            
            has_unsaved_changes = true;
            can_close = false; // Prevent closing when there are unsaved changes
        }
        
        
        public new void close () {
            base.close();
        }
        
        private void show_unsaved_changes_dialog () {
            var dialog = new Adw.AlertDialog(
                _("Unsaved Changes"),
                _("You have unsaved changes. What would you like to do?")
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("discard", _("Discard Changes"));
            dialog.add_response("save", _("Save Changes"));
            
            dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                switch (response) {
                    case "discard":
                        has_unsaved_changes = false;
                        can_close = true; // Allow closing now
                        base.close();
                        break;
                        
                    case "save":
                        if (can_save_current_changes()) {
                            on_save_clicked();
                            // on_save_clicked() will handle closing
                        }
                        break;
                        
                    case "cancel":
                    default:
                        // Do nothing - dialog closes, editor stays open
                        break;
                }
            });
            
            dialog.present(this);
        }
        
        private bool can_save_current_changes () {
            // Check if current state is valid for saving
            var plan_name = plan_name_row.text.strip();
            if (plan_name.length == 0) {
                return false;
            }
            
            if (old_key_selection_row.selected == Gtk.INVALID_LIST_POSITION) {
                return false;
            }
            
            if (targets.length == 0) {
                return false;
            }
            
            bool is_custom_reason = reason_row.selected == 7;
            if (is_custom_reason && custom_reason_row.text.strip().length == 0) {
                return false;
            }
            
            return true;
        }
        
        [GtkCallback]
        private void on_add_target_clicked () {
            var target_dialog = new AddTargetDialog();
            target_dialog.ssh_config = ssh_config;
            
            target_dialog.target_added.connect((target) => {
                targets.add(target);
                refresh_targets_list();
                mark_as_changed();
                validate_form();
            });
            
            target_dialog.present(this);
        }
        
        private RotationPlan? create_new_plan () {
            var selected_key_index = old_key_selection_row.selected;
            if (selected_key_index == Gtk.INVALID_LIST_POSITION || selected_key_index >= available_keys.length) {
                return null;
            }
            
            var old_key = available_keys[selected_key_index];
            var reason = get_rotation_reason();
            
            var plan = new RotationPlan(old_key, reason);
            apply_plan_settings(plan);
            
            return plan;
        }
        
        private void update_existing_plan () {
            if (editing_plan == null) return;
            
            // Update the old key if a different one is selected
            var selected_key_index = old_key_selection_row.selected;
            if (selected_key_index != Gtk.INVALID_LIST_POSITION && selected_key_index < available_keys.length) {
                editing_plan.old_key = available_keys[selected_key_index];
            }
            
            editing_plan.name = plan_name_row.text.strip();
            editing_plan.description = plan_description_row.text.strip();
            editing_plan.rotation_reason = get_rotation_reason();
            apply_plan_settings(editing_plan);
        }
        
        private void apply_plan_settings (RotationPlan plan) {
            plan.name = plan_name_row.text.strip();
            plan.description = plan_description_row.text.strip();
            plan.keep_old_key = keep_old_key_row.active;
            plan.enable_rollback = enable_rollback_row.active;
            plan.rollback_period = (RollbackPeriod) rollback_period_row.selected;
            
            // Clear existing targets and add new ones
            plan.targets.remove_range(0, plan.targets.length);
            for (int i = 0; i < targets.length; i++) {
                plan.add_target(targets[i]);
            }
        }
        
        private string get_rotation_reason () {
            if (reason_row.selected == 7) {
                // Custom reason
                return custom_reason_row.text.strip();
            } else if (reason_row.selected != Gtk.INVALID_LIST_POSITION) {
                var selected_text = ((Gtk.StringList) reason_row.model).get_string(reason_row.selected);
                return selected_text;
            }
            return "Manual rotation";
        }
        
        private void refresh_targets_list () {
            // Clear existing target rows (except placeholder)
            Gtk.Widget? child = targets_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                if (child != targets_placeholder) {
                    targets_list.remove(child);
                }
                child = next;
            }
            
            // Show/hide placeholder
            targets_placeholder.visible = targets.length == 0;
            
            // Add target rows
            for (int i = 0; i < targets.length; i++) {
                var target = targets[i];
                add_target_row(target);
            }
            
            // Trigger validation after updating targets
            validate_form();
        }
        
        private void add_target_row (RotationTarget target) {
            var row = new Adw.ActionRow();
            row.title = target.get_display_name();
            row.subtitle = @"Port: $(target.port)";
            
            // Add server icon
            var server_icon = new Gtk.Image.from_icon_name("network-server-symbolic");
            server_icon.add_css_class("dim-label");
            row.add_prefix(server_icon);
            
            var remove_button = new Gtk.Button();
            remove_button.icon_name = "user-trash-symbolic";
            remove_button.valign = Gtk.Align.CENTER;
            remove_button.add_css_class("flat");
            remove_button.tooltip_text = _("Remove Target");
            
            remove_button.clicked.connect(() => {
                targets.remove(target);
                targets_list.remove(row);
                targets_placeholder.visible = targets.length == 0;
                validate_form(); // Trigger validation when target is removed
            });
            
            row.add_suffix(remove_button);
            targets_list.append(row);
        }
        
        private void update_old_key_icon () {
            if (old_key_selection_row.selected == Gtk.INVALID_LIST_POSITION) {
                old_key_icon.icon_name = "security-high-symbolic";
                return;
            }
            
            if (available_keys.length > old_key_selection_row.selected) {
                var selected_key = available_keys[old_key_selection_row.selected];
                old_key_icon.icon_name = selected_key.key_type.get_icon_name();
            }
        }
        
        private void update_new_key_icon () {
            if (new_key_selection_row.selected == Gtk.INVALID_LIST_POSITION) {
                new_key_icon.icon_name = "security-high-symbolic";
                return;
            }
            
            switch (new_key_selection_row.selected) {
                case 0: // Generate new ED25519 key
                    new_key_icon.icon_name = SSHKeyType.ED25519.get_icon_name();
                    break;
                case 1: // Generate new RSA 4096 key
                    new_key_icon.icon_name = SSHKeyType.RSA.get_icon_name();
                    break;
                case 2: // Select existing key
                    if (existing_key_selection_row.selected != Gtk.INVALID_LIST_POSITION && 
                        available_keys.length > existing_key_selection_row.selected) {
                        var selected_key = available_keys[existing_key_selection_row.selected];
                        new_key_icon.icon_name = selected_key.key_type.get_icon_name();
                    } else {
                        new_key_icon.icon_name = "security-high-symbolic";
                    }
                    break;
                default:
                    new_key_icon.icon_name = "security-high-symbolic";
                    break;
            }
        }
    }
}