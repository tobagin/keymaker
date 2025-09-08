/*
 * Key Maker - Rotation Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/rotation_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/rotation_page.ui")]
#endif
public class KeyMaker.RotationPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Button create_plan_button;
    [GtkChild]
    private unowned Adw.PreferencesGroup active_plans_group;
    [GtkChild]
    private unowned Adw.PreferencesGroup rollback_group;
    
    private GenericArray<RotationPlan> active_plans;
    private GenericArray<RollbackEntry> rollback_entries;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        active_plans = new GenericArray<RotationPlan> ();
        rollback_entries = new GenericArray<RollbackEntry> ();
        
        // Setup button signals
        create_plan_button.clicked.connect (on_create_plan_clicked);
        
        // Load rotation data
        refresh_rotation_data ();
    }
    
    private void on_create_plan_clicked () {
        var dialog = new KeyMaker.RotationPlanEditorDialog (get_root () as Gtk.Window);
        // TODO: Connect to plan_saved signal when available
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_plan_saved (RotationPlan plan) {
        // Add or update plan in the list
        bool found = false;
        for (int i = 0; i < active_plans.length; i++) {
            if (active_plans[i].rotation_id == plan.rotation_id) {
                active_plans[i] = plan;
                found = true;
                break;
            }
        }
        
        if (!found) {
            active_plans.add (plan);
        }
        
        refresh_active_plans_display ();
        show_toast_requested (_("Rotation plan '%s' saved successfully").printf (plan.name));
    }
    
    public void refresh_rotation_data () {
        refresh_active_plans_display ();
        refresh_rollback_display ();
    }
    
    private void refresh_active_plans_display () {
        // Clear current display
        var child = active_plans_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                active_plans_group.remove (child);
            }
            child = next;
        }
        
        // Load active plans from storage
        try {
            // This would normally load from a rotation plan manager
            // For now, we'll show placeholder content
            
            if (active_plans.length == 0) {
                var placeholder_row = new Adw.ActionRow ();
                placeholder_row.title = _("No active rotation plans");
                placeholder_row.subtitle = _("Create your first rotation plan to automate key management");
                placeholder_row.sensitive = false;
                
                var prefix_icon = new Gtk.Image ();
                prefix_icon.icon_name = "view-refresh-symbolic";
                prefix_icon.icon_size = Gtk.IconSize.LARGE;
                placeholder_row.add_prefix (prefix_icon);
                
                active_plans_group.add (placeholder_row);
            } else {
                for (int i = 0; i < active_plans.length; i++) {
                    var plan = active_plans[i];
                    var row = create_rotation_plan_row (plan);
                    active_plans_group.add (row);
                }
            }
            
        } catch (Error e) {
            warning ("Failed to load rotation plans: %s", e.message);
            show_toast_requested (_("Failed to load rotation plans: %s").printf (e.message));
        }
    }
    
    private void refresh_rollback_display () {
        // Clear current display
        var child = rollback_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                rollback_group.remove (child);
            }
            child = next;
        }
        
        // Load rollback entries from storage
        try {
            // This would normally load from a rollback manager
            // For now, we'll show placeholder content
            
            if (rollback_entries.length == 0) {
                var placeholder_row = new Adw.ActionRow ();
                placeholder_row.title = _("No rollback entries available");
                placeholder_row.subtitle = _("Rollback options will appear here after rotations");
                placeholder_row.sensitive = false;
                
                var prefix_icon = new Gtk.Image ();
                prefix_icon.icon_name = "io.github.tobagin.keysmith-backup-center-symbolic";
                prefix_icon.icon_size = Gtk.IconSize.LARGE;
                placeholder_row.add_prefix (prefix_icon);
                
                rollback_group.add (placeholder_row);
            } else {
                for (int i = 0; i < rollback_entries.length; i++) {
                    var entry = rollback_entries[i];
                    var row = create_rollback_row (entry);
                    rollback_group.add (row);
                }
            }
            
        } catch (Error e) {
            warning ("Failed to load rollback entries: %s", e.message);
            show_toast_requested (_("Failed to load rollback entries: %s").printf (e.message));
        }
    }
    
    private Adw.ActionRow create_rotation_plan_row (RotationPlan plan) {
        var row = new Adw.ActionRow ();
        row.title = plan.name;
        row.subtitle = @"$(plan.targets.length) targets • Status: $(plan.status)";
        
        // Add prefix icon
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = "view-refresh-symbolic";
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add status indicator
        var status_indicator = new Gtk.Label ("");
        status_indicator.label = plan.status.to_string ();
        switch (plan.status) {
            case RotationPlanStatus.RUNNING:
                status_indicator.add_css_class ("success");
                break;
            case RotationPlanStatus.SCHEDULED:
                status_indicator.add_css_class ("warning");
                break;
            case RotationPlanStatus.COMPLETED:
                status_indicator.add_css_class ("success");
                break;
            case RotationPlanStatus.FAILED:
                status_indicator.add_css_class ("error");
                break;
            default:
                status_indicator.add_css_class ("dim-label");
                break;
        }
        status_indicator.add_css_class ("caption");
        row.add_suffix (status_indicator);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.add_css_class ("linked");
        
        var execute_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
        execute_button.tooltip_text = _("Execute Rotation");
        execute_button.add_css_class ("flat");
        execute_button.add_css_class ("suggested-action");
        execute_button.clicked.connect (() => on_execute_plan_clicked (plan));
        
        var edit_button = new Gtk.Button.from_icon_name ("document-edit-symbolic");
        edit_button.tooltip_text = _("Edit Plan");
        edit_button.add_css_class ("flat");
        edit_button.clicked.connect (() => on_edit_plan_clicked (plan));
        
        var delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
        delete_button.tooltip_text = _("Delete Plan");
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.clicked.connect (() => on_delete_plan_clicked (plan));
        
        button_box.append (execute_button);
        button_box.append (edit_button);
        button_box.append (delete_button);
        row.add_suffix (button_box);
        
        return row;
    }
    
    private Adw.ActionRow create_rollback_row (RollbackEntry entry) {
        var row = new Adw.ActionRow ();
        row.title = @"Rollback: $(entry.plan_name)";
        row.subtitle = @"Executed: $(entry.executed_at.format ("%x %X")) • Valid until: $(entry.expiry_date.format ("%x"))";
        
        // Add prefix icon
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = "io.github.tobagin.keysmith-backup-center-symbolic";
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.add_css_class ("linked");
        
        var rollback_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic");
        rollback_button.tooltip_text = _("Execute Rollback");
        rollback_button.add_css_class ("flat");
        rollback_button.add_css_class ("destructive-action");
        rollback_button.clicked.connect (() => on_execute_rollback_clicked (entry));
        
        var details_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
        details_button.tooltip_text = _("View Details");
        details_button.add_css_class ("flat");
        details_button.clicked.connect (() => on_rollback_details_clicked (entry));
        
        button_box.append (rollback_button);
        button_box.append (details_button);
        row.add_suffix (button_box);
        
        return row;
    }
    
    private void on_execute_plan_clicked (RotationPlan plan) {
        var dialog = new KeyMaker.KeyRotationDialog (get_root () as Gtk.Window);
        dialog.present (get_root () as Gtk.Window);
        show_toast_requested (_("Executing rotation plan '%s'").printf (plan.name));
    }
    
    private void on_edit_plan_clicked (RotationPlan plan) {
        var dialog = new KeyMaker.RotationPlanEditorDialog (get_root () as Gtk.Window);
        // TODO: Connect to plan_saved signal when available
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_delete_plan_clicked (RotationPlan plan) {
        // Remove from local list
        for (int i = 0; i < active_plans.length; i++) {
            if (active_plans[i].rotation_id == plan.rotation_id) {
                active_plans.remove_index (i);
                break;
            }
        }
        
        refresh_active_plans_display ();
        show_toast_requested (_("Rotation plan '%s' deleted successfully").printf (plan.name));
    }
    
    private void on_execute_rollback_clicked (RollbackEntry entry) {
        // This would execute the rollback operation
        show_toast_requested (_("Rollback functionality not yet implemented"));
    }
    
    private void on_rollback_details_clicked (RollbackEntry entry) {
        // This would show rollback details
        show_toast_requested (_("Rollback details not yet implemented"));
    }
}