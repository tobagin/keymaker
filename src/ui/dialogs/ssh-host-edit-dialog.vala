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
    private unowned Adw.PreferencesGroup template_group;
    
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
    private unowned Adw.SwitchRow multiple_identity_files_row;
    
    [GtkChild]
    private unowned Adw.ComboRow identity_file_row;
    
    [GtkChild]
    private unowned Adw.ExpanderRow identity_files_expander;
    
    [GtkChild]
    private unowned Adw.EntryRow proxy_jump_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow forward_agent_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow strict_host_key_checking_row;
    
    [GtkChild]
    private unowned Gtk.Button save_button;
    
    public SSHConfigHost? existing_host { get; construct; }
    
    private SSHConfig ssh_config;
    private string? selected_identity_file = null;
    private GenericArray<SSHKey>? available_keys = null;
    private GenericArray<Adw.SwitchRow>? key_switch_rows = null;
    
    public signal void host_saved (SSHConfigHost host);
    
    public SSHHostEditDialog (Gtk.Window parent, SSHConfigHost? host = null) {
        Object (
            existing_host: host
        );
    }
    
    construct {
        ssh_config = new SSHConfig ();
        
        setup_templates ();
        setup_identity_files ();
        setup_multiple_identity_toggle ();
        setup_signals ();
        
        if (existing_host != null) {
            // Hide template section when editing existing host
            template_group.visible = false;
            populate_from_existing ();
        } else {
            // Show template section when creating new host
            template_group.visible = true;
            set_defaults ();
        }
        
        update_ui_state ();
    }
    
    private void setup_templates () {
        if (template_row == null) return;
        
        var templates = ssh_config.get_host_templates ();
        var model = new Gtk.StringList (null);
        
        for (int i = 0; i < templates.length; i++) {
            model.append (templates[i]);
        }
        
        template_row.model = model;
        template_row.selected = 0; // Basic Server
    }
    
    private void setup_identity_files () {
        if (identity_file_row == null) return;
        
        try {
            // Get all SSH keys in the ~/.ssh directory
            KeyScanner.scan_ssh_directory.begin (null, (obj, res) => {
                try {
                    var keys = KeyScanner.scan_ssh_directory.end (res);
                    
                    // Store keys for later reference
                    available_keys = new GenericArray<SSHKey> ();
                    key_switch_rows = new GenericArray<Adw.SwitchRow> ();
                    
                    var model = new Gtk.StringList (null);
                    // Add default option
                    model.append (_("None (use default)"));
                    
                    // Add each SSH key as an option and create switch rows
                    keys.foreach ((key) => {
                        available_keys.add (key);
                        var display_name = key.get_display_name ();
                        if (key.comment != null && key.comment.strip () != "") {
                            display_name += @" ($(key.comment))";
                        }
                        
                        // Add to ComboRow model
                        model.append (display_name);
                        
                        // Create switch row for multiple selection
                        var switch_row = new Adw.SwitchRow ();
                        switch_row.set_title (display_name);
                        switch_row.set_subtitle (key.private_path.get_path ());
                        identity_files_expander.add_row (switch_row);
                        key_switch_rows.add (switch_row);
                    });
                    
                    identity_file_row.model = model;
                    identity_file_row.selected = 0; // Default to "None"
                    
                    // If editing an existing host, try to select the current identity file(s)
                    if (existing_host != null && existing_host.identity_file != null) {
                        select_existing_identity_files (existing_host.identity_file);
                    }
                    
                } catch (Error e) {
                    warning ("Failed to load SSH keys: %s", e.message);
                    
                    // Fallback: just show the default option
                    var model = new Gtk.StringList (null);
                    model.append (_("None (use default)"));
                    identity_file_row.model = model;
                    identity_file_row.selected = 0;
                }
            });
            
        } catch (Error e) {
            warning ("Failed to initialize key scanner: %s", e.message);
            
            // Fallback: just show the default option
            var model = new Gtk.StringList (null);
            model.append (_("None (use default)"));
            identity_file_row.model = model;
            identity_file_row.selected = 0;
        }
    }
    
    private void setup_multiple_identity_toggle () {
        if (multiple_identity_files_row == null) return;
        
        // Connect signal to toggle between single and multiple selection modes
        multiple_identity_files_row.notify["active"].connect (() => {
            bool multiple_mode = multiple_identity_files_row.active;
            identity_file_row.visible = !multiple_mode;
            identity_files_expander.visible = multiple_mode;
        });
    }
    
    private void setup_signals () {
        if (save_button != null) {
            save_button.clicked.connect (on_save_clicked);
        }
        
        // Update UI state when fields change
        if (host_name_row != null) {
            host_name_row.notify["text"].connect (update_ui_state);
        }
        if (template_row != null) {
            template_row.notify["selected"].connect (on_template_changed);
        }
        
        // Identity file selection
        // Note: ComboRow selection is handled automatically
        
        // Port validation
        if (port_row != null) {
            port_row.set_range (1, 65535);
        }
    }
    
    private void populate_from_existing () {
        if (host_name_row != null) {
            host_name_row.text = existing_host.name;
        }
        if (hostname_row != null) {
            hostname_row.text = existing_host.hostname ?? "";
        }
        if (user_row != null) {
            user_row.text = existing_host.user ?? "";
        }
        if (port_row != null) {
            port_row.value = existing_host.port ?? 22;
        }
        if (proxy_jump_row != null) {
            proxy_jump_row.text = existing_host.proxy_jump ?? "";
        }
        if (forward_agent_row != null) {
            forward_agent_row.active = existing_host.forward_agent ?? false;
        }
        if (strict_host_key_checking_row != null) {
            strict_host_key_checking_row.active = existing_host.strict_host_key_checking ?? true;
        }
        
        if (existing_host.identity_file != null) {
            selected_identity_file = existing_host.identity_file;
            // Note: Actual selection happens in setup_identity_files() after keys are loaded
        }
    }
    
    private void set_defaults () {
        if (port_row != null) {
            port_row.value = 22;
        }
        if (forward_agent_row != null) {
            forward_agent_row.active = false;
        }
        if (strict_host_key_checking_row != null) {
            strict_host_key_checking_row.active = true;
        }
    }
    
    private void on_template_changed () {
        if (existing_host != null || template_row == null) {
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
                if (hostname_row != null) hostname_row.text = "github.com";
                if (user_row != null) user_row.text = "git";
                if (port_row != null) port_row.value = 22;
                break;
                
            case "GitLab":
                if (hostname_row != null) hostname_row.text = "gitlab.com";
                if (user_row != null) user_row.text = "git";
                if (port_row != null) port_row.value = 22;
                break;
                
            case "Jump Host":
                if (forward_agent_row != null) forward_agent_row.active = true;
                break;
                
            case "Development Server":
                if (forward_agent_row != null) forward_agent_row.active = true;
                if (strict_host_key_checking_row != null) strict_host_key_checking_row.active = false;
                break;
                
            default: // Basic Server
                // Keep defaults
                break;
        }
    }
    
    private string? get_selected_identity_file () {
        if (multiple_identity_files_row != null && multiple_identity_files_row.active) {
            // Multiple selection mode
            return get_selected_identity_files_multiple ();
        } else {
            // Single selection mode
            return get_selected_identity_file_single ();
        }
    }
    
    private string? get_selected_identity_file_single () {
        if (identity_file_row == null || available_keys == null) {
            return null;
        }
        
        var selected_index = identity_file_row.selected;
        
        // Index 0 is "None (use default)"
        if (selected_index == 0) {
            return null;
        }
        
        // Convert to key array index (subtract 1 for "None" option)
        var key_index = selected_index - 1;
        
        if (key_index >= 0 && key_index < available_keys.length) {
            var key = available_keys[key_index];
            return key.private_path.get_path ();
        }
        
        return null;
    }
    
    private string? get_selected_identity_files_multiple () {
        if (available_keys == null || key_switch_rows == null) {
            return null;
        }
        
        var selected_paths = new GenericArray<string> ();
        
        // Check which switch rows are active
        for (uint i = 0; i < key_switch_rows.length && i < available_keys.length; i++) {
            if (key_switch_rows[i].active) {
                selected_paths.add (available_keys[i].private_path.get_path ());
            }
        }
        
        if (selected_paths.length == 0) {
            return null;
        } else if (selected_paths.length == 1) {
            return selected_paths[0];
        } else {
            // Join multiple paths with space (SSH config format)
            var result = new StringBuilder ();
            for (uint i = 0; i < selected_paths.length; i++) {
                if (i > 0) result.append (" ");
                result.append (selected_paths[i]);
            }
            return result.str;
        }
    }
    
    private void select_existing_identity_files (string identity_files_config) {
        if (available_keys == null || key_switch_rows == null) {
            return;
        }
        
        // SSH config can have multiple identity files separated by whitespace or multiple lines
        // For now, we'll handle single files and determine if we need to switch to multiple mode
        var identity_paths = identity_files_config.strip ().split (" ");
        
        if (identity_paths.length > 1) {
            // Multiple identity files - switch to multiple mode
            multiple_identity_files_row.active = true;
            
            // Select the appropriate switch rows
            foreach (string path in identity_paths) {
                var trimmed_path = path.strip ();
                if (trimmed_path.length == 0) continue;
                
                select_switch_for_path (trimmed_path);
            }
        } else {
            // Single identity file - use combo row
            multiple_identity_files_row.active = false;
            
            var single_path = identity_paths[0].strip ();
            select_combo_for_path (single_path);
        }
    }
    
    private void select_combo_for_path (string identity_file_path) {
        if (identity_file_row == null || available_keys == null) {
            return;
        }
        
        // Try to find the matching key in the available keys
        for (uint i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            if (key.private_path.get_path () == identity_file_path) {
                identity_file_row.selected = i + 1; // +1 because index 0 is "None"
                return;
            }
        }
        
        // If we couldn't find the key, it might not be in the ~/.ssh directory
        warning ("Identity file %s not found in available keys", identity_file_path);
    }
    
    private void select_switch_for_path (string identity_file_path) {
        if (available_keys == null || key_switch_rows == null) {
            return;
        }
        
        // Find and activate the switch for this path
        for (uint i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            if (key.private_path.get_path () == identity_file_path) {
                if (i < key_switch_rows.length) {
                    key_switch_rows[i].active = true;
                }
                return;
            }
        }
        
        warning ("Identity file %s not found in available keys", identity_file_path);
    }
    
    private void update_ui_state () {
        if (host_name_row == null || save_button == null) return;
        
        var host_name = (host_name_row.text != null) ? host_name_row.text.strip () : "";
        save_button.sensitive = (host_name.length > 0);
        
        // Show/hide template row for new hosts only
        if (template_row != null) {
            template_row.visible = (existing_host == null);
        }
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
        int port_val = (int) port_row.value;
        host.port = (port_val != 22) ? (int?) port_val : null;
        host.identity_file = get_selected_identity_file ();
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