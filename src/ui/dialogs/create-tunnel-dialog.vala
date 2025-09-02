/*
 * Key Maker - Create/Edit Tunnel Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/create_tunnel_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/create_tunnel_dialog.ui")]
#endif
public class KeyMaker.CreateTunnelDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Adw.EntryRow name_entry;
    
    [GtkChild]
    private unowned Gtk.TextView description_view;
    
    [GtkChild]
    private unowned Adw.ComboRow tunnel_type_combo;
    
    [GtkChild]
    private unowned Adw.EntryRow ssh_host_entry;
    
    [GtkChild]
    private unowned Adw.EntryRow ssh_user_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow ssh_port_row;
    
    [GtkChild]
    private unowned Adw.ActionRow ssh_key_row;
    
    [GtkChild]
    private unowned Gtk.Button ssh_key_button;
    
    [GtkChild]
    private unowned Adw.EntryRow local_host_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow local_port_row;
    
    [GtkChild]
    private unowned Adw.EntryRow remote_host_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow remote_port_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow compression_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow keep_alive_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow auto_reconnect_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow bind_localhost_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow trusted_x11_row;
    
    [GtkChild]
    private unowned Adw.SpinRow connection_timeout_row;
    
    [GtkChild]
    private unowned Gtk.Button save_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup tunnel_config_group;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup x11_group;
    
    private TunnelConfiguration? config;
    private bool editing_mode;
    private string? selected_key_path;
    
    public CreateTunnelDialog (Gtk.Window parent, TunnelConfiguration? existing_config = null) {
        Object ();
        this.config = existing_config;
        this.editing_mode = (existing_config != null);
    }
    
    construct {
        setup_tunnel_types ();
        setup_signals ();
        setup_form ();
        load_existing_config ();
        update_tunnel_specific_controls ();
        update_save_button ();
    }
    
    private void setup_tunnel_types () {
        var model = new Gtk.StringList (null);
        model.append ("Local Forward");
        model.append ("Remote Forward");
        model.append ("Dynamic Forward (SOCKS)");
        model.append ("X11 Forward");
        
        tunnel_type_combo.model = model;
        tunnel_type_combo.selected = 0;
    }
    
    private void setup_signals () {
        save_button.clicked.connect (on_save_tunnel);
        cancel_button.clicked.connect (() => {
            this.force_close ();
        });
        
        ssh_key_button.clicked.connect (on_select_ssh_key);
        tunnel_type_combo.notify["selected"].connect (on_tunnel_type_changed);
        
        // Form validation
        name_entry.changed.connect (update_save_button);
        ssh_host_entry.changed.connect (update_save_button);
        ssh_user_entry.changed.connect (update_save_button);
        local_port_row.notify["value"].connect (update_save_button);
        remote_port_row.notify["value"].connect (update_save_button);
    }
    
    private void setup_form () {
        // Set default values
        ssh_user_entry.text = Environment.get_user_name () ?? "user";
        ssh_port_row.value = 22;
        local_host_entry.text = "localhost";
        local_port_row.value = 8080;
        remote_host_entry.text = "localhost";
        remote_port_row.value = 80;
        connection_timeout_row.value = 30;
        
        // Set default switches
        keep_alive_row.active = true;
        auto_reconnect_row.active = true;
        bind_localhost_row.active = true;
        
        if (editing_mode) {
            header_bar.title_widget = new Adw.WindowTitle ("Edit Tunnel", config?.name ?? "");
            save_button.label = "Save Changes";
        } else {
            header_bar.title_widget = new Adw.WindowTitle ("Create New Tunnel", "Configure SSH tunnel settings");
            save_button.label = "Create Tunnel";
        }
    }
    
    private void load_existing_config () {
        if (config == null) return;
        
        name_entry.text = config.name;
        
        var buffer = description_view.buffer;
        buffer.text = config.description;
        
        tunnel_type_combo.selected = (uint) config.tunnel_type;
        ssh_host_entry.text = config.ssh_host;
        ssh_user_entry.text = config.ssh_user;
        ssh_port_row.value = config.ssh_port;
        
        if (config.ssh_key_path.length > 0) {
            selected_key_path = config.ssh_key_path;
            ssh_key_button.label = Path.get_basename (config.ssh_key_path);
        }
        
        local_host_entry.text = config.local_host;
        local_port_row.value = config.local_port;
        remote_host_entry.text = config.remote_host;
        remote_port_row.value = config.remote_port;
        
        compression_row.active = config.compression;
        keep_alive_row.active = config.keep_alive;
        auto_reconnect_row.active = config.auto_reconnect;
        bind_localhost_row.active = config.bind_to_localhost_only;
        trusted_x11_row.active = config.trusted_x11;
        connection_timeout_row.value = config.connection_timeout;
    }
    
    private void on_tunnel_type_changed () {
        update_tunnel_specific_controls ();
        update_save_button ();
    }
    
    private void update_tunnel_specific_controls () {
        var tunnel_type = (TunnelType) tunnel_type_combo.selected;
        
        // Hide all tunnel-specific controls first
        local_host_entry.visible = false;
        local_port_row.visible = false;
        remote_host_entry.visible = false;
        remote_port_row.visible = false;
        x11_group.visible = false;
        
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
                local_host_entry.visible = true;
                local_port_row.visible = true;
                remote_host_entry.visible = true;
                remote_port_row.visible = true;
                
                local_host_entry.title = "Local Host";
                local_port_row.title = "Local Port";
                remote_host_entry.title = "Remote Host";
                remote_port_row.title = "Remote Port";
                break;
                
            case TunnelType.REMOTE_FORWARD:
                local_host_entry.visible = true;
                local_port_row.visible = true;
                remote_host_entry.visible = true;
                remote_port_row.visible = true;
                
                local_host_entry.title = "Local Host";
                local_port_row.title = "Local Port";
                remote_host_entry.title = "Remote Host";
                remote_port_row.title = "Remote Port";
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                local_host_entry.visible = true;
                local_port_row.visible = true;
                
                local_host_entry.title = "SOCKS Host";
                local_port_row.title = "SOCKS Port";
                break;
                
            case TunnelType.X11_FORWARD:
                x11_group.visible = true;
                break;
        }
    }
    
    private void on_select_ssh_key () {
        var file_chooser = new Gtk.FileChooserDialog (
            "Select SSH Private Key",
            null,
            Gtk.FileChooserAction.OPEN,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Select", Gtk.ResponseType.ACCEPT
        );
        
        // Set initial directory to ~/.ssh
        var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
        if (ssh_dir.query_exists ()) {
            try {
                file_chooser.set_current_folder (ssh_dir);
            } catch (Error e) {
                warning ("Could not set SSH directory: %s", e.message);
            }
        }
        
        // Add file filters
        var key_filter = new Gtk.FileFilter ();
        key_filter.name = "SSH Private Keys";
        key_filter.add_pattern ("id_*");
        key_filter.add_pattern ("*.pem");
        file_chooser.add_filter (key_filter);
        
        var all_filter = new Gtk.FileFilter ();
        all_filter.name = "All Files";
        all_filter.add_pattern ("*");
        file_chooser.add_filter (all_filter);
        
        file_chooser.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                var file = file_chooser.get_file ();
                if (file != null) {
                    selected_key_path = file.get_path ();
                    ssh_key_button.label = Path.get_basename (selected_key_path);
                }
            }
            file_chooser.destroy ();
        });
        
        file_chooser.present ();
    }
    
    private void update_save_button () {
        bool is_valid = validate_form ();
        save_button.sensitive = is_valid;
    }
    
    private bool validate_form () {
        if (name_entry.text.strip ().length == 0) return false;
        if (ssh_host_entry.text.strip ().length == 0) return false;
        if (ssh_user_entry.text.strip ().length == 0) return false;
        
        var tunnel_type = (TunnelType) tunnel_type_combo.selected;
        
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
            case TunnelType.REMOTE_FORWARD:
                if (remote_host_entry.text.strip ().length == 0) return false;
                if (local_port_row.value <= 0 || local_port_row.value > 65535) return false;
                if (remote_port_row.value <= 0 || remote_port_row.value > 65535) return false;
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                if (local_port_row.value <= 0 || local_port_row.value > 65535) return false;
                break;
        }
        
        return true;
    }
    
    private void on_save_tunnel () {
        if (!validate_form ()) {
            show_error ("Invalid Configuration", "Please check all required fields and try again.");
            return;
        }
        
        var new_config = config ?? new TunnelConfiguration ();
        
        // Basic settings
        new_config.name = name_entry.text.strip ();
        new_config.description = get_description_text ();
        new_config.tunnel_type = (TunnelType) tunnel_type_combo.selected;
        new_config.ssh_host = ssh_host_entry.text.strip ();
        new_config.ssh_user = ssh_user_entry.text.strip ();
        new_config.ssh_port = (int) ssh_port_row.value;
        new_config.ssh_key_path = selected_key_path ?? "";
        
        // Tunnel settings
        new_config.local_host = local_host_entry.text.strip ();
        new_config.local_port = (int) local_port_row.value;
        new_config.remote_host = remote_host_entry.text.strip ();
        new_config.remote_port = (int) remote_port_row.value;
        
        // Advanced options
        new_config.compression = compression_row.active;
        new_config.keep_alive = keep_alive_row.active;
        new_config.auto_reconnect = auto_reconnect_row.active;
        new_config.bind_to_localhost_only = bind_localhost_row.active;
        new_config.trusted_x11 = trusted_x11_row.active;
        new_config.connection_timeout = (int) connection_timeout_row.value;
        
        if (!editing_mode) {
            // Add new configuration
            var tunneling = new SSHTunneling ();
            tunneling.add_configuration (new_config);
        }
        
        this.force_close ();
    }
    
    private string get_description_text () {
        var buffer = description_view.buffer;
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        return buffer.get_text (start, end, false).strip ();
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}