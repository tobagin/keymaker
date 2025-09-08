/*
 * Key Maker - Keys Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/keys_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/keys_page.ui")]
#endif
public class KeyMaker.KeysPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Box child_box;
    [GtkChild]
    private unowned Gtk.Button add_key_to_agent_button;
    [GtkChild]
    private unowned Gtk.Button refresh_agent_button;
    [GtkChild]
    private unowned Gtk.ListBox agent_keys_list;
    [GtkChild]
    private unowned Gtk.ListBox key_list_box;
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    [GtkChild]
    private unowned Gtk.MenuButton generate_button;
    
    private GenericArray<KeyMaker.KeyRowWidget> key_rows;
    private GenericArray<SSHKey> ssh_keys;
    private Settings settings;
    private Cancellable? refresh_cancellable;
    private KeyMaker.SSHAgent? ssh_agent;
    
    // Signals for window integration
    public signal void key_copy_requested (SSHKey ssh_key);
    public signal void key_delete_requested (SSHKey ssh_key);
    public signal void key_details_requested (SSHKey ssh_key);
    public signal void key_passphrase_change_requested (SSHKey ssh_key);
    public signal void key_copy_id_requested (SSHKey ssh_key);
    public signal void generate_key_requested ();
    public signal void add_existing_key_requested ();
    public signal void show_toast_requested (string message);
    
    construct {
        // Initialize settings
#if DEVELOPMENT
        settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
        settings = new Settings ("io.github.tobagin.keysmith");
#endif
        
        // Initialize arrays
        ssh_keys = new GenericArray<SSHKey> ();
        key_rows = new GenericArray<KeyMaker.KeyRowWidget> ();
        
        // SSH agent will be initialized when needed
        
        // Setup SSH agent buttons with null checks
        if (add_key_to_agent_button != null) {
            add_key_to_agent_button.clicked.connect (on_add_key_to_agent_clicked);
        }
        if (refresh_agent_button != null) {
            refresh_agent_button.clicked.connect (on_refresh_agent_clicked);
        }
        
        // Setup SSH Keys buttons with null checks
        if (refresh_button != null) {
            refresh_button.clicked.connect (() => refresh_keys ());
        }
        
        // Setup the key list box
        if (key_list_box != null) {
            key_list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        }
        
        // Load SSH keys and agent keys
        refresh_keys ();
        refresh_agent_keys ();
    }
    
    
    public GenericArray<SSHKey> get_ssh_keys () {
        return ssh_keys;
    }
    
    public void refresh_keys () {
        refresh_key_list_async.begin ();
    }
    
    private async void refresh_key_list_async () {
        // Cancel any in-flight scan
        if (refresh_cancellable != null) {
            try { refresh_cancellable.cancel (); } catch (Error e) { }
        }
        refresh_cancellable = new Cancellable ();

        debug ("KeysPage: starting async key scan");
        try {
            var keys = yield KeyMaker.KeyScanner.scan_ssh_directory_with_cancellable (null, refresh_cancellable);

            // Clear current list
            clear_key_list ();
            ssh_keys.remove_range (0, ssh_keys.length);
            
            // Add keys
            for (int i = 0; i < keys.length; i++) {
                ssh_keys.add (keys[i]);
                add_key_to_list (keys[i]);
            }


            debug ("KeysPage: async key scan complete: %d keys", keys.length);
        } catch (IOError.CANCELLED e) {
            debug ("KeysPage: key scan cancelled");
        } catch (KeyMakerError e) {
            show_toast_requested (_("Failed to scan SSH keys: %s").printf (e.message));
            clear_key_list ();
        } catch (Error e) {
            show_toast_requested (_("Failed to scan SSH keys: %s").printf (e.message));
            clear_key_list ();
        }
    }
    
    public void on_key_deleted (SSHKey deleted_key) {
        // Remove the key from our list
        for (int i = 0; i < ssh_keys.length; i++) {
            if (ssh_keys[i] == deleted_key) {
                ssh_keys.remove_index (i);
                break;
            }
        }
        
        remove_key_from_list (deleted_key);
    }
    
    private void on_add_key_to_agent_clicked () {
        var agent = new KeyMaker.SSHAgent ();
        var dialog = new KeyMaker.AddKeyToAgentDialog (get_root () as Gtk.Window, ssh_keys, agent);
        dialog.present (get_root () as Gtk.Window);
        // Refresh after dialog is closed (no signal available)
        dialog.closed.connect (() => {
            refresh_agent_keys ();
        });
    }
    
    private void on_refresh_agent_clicked () {
        refresh_agent_keys ();
    }
    
    private void refresh_agent_keys () {
        refresh_agent_keys_async.begin ();
    }
    
    private async void refresh_agent_keys_async () {
        try {
            // Clear current display
            clear_agent_keys_list ();
            
            var agent = new KeyMaker.SSHAgent ();
            bool is_available = yield agent.check_agent_availability ();
            
            if (is_available) {
                var agent_keys = yield agent.get_loaded_keys ();
                
                if (agent_keys.length == 0) {
                    var no_keys_row = new Adw.ActionRow ();
                    no_keys_row.title = _("No keys loaded");
                    no_keys_row.subtitle = _("Load keys using the SSH Agent Manager");
                    no_keys_row.sensitive = false;
                    if (agent_keys_list != null) {
                        agent_keys_list.append (no_keys_row);
                    }
                } else {
                    for (int i = 0; i < agent_keys.length; i++) {
                        var agent_key = agent_keys[i];
                        var row = create_agent_key_row (agent_key);
                        if (agent_keys_list != null) {
                            agent_keys_list.append (row);
                        }
                    }
                }
            } else {
                var unavailable_row = new Adw.ActionRow ();
                unavailable_row.title = _("SSH agent not available");
                unavailable_row.subtitle = _("Start SSH agent to load keys");
                unavailable_row.sensitive = false;
                if (agent_keys_list != null) {
                    agent_keys_list.append (unavailable_row);
                }
            }
        } catch (Error e) {
            var error_row = new Adw.ActionRow ();
            error_row.title = _("Failed to check agent");
            error_row.subtitle = e.message;
            error_row.sensitive = false;
            if (agent_keys_list != null) {
                agent_keys_list.append (error_row);
            }
            warning ("Failed to check SSH agent status: %s", e.message);
        }
    }
    
    private void clear_agent_keys_list () {
        if (agent_keys_list == null) return;
        
        Gtk.Widget? child = agent_keys_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            agent_keys_list.remove (child);
            child = next;
        }
    }
    
    private Gtk.Widget create_agent_key_row (KeyMaker.SSHAgent.AgentKey agent_key) {
        var row = new Adw.ActionRow ();
        
        // Title: comment + (KEY_TYPE) like in image #2
        string comment = agent_key.comment != "" ? agent_key.comment : "Unnamed Key";
        row.title = @"$(comment) ($(agent_key.key_type))";
        
        // Subtitle: just the fingerprint like in image #2
        row.subtitle = agent_key.fingerprint;
        
        // Add key type icon using proper enum
        var type_icon = new Gtk.Image ();
        SSHKeyType key_type = SSHKeyType.RSA; // default
        if (agent_key.key_type.contains ("Ed25519")) {
            key_type = SSHKeyType.ED25519;
        } else if (agent_key.key_type.contains ("ECDSA")) {
            key_type = SSHKeyType.ECDSA;
        } else if (agent_key.key_type.contains ("RSA")) {
            key_type = SSHKeyType.RSA;
        }
        
        type_icon.icon_name = key_type.get_icon_name ();
        type_icon.icon_size = LARGE;
        
        switch (key_type) {
            case SSHKeyType.ED25519:
                type_icon.add_css_class ("success");
                break;
            case SSHKeyType.RSA:
                type_icon.add_css_class ("accent");
                break;
            case SSHKeyType.ECDSA:
                type_icon.add_css_class ("warning");
                break;
        }
        row.add_prefix (type_icon);
        
        // Add remove button
        var remove_button = new Gtk.Button ();
        remove_button.icon_name = "io.github.tobagin.keysmith-remove-symbolic";
        remove_button.tooltip_text = "Remove from Agent";
        remove_button.add_css_class ("flat");
        remove_button.add_css_class ("destructive-action");
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.clicked.connect (() => {
            remove_key_from_agent (agent_key);
        });
        
        row.add_suffix (remove_button);
        
        return row;
    }
    
    private void remove_key_from_agent (KeyMaker.SSHAgent.AgentKey agent_key) {
        remove_key_from_agent_async.begin (agent_key);
    }
    
    private async void remove_key_from_agent_async (KeyMaker.SSHAgent.AgentKey agent_key) {
        try {
            var agent = new KeyMaker.SSHAgent ();
            yield agent.remove_key_from_agent (agent_key.fingerprint);
            refresh_agent_keys ();
        } catch (Error e) {
            warning ("Failed to remove key from agent: %s", e.message);
            show_toast_requested (_("Failed to remove key from agent: %s").printf (e.message));
        }
    }
    
    public void on_passphrase_changed (SSHKey updated_key) {
        // Refresh the key list to update button tooltips and UI state
        refresh_key_in_list (updated_key);
    }
    
    public void on_key_generated (SSHKey new_key) {
        // Refresh the key list to ensure everything is properly updated
        refresh_keys ();
    }
    
    private void clear_key_list () {
        if (key_list_box == null) return;
        
        // Remove all key rows
        while (key_rows.length > 0) {
            var row = key_rows[0];
            key_list_box.remove (row);
            key_rows.remove_index (0);
        }
    }
    
    private void add_key_to_list (SSHKey ssh_key) {
        if (key_list_box == null) return;
        
        var key_row = new KeyMaker.KeyRowWidget (ssh_key);
        
        // Connect signals
        key_row.copy_requested.connect ((key) => key_copy_requested (key));
        key_row.delete_requested.connect ((key) => key_delete_requested (key));
        key_row.details_requested.connect ((key) => key_details_requested (key));
        key_row.passphrase_change_requested.connect ((key) => key_passphrase_change_requested (key));
        key_row.copy_id_requested.connect ((key) => key_copy_id_requested (key));
        
        key_rows.add (key_row);
        key_list_box.append (key_row);
    }
    
    private void remove_key_from_list (SSHKey ssh_key) {
        if (key_list_box == null) return;
        
        // Find and remove the key row
        for (int i = 0; i < key_rows.length; i++) {
            var row = key_rows[i];
            if (row.ssh_key == ssh_key) {
                key_list_box.remove (row);
                key_rows.remove_index (i);
                break;
            }
        }
    }
    
    private void refresh_key_in_list (SSHKey ssh_key) {
        // Find the key row and refresh it
        for (int i = 0; i < key_rows.length; i++) {
            var row = key_rows[i];
            if (row.ssh_key == ssh_key) {
                row.refresh ();
                break;
            }
        }
    }
}