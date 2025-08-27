/*
 * Key Maker - SSH Agent Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/ssh_agent_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/ssh_agent_dialog.ui")]
#endif
public class KeyMaker.SSHAgentDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.ListBox agent_keys_list;
    
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    
    [GtkChild]
    private unowned Gtk.Button add_key_button;
    
    [GtkChild]
    private unowned Gtk.Button remove_all_button;
    
    [GtkChild]
    private unowned Adw.StatusPage status_page;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    private SSHAgent ssh_agent;
    private GenericArray<SSHKey> available_keys;
    
    public SSHAgentDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        ssh_agent = new SSHAgent ();
        available_keys = new GenericArray<SSHKey> ();
        
        setup_signals ();
        load_agent_keys ();
    }
    
    private void setup_signals () {
        refresh_button.clicked.connect (on_refresh_clicked);
        add_key_button.clicked.connect (on_add_key_clicked);
        remove_all_button.clicked.connect (on_remove_all_clicked);
        
        ssh_agent.agent_keys_changed.connect (on_agent_keys_changed);
    }
    
    private async void load_agent_keys () {
        try {
            var status = yield ssh_agent.get_agent_status ();
            
            if (!status.is_available) {
                show_agent_unavailable ();
                return;
            }
            
            var agent_keys = yield ssh_agent.get_loaded_keys ();
            
            if (agent_keys.length == 0) {
                show_no_keys_loaded ();
            } else {
                show_agent_keys (agent_keys);
            }
            
            // Load available SSH keys for adding
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            available_keys = yield KeyScanner.scan_ssh_directory (ssh_dir);
            
        } catch (KeyMakerError e) {
            show_error (e.message);
        }
    }
    
    private void show_agent_unavailable () {
        status_page.title = "SSH Agent Not Available";
        status_page.description = "The SSH agent is not running or not accessible. Please start your SSH agent and try again.";
        status_page.icon_name = "dialog-warning-symbolic";
        
        main_stack.visible_child = status_page;
        add_key_button.sensitive = false;
        remove_all_button.sensitive = false;
    }
    
    private void show_no_keys_loaded () {
        status_page.title = "No Keys Loaded";
        status_page.description = "SSH agent is running but no keys are currently loaded. Add keys to enable SSH authentication.";
        status_page.icon_name = "dialog-information-symbolic";
        
        main_stack.visible_child = status_page;
        add_key_button.sensitive = true;
        remove_all_button.sensitive = false;
    }
    
    private void show_agent_keys (GenericArray<SSHAgent.AgentKey?> agent_keys) {
        clear_agent_keys_list ();
        
        for (int i = 0; i < agent_keys.length; i++) {
            var key = agent_keys[i];
            var row = create_agent_key_row (key);
            agent_keys_list.append (row);
        }
        
        main_stack.visible_child_name = "keys_page";
        add_key_button.sensitive = true;
        remove_all_button.sensitive = true;
    }
    
    private void show_error (string error_message) {
        status_page.title = "Error Loading Agent Keys";
        status_page.description = error_message;
        status_page.icon_name = "dialog-error-symbolic";
        
        main_stack.visible_child = status_page;
        add_key_button.sensitive = false;
        remove_all_button.sensitive = false;
    }
    
    private void clear_agent_keys_list () {
        Gtk.Widget? child = agent_keys_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            agent_keys_list.remove (child);
            child = next;
        }
    }
    
    private Gtk.Widget create_agent_key_row (SSHAgent.AgentKey key) {
        var row = new Adw.ActionRow ();
        row.title = key.comment != "" ? key.comment : "Unnamed Key";
        row.subtitle = @"$(key.key_type) - $(key.fingerprint)";
        
        // Add key type icon
        var type_icon = new Gtk.Image ();
        switch (key.key_type) {
            case "Ed25519":
                type_icon.icon_name = "emblem-verified-symbolic";
                type_icon.add_css_class ("success");
                break;
            case "RSA":
                type_icon.icon_name = "emblem-important-symbolic";
                type_icon.add_css_class ("warning");
                break;
            case "ECDSA":
                type_icon.icon_name = "emblem-unreadable-symbolic";
                type_icon.add_css_class ("error");
                break;
            default:
                type_icon.icon_name = "emblem-system-symbolic";
                break;
        }
        row.add_prefix (type_icon);
        
        // Add remove button
        var remove_button = new Gtk.Button ();
        remove_button.icon_name = "user-trash-symbolic";
        remove_button.tooltip_text = "Remove from Agent";
        remove_button.add_css_class ("flat");
        remove_button.clicked.connect (() => {
            remove_key_from_agent.begin (key.fingerprint);
        });
        row.add_suffix (remove_button);
        
        return row;
    }
    
    private async void remove_key_from_agent (string fingerprint) {
        try {
            yield ssh_agent.remove_key_from_agent (fingerprint);
        } catch (KeyMakerError e) {
            // Show error toast
            warning ("Failed to remove key from agent: %s", e.message);
        }
    }
    
    private void on_refresh_clicked () {
        load_agent_keys.begin ();
    }
    
    private void on_add_key_clicked () {
        var dialog = new AddKeyToAgentDialog (this, available_keys, ssh_agent);
        dialog.present (this);
    }
    
    private async void on_remove_all_clicked () {
        try {
            yield ssh_agent.remove_all_keys ();
        } catch (KeyMakerError e) {
            warning ("Failed to remove all keys: %s", e.message);
        }
    }
    
    private void on_agent_keys_changed () {
        load_agent_keys.begin ();
    }
}