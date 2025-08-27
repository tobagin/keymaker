/*
 * Key Maker - SSH Config Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/ssh_config_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/ssh_config_dialog.ui")]
#endif
public class KeyMaker.SSHConfigDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.SearchEntry search_entry;
    
    [GtkChild]
    private unowned Gtk.ListBox hosts_list;
    
    [GtkChild]
    private unowned Gtk.Button add_host_button;
    
    [GtkChild]
    private unowned Gtk.Button save_button;
    
    [GtkChild]
    private unowned Gtk.Button reload_button;
    
    [GtkChild]
    private unowned Adw.StatusPage empty_state;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    private SSHConfig ssh_config;
    private GenericArray<SSHConfigHost> filtered_hosts;
    
    public SSHConfigDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        ssh_config = new SSHConfig ();
        filtered_hosts = new GenericArray<SSHConfigHost> ();
        
        setup_signals ();
        load_config ();
    }
    
    private void setup_signals () {
        search_entry.search_changed.connect (on_search_changed);
        add_host_button.clicked.connect (on_add_host_clicked);
        save_button.clicked.connect (on_save_clicked);
        reload_button.clicked.connect (on_reload_clicked);
        hosts_list.row_activated.connect (on_host_row_activated);
        
        ssh_config.config_changed.connect (on_config_changed);
    }
    
    private async void load_config () {
        try {
            yield ssh_config.load_config ();
            refresh_hosts_list ();
        } catch (KeyMakerError e) {
            warning ("Failed to load SSH config: %s", e.message);
            show_error ("Failed to load SSH config", e.message);
        }
    }
    
    private void refresh_hosts_list () {
        clear_hosts_list ();
        
        var all_hosts = ssh_config.get_hosts ();
        filtered_hosts.remove_range (0, filtered_hosts.length);
        
        // Apply search filter
        var query = search_entry.text.strip ();
        if (query.length > 0) {
            var search_results = ssh_config.search_hosts (query);
            for (int i = 0; i < search_results.length; i++) {
                filtered_hosts.add (search_results[i]);
            }
        } else {
            for (int i = 0; i < all_hosts.length; i++) {
                filtered_hosts.add (all_hosts[i]);
            }
        }
        
        if (filtered_hosts.length == 0) {
            if (query.length > 0) {
                empty_state.title = "No Matching Hosts";
                empty_state.description = @"No SSH hosts match \"$(query)\"";
                empty_state.icon_name = "system-search-symbolic";
            } else {
                empty_state.title = "No SSH Hosts";
                empty_state.description = "Add SSH host configurations to manage your connections";
                empty_state.icon_name = "network-server-symbolic";
            }
            main_stack.visible_child = empty_state;
        } else {
            populate_hosts_list ();
            main_stack.visible_child_name = "hosts_page";
        }
    }
    
    private void clear_hosts_list () {
        Gtk.Widget? child = hosts_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            hosts_list.remove (child);
            child = next;
        }
    }
    
    private void populate_hosts_list () {
        for (int i = 0; i < filtered_hosts.length; i++) {
            var host = filtered_hosts[i];
            var row = create_host_row (host);
            hosts_list.append (row);
        }
    }
    
    private Gtk.Widget create_host_row (SSHConfigHost host) {
        var row = new Adw.ActionRow ();
        row.title = host.get_display_name ();
        
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
            type_icon.icon_name = "github-symbolic";
        } else if (host.hostname != null && ("gitlab.com" in host.hostname || "gitlab" in host.hostname)) {
            type_icon.icon_name = "gitlab-symbolic";
        } else if (host.has_jump_host ()) {
            type_icon.icon_name = "network-vpn-symbolic";
        } else {
            type_icon.icon_name = "network-server-symbolic";
        }
        row.add_prefix (type_icon);
        
        // Add edit button
        var edit_button = new Gtk.Button ();
        edit_button.icon_name = "document-edit-symbolic";
        edit_button.tooltip_text = "Edit Host Configuration";
        edit_button.add_css_class ("flat");
        edit_button.clicked.connect (() => {
            edit_host (host);
        });
        row.add_suffix (edit_button);
        
        // Add delete button
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "user-trash-symbolic";
        delete_button.tooltip_text = "Delete Host";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.clicked.connect (() => {
            delete_host (host);
        });
        row.add_suffix (delete_button);
        
        // Store host reference
        row.set_data ("ssh-host", host);
        
        return row;
    }
    
    private void on_search_changed () {
        refresh_hosts_list ();
    }
    
    private void on_add_host_clicked () {
        var dialog = new SSHHostEditDialog (this, null);
        dialog.host_saved.connect ((host) => {
            ssh_config.add_host (host);
            refresh_hosts_list ();
        });
        dialog.present (this);
    }
    
    private void edit_host (SSHConfigHost host) {
        var dialog = new SSHHostEditDialog (this, host);
        dialog.host_saved.connect ((updated_host) => {
            refresh_hosts_list ();
        });
        dialog.present (this);
    }
    
    private void delete_host (SSHConfigHost host) {
        var dialog = new Adw.AlertDialog (
            @"Delete SSH Host \"$(host.name)\"?",
            "This will remove the host configuration from your SSH config file."
        );
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("delete", "Delete");
        dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        dialog.set_close_response ("cancel");
        
        dialog.response.connect ((response) => {
            if (response == "delete") {
                ssh_config.remove_host (host.name);
                refresh_hosts_list ();
            }
        });
        
        dialog.present (this);
    }
    
    private async void on_save_clicked () {
        if (!ssh_config.validate_config ()) {
            show_error ("Invalid Configuration", "Please check your SSH host configurations for errors.");
            return;
        }
        
        save_button.sensitive = false;
        save_button.child = new Gtk.Spinner () { spinning = true };
        
        try {
            yield ssh_config.save_config ();
            
            // Show success message
            var toast = new Adw.Toast ("SSH configuration saved successfully");
            // Note: Would need to access toast overlay from parent window
            
        } catch (KeyMakerError e) {
            show_error ("Failed to Save", e.message);
        } finally {
            save_button.sensitive = true;
            save_button.child = new Gtk.Label ("Save Configuration");
        }
    }
    
    private void on_reload_clicked () {
        load_config.begin ();
    }
    
    private void on_host_row_activated (Gtk.ListBoxRow row) {
        var host = (SSHConfigHost?) row.get_data ("ssh-host");
        if (host != null) {
            edit_host (host);
        }
    }
    
    private void on_config_changed () {
        refresh_hosts_list ();
    }
    
    private void show_error (string title, string message) {
        var dialog = new Adw.AlertDialog (title, message);
        dialog.add_response ("ok", "OK");
        dialog.set_default_response ("ok");
        dialog.present (this);
    }
}