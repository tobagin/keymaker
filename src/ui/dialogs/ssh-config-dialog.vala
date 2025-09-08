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
    private unowned Gtk.Button reload_button;
    
    [GtkChild]
    private unowned Gtk.Button remove_all_hosts_button;
    
    [GtkChild]
    private unowned Adw.StatusPage empty_state;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    
    private SSHConfig ssh_config;
    private GenericArray<SSHConfigHost> filtered_hosts;
    private bool has_unsaved_changes = false;
    
    public SSHConfigDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        ssh_config = new SSHConfig ();
        filtered_hosts = new GenericArray<SSHConfigHost> ();
        
        setup_signals ();
        load_config.begin ((obj, res) => {
            try {
                load_config.end (res);
            } catch (Error e) {
                warning ("Failed to load SSH config: %s", e.message);
                show_error ("Failed to load SSH config", e.message);
            }
        });
    }
    
    private void setup_signals () {
        // Add null checks to prevent crashes
        if (search_entry != null) {
            search_entry.search_changed.connect (on_search_changed);
        }
        if (add_host_button != null) {
            add_host_button.clicked.connect (on_add_host_clicked);
        }
        if (reload_button != null) {
            reload_button.clicked.connect (on_reload_clicked);
        }
        if (remove_all_hosts_button != null) {
            remove_all_hosts_button.clicked.connect (on_remove_all_hosts_clicked);
        }
        if (hosts_list != null) {
            hosts_list.row_activated.connect (on_host_row_activated);
        }
        
        if (ssh_config != null) {
            ssh_config.config_changed.connect (on_config_changed);
        }
        
        // Handle close attempts with unsaved changes
        close_attempt.connect(() => {
            if (has_unsaved_changes) {
                show_unsaved_changes_dialog();
            }
        });
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
        var query = (search_entry != null && search_entry.text != null) ? search_entry.text.strip () : "";
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
            main_stack.visible_child_name = "empty_state";
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
            type_icon.icon_size = LARGE;
        } else if (host.hostname != null && ("gitlab.com" in host.hostname || "gitlab" in host.hostname)) {
            type_icon.icon_name = "io.github.tobagin.keysmith-gitlab-symbolic";
            type_icon.icon_size = LARGE;
        } else if (host.has_jump_host ()) {
            type_icon.icon_name = "network-vpn-symbolic";
            type_icon.icon_size = LARGE;
        } else {
            type_icon.icon_name = "network-server-symbolic";
            type_icon.icon_size = LARGE;
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
                debug ("Connect button clicked for host: %s", host.name);
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
            debug ("Delete button clicked for host: %s", host.name);
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
    
    private void on_search_changed () {
        refresh_hosts_list ();
    }
    
    private void on_add_host_clicked () {
        var dialog = new SSHHostEditDialog ((Gtk.Window) this.get_root (), null);
        dialog.host_saved.connect ((host) => {
            ssh_config.add_host (host);
            has_unsaved_changes = true;
            refresh_hosts_list ();
            auto_save ();
        });
        dialog.present (this);
    }
    
    private void edit_host (SSHConfigHost host) {
        var dialog = new SSHHostEditDialog ((Gtk.Window) this.get_root (), host);
        dialog.host_saved.connect ((updated_host) => {
            has_unsaved_changes = true;
            refresh_hosts_list ();
            auto_save ();
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
                has_unsaved_changes = true;
                refresh_hosts_list ();
                auto_save ();
            }
        });
        
        dialog.present (this);
    }
    
    
    private async void save_config_async () throws Error {
        if (!ssh_config.validate_config ()) {
            throw new KeyMakerError.VALIDATION_FAILED ("Please check your SSH host configurations for errors.");
        }
        
        yield ssh_config.save_config ();
        has_unsaved_changes = false;
    }
    
    private void on_reload_clicked () {
        if (has_unsaved_changes) {
            show_unsaved_changes_dialog ();
        } else {
            reload_config ();
        }
    }
    
    private void on_remove_all_hosts_clicked () {
        var hosts = ssh_config.get_hosts ();
        if (hosts.length == 0) {
            show_error ("No Hosts to Remove", "There are no SSH hosts to remove.");
            return;
        }
        
        var dialog = new Adw.AlertDialog (
            @"Remove All $(hosts.length) SSH Hosts?",
            "This will permanently remove all SSH host configurations from your ~/.ssh/config file. This action cannot be undone."
        );
        
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("remove", _("Remove All"));
        dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        dialog.set_close_response ("cancel");
        
        dialog.response.connect ((response) => {
            if (response == "remove") {
                // Remove all hosts by iterating through the list
                var hosts_to_remove = ssh_config.get_hosts ();
                for (int i = 0; i < hosts_to_remove.length; i++) {
                    ssh_config.remove_host (hosts_to_remove[i].name);
                }
                has_unsaved_changes = true;
                refresh_hosts_list ();
                auto_save ();
            }
        });
        
        dialog.present (this);
    }
    
    
    private void reload_config () {
        load_config.begin ((obj, res) => {
            try {
                load_config.end (res);
                has_unsaved_changes = false;
            } catch (Error e) {
                warning ("Failed to reload SSH config: %s", e.message);
                show_error ("Failed to reload SSH config", e.message);
            }
        });
    }
    
    
    private void show_unsaved_changes_dialog () {
        var dialog = new Adw.AlertDialog (
            "Unsaved Changes",
            "You have unsaved changes to your SSH configuration. What would you like to do?"
        );
        dialog.add_response ("discard", "Discard Changes");
        dialog.add_response ("save", "Save Changes");
        dialog.add_response ("cancel", "Cancel");
        dialog.set_response_appearance ("discard", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_response_appearance ("save", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response ("save");
        dialog.set_close_response ("cancel");
        
        dialog.response.connect ((response) => {
            switch (response) {
                case "discard":
                    has_unsaved_changes = false;
                    this.close ();
                    break;
                case "save":
                    save_config_async.begin ((obj, res) => {
                        try {
                            save_config_async.end (res);
                            this.close ();
                        } catch (Error e) {
                            warning ("Failed to save SSH config: %s", e.message);
                            show_error ("Failed to Save", e.message);
                        }
                    });
                    break;
                case "cancel":
                default:
                    break;
            }
        });
        
        dialog.present (this);
    }
    
    private void on_host_row_activated (Gtk.ListBoxRow listbox_row) {
        // Get the ActionRow child from the ListBoxRow
        var action_row = listbox_row.get_child () as Adw.ActionRow;
        if (action_row == null) return;
        
        var host = (SSHConfigHost?) action_row.get_data<SSHConfigHost> ("ssh-host");
        if (host != null) {
            edit_host (host);
        }
    }
    
    private void on_config_changed () {
        has_unsaved_changes = true;
        refresh_hosts_list ();
        auto_save ();
    }
    
    private void auto_save () {
        if (!has_unsaved_changes) return;
        
        save_config_async.begin ((obj, res) => {
            try {
                save_config_async.end (res);
                has_unsaved_changes = false;
            } catch (Error e) {
                warning ("Failed to auto-save SSH config: %s", e.message);
                // Don't show error dialog for auto-save failures to avoid interrupting user
            }
        });
    }
    
    private void connect_to_host (SSHConfigHost host) {
        // Create and show terminal dialog instead of external terminal
        var root_window = (Gtk.Window) this.get_root ();
        var terminal_dialog = new TerminalDialog (root_window, host.name, host.name);
        terminal_dialog.present (this);
    }
    
    
    private void show_error (string title, string message) {
        var dialog = new Adw.AlertDialog (title, message);
        dialog.add_response ("ok", "OK");
        dialog.set_default_response ("ok");
        dialog.present (this);
    }
}