/*
 * Key Maker - Smart Key Rotation Manager Dialog
 * 
 * Comprehensive rotation plan management with tabs for Plans, Rollbacks, and History
 */

using Gee;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_rotation_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_rotation_dialog.ui")]
#endif
public class KeyMaker.KeyRotationDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    [GtkChild]
    private unowned Gtk.Button close_button;
    [GtkChild]
    private unowned Gtk.Button create_plan_button;
    [GtkChild]
    private unowned Gtk.Button execute_all_button;
    [GtkChild]
    private unowned Adw.ViewSwitcherTitle view_switcher_title;
    [GtkChild]
    private unowned Adw.ViewStack main_stack;
    [GtkChild]
    private unowned Adw.ViewSwitcherBar view_switcher_bar;
    
    // Plans tab widgets
    [GtkChild]
    private unowned Adw.PreferencesGroup draft_plans_group;
    [GtkChild]
    private unowned Gtk.ListBox draft_plans_list;
    [GtkChild]
    private unowned Adw.ActionRow draft_placeholder;
    [GtkChild]
    private unowned Adw.PreferencesGroup running_plans_group;
    [GtkChild]
    private unowned Gtk.ListBox running_plans_list;
    [GtkChild]
    private unowned Adw.ActionRow running_placeholder;
    
    // Rollbacks tab widgets
    [GtkChild]
    private unowned Adw.PreferencesGroup rollback_plans_group;
    [GtkChild]
    private unowned Gtk.ListBox rollback_plans_list;
    [GtkChild]
    private unowned Adw.ActionRow rollback_placeholder;
    [GtkChild]
    private unowned Adw.ComboRow default_rollback_period_row;
    [GtkChild]
    private unowned Adw.SwitchRow enable_rollback_by_default_row;
    
    // History tab widgets
    [GtkChild]
    private unowned Adw.PreferencesGroup history_group;
    [GtkChild]
    private unowned Gtk.Button clear_history_button;
    [GtkChild]
    private unowned Gtk.ListBox history_list;
    [GtkChild]
    private unowned Adw.ActionRow history_placeholder;
    
    private RotationPlanManager plan_manager;
    private GenericArray<SSHKey> available_keys;
    
    public KeyRotationDialog (Gtk.Window? parent = null) {
        plan_manager = new RotationPlanManager();
        available_keys = new GenericArray<SSHKey>();
        
        setup_signals();
        setup_rollback_settings();
        load_available_keys.begin();
        refresh_all_lists();
    }
    
    private void setup_signals () {
        close_button.clicked.connect(on_close_clicked);
        create_plan_button.clicked.connect(on_create_plan_clicked);
        execute_all_button.clicked.connect(on_execute_all_clicked);
        clear_history_button.clicked.connect(on_clear_history_clicked);
        
        // Plan manager signals
        plan_manager.plan_added.connect(on_plan_added);
        plan_manager.plan_updated.connect(on_plan_updated);
        plan_manager.plan_removed.connect(on_plan_removed);
        plan_manager.plan_status_changed.connect(on_plan_status_changed);
        plan_manager.execution_started.connect(on_execution_started);
        plan_manager.execution_completed.connect(on_execution_completed);
        plan_manager.batch_execution_started.connect(on_batch_execution_started);
        plan_manager.batch_execution_completed.connect(on_batch_execution_completed);
        
        // Update execute all button sensitivity
        Timeout.add_seconds(1, () => {
            update_execute_all_button();
            return true;
        });
    }
    
    private void setup_rollback_settings () {
        var period_list = new Gtk.StringList(null);
        period_list.append(_("1 Week"));
        period_list.append(_("1 Fortnight"));
        period_list.append(_("1 Month"));
        
        default_rollback_period_row.model = period_list;
        default_rollback_period_row.selected = 0; // Default to 1 week
    }
    
    private async void load_available_keys () {
        try {
            available_keys = yield KeyScanner.scan_ssh_directory();
        } catch (KeyMakerError e) {
            warning("Failed to load SSH keys: %s", e.message);
        }
    }
    
    [GtkCallback]
    private void on_close_clicked () {
        close();
    }
    
    [GtkCallback]
    private void on_create_plan_clicked () {
        var editor_dialog = new RotationPlanEditorDialog();
        
        editor_dialog.plan_created.connect((plan) => {
            plan_manager.add_plan(plan);
        });
        
        editor_dialog.present(this);
    }
    
    [GtkCallback]
    private void on_execute_all_clicked () {
        var draft_plans = plan_manager.get_draft_plans();
        if (draft_plans.length == 0) {
            return;
        }
        
        plan_manager.execute_batch.begin(draft_plans, (obj, res) => {
            try {
                plan_manager.execute_batch.end(res);
            } catch (Error e) {
                warning("Batch execution failed: %s", e.message);
            }
        });
    }
    
    [GtkCallback]
    private void on_clear_history_clicked () {
        var historical_plans = plan_manager.get_historical_plans();
        for (int i = 0; i < historical_plans.length; i++) {
            plan_manager.remove_plan(historical_plans[i]);
        }
    }
    
    private static void save_plan_to_settings (string key_fingerprint, RotationPlan plan) {
        try {
            var current_variant = KeyMaker.SettingsManager.get_rotation_plans();
            var current_plans = new VariantBuilder (new VariantType ("aa{sv}"));
            
            // Copy existing plans (except the one we're updating)
            var n_plans = (int) current_variant.n_children ();
            for (int i = 0; i < n_plans; i++) {
                var existing_plan = current_variant.get_child_value (i);
                var existing_fingerprint = existing_plan.lookup_value ("key_fingerprint", VariantType.STRING)?.get_string ();
                
                if (existing_fingerprint != key_fingerprint) {
                    current_plans.add_value (existing_plan);
                }
            }
            
            // Add the updated plan
            var plan_dict = new VariantBuilder (new VariantType ("a{sv}"));
            plan_dict.add ("{sv}", "key_fingerprint", new Variant.string (key_fingerprint));
            
            // Create plan data
            var plan_data = new VariantBuilder (new VariantType ("a{sv}"));
            plan_data.add ("{sv}", "rotation_reason", new Variant.string (plan.rotation_reason));
            plan_data.add ("{sv}", "keep_old_key", new Variant.boolean (plan.keep_old_key));
            plan_data.add ("{sv}", "enable_rollback", new Variant.boolean (plan.enable_rollback));
            
            // Serialize targets
            var targets_builder = new VariantBuilder (new VariantType ("aa{sv}"));
            for (int j = 0; j < plan.targets.length; j++) {
                var target = plan.targets[j];
                var target_dict = new VariantBuilder (new VariantType ("a{sv}"));
                target_dict.add ("{sv}", "hostname", new Variant.string (target.hostname));
                target_dict.add ("{sv}", "username", new Variant.string (target.username));
                target_dict.add ("{sv}", "port", new Variant.int32 (target.port));
                if (target.proxy_jump != null) {
                    target_dict.add ("{sv}", "proxy_jump", new Variant.string (target.proxy_jump));
                }
                targets_builder.add_value (target_dict.end ());
            }
            plan_data.add ("{sv}", "targets", targets_builder.end ());
            
            plan_dict.add ("{sv}", "plan_data", plan_data.end ());
            current_plans.add_value (plan_dict.end ());
            
            KeyMaker.SettingsManager.set_rotation_plans(current_plans.end ());
        } catch (Error e) {
            warning ("Failed to save rotation plan: %s", e.message);
        }
    }
    
    private static RotationPlan? load_plan_from_settings (string key_fingerprint, SSHKey ssh_key) {
        try {
            var variant = KeyMaker.SettingsManager.get_rotation_plans();
            var n_plans = (int) variant.n_children ();
            
            for (int i = 0; i < n_plans; i++) {
                var plan_dict = variant.get_child_value (i);
                var stored_fingerprint = plan_dict.lookup_value ("key_fingerprint", VariantType.STRING)?.get_string ();
                
                if (stored_fingerprint == key_fingerprint) {
                    var plan_data = plan_dict.lookup_value ("plan_data", VariantType.VARDICT);
                    if (plan_data == null) continue;
                    
                    // Create new plan with the SSH key
                    var plan = new RotationPlan (ssh_key);
                    
                    // Restore settings
                    var reason = plan_data.lookup_value ("rotation_reason", VariantType.STRING);
                    if (reason != null) plan.rotation_reason = reason.get_string ();
                    
                    var keep_old = plan_data.lookup_value ("keep_old_key", VariantType.BOOLEAN);
                    if (keep_old != null) plan.keep_old_key = keep_old.get_boolean ();
                    
                    var enable_rollback = plan_data.lookup_value ("enable_rollback", VariantType.BOOLEAN);
                    if (enable_rollback != null) plan.enable_rollback = enable_rollback.get_boolean ();
                    
                    // Restore targets
                    var targets_variant = plan_data.lookup_value ("targets", new VariantType ("aa{sv}"));
                    if (targets_variant != null) {
                        var n_targets = (int) targets_variant.n_children ();
                        for (int j = 0; j < n_targets; j++) {
                            var target_dict = targets_variant.get_child_value (j);
                            var hostname = target_dict.lookup_value ("hostname", VariantType.STRING)?.get_string ();
                            var username = target_dict.lookup_value ("username", VariantType.STRING)?.get_string ();
                            
                            if (hostname != null && username != null) {
                                var port_variant = target_dict.lookup_value ("port", VariantType.INT32);
                                var port = port_variant != null ? port_variant.get_int32 () : 22;
                                
                                var target = new RotationTarget (hostname, username, port);
                                
                                var proxy_jump = target_dict.lookup_value ("proxy_jump", VariantType.STRING);
                                if (proxy_jump != null) {
                                    target.proxy_jump = proxy_jump.get_string ();
                                }
                                
                                plan.add_target (target);
                            }
                        }
                    }
                    
                    return plan;
                }
            }
        } catch (Error e) {
            warning ("Failed to load rotation plan from settings: %s", e.message);
        }
        
        return null;
    }
    
    private void setup_signals () {
        key_selection_row.notify["selected"].connect (on_key_selection_changed);
        start_rotation_button.clicked.connect (on_start_rotation);
        cancel_button.clicked.connect (on_cancel_clicked);
        add_target_button.clicked.connect (on_add_target);
        pause_button.clicked.connect (on_pause_rotation);
        abort_button.clicked.connect (on_abort_rotation);
        close_button.clicked.connect (on_close_clicked);
        
        // Rotation manager signals
        rotation_manager.rotation_started.connect (on_rotation_started);
        rotation_manager.rotation_stage_changed.connect (on_rotation_stage_changed);
        rotation_manager.rotation_progress.connect (on_rotation_progress);
        rotation_manager.rotation_completed.connect (on_rotation_completed);
        
        // Connect signals for plan settings persistence
        custom_reason_row.notify["text"].connect ((obj, pspec) => {
            if (current_plan != null && custom_reason_row.visible) {
                current_plan.rotation_reason = custom_reason_row.text.strip ();
                saved_plans.set (ssh_key.fingerprint, current_plan);
                save_plan_to_settings (ssh_key.fingerprint, current_plan);
            }
        });
        
        keep_old_key_row.notify["active"].connect ((obj, pspec) => {
            if (current_plan != null) {
                current_plan.keep_old_key = keep_old_key_row.active;
                saved_plans.set (ssh_key.fingerprint, current_plan);
                save_plan_to_settings (ssh_key.fingerprint, current_plan);
            }
        });
        
        enable_rollback_row.notify["active"].connect ((obj, pspec) => {
            if (current_plan != null) {
                current_plan.enable_rollback = enable_rollback_row.active;
                saved_plans.set (ssh_key.fingerprint, current_plan);
                save_plan_to_settings (ssh_key.fingerprint, current_plan);
            }
        });
        
        // Enable/disable start button based on targets
        update_start_button_state ();
    }
    
    private void setup_log_view () {
        log_buffer = log_view.buffer;
        log_view.editable = false;
        log_view.cursor_visible = false;
        
        // Add some styling
        var tag_table = log_buffer.get_tag_table ();
        var timestamp_tag = new Gtk.TextTag ("timestamp");
        timestamp_tag.foreground = "gray";
        tag_table.add (timestamp_tag);
    }
    
    private void setup_rotation_reasons () {
        // Set up preset rotation reasons
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
        
        // Handle reason selection changes
        reason_row.notify["selected"].connect (on_reason_selection_changed);
    }
    
    private void on_reason_selection_changed () {
        bool is_custom = reason_row.selected == 7; // "Custom reason" is the last item
        custom_reason_row.visible = is_custom;
        
        // Update the current plan with the selected reason
        if (current_plan != null) {
            if (is_custom) {
                current_plan.rotation_reason = custom_reason_row.text.strip ();
            } else if (reason_row.selected != Gtk.INVALID_LIST_POSITION) {
                var selected_text = ((Gtk.StringList) reason_row.model).get_string (reason_row.selected);
                current_plan.rotation_reason = selected_text;
            }
            
            // Save the plan
            saved_plans.set (ssh_key.fingerprint, current_plan);
            save_plan_to_settings (ssh_key.fingerprint, current_plan);
        }
    }
    
    private void create_initial_plan () {
        // First, load saved plans from settings if not already loaded
        load_saved_plans ();
        
        // Check if we have a saved plan for this key
        if (saved_plans.has_key (ssh_key.fingerprint)) {
            current_plan = saved_plans.get (ssh_key.fingerprint);
        } else {
            // Try to load from persistent storage
            current_plan = load_plan_from_settings (ssh_key.fingerprint, ssh_key);
            
            if (current_plan == null) {
                // Create new plan if no saved one exists
                current_plan = rotation_manager.create_rotation_plan (ssh_key, "Manual rotation");
            }
            
            // Store in memory cache
            saved_plans.set (ssh_key.fingerprint, current_plan);
        }
        
        // Find matching reason in the list and set it as selected
        var reason_list = (Gtk.StringList) reason_row.model;
        bool found = false;
        for (uint i = 0; i < reason_list.get_n_items (); i++) {
            var item = reason_list.get_string (i);
            if (item == current_plan.rotation_reason) {
                reason_row.selected = (int) i;
                found = true;
                break;
            }
        }
        
        // If not found in preset reasons, select "Custom reason" and set the text
        if (!found) {
            reason_row.selected = 7; // "Custom reason" position
            custom_reason_row.text = current_plan.rotation_reason;
        }
        keep_old_key_row.active = current_plan.keep_old_key;
        enable_rollback_row.active = current_plan.enable_rollback;
        
        populate_targets_list ();
    }
    
    private void populate_targets_list () {
        clear_targets_list ();
        
        if (current_plan == null) {
            targets_placeholder.visible = true;
            return;
        }
        
        bool has_targets = current_plan.targets.length > 0;
        targets_placeholder.visible = !has_targets;
        
        for (int i = 0; i < current_plan.targets.length; i++) {
            var target = current_plan.targets[i];
            add_target_row (target);
        }
        
        update_start_button_state ();
    }
    
    private void clear_targets_list () {
        Gtk.Widget? child = targets_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            // Don't remove the placeholder row
            if (child != targets_placeholder) {
                targets_list.remove (child);
            }
            child = next;
        }
    }
    
    private void add_target_row (RotationTarget target) {
        var row = new Adw.ActionRow ();
        row.title = target.get_display_name ();
        row.subtitle = @"Port: $(target.port)";
        
        // Add server icon
        var server_icon = new Gtk.Image ();
        server_icon.icon_name = "network-server-symbolic";
        row.add_prefix (server_icon);
        
        // Add remove button
        var remove_button = new Gtk.Button ();
        remove_button.icon_name = "user-trash-symbolic";
        remove_button.tooltip_text = "Remove Target";
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.add_css_class ("flat");
        remove_button.clicked.connect (() => {
            remove_target (target);
        });
        row.add_suffix (remove_button);
        
        targets_list.append (row);
    }
    
    private void remove_target (RotationTarget target) {
        if (current_plan == null) return;
        
        // Find and remove target
        for (int i = 0; i < current_plan.targets.length; i++) {
            if (current_plan.targets[i] == target) {
                current_plan.targets.remove_index (i);
                break;
            }
        }
        
        populate_targets_list ();
        
        // Update saved plan
        saved_plans.set (ssh_key.fingerprint, current_plan);
        save_plan_to_settings (ssh_key.fingerprint, current_plan);
    }
    
    private void load_recommendations () {
        var recommendations = rotation_manager.get_rotation_recommendations (ssh_key);
        
        if (recommendations.length > 0) {
            var rec_text = string.joinv ("\n• ", recommendations.data);
            current_plan.add_log_entry (@"Recommendations:\n• $(rec_text)");
        }
    }
    
    private void on_add_target () {
        // Create enhanced dialog with SSH config host selection
        var dialog = new Adw.Dialog ();
        dialog.title = _("Add Target Server");
        dialog.content_width = 600;
        dialog.content_height = 450;
        
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var header_bar = new Adw.HeaderBar ();
        header_bar.title_widget = new Adw.WindowTitle (_("Add Target Server"), _("Select from SSH config or enter manually"));
        content_box.append (header_bar);
        
        var clamp = new Adw.Clamp ();
        clamp.maximum_size = 600;
        clamp.tightening_threshold = 500;
        
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        main_box.margin_top = 24;
        main_box.margin_bottom = 24;
        main_box.margin_start = 24;
        main_box.margin_end = 24;
        
        // Selection method group
        var method_group = new Adw.PreferencesGroup ();
        method_group.title = _("Selection Method");
        
        var method_row = new Adw.ComboRow ();
        method_row.title = _("Target Source");
        method_row.subtitle = _("Choose from existing SSH config or enter manually");
        var method_list = new Gtk.StringList (null);
        method_list.append (_("SSH Config Host"));
        method_list.append (_("Manual Entry"));
        method_row.model = method_list;
        method_row.selected = 0; // Default to SSH config
        method_group.add (method_row);
        
        main_box.append (method_group);
        
        // SSH Config host selection group
        var config_group = new Adw.PreferencesGroup ();
        config_group.title = _("SSH Config Hosts");
        
        var host_row = new Adw.ComboRow ();
        host_row.title = _("Select Host");
        host_row.subtitle = _("Choose from your SSH configuration");
        
        // Load SSH config hosts
        var ssh_config = new SSHConfig ();
        ssh_config.load_config.begin ((obj, res) => {
            try {
                ssh_config.load_config.end (res);
                var hosts = ssh_config.get_hosts ();
                var host_list = new Gtk.StringList (null);
                
                if (hosts.length > 0) {
                    for (uint i = 0; i < hosts.length; i++) {
                        var host = hosts.get (i);
                        // Show just the host name for cleaner display
                        host_list.append (host.name);
                    }
                    host_row.model = host_list;
                } else {
                    host_list.append (_("No SSH config hosts found"));
                    host_row.model = host_list;
                    host_row.sensitive = false;
                }
            } catch (Error e) {
                warning ("Failed to load SSH config: %s", e.message);
                var error_list = new Gtk.StringList (null);
                error_list.append (_("Failed to load SSH config"));
                host_row.model = error_list;
                host_row.sensitive = false;
            }
        });
        
        config_group.add (host_row);
        main_box.append (config_group);
        
        // Manual entry group
        var manual_group = new Adw.PreferencesGroup ();
        manual_group.title = _("Manual Configuration");
        manual_group.visible = false; // Initially hidden
        
        var hostname_row = new Adw.EntryRow ();
        hostname_row.title = _("Hostname");
        hostname_row.text = "";
        manual_group.add (hostname_row);
        
        var port_row = new Adw.SpinRow.with_range (1, 65535, 1);
        port_row.title = _("Port");
        port_row.value = 22;
        manual_group.add (port_row);
        
        var username_row = new Adw.EntryRow ();
        username_row.title = _("Username");
        username_row.text = "";
        manual_group.add (username_row);
        
        main_box.append (manual_group);
        
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        button_box.halign = Gtk.Align.END;
        
        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        var add_button = new Gtk.Button.with_label (_("Add"));
        add_button.add_css_class ("suggested-action");
        
        button_box.append (cancel_button);
        button_box.append (add_button);
        main_box.append (button_box);
        
        clamp.child = main_box;
        content_box.append (clamp);
        dialog.child = content_box;
        
        // Update button sensitivity based on current mode
        void update_add_button_sensitivity () {
            if (method_row.selected == 0) {
                // SSH Config mode - button enabled if host is selected and sensitive
                add_button.sensitive = host_row.sensitive && host_row.selected != Gtk.INVALID_LIST_POSITION;
            } else {
                // Manual mode - button enabled if hostname and username are filled
                add_button.sensitive = hostname_row.text.strip ().length > 0 && 
                                     username_row.text.strip ().length > 0;
            }
        }
        
        // Method selection toggle logic
        method_row.notify["selected"].connect (() => {
            bool is_manual = method_row.selected == 1;
            config_group.visible = !is_manual;
            manual_group.visible = is_manual;
            update_add_button_sensitivity ();
        });
        
        // Connect signals
        cancel_button.clicked.connect (() => {
            dialog.close ();
        });
        
        add_button.clicked.connect (() => {
            string target_hostname = "";
            string target_username = "";
            int target_port = 22;
            
            if (method_row.selected == 0) {
                // SSH Config host selected
                if (host_row.sensitive && host_row.selected != Gtk.INVALID_LIST_POSITION) {
                    var hosts = ssh_config.get_hosts ();
                    if (host_row.selected < hosts.length) {
                        var selected_host = hosts.get (host_row.selected);
                        target_hostname = selected_host.hostname ?? selected_host.name;
                        target_username = selected_host.user ?? Environment.get_user_name ();
                        target_port = selected_host.port ?? 22;
                    }
                }
            } else {
                // Manual entry
                target_hostname = hostname_row.text.strip ();
                target_username = username_row.text.strip ();
                target_port = (int) port_row.value;
            }
            
            if (target_hostname.length > 0 && target_username.length > 0) {
                if (current_plan != null) {
                    var target = new RotationTarget (target_hostname, target_username);
                    if (target_port != 22) {
                        // Store port in target if not default (RotationTarget might need extension for port)
                        debug ("Target port: %d (not yet stored in RotationTarget)", target_port);
                    }
                    current_plan.add_target (target);
                    populate_targets_list ();
                    // Update saved plan
                    saved_plans.set (ssh_key.fingerprint, current_plan);
                    save_plan_to_settings (ssh_key.fingerprint, current_plan);
                }
                dialog.close ();
            }
        });
        
        // Connect change signals
        host_row.notify["selected"].connect (() => {
            update_add_button_sensitivity ();
        });
        hostname_row.notify["text"].connect (() => {
            update_add_button_sensitivity ();
        });
        username_row.notify["text"].connect (() => {
            update_add_button_sensitivity ();
        });
        
        update_add_button_sensitivity ();
        dialog.present (this);
    }
    
    private void update_start_button_state () {
        start_rotation_button.sensitive = (
            current_plan != null && 
            current_plan.targets.length > 0 && 
            !rotation_in_progress
        );
    }
    
    private async void load_ssh_keys_async () {
        try {
            var keys = yield KeyScanner.scan_ssh_directory ();
            available_keys.remove_range (0, available_keys.length);
            
            // Create string list for ComboRow
            var string_list = new Gtk.StringList (null);
            
            for (uint i = 0; i < keys.length; i++) {
                var key = keys.get (i);
                available_keys.add (key);
                
                // Format: "key_name (key_type)"
                var display_name = key.get_display_name ();
                var type_desc = key.get_type_description ();
                if (type_desc.length > 0) {
                    display_name += @" ($(type_desc))";
                }
                
                string_list.append (display_name);
            }
            
            key_selection_row.model = string_list;
            
            // If a key was pre-selected, select it in the combo
            if (ssh_key != null) {
                for (uint i = 0; i < available_keys.length; i++) {
                    var key = available_keys.get (i);
                    if (key.fingerprint == ssh_key.fingerprint) {
                        key_selection_row.selected = i;
                        break;
                    }
                }
            }
            
            // If no pre-selected key or we couldn't find it, create initial plan when a key is selected
            if (ssh_key == null || key_selection_row.selected == Gtk.INVALID_LIST_POSITION) {
                if (available_keys.length > 0) {
                    key_selection_row.selected = 0;
                    on_key_selection_changed ();
                }
            } else {
                create_initial_plan ();
                load_recommendations ();
            }
            
        } catch (Error e) {
            warning ("Failed to load SSH keys: %s", e.message);
        }
    }
    
    private void on_key_selection_changed () {
        var selected = key_selection_row.selected;
        if (selected != Gtk.INVALID_LIST_POSITION && selected < available_keys.length) {
            ssh_key = available_keys.get (selected);
            create_initial_plan ();
            load_recommendations ();
        } else {
            ssh_key = null;
            current_plan = null;
            update_start_button_state ();
        }
    }
    
    private async void on_start_rotation () {
        if (current_plan == null) return;
        
        // Update plan settings
        // Get rotation reason from ComboRow selection or custom input
        if (reason_row.selected == 7) {
            // Custom reason selected
            current_plan.rotation_reason = custom_reason_row.text.strip ();
        } else if (reason_row.selected != Gtk.INVALID_LIST_POSITION) {
            // Preset reason selected
            var selected_text = ((Gtk.StringList) reason_row.model).get_string (reason_row.selected);
            current_plan.rotation_reason = selected_text;
        }
        current_plan.keep_old_key = keep_old_key_row.active;
        current_plan.enable_rollback = enable_rollback_row.active;
        
        rotation_in_progress = true;
        main_stack.visible_child = progress_page;
        
        try {
            yield rotation_manager.execute_rotation_plan (current_plan);
        } catch (KeyMakerError e) {
            show_error ("Rotation failed", e.message);
        }
    }
    
    private void on_rotation_started (RotationPlan plan) {
        progress_bar.fraction = 0.0;
        current_stage_label.label = "Starting rotation...";
        progress_details.label = "Initializing key rotation process";
        
        append_log_entry ("Key rotation started");
    }
    
    private void on_rotation_stage_changed (RotationPlan plan, RotationStage stage) {
        current_stage_label.label = stage.to_string ();
        
        // Update progress based on stage
        double progress = 0.0;
        switch (stage) {
            case RotationStage.GENERATING_NEW_KEY:
                progress = 0.2;
                break;
            case RotationStage.BACKING_UP_OLD_KEY:
                progress = 0.3;
                break;
            case RotationStage.DEPLOYING_NEW_KEY:
                progress = 0.6;
                break;
            case RotationStage.VERIFYING_ACCESS:
                progress = 0.8;
                break;
            case RotationStage.REMOVING_OLD_KEY:
                progress = 0.9;
                break;
            case RotationStage.COMPLETED:
                progress = 1.0;
                break;
        }
        
        progress_bar.fraction = progress;
        append_log_entry (@"Stage: $(stage.to_string ())");
    }
    
    private void on_rotation_progress (RotationPlan plan, string message) {
        progress_details.label = message;
        append_log_entry (message);
    }
    
    private void on_rotation_completed (RotationPlan plan, bool success) {
        rotation_in_progress = false;
        
        if (success) {
            show_success_results (plan);
        } else {
            show_failure_results (plan);
        }
        
        main_stack.visible_child = results_page;
    }
    
    private void show_success_results (RotationPlan plan) {
        result_icon.icon_name = "emblem-ok-symbolic";
        result_icon.add_css_class ("success");
        result_title.label = "Rotation Successful";
        result_title.add_css_class ("success");
        
        var successful = plan.get_successful_deployments ();
        result_summary.label = @"Successfully rotated key to $(successful) of $(plan.targets.length) targets";
        
        populate_results_list (plan, true);
    }
    
    private void show_failure_results (RotationPlan plan) {
        result_icon.icon_name = "dialog-error-symbolic";
        result_icon.add_css_class ("error");
        result_title.label = "Rotation Failed";
        result_title.add_css_class ("error");
        
        var successful = plan.get_successful_deployments ();
        result_summary.label = @"Deployed to $(successful) of $(plan.targets.length) targets before failure";
        
        populate_results_list (plan, false);
    }
    
    private void populate_results_list (RotationPlan plan, bool success) {
        clear_results_list ();
        
        // Add overall result
        var overall_row = new Adw.ActionRow ();
        overall_row.title = success ? "Key Rotation Completed" : "Key Rotation Failed";
        overall_row.subtitle = @"Duration: $(format_duration (plan.started_at, plan.completed_at))";
        
        var overall_icon = new Gtk.Image ();
        overall_icon.icon_name = success ? "emblem-ok-symbolic" : "dialog-error-symbolic";
        overall_icon.add_css_class (success ? "success" : "error");
        overall_row.add_prefix (overall_icon);
        
        results_list.append (overall_row);
        
        // Add target results
        for (int i = 0; i < plan.targets.length; i++) {
            var target = plan.targets[i];
            add_target_result_row (target);
        }
        
        // Add new key info if generated
        if (plan.new_key != null) {
            var key_row = new Adw.ActionRow ();
            key_row.title = "New Key Generated";
            key_row.subtitle = plan.new_key.get_display_name ();
            
            var key_icon = new Gtk.Image ();
            key_icon.icon_name = "dialog-password-symbolic";
            key_row.add_prefix (key_icon);
            
            results_list.append (key_row);
        }
    }
    
    private void add_target_result_row (RotationTarget target) {
        var row = new Adw.ActionRow ();
        row.title = target.get_display_name ();
        
        var status_parts = new GenericArray<string> ();
        
        if (target.deployment_success) {
            status_parts.add ("Deployed");
            if (target.verification_success) {
                status_parts.add ("Verified");
            }
        }
        
        if (target.error_message.length > 0) {
            status_parts.add (@"Error: $(target.error_message)");
        }
        
        row.subtitle = string.joinv (" • ", status_parts.data);
        
        var icon = new Gtk.Image ();
        if (target.deployment_success && target.verification_success) {
            icon.icon_name = "emblem-ok-symbolic";
            icon.add_css_class ("success");
        } else if (target.deployment_success) {
            icon.icon_name = "emblem-important-symbolic";
            icon.add_css_class ("warning");
        } else {
            icon.icon_name = "dialog-error-symbolic";
            icon.add_css_class ("error");
        }
        
        row.add_prefix (icon);
        results_list.append (row);
    }
    
    private void clear_results_list () {
        Gtk.Widget? child = results_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            results_list.remove (child);
            child = next;
        }
    }
    
    private string format_duration (DateTime? start, DateTime? end) {
        if (start == null || end == null) {
            return "Unknown";
        }
        
        var duration = end.difference (start) / TimeSpan.SECOND;
        if (duration < 60) {
            return @"$(duration)s";
        } else if (duration < 3600) {
            return @"$(duration / 60)m $(duration % 60)s";
        } else {
            var hours = duration / 3600;
            var minutes = (duration % 3600) / 60;
            return @"$(hours)h $(minutes)m";
        }
    }
    
    private void append_log_entry (string message) {
        var timestamp = new DateTime.now_local ().format ("%H:%M:%S");
        var entry = @"[$(timestamp)] $(message)\n";
        
        Gtk.TextIter iter;
        log_buffer.get_end_iter (out iter);
        log_buffer.insert (ref iter, entry, -1);
        
        // Auto-scroll to bottom
        var mark = log_buffer.get_insert ();
        log_view.scroll_mark_onscreen (mark);
    }
    
    private void on_pause_rotation () {
        // Implementation for pausing rotation (if supported)
    }
    
    private void on_abort_rotation () {
        var dialog = new Adw.AlertDialog (
            "Abort Key Rotation?",
            "This will stop the rotation process and attempt to rollback any changes made so far."
        );
        
        dialog.add_response ("continue", "Continue");
        dialog.add_response ("abort", "Abort Rotation");
        dialog.set_response_appearance ("abort", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("continue");
        
        dialog.response.connect ((response) => {
            if (response == "abort") {
                // Implementation for aborting rotation
                rotation_in_progress = false;
                append_log_entry ("Rotation aborted by user");
            }
        });
        
        dialog.present (this);
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
    
    private void on_cancel_clicked () {
        if (rotation_in_progress) {
            on_abort_rotation ();
        } else {
            close ();
        }
    }
    
    private void on_close_clicked () {
        close ();
    }
}

public class KeyMaker.AddRotationTargetDialog : Adw.Dialog {
    private Adw.EntryRow hostname_row;
    private Adw.EntryRow username_row;
    private Adw.SpinRow port_row;
    private Adw.EntryRow proxy_jump_row;
    private Gtk.Button add_button;
    private Gtk.Button cancel_button;
    
    public signal void target_added (RotationTarget target);
    
    construct {
        title = "Add Rotation Target";
        create_ui ();
        setup_signals ();
        setup_defaults ();
    }
    
    private void create_ui () {
        
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        
        // Header bar
        var header_bar = new Adw.HeaderBar ();
        content_box.append (header_bar);
        
        // Content
        var clamp = new Adw.Clamp ();
        clamp.maximum_size = 600;
        clamp.tightening_threshold = 500;
        clamp.vexpand = true;
        
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        main_box.margin_top = 24;
        main_box.margin_bottom = 24;
        main_box.margin_start = 12;
        main_box.margin_end = 12;
        
        var group = new Adw.PreferencesGroup ();
        group.title = "Target Server";
        
        hostname_row = new Adw.EntryRow ();
        hostname_row.title = "Hostname";
        group.add (hostname_row);
        
        username_row = new Adw.EntryRow ();
        username_row.title = "Username";
        group.add (username_row);
        
        port_row = new Adw.SpinRow.with_range (1, 65535, 1);
        port_row.title = "Port";
        port_row.value = 22;
        group.add (port_row);
        
        proxy_jump_row = new Adw.EntryRow ();
        proxy_jump_row.title = "Proxy Jump (Optional)";
        group.add (proxy_jump_row);
        
        main_box.append (group);
        
        // Buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        button_box.halign = Gtk.Align.END;
        
        cancel_button = new Gtk.Button.with_label ("Cancel");
        add_button = new Gtk.Button.with_label ("Add Target");
        add_button.add_css_class ("suggested-action");
        
        button_box.append (cancel_button);
        button_box.append (add_button);
        main_box.append (button_box);
        
        clamp.child = main_box;
        content_box.append (clamp);
        
        set_child (content_box);
    }
    
    private void setup_signals () {
        add_button.clicked.connect (on_add_clicked);
        cancel_button.clicked.connect (on_cancel_clicked);
        
        hostname_row.notify["text"].connect (update_ui_state);
        username_row.notify["text"].connect (update_ui_state);
        
        port_row.set_range (1, 65535);
    }
    
    private void setup_defaults () {
        username_row.text = Environment.get_user_name ();
        port_row.value = 22;
        update_ui_state ();
    }
    
    private void update_ui_state () {
        var hostname = hostname_row.text.strip ();
        var username = username_row.text.strip ();
        
        add_button.sensitive = (hostname.length > 0 && username.length > 0);
    }
    
    private void on_add_clicked () {
        var hostname = hostname_row.text.strip ();
        var username = username_row.text.strip ();
        var port = (int) port_row.value;
        var proxy_jump = proxy_jump_row.text.strip ();
        
        if (hostname.length == 0 || username.length == 0) {
            return;
        }
        
        var target = new RotationTarget (hostname, username, port);
        if (proxy_jump.length > 0) {
            target.proxy_jump = proxy_jump;
        }
        
        target_added (target);
        close ();
    }
    
    private void on_cancel_clicked () {
        close ();
    }
}