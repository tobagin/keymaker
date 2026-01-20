/*
 * SSHer - Hosts Page
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
    [GtkChild]
    private unowned Gtk.Button mobile_menu_button;
    
    private GenericArray<SSHConfigHost> hosts;
    private GenericArray<SSHConfigHost> filtered_hosts;

    // Signals for window integration
    public signal void show_toast_requested (string message);

    public bool mobile_view { get; set; default = false; }

    construct {
        // Initialize hosts lists
        hosts = new GenericArray<SSHConfigHost> ();
        filtered_hosts = new GenericArray<SSHConfigHost> ();
        
        // Listen for mobile view changes
        notify["mobile-view"].connect (on_mobile_view_changed);

        // Setup button signals with null checks
        if (add_host_button != null) {
            add_host_button.clicked.connect (add_host);
        }
        if (reload_button != null) {
            reload_button.clicked.connect (on_reload_clicked);
        }
        if (remove_all_hosts_button != null) {
            remove_all_hosts_button.clicked.connect (remove_all_hosts_ui);
        }
        if (mobile_menu_button != null) {
            mobile_menu_button.clicked.connect (show_header_mobile_menu);
        }
        
        // Load hosts
        load_hosts ();
    }
    
    private void show_header_mobile_menu () {
        var sheet = new Adw.Dialog ();
        sheet.title = _("Page Actions");
        
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.margin_top = 12;
        box.margin_bottom = 12;
        box.margin_start = 12;
        box.margin_end = 12;
        box.spacing = 12;
        
        var actions_group = new Adw.PreferencesGroup ();
        
        // Add New Host
        var row_add = new Adw.ButtonRow ();
        row_add.title = _("Add New Host");
        row_add.start_icon_name = "tab-new-symbolic";
        row_add.activated.connect (() => {
            sheet.close ();
            add_host ();
        });
        actions_group.add (row_add);
        
        // Reload
        var row_reload = new Adw.ButtonRow ();
        row_reload.title = _("Reload Configuration");
        row_reload.start_icon_name = "view-refresh-symbolic";
        row_reload.activated.connect (() => {
            sheet.close ();
            on_reload_clicked ();
        });
        actions_group.add (row_reload);
        
        box.append (actions_group);
        
        // Destructive
        var destructive_group = new Adw.PreferencesGroup ();
        var row_remove_all = new Adw.ButtonRow ();
        row_remove_all.title = _("Remove All Hosts");
        row_remove_all.start_icon_name = "user-trash-symbolic";
        row_remove_all.add_css_class ("destructive-action");
        row_remove_all.activated.connect (() => {
            sheet.close ();
            remove_all_hosts_ui ();
        });
        destructive_group.add (row_remove_all);
        
        box.append (destructive_group);
        
        sheet.child = box;
        sheet.present (this.get_root () as Gtk.Widget);
    }
    
    public void add_host () {
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
    
    private void on_mobile_view_changed () {
         var child = hosts_list.get_first_child ();
         while (child != null) {
             var row = child as Adw.ActionRow;
             if (row != null) {
                 var desktop = row.get_data<Gtk.Box>("desktop_buttons_box");
                 var mobile = row.get_data<Gtk.Button>("mobile_menu_button");
                 if (desktop != null && mobile != null) {
                     desktop.visible = !mobile_view;
                     mobile.visible = mobile_view;
                 }
             }
             child = child.get_next_sibling ();
         }
    }
    
    public void remove_all_hosts_ui () {
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
        
        // Create a button box to hold desktop buttons
        var desktop_buttons_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        desktop_buttons_box.valign = Gtk.Align.CENTER;
        
        // Create mobile menu button (Gtk.Button opening Adw.BottomSheet)
        var mobile_menu_button = new Gtk.Button.from_icon_name ("open-menu-symbolic");
        mobile_menu_button.tooltip_text = _("Actions");
        mobile_menu_button.valign = Gtk.Align.CENTER;
        mobile_menu_button.add_css_class ("flat");
        
        mobile_menu_button.clicked.connect (() => {
             var sheet = new Adw.Dialog ();
             sheet.title = _("Actions");
             var sheet_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
             sheet_box.margin_top = 12;
             sheet_box.margin_bottom = 12;
             sheet_box.margin_start = 12;
             sheet_box.margin_end = 12;
             sheet_box.spacing = 12;
             
             var sheet_actions = new Adw.PreferencesGroup ();
             
             // Connect
             if (host.line_number > -1 && host.hostname != null && host.hostname.strip () != "") {
                 var row_connect = new Adw.ButtonRow ();
                 row_connect.title = _("Connect via SSH");
                 row_connect.start_icon_name = "utilities-terminal-symbolic";
                 row_connect.activated.connect (() => {
                     sheet.close ();
                     connect_to_host (host);
                 });
                 sheet_actions.add (row_connect);
             }
             
             // Edit
             var row_edit = new Adw.ButtonRow ();
             row_edit.title = _("Edit Host");
             row_edit.start_icon_name = "document-edit-symbolic";
             row_edit.activated.connect (() => {
                 sheet.close ();
                 edit_host (host);
             });
             sheet_actions.add (row_edit);
             
             sheet_box.append (sheet_actions);
             
             // Delete
             var sheet_destructive = new Adw.PreferencesGroup ();
             var row_delete = new Adw.ButtonRow ();
             row_delete.title = _("Delete Host");
             row_delete.start_icon_name = "io.github.tobagin.keysmith-remove-symbolic";
             row_delete.add_css_class ("destructive-action");
             row_delete.activated.connect (() => {
                 sheet.close ();
                 delete_host (host);
             });
             sheet_destructive.add (row_delete);
             
             sheet_box.append (sheet_destructive);
             
             sheet.child = sheet_box;
             sheet.present (this.get_root () as Gtk.Widget);
        });
        
        // Add connect button (desktop only)
        if (host.line_number > -1 && host.hostname != null && host.hostname.strip () != "") {
            var connect_button = new Gtk.Button ();
            connect_button.icon_name = "utilities-terminal-symbolic";
            connect_button.tooltip_text = "Connect via SSH";
            connect_button.add_css_class ("flat");
            connect_button.valign = Gtk.Align.CENTER;
            connect_button.clicked.connect (() => {
                connect_to_host (host);
            });
            desktop_buttons_box.append (connect_button);
        }
        
        // Add edit button (desktop only)
        var edit_button = new Gtk.Button ();
        edit_button.icon_name = "document-edit-symbolic";
        edit_button.tooltip_text = "Edit Host Configuration";
        edit_button.add_css_class ("flat");
        edit_button.valign = Gtk.Align.CENTER;
        edit_button.clicked.connect (() => {
            edit_host (host);
        });
        desktop_buttons_box.append (edit_button);

        // Add delete button (desktop only)
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "io.github.tobagin.keysmith-remove-symbolic";
        delete_button.tooltip_text = "Delete Host";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.clicked.connect (() => {
            delete_host (host);
        });
        desktop_buttons_box.append (delete_button);
        
        row.add_suffix (desktop_buttons_box);
        row.add_suffix (mobile_menu_button);
        
        // Store widgets for toggling
        row.set_data ("desktop_buttons_box", desktop_buttons_box);
        row.set_data ("mobile_menu_button", mobile_menu_button);
        row.set_data ("ssh-host", host);
        
        // Set initial visibility
        desktop_buttons_box.visible = !mobile_view;
        mobile_menu_button.visible = mobile_view;
        
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