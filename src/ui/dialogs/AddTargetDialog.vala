/*
 * Key Maker - Add Target Dialog
 * 
 * Dialog for adding target servers to rotation plans
 */

namespace KeyMaker {

#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/add_target_dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/add_target_dialog.ui")]
#endif
    public class AddTargetDialog : Adw.Dialog {
        
        [GtkChild] private unowned Gtk.Button cancel_button;
        [GtkChild] private unowned Gtk.Button add_button;
        [GtkChild] private unowned Adw.ComboRow selection_mode_row;
        [GtkChild] private unowned Adw.ComboRow ssh_hosts_row;
        [GtkChild] private unowned Adw.EntryRow hostname_row;
        [GtkChild] private unowned Adw.EntryRow username_row;
        [GtkChild] private unowned Adw.SpinRow port_row;
        [GtkChild] private unowned Adw.PreferencesGroup manual_group;
        
        public signal void target_added (RotationTarget target);
        public SSHConfig? ssh_config { 
            get { return _ssh_config; }
            set {
                _ssh_config = value;
                setup_ssh_hosts();
            } 
        }
        
        private SSHConfig? _ssh_config;
        
        public AddTargetDialog () {
            setup_signals();
        }
        
        private void setup_signals () {
            selection_mode_row.notify["selected"].connect(on_selection_mode_changed);
        }
        
        private void setup_ssh_hosts () {
            if (_ssh_config == null) return;
            
            var hosts_list = new Gtk.StringList(null);
            var hosts = _ssh_config.get_hosts();
            
            for (int i = 0; i < hosts.length; i++) {
                hosts_list.append(hosts[i].name);
            }
            
            ssh_hosts_row.model = hosts_list;
            if (hosts_list.get_n_items() > 0) {
                ssh_hosts_row.selected = 0;
            }
        }
        
        private void on_selection_mode_changed () {
            bool is_manual = selection_mode_row.selected == 1;
            manual_group.visible = is_manual;
            ssh_hosts_row.visible = !is_manual;
        }
        
        [GtkCallback]
        private void on_cancel_clicked () {
            close();
        }
        
        [GtkCallback]
        private void on_add_clicked () {
            if (selection_mode_row.selected == 0) {
                // SSH Config mode
                if (_ssh_config == null || ssh_hosts_row.selected == Gtk.INVALID_LIST_POSITION) {
                    return;
                }
                
                var hosts = _ssh_config.get_hosts();
                if (ssh_hosts_row.selected >= hosts.length) {
                    return;
                }
                
                var host = hosts[ssh_hosts_row.selected];
                var hostname = host.hostname ?? host.name;
                var username = host.user ?? "root";
                var port = host.port ?? 22;
                
                var target = new RotationTarget(hostname, username, port);
                target_added(target);
                close();
            } else {
                // Manual mode
                var hostname = hostname_row.text.strip();
                var username = username_row.text.strip();
                var port = (int) port_row.value;
                
                if (hostname.length > 0 && username.length > 0) {
                    var target = new RotationTarget(hostname, username, port);
                    target_added(target);
                    close();
                }
            }
        }
    }
}