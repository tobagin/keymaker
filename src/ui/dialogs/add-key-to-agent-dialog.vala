/*
 * Key Maker - Add Key to Agent Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/add_key_to_agent_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/add_key_to_agent_dialog.ui")]
#endif
public class KeyMaker.AddKeyToAgentDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.ListBox keys_list;
    
    [GtkChild]
    private unowned Adw.SpinRow timeout_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow enable_timeout_row;
    
    [GtkChild]
    private unowned Gtk.Button add_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    private GenericArray<SSHKey> available_keys;
    private SSHAgent ssh_agent;
    private SSHKey? selected_key;
    
    public AddKeyToAgentDialog (Gtk.Window parent, GenericArray<SSHKey> keys, SSHAgent agent) {
        Object ();
        available_keys = keys;
        ssh_agent = agent;
    }
    
    construct {
        selected_key = null;
        setup_signals ();
        populate_keys_list ();
        update_ui_state ();
    }
    
    private void setup_signals () {
        add_button.clicked.connect (on_add_clicked);
        cancel_button.clicked.connect (on_cancel_clicked);
        keys_list.row_selected.connect (on_key_selected);
        enable_timeout_row.notify["active"].connect (on_timeout_toggled);
    }
    
    private void populate_keys_list () {
        for (int i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            
            // Skip if key is already loaded in agent
            if (ssh_agent.is_key_loaded (key.fingerprint)) {
                continue;
            }
            
            var row = create_key_row (key);
            keys_list.append (row);
        }
    }
    
    private Gtk.Widget create_key_row (SSHKey key) {
        var row = new Adw.ActionRow ();
        row.title = key.comment != null && key.comment != "" ? key.comment : key.private_path.get_basename ();
        row.subtitle = @"$(key.key_type.to_string ()) - $(key.fingerprint)";
        
        // Add key type icon
        var type_icon = new Gtk.Image ();
        switch (key.key_type) {
            case SSHKeyType.ED25519:
                type_icon.icon_name = "emblem-verified-symbolic";
                type_icon.add_css_class ("success");
                break;
            case SSHKeyType.RSA:
                type_icon.icon_name = "emblem-important-symbolic";
                type_icon.add_css_class ("warning");
                break;
            case SSHKeyType.ECDSA:
                type_icon.icon_name = "emblem-unreadable-symbolic";
                type_icon.add_css_class ("error");
                break;
        }
        row.add_prefix (type_icon);
        
        // Store key reference
        row.set_data ("ssh-key", key);
        
        return row;
    }
    
    private void on_key_selected (Gtk.ListBoxRow? row) {
        if (row != null) {
            selected_key = (SSHKey?) row.get_data ("ssh-key");
        } else {
            selected_key = null;
        }
        update_ui_state ();
    }
    
    private void update_ui_state () {
        add_button.sensitive = (selected_key != null);
        timeout_row.sensitive = enable_timeout_row.active;
    }
    
    private void on_timeout_toggled () {
        update_ui_state ();
    }
    
    private async void on_add_clicked () {
        if (selected_key == null) {
            return;
        }
        
        add_button.sensitive = false;
        add_button.child = new Gtk.Spinner () {
            spinning = true
        };
        
        try {
            int? timeout = null;
            if (enable_timeout_row.active) {
                timeout = (int) timeout_row.value * 60; // Convert minutes to seconds
            }
            
            yield ssh_agent.add_key_to_agent (selected_key.private_path, timeout);
            
            close ();
            
        } catch (KeyMakerError e) {
            // Show error message
            warning ("Failed to add key to agent: %s", e.message);
            
            // Reset button state
            add_button.sensitive = true;
            add_button.child = new Gtk.Label ("Add to Agent");
        }
    }
    
    private void on_cancel_clicked () {
        close ();
    }
}