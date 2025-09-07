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
    private unowned Gtk.Button create_plan_button;
    [GtkChild]
    private unowned Gtk.Button execute_all_button;
    [GtkChild]
    private unowned Adw.ViewStack main_stack;
    [GtkChild]
    private unowned Adw.ViewSwitcherBar view_switcher_bar;
    
    // Status tab widgets
    [GtkChild]
    private unowned Adw.StatusPage rotation_status_page;
    [GtkChild]
    private unowned Gtk.Button create_plan_status_button;
    
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
    private RotationPlanActions plan_actions;
    
    public KeyRotationDialog (Gtk.Window? parent = null) {
        plan_manager = new RotationPlanManager();
        available_keys = new GenericArray<SSHKey>();
        plan_actions = new RotationPlanActions(plan_manager, parent != null ? parent : (Gtk.Window)this);
        
        setup_signals();
        setup_rollback_settings();
        setup_status_page();
        load_available_keys.begin();
        refresh_all_lists();
    }
    
    private void setup_signals () {
        // Note: Button signal connections are handled by Blueprint callbacks
        
        // Plan actions signals
        plan_actions.show_toast.connect(show_toast);
        plan_actions.plans_changed.connect(refresh_all_lists);
        
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
        
        // Initial button state update
        update_execute_all_button();
    }
    
    private void setup_rollback_settings () {
        var period_list = new Gtk.StringList(null);
        period_list.append(_("1 Week"));
        period_list.append(_("1 Fortnight"));
        period_list.append(_("1 Month"));
        
        default_rollback_period_row.model = period_list;
        default_rollback_period_row.selected = 0; // Default to 1 week
    }
    
    private void setup_status_page () {
        // Setup status button signal  
        create_plan_status_button.clicked.connect (() => {
            main_stack.set_visible_child_name ("plans");
            on_create_plan_clicked ();
        });
    }
    
    private void update_status_page () {
        // Status page is static - no dynamic updates needed
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
        plan_actions.create_new_plan();
    }
    
    [GtkCallback]
    private void on_execute_all_clicked () {
        plan_actions.execute_all_draft_plans();
    }
    
    [GtkCallback]
    private void on_clear_history_clicked () {
        plan_actions.clear_history();
    }
    
    private void refresh_all_lists () {
        update_status_page();
        refresh_draft_plans();
        refresh_running_plans();
        refresh_rollback_plans();
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
    
    private void refresh_rollback_plans () {
        clear_list_except_placeholder(rollback_plans_list, rollback_placeholder);
        
        var rollback_plans = plan_manager.get_rollback_available_plans();
        rollback_placeholder.visible = rollback_plans.length == 0;
        
        for (int i = 0; i < rollback_plans.length; i++) {
            var plan = rollback_plans[i];
            add_rollback_plan_row(plan);
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
            plan_actions.handle_plan_action(plan, action);
        });
        draft_plans_list.append(row);
    }
    
    private void add_running_plan_row (RotationPlan plan) {
        var row = new RunningPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            plan_actions.handle_plan_action(plan, action);
        });
        running_plans_list.append(row);
    }
    
    private void add_rollback_plan_row (RotationPlan plan) {
        var row = new RollbackPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            plan_actions.handle_plan_action(plan, action);
        });
        rollback_plans_list.append(row);
    }
    
    private void add_history_plan_row (RotationPlan plan) {
        var row = new HistoryPlanRow(plan);
        row.plan_action_requested.connect((action) => {
            plan_actions.handle_plan_action(plan, action);
        });
        history_list.append(row);
    }
    
    
    private void update_execute_all_button () {
        var draft_plans = plan_manager.get_draft_plans();
        int executable_count = 0;
        
        for (int i = 0; i < draft_plans.length; i++) {
            if (draft_plans[i].can_execute()) {
                executable_count++;
            }
        }
        
        execute_all_button.sensitive = executable_count > 0;
        execute_all_button.tooltip_text = _("Execute all");
    }
    
    private void show_toast (string message, bool is_error = false) {
        if (is_error) {
            warning("Rotation Manager: %s", message);
        } else {
            debug("Rotation Manager: %s", message);
        }
    }
    
    // Signal handlers for plan manager events
    
    private void on_plan_added (RotationPlan plan) {
        refresh_draft_plans();
        update_execute_all_button();
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
        refresh_running_plans();
        refresh_draft_plans();
    }
    
    private void on_execution_completed (RotationPlan plan, bool success) {
        refresh_all_lists();
        
        if (success) {
            show_toast(@"Plan '$(plan.name)' completed successfully");
        } else {
            show_toast(@"Plan '$(plan.name)' failed", true);
        }
    }
    
    private void on_batch_execution_started (GenericArray<RotationPlan> plans) {
        show_toast(@"Starting batch execution of $(plans.length) plans");
    }
    
    private void on_batch_execution_completed (int successful, int failed) {
        string message = @"Batch execution completed: $(successful) successful, $(failed) failed";
        if (failed > 0) {
            show_toast(message, true);
        } else {
            show_toast(message);
        }
    }
    
    private void on_plans_loaded () {
        refresh_all_lists();
    }
}