/*
 * SSHer - Rotation Page
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
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/rotation_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/rotation_page.ui")]
#endif
public class KeyMaker.RotationPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Box child_box;
    [GtkChild]
    private unowned Gtk.Button create_plan_button;
    [GtkChild]
    private unowned Gtk.Button execute_all_button;
    [GtkChild]
    private unowned Gtk.Button refresh_plans_button;
    [GtkChild]
    private unowned Gtk.Button remove_all_plans_button;
    
    // Draft Plans Section
    [GtkChild]
    private unowned Adw.PreferencesGroup draft_plans_group;
    [GtkChild]
    private unowned Gtk.ListBox draft_plans_list;
    [GtkChild]
    private unowned Adw.ActionRow draft_placeholder;
    
    // Running Plans Section  
    [GtkChild]
    private unowned Adw.PreferencesGroup running_plans_group;
    [GtkChild]
    private unowned Gtk.ListBox running_plans_list;
    [GtkChild]
    private unowned Adw.ActionRow running_placeholder;
    
    // History Section
    [GtkChild]
    private unowned Adw.PreferencesGroup history_group;
    [GtkChild]
    private unowned Gtk.Button refresh_history_button;
    [GtkChild]
    private unowned Gtk.Button clear_history_button;
    [GtkChild]
    private unowned Gtk.ListBox history_list;
    [GtkChild]
    private unowned Adw.ActionRow history_placeholder;
    
    private RotationPlanManager plan_manager;
    private GenericArray<SSHKey> available_keys;
    private RotationPlanActions? plan_actions;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        plan_manager = new RotationPlanManager();
        available_keys = new GenericArray<SSHKey>();
    }
    
    public override void constructed () {
        base.constructed();
        
        setup_signals();
        load_available_keys.begin();
        refresh_all_lists();
    }
    
    private RotationPlanActions get_plan_actions() {
        if (plan_actions == null) {
            var window = get_root() as Gtk.Window;
            if (window == null) {
                // Fallback: find the window in the widget hierarchy
                var widget = this as Gtk.Widget;
                while (widget != null && !(widget is Gtk.Window)) {
                    widget = widget.get_parent();
                }
                window = widget as Gtk.Window;
            }
            plan_actions = new RotationPlanActions(plan_manager, window);
            
            // Set up plan actions signals now that it's created
            plan_actions.show_toast.connect(show_toast);
            plan_actions.plans_changed.connect(refresh_all_lists);
        }
        return plan_actions;
    }
    
    private void setup_signals () {
        // Plan manager signals
        plan_manager.plan_added.connect(on_plan_added);
        plan_manager.plan_updated.connect(on_plan_updated);
        plan_manager.plan_removed.connect(on_plan_removed);
        plan_manager.plan_status_changed.connect(on_plan_status_changed);
        plan_manager.execution_started.connect(on_execution_started);
        plan_manager.execution_completed.connect(on_execution_completed);
        plan_manager.batch_execution_started.connect(on_batch_execution_started);
        plan_manager.batch_execution_completed.connect(on_batch_execution_completed);
        plan_manager.plans_loaded.connect(on_plans_loaded);
    }
    
    private async void load_available_keys () {
        try {
            available_keys = yield KeyScanner.scan_ssh_directory();
        } catch (KeyMakerError e) {
            warning("Failed to load SSH keys: %s", e.message);
        }
    }
    
    [GtkCallback]
    private void on_create_plan_clicked () {
        get_plan_actions().create_new_plan();
    }
    
    [GtkCallback]
    private void on_execute_all_clicked () {
        get_plan_actions().execute_all_draft_plans();
    }
    
    [GtkCallback]
    private void on_refresh_plans_clicked () {
        refresh_all_lists();
    }
    
    [GtkCallback]
    private void on_remove_all_plans_clicked () {
        get_plan_actions().remove_all_draft_plans();
    }
    
    [GtkCallback]
    private void on_refresh_history_clicked () {
        refresh_history();
    }
    
    [GtkCallback]
    private void on_clear_history_clicked () {
        get_plan_actions().clear_history();
    }
    
    private void refresh_all_lists () {
        refresh_draft_plans();
        refresh_running_plans();
        refresh_history();
        update_execute_all_button();
    }
    
    private void refresh_draft_plans () {
        clear_list_except_placeholder(draft_plans_list, draft_placeholder);
        
        var draft_plans = plan_manager.get_draft_plans();
        draft_placeholder.visible = draft_plans.length == 0;
        
        for (int i = 0; i < draft_plans.length; i++) {
            var plan = draft_plans[i];
            add_draft_plan_row(plan);
        }
    }
    
    private void refresh_running_plans () {
        clear_list_except_placeholder(running_plans_list, running_placeholder);
        
        var running_plans = plan_manager.get_running_plans();
        running_placeholder.visible = running_plans.length == 0;
        
        for (int i = 0; i < running_plans.length; i++) {
            var plan = running_plans[i];
            add_running_plan_row(plan);
        }
    }
    
    private void refresh_history () {
        clear_list_except_placeholder(history_list, history_placeholder);
        
        var historical_plans = plan_manager.get_historical_plans();
        history_placeholder.visible = historical_plans.length == 0;
        
        for (int i = 0; i < historical_plans.length; i++) {
            var plan = historical_plans[i];
            add_history_plan_row(plan);
        }
    }
    
    private void clear_list_except_placeholder (Gtk.ListBox list, Gtk.Widget placeholder) {
        Gtk.Widget? child = list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            if (child != placeholder) {
                list.remove(child);
            }
            child = next;
        }
    }
    
    private void add_draft_plan_row (RotationPlan plan) {
        var row = new DraftPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            get_plan_actions().handle_plan_action(plan, action);
        });
        draft_plans_list.append(row);
    }
    
    private void add_running_plan_row (RotationPlan plan) {
        var row = new RunningPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            get_plan_actions().handle_plan_action(plan, action);
        });
        running_plans_list.append(row);
    }
    
    private void add_history_plan_row (RotationPlan plan) {
        var row = new HistoryPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            get_plan_actions().handle_plan_action(plan, action);
        });
        history_list.append(row);
    }
    
    private void update_execute_all_button () {
        var draft_plans = plan_manager.get_draft_plans();
        execute_all_button.sensitive = draft_plans.length > 0;
    }
    
    private void show_toast (string message) {
        show_toast_requested(message);
    }
    
    private void on_plan_added (RotationPlan plan) {
        refresh_all_lists();
        //show_toast(_("Plan '%s' added").printf(plan.name));
    }
    
    private void on_plan_updated (RotationPlan plan) {
        refresh_all_lists();
    }
    
    private void on_plan_removed (RotationPlan plan) {
        refresh_all_lists();
    }
    
    private void on_plan_status_changed (RotationPlan plan, RotationPlanStatus old_status) {
        refresh_all_lists();
    }
    
    private void on_execution_started (RotationPlan plan) {
        refresh_all_lists();
        show_toast(_("Executing plan '%s'").printf(plan.name));
    }
    
    private void on_execution_completed (RotationPlan plan, bool success) {
        refresh_all_lists();
        if (success) {
            show_toast(_("Plan '%s' completed successfully").printf(plan.name));
        } else {
            show_toast(_("Plan '%s' execution failed").printf(plan.name));
        }
    }
    
    private void on_batch_execution_started (GenericArray<RotationPlan> plans) {
        show_toast(_("Executing %u plans").printf(plans.length));
    }
    
    private void on_batch_execution_completed (int successful, int failed) {
        refresh_all_lists();
        if (failed == 0) {
            show_toast(_("All %d plans completed successfully").printf(successful));
        } else {
            show_toast(_("%d plans completed, %d failed").printf(successful, failed));
        }
    }
    
    private void on_plans_loaded () {
        refresh_all_lists();
    }
}