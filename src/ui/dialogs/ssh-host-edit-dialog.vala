/*
 * Key Maker - SSH Host Edit Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/ssh_host_edit_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/ssh_host_edit_dialog.ui")]
#endif
public class KeyMaker.SSHHostEditDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.EntryRow host_name_row;
    
    [GtkChild]
    private unowned Adw.EntryRow hostname_row;
    
    [GtkChild]
    private unowned Adw.EntryRow user_row;
    
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    
    [GtkChild]
    private unowned Adw.ComboRow template_row;
    
    [GtkChild]
    private unowned Adw.ActionRow identity_file_row;
    
    [GtkChild]
    private unowned Gtk.Label identity_file_label;
    
    [GtkChild]
    private unowned Adw.EntryRow proxy_jump_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow forward_agent_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow strict_host_key_checking_row;
    
    [GtkChild]
    private unowned Gtk.Button save_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    public SSHConfigHost? existing_host { get; construct; }
    
    private SSHConfig ssh_config;
    private string? selected_identity_file = null;
    
    public signal void host_saved (SSHConfigHost host);
    
    public SSHHostEditDialog (Gtk.Window parent, SSHConfigHost? host = null) {
        Object (
            existing_host: host
        );
    }
    
    construct {
        ssh_config = new SSHConfig ();
        
        setup_templates ();
        setup_signals ();
        
        if (existing_host != null) {
            populate_from_existing ();
        } else {
            set_defaults ();
        }
        
        update_ui_state ();
    }
    
    private void setup_templates () {
        var templates = ssh_config.get_host_templates ();
        var model = new Gtk.StringList (null);
        
        for (int i = 0; i < templates.length; i++) {
            model.append (templates[i]);
        }
        
        template_row.model = model;
        template_row.selected = 0; // Basic Server
    }
    
    private void setup_signals () {
        save_button.clicked.connect (on_save_clicked);
        cancel_button.clicked.connect (on_cancel_clicked);
        
        // Update UI state when fields change
        host_name_row.notify["text"].connect (update_ui_state);
        template_row.notify["selected"].connect (on_template_changed);
        
        // Identity file selection
        identity_file_row.activated.connect (on_select_identity_file);
        
        // Port validation
        port_row.set_range (1, 65535);
    }
    
    private void populate_from_existing () {
        host_name_row.text = existing_host.name;
        hostname_row.text = existing_host.hostname ?? "";
        user_row.text = existing_host.user ?? "";
        port_row.value = existing_host.port ?? 22;
        proxy_jump_row.text = existing_host.proxy_jump ?? "";
        forward_agent_row.active = existing_host.forward_agent ?? false;
        strict_host_key_checking_row.active = existing_host.strict_host_key_checking ?? true;
        
        if (existing_host.identity_file != null) {
            selected_identity_file = existing_host.identity_file;
            identity_file_label.label = Path.get_basename (selected_identity_file);
        }
    }
    
    private void set_defaults () {
        port_row.value = 22;
        forward_agent_row.active = false;
        strict_host_key_checking_row.active = true;
    }
    
    private void on_template_changed () {
        if (existing_host != null) {
            return; // Don't apply templates to existing hosts
        }
        
        var selected_index = template_row.selected;
        var templates = ssh_config.get_host_templates ();
        
        if (selected_index < templates.length) {
            var template_name = templates[selected_index];
            apply_template (template_name);
        }
    }
    
    private void apply_template (string template_name) {
        switch (template_name) {
            case "GitHub":
                hostname_row.text = "github.com";
                user_row.text = "git";
                port_row.value = 22;
                break;
                
            case "GitLab":
                hostname_row.text = "gitlab.com";
                user_row.text = "git";
                port_row.value = 22;
                break;
                
            case "Jump Host":
                forward_agent_row.active = true;
                break;
                
            case "Development Server":
                forward_agent_row.active = true;
                strict_host_key_checking_row.active = false;
                break;
                
            default: // Basic Server
                // Keep defaults
                break;
        }
    }
    
    private void on_select_identity_file () {
        var dialog = new Gtk.FileDialog ();
        dialog.title = "Select SSH Identity File";
        dialog.modal = true;
        
        // Set initial folder to ~/.ssh
        var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
        dialog.set_initial_folder (ssh_dir);
        
        // Add filter for SSH keys
        var filter = new Gtk.FileFilter ();
        filter.set_name ("SSH Keys");
        filter.add_pattern ("id_*");
        filter.add_pattern ("*_rsa");
        filter.add_pattern ("*_ed25519");
        filter.add_pattern ("*_ecdsa");
        
        var filter_list = new Gio.ListStore (typeof (Gtk.FileFilter));
        filter_list.append (filter);
        dialog.set_filters (filter_list);
        
        dialog.open.begin (this, null, (obj, res) => {
            try {
                var file = dialog.open.end (res);
                selected_identity_file = file.get_path ();
                identity_file_label.label = Path.get_basename (selected_identity_file);
            } catch (Error e) {
                // User cancelled or error occurred
            }
        });
    }
    
    private void update_ui_state () {
        var host_name = host_name_row.text.strip ();
        save_button.sensitive = (host_name.length > 0);
        
        // Show/hide template row for new hosts only
        template_row.visible = (existing_host == null);
    }
    
    private void on_save_clicked () {
        var host_name = host_name_row.text.strip ();
        
        if (host_name.length == 0) {
            return;
        }
        
        SSHConfigHost host;
        if (existing_host != null) {
            host = existing_host;
        } else {
            host = new SSHConfigHost (host_name);
        }
        
        // Update host properties
        host.name = host_name;
        host.hostname = hostname_row.text.strip () != "" ? hostname_row.text.strip () : null;
        host.user = user_row.text.strip () != "" ? user_row.text.strip () : null;
        host.port = (int) port_row.value != 22 ? (int) port_row.value : null;
        host.identity_file = selected_identity_file;
        host.proxy_jump = proxy_jump_row.text.strip () != "" ? proxy_jump_row.text.strip () : null;
        host.forward_agent = forward_agent_row.active;
        host.strict_host_key_checking = strict_host_key_checking_row.active;
        
        host_saved (host);
        close ();
    }
    
    private void on_cancel_clicked () {
        close ();
    }
}