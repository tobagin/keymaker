/*
 * Key Maker - Key Rotation Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Gee;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_rotation_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_rotation_dialog.ui")]
#endif
public class KeyMaker.KeyRotationDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Gtk.Box planning_page;
    
    [GtkChild]
    private unowned Adw.EntryRow reason_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow keep_old_key_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow enable_rollback_row;
    
    [GtkChild]
    private unowned Gtk.ListBox targets_list;
    
    [GtkChild]
    private unowned Gtk.Button add_target_button;
    
    [GtkChild]
    private unowned Gtk.Button start_rotation_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    [GtkChild]
    private unowned Gtk.Box progress_page;
    
    [GtkChild]
    private unowned Gtk.ProgressBar progress_bar;
    
    [GtkChild]
    private unowned Gtk.Label current_stage_label;
    
    [GtkChild]
    private unowned Gtk.Label progress_details;
    
    [GtkChild]
    private unowned Gtk.ScrolledWindow log_scroll;
    
    [GtkChild]
    private unowned Gtk.TextView log_view;
    
    [GtkChild]
    private unowned Gtk.Button pause_button;
    
    [GtkChild]
    private unowned Gtk.Button abort_button;
    
    [GtkChild]
    private unowned Gtk.Box results_page;
    
    [GtkChild]
    private unowned Gtk.Image result_icon;
    
    [GtkChild]
    private unowned Gtk.Label result_title;
    
    [GtkChild]
    private unowned Gtk.Label result_summary;
    
    [GtkChild]
    private unowned Gtk.ListBox results_list;
    
    [GtkChild]
    private unowned Gtk.Button close_button;
    
    public SSHKey ssh_key { get; construct; }
    
    private KeyRotationManager rotation_manager;
    private RotationPlan? current_plan = null;
    private Gtk.TextBuffer log_buffer;
    private bool rotation_in_progress = false;
    
    // Static storage for rotation plans per key to persist across dialog sessions
    private static HashMap<string, RotationPlan> saved_plans = new HashMap<string, RotationPlan> ();
    private static GLib.Settings settings = new GLib.Settings (Config.APP_ID);
    
    public KeyRotationDialog (Gtk.Window parent, SSHKey key) {
        Object (
            ssh_key: key
        );
    }
    
    construct {
        rotation_manager = new KeyRotationManager ();
        
        setup_signals ();
        setup_log_view ();
        create_initial_plan ();
        load_recommendations ();
        
        main_stack.visible_child = planning_page;
    }
    
    private static void load_saved_plans () {
        if (saved_plans.size > 0) return; // Already loaded
        
        try {
            var variant = settings.get_value ("rotation-plans");
            var n_plans = (int) variant.n_children ();
            
            for (int i = 0; i < n_plans; i++) {
                var plan_dict = variant.get_child_value (i);
                var key_fingerprint = plan_dict.lookup_value ("key_fingerprint", VariantType.STRING)?.get_string ();
                
                if (key_fingerprint != null) {
                    var plan_data = plan_dict.lookup_value ("plan_data", VariantType.VARDICT);
                    if (plan_data != null) {
                        // For now, just mark that we found saved data for this key
                        // The actual plan will be reconstructed when needed
                        debug ("Found saved rotation plan data for key: %s", key_fingerprint);
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to load saved rotation plans: %s", e.message);
        }
    }
    
    private static void save_plan_to_settings (string key_fingerprint, RotationPlan plan) {
        try {
            var current_variant = settings.get_value ("rotation-plans");
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
            
            settings.set_value ("rotation-plans", current_plans.end ());
        } catch (Error e) {
            warning ("Failed to save rotation plan: %s", e.message);
        }
    }
    
    private static RotationPlan? load_plan_from_settings (string key_fingerprint, SSHKey ssh_key) {
        try {
            var variant = settings.get_value ("rotation-plans");
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
        reason_row.notify["text"].connect ((obj, pspec) => {
            if (current_plan != null) {
                current_plan.rotation_reason = reason_row.text.strip ();
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
        
        reason_row.text = current_plan.rotation_reason;
        keep_old_key_row.active = current_plan.keep_old_key;
        enable_rollback_row.active = current_plan.enable_rollback;
        
        populate_targets_list ();
    }
    
    private void populate_targets_list () {
        clear_targets_list ();
        
        if (current_plan == null) return;
        
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
            targets_list.remove (child);
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
        // Create a dialog with input fields
        var dialog = new Adw.Dialog ();
        dialog.title = _("Add Target Server");
        dialog.content_width = 400;
        dialog.content_height = 250;
        
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var header_bar = new Adw.HeaderBar ();
        header_bar.title_widget = new Adw.WindowTitle (_("Add Target Server"), _("Enter connection details"));
        content_box.append (header_bar);
        
        var clamp = new Adw.Clamp ();
        clamp.maximum_size = 400;
        clamp.tightening_threshold = 300;
        
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        main_box.margin_top = 24;
        main_box.margin_bottom = 24;
        main_box.margin_start = 24;
        main_box.margin_end = 24;
        
        var form_group = new Adw.PreferencesGroup ();
        
        var hostname_row = new Adw.EntryRow ();
        hostname_row.title = _("Hostname");
        hostname_row.text = "";
        form_group.add (hostname_row);
        
        var username_row = new Adw.EntryRow ();
        username_row.title = _("Username");
        username_row.text = "";
        form_group.add (username_row);
        
        main_box.append (form_group);
        
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
        
        // Connect signals
        cancel_button.clicked.connect (() => {
            dialog.close ();
        });
        
        add_button.clicked.connect (() => {
            var hostname = hostname_row.text.strip ();
            var username = username_row.text.strip ();
            
            if (hostname.length > 0 && username.length > 0) {
                if (current_plan != null) {
                    var target = new RotationTarget (hostname, username);
                    current_plan.add_target (target);
                    populate_targets_list ();
                    // Update saved plan
                    saved_plans.set (ssh_key.fingerprint, current_plan);
                    save_plan_to_settings (ssh_key.fingerprint, current_plan);
                }
                dialog.close ();
            }
        });
        
        // Enable add button only when both fields have text
        void update_add_button_sensitivity () {
            add_button.sensitive = hostname_row.text.strip ().length > 0 && 
                                 username_row.text.strip ().length > 0;
        }
        
        hostname_row.notify["text"].connect ((obj, pspec) => {
            update_add_button_sensitivity ();
        });
        username_row.notify["text"].connect ((obj, pspec) => {
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
    
    private async void on_start_rotation () {
        if (current_plan == null) return;
        
        // Update plan settings
        current_plan.rotation_reason = reason_row.text.strip ();
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