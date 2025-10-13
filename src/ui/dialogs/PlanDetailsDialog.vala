/*
 * SSHer - Plan Details Dialog
 * 
 * Dialog showing comprehensive plan details
 */

namespace KeyMaker {

#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/plan_details_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/plan_details_dialog.ui")]
#endif
    public class PlanDetailsDialog : Adw.Dialog {
        
        [GtkChild] private unowned Adw.HeaderBar header_bar;
        [GtkChild] private unowned Adw.PreferencesGroup info_group;
        [GtkChild] private unowned Adw.ActionRow name_row;
        [GtkChild] private unowned Adw.ActionRow status_row;
        [GtkChild] private unowned Gtk.Image status_image;
        [GtkChild] private unowned Adw.ActionRow description_row;
        [GtkChild] private unowned Adw.ActionRow reason_row;
        [GtkChild] private unowned Adw.ActionRow old_key_row;
        [GtkChild] private unowned Adw.ActionRow new_key_row;
        [GtkChild] private unowned Adw.ActionRow rollback_enabled_row;
        [GtkChild] private unowned Adw.ActionRow rollback_period_row;
        [GtkChild] private unowned Adw.ActionRow keep_old_key_row;
        [GtkChild] private unowned Adw.ExpanderRow targets_expander;
        [GtkChild] private unowned Adw.ActionRow created_row;
        [GtkChild] private unowned Adw.ActionRow last_update_row;
        [GtkChild] private unowned Gtk.Image old_key_icon;
        [GtkChild] private unowned Gtk.Image new_key_icon;
        
        public PlanDetailsDialog (RotationPlan plan) {
            title = @"Plan Details: $(plan.name)";
            
            populate_plan_info(plan);
            populate_targets(plan);
            populate_status(plan);
            populate_config(plan);
        }
        
        private void populate_plan_info (RotationPlan plan) {
            name_row.subtitle = plan.name;
            
            status_row.subtitle = plan.status.to_string();
            status_image.icon_name = plan.status.get_icon_name();
            
            if (plan.description != null && plan.description.length > 0) {
                description_row.subtitle = plan.description;
                description_row.visible = true;
            }
            
            reason_row.subtitle = plan.rotation_reason;
            created_row.subtitle = plan.created_at.format("%Y-%m-%d %H:%M:%S");
        }
        
        private void populate_targets (RotationPlan plan) {
            // Clear existing targets
            var child = targets_expander.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                targets_expander.remove(child);
                child = next;
            }
            
            // Update expander title to show count
            targets_expander.title = @"$(plan.targets.length) Target Server$(plan.targets.length != 1 ? "s" : "")";
            
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                var target_row = new Adw.ActionRow();
                target_row.title = target.get_display_name();
                target_row.subtitle = @"Port $(target.port)";
                
                var server_image = new Gtk.Image.from_icon_name("network-wired-symbolic");
                target_row.add_prefix(server_image);
                
                targets_expander.add_row(target_row);
            }
            
            if (plan.targets.length == 0) {
                var empty_row = new Adw.ActionRow();
                empty_row.title = _("No targets configured");
                empty_row.add_css_class("dim-label");
                targets_expander.add_row(empty_row);
            }
        }
        
        private void populate_status (RotationPlan plan) {
            if (plan.started_at != null) {
                last_update_row.subtitle = plan.started_at.format("%Y-%m-%d %H:%M:%S");
            } else {
                last_update_row.subtitle = plan.created_at.format("%Y-%m-%d %H:%M:%S");
            }
        }
        
        private void populate_config (RotationPlan plan) {
            old_key_row.subtitle = plan.old_key.get_display_name();
            new_key_row.subtitle = plan.new_key != null ? plan.new_key.get_display_name() : _("Will be generated");
            
            // Set dynamic icons based on key types
            old_key_icon.icon_name = plan.old_key.key_type.get_icon_name();
            if (plan.new_key != null) {
                new_key_icon.icon_name = plan.new_key.key_type.get_icon_name();
            } else {
                // For generated keys, assume ED25519 as default (could be enhanced based on plan config)
                new_key_icon.icon_name = SSHKeyType.ED25519.get_icon_name();
            }
            
            rollback_enabled_row.subtitle = plan.enable_rollback ? _("Yes") : _("No");
            
            if (plan.enable_rollback) {
                rollback_period_row.subtitle = plan.rollback_period.to_string();
                rollback_period_row.visible = true;
            } else {
                rollback_period_row.visible = false;
            }
            
            keep_old_key_row.subtitle = plan.keep_old_key ? _("Yes") : _("No");
        }
    }
}