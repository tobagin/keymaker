/*
 * SSHer - Rotation Plan Actions Handler
 * 
 * Handles all plan-related actions (edit, execute, rollback, etc.)
 */

namespace KeyMaker {
    
    public class RotationPlanActions : GLib.Object {
        
        public signal void show_toast (string message, bool is_error = false);
        public signal void plans_changed ();
        
        private RotationPlanManager plan_manager;
        private Gtk.Window parent_window;
        
        public RotationPlanActions (RotationPlanManager manager, Gtk.Window parent) {
            plan_manager = manager;
            parent_window = parent;
        }
        
        /**
         * Handle a plan action from a row widget
         */
        public void handle_plan_action (RotationPlan plan, string action) {
            switch (action) {
                case "edit":
                    edit_plan(plan);
                    break;
                    
                case "duplicate":
                    duplicate_plan(plan);
                    break;
                    
                case "execute":
                    execute_plan(plan);
                    break;
                    
                case "delete":
                    delete_plan(plan);
                    break;
                    
                case "cancel":
                    cancel_plan(plan);
                    break;
                    
                case "rollback":
                    rollback_plan(plan);
                    break;
                    
                case "view-details":
                    show_plan_details(plan);
                    break;
                    
                default:
                    warning("Unknown plan action: %s", action);
                    break;
            }
        }
        
        /**
         * Create a new plan
         */
        public void create_new_plan () {
            var editor_dialog = new RotationPlanEditorDialog();
            
            editor_dialog.plan_created.connect((plan) => {
                plan_manager.add_plan(plan);
                show_toast(@"Plan '$(plan.name)' created");
                plans_changed();
            });
            
            editor_dialog.present(parent_window);
        }
        
        /**
         * Execute multiple plans in batch
         */
        public void execute_all_draft_plans () {
            var draft_plans = plan_manager.get_draft_plans();
            var executable_plans = new GenericArray<RotationPlan>();
            
            for (int i = 0; i < draft_plans.length; i++) {
                if (draft_plans[i].can_execute()) {
                    executable_plans.add(draft_plans[i]);
                }
            }
            
            if (executable_plans.length == 0) {
                show_toast("No executable plans available", true);
                return;
            }
            
            // Show confirmation dialog
            var dialog = new Adw.AlertDialog(
                @"Execute $(executable_plans.length) Plans?",
                @"This will start executing $(executable_plans.length) rotation plan$(executable_plans.length > 1 ? "s" : "") sequentially."
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("execute", _("Execute All"));
            dialog.set_response_appearance("execute", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "execute") {
                    plan_manager.execute_batch.begin(executable_plans, (obj, res) => {
                        try {
                            plan_manager.execute_batch.end(res);
                        } catch (Error e) {
                            show_toast(@"Batch execution failed: $(e.message)", true);
                        }
                    });
                }
            });
            
            dialog.present(parent_window);
        }
        
        /**
         * Remove all draft plans
         */
        public void remove_all_draft_plans () {
            var draft_plans = plan_manager.get_draft_plans();
            if (draft_plans.length == 0) {
                show_toast("No draft plans to remove");
                return;
            }
            
            var dialog = new Adw.AlertDialog(
                @"Remove $(draft_plans.length) Draft Plans?",
                "This will permanently remove all draft plans. This action cannot be undone."
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("remove", _("Remove All"));
            dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "remove") {
                    for (int i = 0; i < draft_plans.length; i++) {
                        plan_manager.remove_plan(draft_plans[i]);
                    }
                    show_toast(@"Removed $(draft_plans.length) draft plans");
                    plans_changed();
                }
            });
            
            dialog.present(parent_window);
        }
        
        /**
         * Clear all historical plans
         */
        public void clear_history () {
            var historical_plans = plan_manager.get_historical_plans();
            if (historical_plans.length == 0) {
                show_toast("No history to clear");
                return;
            }
            
            var dialog = new Adw.AlertDialog(
                @"Clear $(historical_plans.length) Historical Plans?",
                "This will permanently remove all completed, failed, and rolled-back plans from the history."
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("clear", _("Clear History"));
            dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "clear") {
                    for (int i = 0; i < historical_plans.length; i++) {
                        plan_manager.remove_plan(historical_plans[i]);
                    }
                    show_toast(@"Cleared $(historical_plans.length) historical plans");
                    plans_changed();
                }
            });
            
            dialog.present(parent_window);
        }
        
        private void edit_plan (RotationPlan plan) {
            var editor_dialog = new RotationPlanEditorDialog.edit_plan(plan);
            
            editor_dialog.plan_updated.connect((updated_plan) => {
                plan_manager.update_plan(updated_plan);
                show_toast(@"Plan '$(updated_plan.name)' updated");
                plans_changed();
            });
            
            editor_dialog.present(parent_window);
        }
        
        private void duplicate_plan (RotationPlan plan) {
            var duplicate = plan_manager.duplicate_plan(plan);
            show_toast(@"Plan duplicated as '$(duplicate.name)'");
            plans_changed();
        }
        
        private void execute_plan (RotationPlan plan) {
            if (!plan.can_execute()) {
                show_toast(@"Plan '$(plan.name)' cannot be executed", true);
                return;
            }
            
            plan_manager.execute_plan.begin(plan, (obj, res) => {
                try {
                    plan_manager.execute_plan.end(res);
                } catch (Error e) {
                    show_toast(@"Execution failed: $(e.message)", true);
                }
            });
        }
        
        private void delete_plan (RotationPlan plan) {
            var dialog = new Adw.AlertDialog(
                @"Delete Plan '$(plan.name)'?",
                "This action cannot be undone."
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("delete", _("Delete"));
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "delete") {
                    plan_manager.remove_plan(plan);
                    show_toast(@"Plan '$(plan.name)' deleted");
                    plans_changed();
                }
            });
            
            dialog.present(parent_window);
        }
        
        private void cancel_plan (RotationPlan plan) {
            var dialog = new Adw.AlertDialog(
                @"Cancel Plan '$(plan.name)'?",
                "This will stop the current execution and may leave the rotation in an incomplete state."
            );
            
            dialog.add_response("continue", _("Continue"));
            dialog.add_response("cancel", _("Cancel Execution"));
            dialog.set_response_appearance("cancel", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("continue");
            
            dialog.response.connect((response) => {
                if (response == "cancel") {
                    plan_manager.cancel_plan(plan);
                    show_toast(@"Plan '$(plan.name)' cancelled");
                    plans_changed();
                }
            });
            
            dialog.present(parent_window);
        }
        
        private void rollback_plan (RotationPlan plan) {
            if (!plan.can_rollback()) {
                show_toast(@"Plan '$(plan.name)' cannot be rolled back", true);
                return;
            }
            
            var dialog = new Adw.AlertDialog(
                @"Rollback Plan '$(plan.name)'?",
                "This will revert the key rotation and restore the old key on all target servers."
            );
            
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("rollback", _("Rollback"));
            dialog.set_response_appearance("rollback", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            
            dialog.response.connect((response) => {
                if (response == "rollback") {
                    plan_manager.rollback_plan.begin(plan, (obj, res) => {
                        try {
                            plan_manager.rollback_plan.end(res);
                            show_toast(@"Plan '$(plan.name)' rolled back successfully");
                            plans_changed();
                        } catch (Error e) {
                            show_toast(@"Rollback failed: $(e.message)", true);
                        }
                    });
                }
            });
            
            dialog.present(parent_window);
        }
        
        private void show_plan_details (RotationPlan plan) {
            var details_dialog = new PlanDetailsDialog(plan);
            details_dialog.present(parent_window);
        }
    }
}