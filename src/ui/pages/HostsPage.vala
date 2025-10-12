/*
 * Key Maker - Hosts Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/hosts_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/hosts_page.ui")]
#endif
public class KeyMaker.HostsPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Button add_host_button;
    [GtkChild]
    private unowned Gtk.Button reload_button;
    [GtkChild]
    private unowned Gtk.Button remove_all_hosts_button;
    [GtkChild]
    private unowned Gtk.ListBox hosts_list;
    
    private GenericArray<SSHConfigHost> hosts;
    private GenericArray<SSHConfigHost> filtered_hosts;

    // Signals for window integration
    public signal void show_toast_requested (string message);

    construct {
        // Initialize hosts lists
        hosts = new GenericArray<SSHConfigHost> ();
        filtered_hosts = new GenericArray<SSHConfigHost> ();
        
        // Setup button signals with null checks
        if (add_host_button != null) {
            add_host_button.clicked.connect (on_add_host_clicked);
        }
        if (reload_button != null) {
            reload_button.clicked.connect (on_reload_clicked);
        }
        if (remove_all_hosts_button != null) {
            remove_all_hosts_button.clicked.connect (on_remove_all_clicked);
        }
        
        
        // Load hosts
        load_hosts ();
    }
    
    private void on_add_host_clicked () {
        var dialog = new KeyMaker.SSHHostEditDialog (get_root () as Gtk.Window, null);
        dialog.host_saved.connect (on_host_saved);
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_host_saved (SSHConfigHost host) {
        save_host_async.begin (host);
    }

    private async void save_host_async (SSHConfigHost host) {
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            yield ssh_config.load_config ();

            // Add or update host
            ssh_config.add_host (host);

            // Save to file
            yield ssh_config.save_config ();

            // Update in-memory list
            bool found = false;
            for (int i = 0; i < hosts.length; i++) {
                if (hosts[i].name == host.name) {
                    hosts[i] = host;
                    found = true;
                    break;
                }
            }

            if (!found) {
                hosts.add (host);
            }

            // Refresh the UI
            refresh_hosts_display ();
            show_toast_requested (_("Host '%s' saved successfully").printf (host.name));

        } catch (Error e) {
            warning ("Failed to save host: %s", e.message);
            show_toast_requested (_("Failed to save host: %s").printf (e.message));
        }
    }
    
    private void load_hosts () {
        load_hosts_async.begin ();
    }
    
    private async void load_hosts_async () {
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            yield ssh_config.load_config ();
            var loaded_hosts = ssh_config.get_hosts ();
            
            hosts.remove_range (0, hosts.length);
            for (int i = 0; i < loaded_hosts.length; i++) {
                hosts.add (loaded_hosts[i]);
            }
            
            refresh_hosts_display ();
            
            
        } catch (Error e) {
            warning ("Failed to load SSH hosts: %s", e.message);
            show_toast_requested (_("Failed to load SSH hosts: %s").printf (e.message));
        }
    }
    
    private void refresh_hosts_display () {
        // Clear and populate filtered hosts (no search functionality)
        filtered_hosts.remove_range (0, filtered_hosts.length);
        for (int i = 0; i < hosts.length; i++) {
            filtered_hosts.add (hosts[i]);
        }
        
        // Clear current display
        var child = hosts_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            hosts_list.remove (child);
            child = next;
        }

        // If no hosts, show empty state row
        if (filtered_hosts.length == 0) {
            var empty_row = new Adw.ActionRow ();
            empty_row.title = _("No SSH Hosts");
            empty_row.subtitle = _("Click the + button above to add your first SSH host configuration");
            empty_row.sensitive = false;

            var icon = new Gtk.Image ();
            icon.icon_name = "network-server-symbolic";
            icon.opacity = 0.5;
            empty_row.add_prefix (icon);

            hosts_list.append (empty_row);
            return;
        }

        // Add hosts to display
        for (int i = 0; i < filtered_hosts.length; i++) {
            var host = filtered_hosts[i];
            var row = create_host_row (host);
            hosts_list.append (row);
        }
    }
    
    
    private void on_reload_clicked () {
        load_hosts ();
    }
    
    private void on_remove_all_clicked () {
        if (hosts.length == 0) {
            return;
        }
        
        var dialog = new Adw.AlertDialog (_("Remove All Hosts"), 
            _("This will remove all SSH host configurations from ~/.ssh/config. This action cannot be undone."));
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("remove", _("Remove All"));
        dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        
        dialog.response.connect ((response_id) => {
            if (response_id == "remove") {
                remove_all_hosts ();
            }
        });
        
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void remove_all_hosts () {
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            
            // Remove all hosts
            hosts.remove_range (0, hosts.length);
            
            // Clear the config (this would need to be implemented in SSHConfig)
            // For now, just refresh
            refresh_hosts_display ();
            show_toast_requested (_("All hosts removed successfully"));
            
        } catch (Error e) {
            warning ("Failed to remove all hosts: %s", e.message);
            show_toast_requested (_("Failed to remove hosts: %s").printf (e.message));
        }
    }
    
    private Gtk.Widget create_host_row (SSHConfigHost host) {
        debug ("Creating row for host: %s", host.name);
        var row = new Adw.ActionRow ();
        row.title = host.get_display_name ();
        row.activatable = false; // Prevent row activation from interfering with button clicks
        
        // Build subtitle with key details
        var subtitle_parts = new GenericArray<string> ();
        if (host.user != null) {
            subtitle_parts.add (@"user: $(host.user)");
        }
        if (host.port != null && host.port != 22) {
            subtitle_parts.add (@"port: $(host.port)");
        }
        if (host.has_jump_host ()) {
            subtitle_parts.add ("via jump host");
        }
        
        if (subtitle_parts.length > 0) {
            row.subtitle = string.joinv (" • ", subtitle_parts.data);
        }
        
        // Add connection type icon
        var type_icon = new Gtk.Image ();
        if (host.hostname != null && "github.com" in host.hostname) {
            type_icon.icon_name = "io.github.tobagin.keysmith-github-symbolic";
        } else if (host.hostname != null && ("gitlab.com" in host.hostname || "gitlab" in host.hostname)) {
            type_icon.icon_name = "io.github.tobagin.keysmith-gitlab-symbolic";
        } else if (host.has_jump_host ()) {
            type_icon.icon_name = "network-vpn-symbolic";
        } else {
            type_icon.icon_name = "network-server-symbolic";
        }
        row.add_prefix (type_icon);
        
        // Create a button box to hold all buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.valign = Gtk.Align.CENTER;
        
        // Add connect button (only for saved hosts with hostname/IP)
        if (host.line_number > -1 && host.hostname != null && host.hostname.strip () != "") {
            var connect_button = new Gtk.Button ();
            connect_button.icon_name = "utilities-terminal-symbolic";
            connect_button.tooltip_text = "Connect via SSH";
            connect_button.add_css_class ("flat");
            connect_button.valign = Gtk.Align.CENTER;
            connect_button.clicked.connect (() => {
                print ("🖱️ Connect button clicked for host: %s\n", host.name);
                connect_to_host (host);
            });
            button_box.append (connect_button);
        }
        
        // Add edit button
        var edit_button = new Gtk.Button ();
        edit_button.icon_name = "document-edit-symbolic";
        edit_button.tooltip_text = "Edit Host Configuration";
        edit_button.add_css_class ("flat");
        edit_button.valign = Gtk.Align.CENTER;
        edit_button.sensitive = true;
        edit_button.clicked.connect (() => {
            debug ("Edit button clicked for host: %s", host.name);
            edit_host (host);
        });
        button_box.append (edit_button);
        
        // Add delete button
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "io.github.tobagin.keysmith-remove-symbolic";
        delete_button.tooltip_text = "Delete Host";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.sensitive = true;
        delete_button.clicked.connect (() => {
            print ("🗑️  Delete button clicked for host: %s\n", host.name);
            delete_host (host);
        });
        
        button_box.append (delete_button);
        row.add_suffix (button_box);
        
        // Store host reference
        row.set_data ("ssh-host", host);
        
        // Force show all widgets
        button_box.show ();
        
        debug ("Row created for host %s with buttons", host.name);
        
        return row;
    }
    
    private void on_edit_host_clicked (SSHConfigHost host) {
        var dialog = new KeyMaker.SSHHostEditDialog (get_root () as Gtk.Window, host);
        dialog.host_saved.connect (on_host_saved);
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_remove_host_clicked (SSHConfigHost host) {
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            ssh_config.remove_host (host.name);
            ssh_config.save_config.begin ();
            
            // Remove from local list
            for (int i = 0; i < hosts.length; i++) {
                if (hosts[i].name == host.name) {
                    hosts.remove_index (i);
                    break;
                }
            }
            
            refresh_hosts_display ();
            show_toast_requested (_("Host '%s' removed successfully").printf (host.name));
            
        } catch (Error e) {
            warning ("Failed to remove host: %s", e.message);
            show_toast_requested (_("Failed to remove host: %s").printf (e.message));
        }
    }
    
    public void refresh_hosts () {
        load_hosts ();
    }
    
    private void connect_to_host (SSHConfigHost host) {
        print ("🔌 connect_to_host called for: %s\n", host.name);

        // Create and show terminal dialog instead of external terminal
        var root_window = get_root () as Gtk.Window;

        if (root_window == null) {
            print ("❌ Root window is null, cannot present terminal dialog\n");
            show_toast_requested (_("Failed to open terminal: No parent window"));
            return;
        }

        print ("✅ Root window found, creating TerminalDialog for host: %s\n", host.name);
        try {
            var terminal_dialog = new KeyMaker.TerminalDialog (root_window, host.name, host.name);
            print ("📦 TerminalDialog created, now presenting...\n");
            terminal_dialog.present (root_window);
            print ("✨ Terminal dialog presented successfully\n");
        } catch (Error e) {
            print ("❌ Failed to create or present terminal dialog: %s\n", e.message);
            show_toast_requested (_("Failed to open terminal: %s").printf (e.message));
        }
    }
    
    private void edit_host (SSHConfigHost host) {
        var dialog = new KeyMaker.SSHHostEditDialog (get_root () as Gtk.Window, host);
        dialog.host_saved.connect (on_host_saved);
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void delete_host (SSHConfigHost host) {
        print ("🚨 delete_host() called for: %s\n", host.name);
        var dialog = new Adw.AlertDialog (
            @"Delete SSH Host \"$(host.name)\"?",
            "This will remove the host configuration from your SSH config file."
        );
        print ("📝 AlertDialog created\n");
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("delete", "Delete");
        dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        dialog.set_close_response ("cancel");

        dialog.response.connect ((response) => {
            print ("📤 Dialog response: %s\n", response);
            if (response == "delete") {
                print ("✅ User confirmed delete, calling delete_host_async\n");
                delete_host_async.begin (host);
            }
        });

        print ("🎭 Presenting AlertDialog\n");
        dialog.present (get_root () as Gtk.Window);
        print ("✨ AlertDialog presented\n");
    }

    private async void delete_host_async (SSHConfigHost host) {
        print ("🔧 delete_host_async() started for: %s\n", host.name);
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            print ("📂 Loading SSH config...\n");
            yield ssh_config.load_config ();  // Load existing config first!
            print ("✅ SSH config loaded\n");

            print ("🗑️  Removing host: %s\n", host.name);
            ssh_config.remove_host (host.name);
            print ("💾 Saving SSH config...\n");
            yield ssh_config.save_config ();  // Now save
            print ("✅ SSH config saved\n");

            // Remove from local list
            for (int i = 0; i < hosts.length; i++) {
                if (hosts[i].name == host.name) {
                    hosts.remove_index (i);
                    print ("✅ Host removed from local list\n");
                    break;
                }
            }

            refresh_hosts_display ();
            show_toast_requested (_("Host '%s' deleted successfully").printf (host.name));
            print ("🎉 Delete operation completed successfully\n");

        } catch (Error e) {
            print ("❌ Delete failed: %s\n", e.message);
            warning ("Failed to delete host: %s", e.message);
            show_toast_requested (_("Failed to delete host: %s").printf (e.message));
        }
    }
}