/*
 * SSHer - Create/Edit Tunnel Dialog
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
    private unowned Adw.EntryRow description_entry;
    
    [GtkChild]
    private unowned Adw.ComboRow tunnel_type_combo;
    
    [GtkChild]
    private unowned Adw.ComboRow ssh_host_combo;
    
    [GtkChild]
    private unowned Adw.EntryRow ssh_host_entry;
    
    [GtkChild]
    private unowned Adw.EntryRow ssh_user_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow ssh_port_row;
    
    [GtkChild]
    private unowned Adw.ComboRow ssh_key_combo;
    
    [GtkChild]
    private unowned Adw.ComboRow local_host_combo;
    
    [GtkChild]
    private unowned Adw.EntryRow local_host_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow local_port_row;
    
    [GtkChild]
    private unowned Adw.ComboRow remote_host_combo;
    
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
    private unowned Adw.PreferencesGroup tunnel_config_group;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup x11_group;
    
    private TunnelConfiguration? config;
    private bool editing_mode;
    private GenericArray<string> ssh_key_paths;
    private GenericArray<SSHConfigHost> ssh_hosts;
    private GenericArray<string> ssh_host_names;
    
    public CreateTunnelDialog (Gtk.Window parent, TunnelConfiguration? existing_config = null) {
        Object ();
        this.config = existing_config;
        this.editing_mode = (existing_config != null);
    }
    
    construct {
        ssh_key_paths = new GenericArray<string> ();
        ssh_hosts = new GenericArray<SSHConfigHost> ();
        ssh_host_names = new GenericArray<string> ();
        setup_tunnel_types ();
        setup_ssh_keys ();
        setup_ssh_hosts ();
        setup_local_hosts ();
        setup_remote_hosts ();
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
    
    private void setup_ssh_keys () {
        var model = new Gtk.StringList (null);
        model.append ("Default (automatic)");
        ssh_key_paths.add ("");  // Empty path for default
        
        // Scan ~/.ssh directory for private keys
        var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
        if (ssh_dir.query_exists ()) {
            try {
                var enumerator = ssh_dir.enumerate_children ("standard::name,standard::type", FileQueryInfoFlags.NONE);
                FileInfo? info;
                
                while ((info = enumerator.next_file ()) != null) {
                    var name = info.get_name ();
                    
                    // Look for common private key patterns
                    if ((name.has_prefix ("id_") && !name.has_suffix (".pub")) ||
                        name.has_suffix (".pem") ||
                        name.has_suffix ("_rsa") ||
                        name.has_suffix ("_ed25519") ||
                        name.has_suffix ("_ecdsa")) {
                        
                        var key_path = Path.build_filename (ssh_dir.get_path (), name);
                        var key_file = File.new_for_path (key_path);
                        
                        // Check if corresponding public key exists (good indicator it's a key pair)
                        var pub_file = File.new_for_path (key_path + ".pub");
                        if (pub_file.query_exists ()) {
                            model.append (name);
                            ssh_key_paths.add (key_path);
                        }
                    }
                }
            } catch (Error e) {
                warning ("Failed to scan SSH keys: %s", e.message);
            }
        }
        
        ssh_key_combo.model = model;
        ssh_key_combo.selected = 0;  // Default to "Default (automatic)"
    }
    
    private void setup_ssh_hosts () {
        var model = new Gtk.StringList (null);
        
        // Add custom option first
        model.append ("Custom...");
        ssh_host_names.add ("");  // Empty string for custom
        
        // Load hosts from SSH config
        load_ssh_hosts_async.begin ();
        
        ssh_host_combo.model = model;
        ssh_host_combo.selected = 0;  // Default to "Custom..."
    }
    
    private async void load_ssh_hosts_async () {
        try {
            var ssh_config = new KeyMaker.SSHConfig ();
            yield ssh_config.load_config ();
            var loaded_hosts = ssh_config.get_hosts ();
            
            var model = (Gtk.StringList) ssh_host_combo.model;
            
            for (int i = 0; i < loaded_hosts.length; i++) {
                var host = loaded_hosts[i];
                ssh_hosts.add (host);
                ssh_host_names.add (host.name);
                model.append (host.get_display_name ());
            }
            
            // If we loaded any hosts, default to the first one instead of custom
            if (loaded_hosts.length > 0) {
                ssh_host_combo.selected = 1;  // First loaded host (index 1, after "Custom...")
                update_save_button ();  // Update button state after changing selection
            }
        } catch (Error e) {
            warning ("Failed to load SSH hosts: %s", e.message);
        }
    }
    
    private void setup_local_hosts () {
        var model = new Gtk.StringList (null);
        
        // Add common local host options
        model.append ("localhost");
        model.append ("127.0.0.1");
        model.append ("0.0.0.0 (Allow external connections)");
        model.append ("::1 (IPv6 loopback)");
        model.append (":: (IPv6 all interfaces)");
        model.append ("Custom...");
        
        local_host_combo.model = model;
        local_host_combo.selected = 0;  // Default to "localhost"
    }
    
    private void setup_remote_hosts () {
        var model = new Gtk.StringList (null);
        
        // Add common remote host options
        model.append ("localhost");
        model.append ("127.0.0.1");
        model.append ("0.0.0.0");
        model.append ("Custom...");
        
        remote_host_combo.model = model;
        remote_host_combo.selected = 0;  // Default to "localhost"
    }
    
    private void setup_signals () {
        save_button.clicked.connect (on_save_tunnel);
        tunnel_type_combo.notify["selected"].connect (on_tunnel_type_changed);
        ssh_host_combo.notify["selected"].connect (on_ssh_host_changed);
        local_host_combo.notify["selected"].connect (on_local_host_changed);
        remote_host_combo.notify["selected"].connect (on_remote_host_changed);
        
        // Form validation
        name_entry.changed.connect (update_save_button);
        ssh_host_entry.changed.connect (update_save_button);
        local_host_entry.changed.connect (update_save_button);
        remote_host_entry.changed.connect (update_save_button);
        ssh_user_entry.changed.connect (update_save_button);
        local_port_row.notify["value"].connect (update_save_button);
        remote_port_row.notify["value"].connect (update_save_button);
    }
    
    private void setup_form () {
        // Set default values
        ssh_host_entry.text = "example.com";  // Default custom SSH host
        ssh_user_entry.text = Environment.get_user_name () ?? "user";
        ssh_port_row.value = 22;
        local_port_row.value = 8080;
        remote_port_row.value = 80;
        connection_timeout_row.value = 30;
        
        // Set default switches
        keep_alive_row.active = true;
        auto_reconnect_row.active = true;
        bind_localhost_row.active = true;
        
        if (editing_mode) {
            save_button.label = "Save Changes";
        } else {
            save_button.label = "Create Tunnel";
        }
    }
    
    private void load_existing_config () {
        if (config == null) return;
        
        name_entry.text = config.name;
        description_entry.text = config.description;
        
        tunnel_type_combo.selected = (uint) config.tunnel_type;
        
        // Find the host in our list and select it, or use custom
        bool found_host = false;
        for (uint i = 0; i < ssh_host_names.length; i++) {
            if (ssh_host_names[i] == config.ssh_host) {
                ssh_host_combo.selected = i;
                found_host = true;
                break;
            }
        }
        
        if (!found_host) {
            // Use custom option
            ssh_host_combo.selected = 0;
            ssh_host_entry.text = config.ssh_host;
            ssh_host_entry.visible = true;
        }
        
        ssh_user_entry.text = config.ssh_user;
        ssh_port_row.value = config.ssh_port;
        
        // Find the key in our list and select it
        if (config.ssh_key_path.length > 0) {
            for (uint i = 0; i < ssh_key_paths.length; i++) {
                if (ssh_key_paths[i] == config.ssh_key_path) {
                    ssh_key_combo.selected = i;
                    break;
                }
            }
        } else {
            ssh_key_combo.selected = 0;  // Default
        }
        
        // Set local host - check if it's one of our predefined options
        var local_host = config.local_host;
        if (local_host == "localhost") {
            local_host_combo.selected = 0;
        } else if (local_host == "127.0.0.1") {
            local_host_combo.selected = 1;
        } else if (local_host == "0.0.0.0") {
            local_host_combo.selected = 2;
        } else if (local_host == "::1") {
            local_host_combo.selected = 3;
        } else if (local_host == "::" || local_host == "::0") {
            local_host_combo.selected = 4;
        } else {
            // Custom option
            local_host_combo.selected = 5;
            local_host_entry.text = local_host;
            local_host_entry.visible = true;
        }
        
        local_port_row.value = config.local_port;
        
        // Set remote host - check if it's one of our predefined options
        var remote_host = config.remote_host;
        if (remote_host == "localhost") {
            remote_host_combo.selected = 0;
        } else if (remote_host == "127.0.0.1") {
            remote_host_combo.selected = 1;
        } else if (remote_host == "0.0.0.0") {
            remote_host_combo.selected = 2;
        } else {
            // Custom option
            remote_host_combo.selected = 3;
            remote_host_entry.text = remote_host;
            remote_host_entry.visible = true;
        }
        
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
    
    private void on_ssh_host_changed () {
        // Show/hide custom entry based on selection
        bool is_custom = (ssh_host_combo.selected == 0);  // First item is "Custom..."
        ssh_host_entry.visible = is_custom;
        
        // Auto-fill user if this is a configured host
        if (!is_custom && ssh_host_combo.selected < ssh_hosts.length + 1) {
            var host_index = ssh_host_combo.selected - 1;  // Subtract 1 for "Custom..." option
            var host = ssh_hosts[host_index];
            if (host.user != null) {
                ssh_user_entry.text = host.user;
            }
            if (host.port != null) {
                ssh_port_row.value = host.port;
            }
        }
        
        update_save_button ();
    }
    
    private void on_local_host_changed () {
        // Show/hide custom entry based on selection
        bool is_custom = (local_host_combo.selected == 5);  // "Custom..." is 6th item (index 5)
        local_host_entry.visible = is_custom;
        
        // Warn about insecure options
        var selected = local_host_combo.selected;
        if (selected == 2 || selected == 4) {  // 0.0.0.0 or :: (all interfaces)
            show_security_warning ();
        }
        
        update_save_button ();
    }
    
    private void show_security_warning () {
        var warning_dialog = new Adw.AlertDialog (
            _("Security Warning"),
            _("Binding to all interfaces (0.0.0.0 or ::) allows connections from other machines on the network. This may expose your tunnel to unauthorized access. Only use this option if you understand the security implications and need to share the tunnel with other machines.")
        );
        warning_dialog.add_response ("ok", _("I Understand"));
        warning_dialog.set_default_response ("ok");
        warning_dialog.present (this);
    }
    
    private void on_remote_host_changed () {
        // Show/hide custom entry based on selection
        bool is_custom = (remote_host_combo.selected == 3);  // "Custom..." is 4th item (index 3)
        remote_host_entry.visible = is_custom;
        
        update_save_button ();
    }
    
    private void update_tunnel_specific_controls () {
        var tunnel_type = (TunnelType) tunnel_type_combo.selected;
        
        // Hide all tunnel-specific controls first
        local_host_combo.visible = false;
        local_host_entry.visible = false;
        local_port_row.visible = false;
        remote_host_combo.visible = false;
        remote_host_entry.visible = false;
        remote_port_row.visible = false;
        x11_group.visible = false;
        
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
                local_host_combo.visible = true;
                local_host_entry.visible = (local_host_combo.selected == 5);
                local_port_row.visible = true;
                remote_host_combo.visible = true;
                remote_host_entry.visible = (remote_host_combo.selected == 3);
                remote_port_row.visible = true;
                
                local_host_entry.title = "Local Host";
                local_port_row.title = "Local Port";
                remote_host_entry.title = "Remote Host";
                remote_port_row.title = "Remote Port";
                break;
                
            case TunnelType.REMOTE_FORWARD:
                local_host_combo.visible = true;
                local_host_entry.visible = (local_host_combo.selected == 5);
                local_port_row.visible = true;
                remote_host_combo.visible = true;
                remote_host_entry.visible = (remote_host_combo.selected == 3);
                remote_port_row.visible = true;
                
                local_host_entry.title = "Local Host";
                local_port_row.title = "Local Port";
                remote_host_entry.title = "Remote Host";
                remote_port_row.title = "Remote Port";
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                local_host_combo.visible = true;
                local_host_entry.visible = (local_host_combo.selected == 5);
                local_port_row.visible = true;
                
                local_host_entry.title = "SOCKS Host";
                local_port_row.title = "SOCKS Port";
                break;
                
            case TunnelType.X11_FORWARD:
                x11_group.visible = true;
                break;
        }
    }
    
    
    private void update_save_button () {
        bool is_valid = validate_form ();
        save_button.sensitive = is_valid;
    }
    
    private bool validate_form () {
        if (name_entry.text.strip ().length == 0) return false;
        
        // Check SSH host - either from combo or custom entry
        bool is_custom = (ssh_host_combo.selected == 0);
        if (is_custom && ssh_host_entry.text.strip ().length == 0) return false;
        // For non-custom, just ensure a valid selection is made (combo will handle bounds)
        if (!is_custom && ssh_host_combo.selected < 0) return false;
        
        if (ssh_user_entry.text.strip ().length == 0) return false;
        
        var tunnel_type = (TunnelType) tunnel_type_combo.selected;
        
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
            case TunnelType.REMOTE_FORWARD:
                // Check local host - either from combo or custom entry
                bool is_custom_local = (local_host_combo.selected == 5);
                if (is_custom_local && local_host_entry.text.strip ().length == 0) return false;
                
                // Check remote host - either from combo or custom entry
                bool is_custom_remote = (remote_host_combo.selected == 3);
                if (is_custom_remote && remote_host_entry.text.strip ().length == 0) return false;
                
                if (local_port_row.value <= 0 || local_port_row.value > 65535) return false;
                if (remote_port_row.value <= 0 || remote_port_row.value > 65535) return false;
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                // Check local host - either from combo or custom entry
                bool is_custom_local_dynamic = (local_host_combo.selected == 5);
                if (is_custom_local_dynamic && local_host_entry.text.strip ().length == 0) return false;
                
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
        new_config.description = description_entry.text.strip ();
        new_config.tunnel_type = (TunnelType) tunnel_type_combo.selected;
        
        // Get SSH host - either from combo or custom entry
        bool is_custom = (ssh_host_combo.selected == 0);
        if (is_custom) {
            new_config.ssh_host = ssh_host_entry.text.strip ();
        } else {
            var host_index = ssh_host_combo.selected - 1;  // Subtract 1 for "Custom..." option
            new_config.ssh_host = ssh_host_names[host_index];
        }
        new_config.ssh_user = ssh_user_entry.text.strip ();
        new_config.ssh_port = (int) ssh_port_row.value;
        new_config.ssh_key_path = ssh_key_paths[ssh_key_combo.selected];
        
        // Tunnel settings
        // Get local host - either from combo or custom entry
        bool is_custom_local = (local_host_combo.selected == 5);
        if (is_custom_local) {
            new_config.local_host = local_host_entry.text.strip ();
        } else {
            // Get value from combo
            string[] local_options = {"localhost", "127.0.0.1", "0.0.0.0", "::1", "::"};
            new_config.local_host = local_options[local_host_combo.selected];
        }
        
        new_config.local_port = (int) local_port_row.value;
        
        // Get remote host - either from combo or custom entry
        bool is_custom_remote = (remote_host_combo.selected == 3);
        if (is_custom_remote) {
            new_config.remote_host = remote_host_entry.text.strip ();
        } else {
            // Get value from combo
            string[] remote_options = {"localhost", "127.0.0.1", "0.0.0.0"};
            new_config.remote_host = remote_options[remote_host_combo.selected];
        }
        
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
    
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}