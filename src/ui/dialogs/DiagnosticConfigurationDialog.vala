/*
 * Key Maker - Diagnostic Configuration Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/diagnostic_configuration_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/diagnostic_configuration_dialog.ui")]
#endif
public class KeyMaker.DiagnosticConfigurationDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.WindowTitle window_title;
    [GtkChild]
    private unowned Gtk.Button create_button;
    [GtkChild]
    private unowned Adw.SwitchRow auto_run_switch;
    
    // Template selection
    [GtkChild]
    private unowned Adw.ComboRow template_selection_row;
    
    // Basic information
    [GtkChild]
    private unowned Adw.EntryRow name_entry;
    [GtkChild]
    private unowned Adw.EntryRow description_entry;
    
    // Connection settings
    [GtkChild]
    private unowned Adw.PreferencesGroup connection_group;
    [GtkChild]
    private unowned Adw.ComboRow hostname_combo;
    [GtkChild]
    private unowned Adw.EntryRow custom_hostname_entry;
    [GtkChild]
    private unowned Adw.EntryRow username_entry;
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    [GtkChild]
    private unowned Adw.ComboRow auth_method_row;
    [GtkChild]
    private unowned Adw.ComboRow ssh_key_combo;
    [GtkChild]
    private unowned Adw.ComboRow ssh_agent_combo;
    [GtkChild]
    private unowned Adw.PasswordEntryRow password_entry;
    [GtkChild]
    private unowned Adw.SpinRow timeout_row;
    [GtkChild]
    private unowned Adw.EntryRow proxy_jump_entry;
    
    // Test options
    [GtkChild]
    private unowned Adw.PreferencesGroup test_options_group;
    [GtkChild]
    private unowned Adw.SwitchRow test_basic_connection_switch;
    [GtkChild]
    private unowned Adw.SwitchRow test_dns_resolution_switch;
    [GtkChild]
    private unowned Adw.SwitchRow test_protocol_detection_switch;
    [GtkChild]
    private unowned Adw.SwitchRow test_performance_switch;
    [GtkChild]
    private unowned Adw.SwitchRow test_tunnel_capabilities_switch;
    [GtkChild]
    private unowned Adw.SwitchRow test_permissions_switch;
    
    private DiagnosticConfiguration config;
    private DiagnosticType diagnostic_type;
    private string selected_ssh_key_path = "";
    private GenericArray<SSHKey> available_keys;
    private GenericArray<SSHConfigHost> available_hosts;
    private GenericArray<SSHAgent.AgentKey?> available_agent_keys;
    private SSHAgent ssh_agent;
    
    public signal void configuration_created(DiagnosticConfiguration configuration, bool auto_run);
    
    public DiagnosticConfigurationDialog() {
        Object();
        diagnostic_type = DiagnosticType.CONNECTION_TEST; // Default
    }
    
    public void populate_from_config(DiagnosticConfiguration existing_config) {
        config = existing_config;
        diagnostic_type = existing_config.diagnostic_type;
        
        // Populate basic information
        name_entry.text = existing_config.name;
        description_entry.text = existing_config.description;
        
        // Populate connection settings
        set_hostname_from_string(existing_config.hostname);
        username_entry.text = existing_config.username;
        port_row.value = existing_config.port;
        timeout_row.value = existing_config.timeout;
        proxy_jump_entry.text = existing_config.proxy_jump;
        
        // Set auth method
        switch (existing_config.auth_method) {
            case "key":
                auth_method_row.selected = 0;
                break;
            case "password":
                auth_method_row.selected = 1;
                break;
            case "agent":
                auth_method_row.selected = 2;
                break;
        }
        
        // Set SSH key if provided
        if (existing_config.ssh_key_path != "") {
            selected_ssh_key_path = existing_config.ssh_key_path;
            set_ssh_key_from_path(selected_ssh_key_path);
        }
        
        // Set password if provided
        password_entry.text = existing_config.password;
        
        // Populate test options
        test_basic_connection_switch.active = existing_config.test_basic_connection;
        test_dns_resolution_switch.active = existing_config.test_dns_resolution;
        test_protocol_detection_switch.active = existing_config.test_protocol_detection;
        test_performance_switch.active = existing_config.test_performance;
        test_tunnel_capabilities_switch.active = existing_config.test_tunnel_capabilities;
        test_permissions_switch.active = existing_config.test_permissions;
        
        // Set template selection based on diagnostic type
        switch (existing_config.diagnostic_type) {
            case DiagnosticType.CONNECTION_TEST:
                template_selection_row.selected = 0;
                break;
            case DiagnosticType.PERFORMANCE_TEST:
                template_selection_row.selected = 1;
                break;
            case DiagnosticType.SECURITY_AUDIT:
                template_selection_row.selected = 2;
                break;
            case DiagnosticType.PROTOCOL_ANALYSIS:
                template_selection_row.selected = 3;
                break;
            case DiagnosticType.TUNNEL_TEST:
                template_selection_row.selected = 4;
                break;
            case DiagnosticType.PERMISSION_CHECK:
                template_selection_row.selected = 5;
                break;
        }
        
        // Update window title for editing
        window_title.title = _("Edit %s").printf(get_type_display_name());
        create_button.label = _("Update");
        
        validate_form();
    }
    
    construct {
        // Initialize data structures
        available_keys = new GenericArray<SSHKey>();
        available_hosts = new GenericArray<SSHConfigHost>();
        available_agent_keys = new GenericArray<SSHAgent.AgentKey?>();
        ssh_agent = new SSHAgent();
        
        // Create config after construct is ready
        config = new DiagnosticConfiguration.with_type(diagnostic_type);
        
        // Setup button signals
        create_button.clicked.connect(on_save_clicked);
        
        // Setup combo boxes
        setup_hostname_combo();
        setup_auth_method_combo();
        setup_ssh_key_combo();
        setup_ssh_agent_combo();
        
        // Setup template selection
        template_selection_row.notify["selected"].connect(on_template_changed);
        
        // Setup validation
        hostname_combo.notify["selected"].connect(validate_form);
        username_entry.notify["text"].connect(validate_form);
        custom_hostname_entry.notify["text"].connect(validate_form);
        
        // Setup auto-run switch from settings
        auto_run_switch.active = SettingsManager.auto_run_diagnostics;
        
        // Initialize form with type-specific defaults
        setup_form_for_type();
        validate_form();
    }
    
    private void setup_hostname_combo() {
        var string_list = new Gtk.StringList(null);
        
        // Load configured hosts
        var ssh_config = new SSHConfig();
        ssh_config.load_config.begin((obj, res) => {
            try {
                ssh_config.load_config.end(res);
                available_hosts = ssh_config.get_hosts();
                
                // Populate hostname combo
                for (int i = 0; i < available_hosts.length; i++) {
                    var host = available_hosts[i];
                    string_list.append(host.get_display_name());
                }
                
                // Add "Custom" option at the end
                string_list.append(_("Custom"));
                
                hostname_combo.model = string_list;
                hostname_combo.selected = 0; // Select first host by default
                
                // Setup hostname combo selection handler
                hostname_combo.notify["selected"].connect(on_hostname_combo_changed);
                
            } catch (Error e) {
                warning("Failed to load SSH config: %s", e.message);
                // Just add "Custom" option if config loading fails
                string_list.append(_("Custom"));
                hostname_combo.model = string_list;
                hostname_combo.selected = 0;
                hostname_combo.notify["selected"].connect(on_hostname_combo_changed);
            }
        });
    }
    
    private void setup_auth_method_combo() {
        var string_list = new Gtk.StringList(null);
        string_list.append(_("SSH Key"));
        string_list.append(_("Password"));
        string_list.append(_("SSH Agent"));
        auth_method_row.model = string_list;
        auth_method_row.selected = 0;
        
        auth_method_row.notify["selected"].connect(() => {
            update_auth_method_visibility();
            update_auth_method();
        });
    }
    
    private void setup_ssh_key_combo() {
        try {
            // Get all SSH keys in the ~/.ssh directory
            KeyScanner.scan_ssh_directory.begin (null, (obj, res) => {
                try {
                    var keys = KeyScanner.scan_ssh_directory.end (res);
                    
                    // Store keys for later reference
                    available_keys = new GenericArray<SSHKey> ();
                    
                    var model = new Gtk.StringList (null);
                    // NOTE: Not adding "None (use default)" option for diagnostics
                    
                    // Add each SSH key as an option
                    keys.foreach ((key) => {
                        available_keys.add (key);
                        var display_name = key.get_display_name ();
                        if (key.comment != null && key.comment.strip () != "") {
                            display_name += @" ($(key.comment))";
                        }
                        
                        // Add to ComboRow model
                        model.append (display_name);
                    });
                    
                    ssh_key_combo.model = model;
                    ssh_key_combo.selected = 0;
                    
                } catch (Error e) {
                    warning ("Failed to load SSH keys: %s", e.message);
                    
                    // Fallback: show error message
                    var model = new Gtk.StringList (null);
                    model.append (_("No keys found"));
                    ssh_key_combo.model = model;
                    ssh_key_combo.selected = 0;
                }
            });
        } catch (Error e) {
            warning ("Failed to start SSH key scan: %s", e.message);
        }
    }
    
    private void setup_ssh_agent_combo() {
        var string_list = new Gtk.StringList(null);
        
        // Load SSH agent keys
        ssh_agent.get_loaded_keys.begin((obj, res) => {
            try {
                available_agent_keys = ssh_agent.get_loaded_keys.end(res);
                
                // Clear and repopulate the string list
                string_list = new Gtk.StringList(null);
                if (available_agent_keys.length == 0) {
                    string_list.append(_("No keys loaded in agent"));
                } else {
                    for (int i = 0; i < available_agent_keys.length; i++) {
                        var agent_key = available_agent_keys[i];
                        var key_name = agent_key.comment.length > 0 ? agent_key.comment : agent_key.key_type;
                        string_list.append(key_name);
                    }
                }
                
                ssh_agent_combo.model = string_list;
                if (string_list.get_n_items() > 0) {
                    ssh_agent_combo.selected = 0;
                }
                
            } catch (Error e) {
                string_list.append(_("Agent not available"));
                ssh_agent_combo.model = string_list;
            }
        });
    }
    
    private void on_hostname_combo_changed() {
        // Show custom hostname entry if "Custom" is selected (last item)
        var is_custom = hostname_combo.selected == (int)(hostname_combo.model.get_n_items() - 1);
        custom_hostname_entry.visible = is_custom;
        validate_form();
    }
    
    private void update_auth_method_visibility() {
        var selected = auth_method_row.selected;
        
        // Show/hide UI elements based on auth method
        ssh_key_combo.visible = (selected == 0); // SSH Key
        password_entry.visible = (selected == 1); // Password  
        ssh_agent_combo.visible = (selected == 2); // SSH Agent
        
        // Refresh SSH agent keys if agent is selected
        if (selected == 2) {
            setup_ssh_agent_combo();
        }
    }
    
    private void update_auth_method() {
        switch (auth_method_row.selected) {
            case 0:
                config.auth_method = "key";
                // Update selected SSH key path
                if (ssh_key_combo.selected >= 0 && ssh_key_combo.selected < available_keys.length) {
                    var key = available_keys[ssh_key_combo.selected];
                    selected_ssh_key_path = key.private_path.get_path();
                }
                break;
            case 1:
                config.auth_method = "password";
                selected_ssh_key_path = "";
                break;
            case 2:
                config.auth_method = "agent";
                selected_ssh_key_path = "";
                break;
        }
    }
    
    private void on_template_changed() {
        // Map template selection to diagnostic type
        var selected = template_selection_row.selected;
        switch (selected) {
            case 0:
                diagnostic_type = DiagnosticType.CONNECTION_TEST;
                break;
            case 1:
                diagnostic_type = DiagnosticType.PERFORMANCE_TEST;
                break;
            case 2:
                diagnostic_type = DiagnosticType.SECURITY_AUDIT;
                break;
            case 3:
                diagnostic_type = DiagnosticType.PROTOCOL_ANALYSIS;
                break;
            case 4:
                diagnostic_type = DiagnosticType.TUNNEL_TEST;
                break;
            case 5:
                diagnostic_type = DiagnosticType.PERMISSION_CHECK;
                break;
            case 6:
            default:
                diagnostic_type = DiagnosticType.CONNECTION_TEST; // Custom defaults to connection test
                break;
        }
        
        // Recreate config with new type
        config = new DiagnosticConfiguration.with_type(diagnostic_type);
        
        // Update form for new type
        setup_form_for_type();
        validate_form();
    }
    
    private void setup_form_for_type() {
        window_title.title = _("Configure %s").printf(get_type_display_name());
        name_entry.text = config.name;
        description_entry.text = config.description;
        
        // Set test options based on type defaults
        test_basic_connection_switch.active = config.test_basic_connection;
        test_dns_resolution_switch.active = config.test_dns_resolution;
        test_protocol_detection_switch.active = config.test_protocol_detection;
        test_performance_switch.active = config.test_performance;
        test_tunnel_capabilities_switch.active = config.test_tunnel_capabilities;
        test_permissions_switch.active = config.test_permissions;
        
        // Hide connection settings for certain types if not needed
        switch (diagnostic_type) {
            case DiagnosticType.PROTOCOL_ANALYSIS:
                // Protocol analysis may not need full connection
                break;
            default:
                // Most diagnostics need connection settings
                break;
        }
    }
    
    private string get_type_display_name() {
        switch (diagnostic_type) {
            case DiagnosticType.CONNECTION_TEST:
                return _("Connection Test");
            case DiagnosticType.PERFORMANCE_TEST:
                return _("Performance Test");
            case DiagnosticType.SECURITY_AUDIT:
                return _("Security Audit");
            case DiagnosticType.PROTOCOL_ANALYSIS:
                return _("Protocol Analysis");
            case DiagnosticType.TUNNEL_TEST:
                return _("Tunnel Test");
            case DiagnosticType.PERMISSION_CHECK:
                return _("Permission Check");
            default:
                return _("Diagnostic");
        }
    }
    
    private void set_hostname_from_string(string hostname) {
        // Find matching host in available_hosts
        for (int i = 0; i < available_hosts.length; i++) {
            var host = available_hosts[i];
            if (host.hostname == hostname || host.name == hostname) {
                hostname_combo.selected = i;
                return;
            }
        }
        
        // If not found, select "Custom" option (last item) and set custom hostname
        hostname_combo.selected = (int)(hostname_combo.model.get_n_items() - 1);
        custom_hostname_entry.text = hostname;
        custom_hostname_entry.visible = true;
    }
    
    private void set_ssh_key_from_path(string key_path) {
        for (int i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            if (key.private_path.get_path() == key_path) {
                ssh_key_combo.selected = i;
                return;
            }
        }
    }
    
    private string get_selected_hostname() {
        var selected = hostname_combo.selected;
        if (selected >= 0 && selected < available_hosts.length) {
            var host = available_hosts[selected];
            return host.hostname ?? host.name;
        }
        // Custom option selected - get from custom hostname entry
        if (custom_hostname_entry.visible) {
            return custom_hostname_entry.text.strip();
        }
        return "";
    }
    
    private void validate_form() {
        bool valid = get_selected_hostname().length > 0 && username_entry.text.length > 0;
        create_button.sensitive = valid;
    }
    
    private void on_save_clicked() {
        // Update configuration with form values
        config.name = name_entry.text.strip();
        config.description = description_entry.text.strip();
        config.hostname = get_selected_hostname();
        config.username = username_entry.text.strip();
        config.port = (int)port_row.value;
        config.ssh_key_path = selected_ssh_key_path;
        config.password = password_entry.text;
        config.timeout = (int)timeout_row.value;
        config.proxy_jump = proxy_jump_entry.text.strip();
        
        update_auth_method();
        
        // Update test options
        config.test_basic_connection = test_basic_connection_switch.active;
        config.test_dns_resolution = test_dns_resolution_switch.active;
        config.test_protocol_detection = test_protocol_detection_switch.active;
        config.test_performance = test_performance_switch.active;
        config.test_tunnel_capabilities = test_tunnel_capabilities_switch.active;
        config.test_permissions = test_permissions_switch.active;
        
        // Use custom name if provided, otherwise generate from connection
        if (config.name == "") {
            config.name = @"$(config.username)@$(config.hostname)";
        }
        
        if (config.description == "") {
            config.description = get_type_display_name();
        }
        
        bool auto_run = auto_run_switch.active;
        configuration_created(config, auto_run);
        close();
    }
}