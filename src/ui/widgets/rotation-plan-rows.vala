/*
 * Key Maker - Rotation Plan Row Widgets
 * 
 * Individual row widgets for different plan states in the rotation manager
 */

namespace KeyMaker {
    
    /**
     * Base class for rotation plan rows
     */
    public abstract class RotationPlanRowBase : Adw.ActionRow {
        public RotationPlan plan { get; construct; }
        
        public signal void plan_action_requested (string action);
        
        protected RotationPlanRowBase (RotationPlan plan) {
            Object (plan: plan);
        }
        
        construct {
            setup_basic_info();
            setup_actions();
        }
        
        protected virtual void setup_basic_info () {
            title = plan.name;
            subtitle = get_subtitle_text();
            
            var plan_image = new Gtk.Image();
            plan_image.icon_name = "accessories-text-editor-symbolic";
            plan_image.icon_size = LARGE;
            add_prefix(plan_image);
        }
        
        protected abstract string get_subtitle_text ();
        protected abstract void setup_actions ();
        
        protected Gtk.Button create_action_button (string icon_name, string tooltip, string action, string? css_class = null) {
            var button = new Gtk.Button();
            button.icon_name = icon_name;
            button.tooltip_text = tooltip;
            button.valign = Gtk.Align.CENTER;
            button.add_css_class("flat");
            if (css_class != null) {
                button.add_css_class(css_class);
            }
            button.clicked.connect(() => plan_action_requested(action));
            return button;
        }
    }
    
    /**
     * Row widget for draft plans
     */
    public class DraftPlanRow : RotationPlanRowBase {
        
        public DraftPlanRow (RotationPlan plan) {
            base (plan);
        }
        
        protected override string get_subtitle_text () {
            return @"Key: $(plan.old_key.get_display_name()) • $(plan.targets.length) targets";
        }
        
        protected override void setup_actions () {
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            
            var execute_button = create_action_button("media-playback-start-symbolic", _("Execute Plan"), "execute");
            var view_details_button = create_action_button("view-reveal-symbolic", _("View Details"), "view-details");
            var edit_button = create_action_button("document-edit-symbolic", _("Edit Plan"), "edit");
            var duplicate_button = create_action_button("io.github.tobagin.keysmith-duplicate-symbolic", _("Duplicate Plan"), "duplicate");
            var delete_button = create_action_button("io.github.tobagin.keysmith-remove-symbolic", _("Delete Plan"), "delete", "destructive-action");
            
            execute_button.sensitive = plan.can_execute();
            
            button_box.append(execute_button);
            button_box.append(view_details_button);
            button_box.append(edit_button);
            button_box.append(duplicate_button);
            button_box.append(delete_button);
            
            add_suffix(button_box);
            
            // Remove row activation since we now have a dedicated button
            activatable = false;
        }
    }
    
    /**
     * Row widget for running plans
     */
    public class RunningPlanRow : RotationPlanRowBase {
        
        private Gtk.ProgressBar progress_bar;
        
        public RunningPlanRow (RotationPlan plan) {
            base (plan);
            
            // Update progress periodically
            Timeout.add_seconds(1, () => {
                update_progress();
                return true;
            });
        }
        
        protected override string get_subtitle_text () {
            return @"$(plan.current_operation) • $((int)plan.progress_percentage)% complete";
        }
        
        protected override void setup_actions () {
            var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            
            progress_bar = new Gtk.ProgressBar();
            progress_bar.fraction = plan.progress_percentage / 100.0;
            progress_bar.hexpand = true;
            
            var cancel_button = create_action_button("process-stop-symbolic", _("Cancel Execution"), "cancel", "destructive-action");
            
            suffix_box.append(progress_bar);
            suffix_box.append(cancel_button);
            
            add_suffix(suffix_box);
        }
        
        private void update_progress () {
            progress_bar.fraction = plan.progress_percentage / 100.0;
            subtitle = get_subtitle_text();
        }
    }
    
    /**
     * Row widget for rollback-available plans
     */
    public class RollbackPlanRow : RotationPlanRowBase {
        
        public RollbackPlanRow (RotationPlan plan) {
            base (plan);
        }
        
        protected override string get_subtitle_text () {
            var time_remaining = plan.get_rollback_time_remaining();
            var completed_date = plan.completed_at?.format("%Y-%m-%d %H:%M") ?? "unknown";
            return @"Completed $(completed_date) • Expires in $(time_remaining)";
        }
        
        protected override void setup_actions () {
            var rollback_button = create_action_button("io.github.tobagin.keysmith-rollback-symbolic", _("Rollback Rotation"), "rollback", "destructive-action");
            add_suffix(rollback_button);
        }
    }
    
    /**
     * Row widget for historical plans
     */
    public class HistoryPlanRow : RotationPlanRowBase {
        
        public HistoryPlanRow (RotationPlan plan) {
            base (plan);
        }
        
        protected override string get_subtitle_text () {
            string status_text = plan.status.to_string();
            string date_text = plan.completed_at?.format("%Y-%m-%d %H:%M") ?? "unknown";
            return @"$(status_text) • $(date_text)";
        }
        
        protected override void setup_actions () {
            // History rows are read-only by default
            var view_button = create_action_button("view-reveal-symbolic", _("View Details"), "view-details");
            add_suffix(view_button);
            
            activatable = true;
            activated.connect(() => plan_action_requested("view-details"));
        }
    }
}