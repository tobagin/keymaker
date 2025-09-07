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
    
    [GtkChild]
    private unowned Gtk.ScrolledWindow keys_scrolled_window;
    
    private SSHAgent ssh_agent;
    private GenericArray<SSHKey> available_keys;
    private GenericArray<SSHKey>? provided_keys;
    
    public SSHAgentDialog (Gtk.Window parent, GenericArray<SSHKey>? keys = null) {
        Object ();
        provided_keys = keys;
    }
    
    construct {
        ssh_agent = new SSHAgent ();
        available_keys = new GenericArray<SSHKey> ();
        
        setup_signals ();
        
        // Use provided keys or create empty array
        if (provided_keys != null) {
            available_keys = provided_keys;
        }
        
        // Check if GNOME Keyring is managing SSH keys
        bool has_gnome_keyring = detect_gnome_keyring ();
        
        // Load agent keys using synchronous method to avoid crashes
        try {
            load_agent_keys_sync ();
            // Set agent availability flag after successful load
            set_agent_available (true);
        } catch (Error e) {
            warning ("Failed to load agent keys: %s", e.message);
            show_error (e.message);
            set_agent_available (false);
        }
        
        // Configure Remove All button based on SSH agent type
        if (remove_all_button != null) {
            if (has_gnome_keyring) {
                // Disable Remove All button for GNOME Keyring users
                remove_all_button.visible = true;
                remove_all_button.sensitive = false;
                remove_all_button.tooltip_text = "Remove All is disabled because GNOME Keyring automatically reloads SSH keys. Use system settings to manage key auto-loading.";
            } else {
                remove_all_button.visible = false; // Will be shown when keys are loaded
            }
        }
    }
    
    private void setup_signals () {
        // Temporarily disable UI signal connections to test
        if (refresh_button != null) {
            refresh_button.clicked.connect (on_refresh_clicked);
        }
        if (add_key_button != null) {
            add_key_button.clicked.connect (on_add_key_clicked);
        }
        if (remove_all_button != null) {
            remove_all_button.clicked.connect (on_remove_all_clicked);
        }
        
        if (ssh_agent != null) {
            ssh_agent.agent_keys_changed.connect (on_agent_keys_changed);
        }
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
        
        if (main_stack != null && status_page != null) {
            main_stack.visible_child = status_page;
        }
        if (add_key_button != null) {
            add_key_button.sensitive = false;
        }
        if (remove_all_button != null) {
            remove_all_button.sensitive = false;
        }
    }
    
    private void show_no_keys_loaded () {
        status_page.title = "No Keys Loaded";
        status_page.description = "SSH agent is running but no keys are currently loaded. Add keys to enable SSH authentication.";
        status_page.icon_name = "dialog-information-symbolic";
        
        if (main_stack != null && status_page != null) {
            main_stack.visible_child = status_page;
        }
        if (add_key_button != null) {
            add_key_button.sensitive = true;
        }
        if (remove_all_button != null) {
            remove_all_button.sensitive = false;
        }
    }
    
    private void show_agent_keys (GenericArray<SSHAgent.AgentKey?> agent_keys) {
        clear_agent_keys_list ();
        
        for (int i = 0; i < agent_keys.length; i++) {
            var key = agent_keys[i];
            var row = create_agent_key_row (key);
            if (agent_keys_list != null) {
                agent_keys_list.append (row);
            }
        }
        
        main_stack.visible_child = keys_scrolled_window;
        add_key_button.sensitive = true;
        remove_all_button.sensitive = true;
    }
    
    private void show_error (string error_message) {
        status_page.title = "Error Loading Agent Keys";
        status_page.description = error_message;
        status_page.icon_name = "dialog-error-symbolic";
        
        if (main_stack != null && status_page != null) {
            main_stack.visible_child = status_page;
        }
        if (add_key_button != null) {
            add_key_button.sensitive = false;
        }
        if (remove_all_button != null) {
            remove_all_button.sensitive = false;
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
    
    // Synchronous version to avoid async subprocess crashes
    private void load_agent_keys_sync () throws Error {
        debug ("SSHAgentDialog: Loading agent keys synchronously");
        
        // Check if SSH agent is available by running ssh-add -l
        string stdout_output, stderr_output;
        int exit_status;
        
        string[] cmd = {"ssh-add", "-l", null};
        
        bool success = Process.spawn_sync (
            null, // working_directory
            cmd,
            null, // envp
            SpawnFlags.SEARCH_PATH,
            null, // child_setup
            out stdout_output,
            out stderr_output,
            out exit_status
        );
        
        if (!success) {
            throw new IOError.FAILED ("Failed to execute ssh-add command");
        }
        
        debug ("SSHAgentDialog: ssh-add -l exit status: %d", exit_status);
        debug ("SSHAgentDialog: stdout: %s", stdout_output);
        debug ("SSHAgentDialog: stderr: %s", stderr_output);
        
        if (exit_status == 0) {
            // Agent has keys loaded
            show_loaded_keys (stdout_output);
        } else if (exit_status == 1) {
            // Agent is running but no keys loaded
            show_no_keys_loaded ();
        } else {
            // Agent not available or other error
            throw new IOError.FAILED ("SSH agent not available: %s".printf (stderr_output.strip ()));
        }
    }
    
    private void show_loaded_keys (string ssh_add_output) {
        debug ("SSHAgentDialog: Showing loaded keys");
        
        // Clear existing keys list
        clear_agent_keys_list ();
        
        // Parse ssh-add -l output
        var lines = ssh_add_output.strip ().split ("\n");
        int key_count = 0;
        
        foreach (string line in lines) {
            if (line.strip () != "") {
                debug ("SSHAgentDialog: Processing agent key: %s", line);
                
                // Parse ssh-add -l output: "bits fingerprint comment (type)"
                var parts = line.strip ().split (" ");
                if (parts.length >= 2) {
                    string fingerprint = parts[1];
                    string comment = "";
                    
                    // Extract comment (everything after fingerprint)
                    if (parts.length > 2) {
                        var comment_parts = new string[parts.length - 2];
                        for (int i = 2; i < parts.length; i++) {
                            comment_parts[i-2] = parts[i];
                        }
                        comment = string.joinv (" ", comment_parts);
                    }
                    
                    // Create a row for the loaded key with proper key type detection
                    var row = new Adw.ActionRow ();
                    row.title = comment != "" ? comment : "SSH Key";
                    row.subtitle = fingerprint;
                    
                    // Detect key type from the line (last part in parentheses)
                    SSHKeyType key_type = SSHKeyType.RSA; // default
                    if (line.contains ("(ED25519)")) {
                        key_type = SSHKeyType.ED25519;
                    } else if (line.contains ("(ECDSA)")) {
                        key_type = SSHKeyType.ECDSA;
                    } else if (line.contains ("(RSA)")) {
                        key_type = SSHKeyType.RSA;
                    }
                    
                    // Add key type icon with same styling as main window
                    var key_icon = new Gtk.Image ();
                    switch (key_type) {
                        case SSHKeyType.ED25519:
                            // Green for ED25519 (most secure)
                            key_icon.icon_name = key_type.get_icon_name ();
                            key_icon.add_css_class ("success");
                            break;
                        case SSHKeyType.RSA:
                            // Blue/accent for RSA (good compatibility)
                            key_icon.icon_name = key_type.get_icon_name ();
                            key_icon.add_css_class ("accent");
                            break;
                        case SSHKeyType.ECDSA:
                            // Yellow/warning for ECDSA (compatibility issues)
                            key_icon.icon_name = key_type.get_icon_name ();
                            key_icon.add_css_class ("warning");
                            break;
                    }
                    row.add_prefix (key_icon);
                    
                    debug ("SSHAgentDialog: Created row for %s key: %s", key_type.to_string (), comment);
                    
                    if (agent_keys_list != null) {
                        agent_keys_list.append (row);
                        key_count++;
                    }
                }
            }
        }
        
        // Show the keys page
        if (keys_scrolled_window != null && main_stack != null) {
            main_stack.visible_child = keys_scrolled_window;
        }
        if (add_key_button != null) {
            add_key_button.sensitive = true;
        }
        if (remove_all_button != null) {
            debug ("SSHAgentDialog: Setting Remove All button visible=%s for %d keys", (key_count > 0).to_string (), key_count);
            
            // Show button only if keys are loaded
            remove_all_button.visible = (key_count > 0);
            
            // Enable only if not using GNOME Keyring
            bool has_gnome_keyring = detect_gnome_keyring ();
            if (has_gnome_keyring) {
                remove_all_button.sensitive = false;
                remove_all_button.tooltip_text = "Remove All is disabled because GNOME Keyring automatically reloads SSH keys. Use system settings to manage key auto-loading.";
            } else {
                remove_all_button.sensitive = true;
                remove_all_button.tooltip_text = "Remove all SSH keys from the agent";
            }
        } else {
            debug ("SSHAgentDialog: WARNING - remove_all_button is NULL!");
        }
        
        debug ("SSHAgentDialog: Displayed %d loaded keys", key_count);
    }
    
    
    private void on_refresh_clicked () {
        try {
            load_agent_keys_sync ();
        } catch (Error e) {
            warning ("Failed to refresh agent keys: %s", e.message);
            show_error (e.message);
        }
    }
    
    private void on_add_key_clicked () {
        var dialog = new AddKeyToAgentDialog ((Gtk.Window) this.get_root (), available_keys, ssh_agent);
        dialog.present (this);
    }
    
    private void on_remove_all_clicked () {
        // Skip operation if GNOME Keyring is detected (button should be disabled anyway)
        if (detect_gnome_keyring ()) {
            debug ("SSHAgentDialog: Remove All clicked but GNOME Keyring detected - operation skipped");
            return;
        }
        
        try {
            remove_all_keys_sync ();
            
            // Check immediately after removal to see if keys are still gone
            debug ("SSHAgentDialog: Checking keys immediately after removal...");
            check_agent_keys_immediately ();
            
            // Small delay to see if keys get auto-reloaded and inform user
            GLib.Timeout.add (500, () => {
                debug ("SSHAgentDialog: Checking keys 500ms after removal...");
                try {
                    // Check if keys are back (GNOME Keyring auto-reload)
                    string stdout_output, stderr_output;
                    int exit_status;
                    string[] cmd = {"ssh-add", "-l", null};
                    
                    bool success = Process.spawn_sync (
                        null, cmd, null, SpawnFlags.SEARCH_PATH,
                        null, out stdout_output, out stderr_output, out exit_status
                    );
                    
                    if (success && exit_status == 0 && stdout_output.strip () != "") {
                        // Keys were auto-reloaded - show user feedback
                        show_keyring_auto_reload_info ();
                    }
                    
                    load_agent_keys_sync ();
                } catch (Error e) {
                    warning ("Failed to refresh after delay: %s", e.message);
                }
                return false; // Don't repeat
            });
            
        } catch (Error e) {
            warning ("Failed to remove all keys: %s", e.message);
        }
    }
    
    private void on_agent_keys_changed () {
        load_agent_keys.begin ();
    }
    
    // Helper method to set agent availability flag
    private void set_agent_available (bool available) {
        // Access the private field via reflection-style access
        // Since we can't directly access private fields, we'll assume agent is available
        // when we can successfully run ssh-add -l
        debug ("SSHAgentDialog: Setting agent availability to %s", available.to_string ());
    }
    
    // Synchronous method to remove all keys from SSH agent
    private void remove_all_keys_sync () throws Error {
        debug ("SSHAgentDialog: Removing all keys synchronously");
        
        // First, let's check the SSH agent environment and diagnose the issue
        var ssh_auth_sock = Environment.get_variable ("SSH_AUTH_SOCK");
        var ssh_agent_pid = Environment.get_variable ("SSH_AGENT_PID");
        debug ("SSHAgentDialog: SSH_AUTH_SOCK = %s", ssh_auth_sock ?? "(null)");
        debug ("SSHAgentDialog: SSH_AGENT_PID = %s", ssh_agent_pid ?? "(null)");
        
        // Diagnose what SSH agents might be running on the host
        diagnose_ssh_agents ();
        
        string stdout_output, stderr_output;
        int exit_status;
        
        string[] cmd = {"ssh-add", "-D", null};
        
        bool success = Process.spawn_sync (
            null, // working_directory
            cmd,
            null, // use default environment
            SpawnFlags.SEARCH_PATH,
            null, // child_setup
            out stdout_output,
            out stderr_output,
            out exit_status
        );
        
        debug ("SSHAgentDialog: ssh-add -D exit status: %d", exit_status);
        debug ("SSHAgentDialog: ssh-add -D stdout: %s", stdout_output.strip ());
        debug ("SSHAgentDialog: ssh-add -D stderr: %s", stderr_output.strip ());
        
        if (!success) {
            throw new IOError.FAILED ("Failed to execute ssh-add -D command");
        }
        
        if (exit_status != 0) {
            throw new IOError.FAILED ("ssh-add -D failed: %s".printf (stderr_output.strip ()));
        }
        
        debug ("SSHAgentDialog: ssh-add -D command completed successfully");
    }
    
    // Quick check of agent keys without updating UI
    private void check_agent_keys_immediately () {
        try {
            string stdout_output, stderr_output;
            int exit_status;
            
            string[] cmd = {"ssh-add", "-l", null};
            
            bool success = Process.spawn_sync (
                null, cmd, null, SpawnFlags.SEARCH_PATH,
                null, out stdout_output, out stderr_output, out exit_status
            );
            
            if (success) {
                debug ("SSHAgentDialog: Immediate check - exit status: %d", exit_status);
                debug ("SSHAgentDialog: Immediate check - stdout: %s", stdout_output.strip ());
                if (exit_status == 1) {
                    debug ("SSHAgentDialog: Keys successfully removed - agent has no keys");
                } else if (exit_status == 0) {
                    debug ("SSHAgentDialog: WARNING - Keys are still present after removal!");
                }
            }
        } catch (Error e) {
            debug ("SSHAgentDialog: Error in immediate check: %s", e.message);
        }
    }
    
    // Find the real SSH agent socket (not Flatpak proxy)
    private string? find_real_ssh_agent_socket () {
        try {
            // Common locations for SSH agent sockets
            var user_runtime_dir = Environment.get_variable ("XDG_RUNTIME_DIR");
            if (user_runtime_dir != null) {
                // GNOME keyring SSH agent
                var keyring_socket = Path.build_filename (user_runtime_dir, "keyring", "ssh");
                if (File.new_for_path (keyring_socket).query_exists ()) {
                    debug ("SSHAgentDialog: Found GNOME keyring SSH socket: %s", keyring_socket);
                    return keyring_socket;
                }
                
                // systemd SSH agent
                var systemd_socket = Path.build_filename (user_runtime_dir, "ssh-agent.socket");
                if (File.new_for_path (systemd_socket).query_exists ()) {
                    debug ("SSHAgentDialog: Found systemd SSH socket: %s", systemd_socket);
                    return systemd_socket;
                }
                
                // Generic pattern: /run/user/UID/ssh-*
                var runtime_dir = File.new_for_path (user_runtime_dir);
                try {
                    var enumerator = runtime_dir.enumerate_children ("standard::name,standard::type", 
                                                                    FileQueryInfoFlags.NONE);
                    FileInfo? info;
                    while ((info = enumerator.next_file ()) != null) {
                        var name = info.get_name ();
                        if (name.has_prefix ("ssh-") && info.get_file_type () == FileType.SPECIAL) {
                            var socket_path = Path.build_filename (user_runtime_dir, name);
                            debug ("SSHAgentDialog: Found SSH socket: %s", socket_path);
                            return socket_path;
                        }
                    }
                } catch (Error e) {
                    debug ("SSHAgentDialog: Error scanning runtime directory: %s", e.message);
                }
            }
            
            // Try /tmp/ssh-* pattern (less common but possible)
            var tmp_dir = File.new_for_path ("/tmp");
            try {
                var enumerator = tmp_dir.enumerate_children ("standard::name,standard::type", 
                                                            FileQueryInfoFlags.NONE);
                FileInfo? info;
                while ((info = enumerator.next_file ()) != null) {
                    var name = info.get_name ();
                    if (name.has_prefix ("ssh-") && info.get_file_type () == FileType.DIRECTORY) {
                        // Look for agent.* files in ssh-* directories
                        var ssh_dir = tmp_dir.get_child (name);
                        var ssh_enumerator = ssh_dir.enumerate_children ("standard::name,standard::type", 
                                                                        FileQueryInfoFlags.NONE);
                        FileInfo? ssh_info;
                        while ((ssh_info = ssh_enumerator.next_file ()) != null) {
                            var ssh_name = ssh_info.get_name ();
                            if (ssh_name.has_prefix ("agent.") && ssh_info.get_file_type () == FileType.SPECIAL) {
                                var socket_path = Path.build_filename ("/tmp", name, ssh_name);
                                debug ("SSHAgentDialog: Found SSH socket in /tmp: %s", socket_path);
                                return socket_path;
                            }
                        }
                    }
                }
            } catch (Error e) {
                debug ("SSHAgentDialog: Error scanning /tmp directory: %s", e.message);
            }
            
        } catch (Error e) {
            debug ("SSHAgentDialog: Error finding real SSH agent socket: %s", e.message);
        }
        
        debug ("SSHAgentDialog: No real SSH agent socket found");
        return null;
    }
    
    // Diagnose SSH agent situation to understand the issue
    private void diagnose_ssh_agents () {
        debug ("SSHAgentDialog: === SSH Agent Diagnosis ===");
        
        // Check if we can access /proc to see running processes
        try {
            var proc_dir = File.new_for_path ("/proc");
            if (proc_dir.query_exists ()) {
                debug ("SSHAgentDialog: Can access /proc directory");
            } else {
                debug ("SSHAgentDialog: Cannot access /proc directory");
            }
        } catch (Error e) {
            debug ("SSHAgentDialog: Error accessing /proc: %s", e.message);
        }
        
        // Try to list SSH agent processes using ps
        try {
            string stdout_output, stderr_output;
            int exit_status;
            
            string[] cmd = {"ps", "aux", null};
            bool success = Process.spawn_sync (
                null, cmd, null, SpawnFlags.SEARCH_PATH,
                null, out stdout_output, out stderr_output, out exit_status
            );
            
            if (success && exit_status == 0) {
                var lines = stdout_output.split ("\n");
                foreach (string line in lines) {
                    if ("ssh-agent" in line || "gnome-keyring" in line) {
                        debug ("SSHAgentDialog: Found agent process: %s", line.strip ());
                    }
                }
            } else {
                debug ("SSHAgentDialog: Cannot run 'ps aux' command (exit: %d)", exit_status);
            }
        } catch (Error e) {
            debug ("SSHAgentDialog: Error running ps command: %s", e.message);
        }
        
        // Check what the Flatpak proxy is actually connected to
        var ssh_auth_sock = Environment.get_variable ("SSH_AUTH_SOCK");
        if (ssh_auth_sock == "/run/flatpak/ssh-auth") {
            debug ("SSHAgentDialog: Using Flatpak SSH proxy");
            
            // Try to get more info about the proxy
            try {
                var proxy_file = File.new_for_path (ssh_auth_sock);
                if (proxy_file.query_exists ()) {
                    var info = proxy_file.query_info ("standard::*", FileQueryInfoFlags.NONE);
                    debug ("SSHAgentDialog: Proxy file type: %s", info.get_file_type ().to_string ());
                }
            } catch (Error e) {
                debug ("SSHAgentDialog: Error checking proxy file: %s", e.message);
            }
        }
        
        debug ("SSHAgentDialog: === End SSH Agent Diagnosis ===");
    }
    
    // Show information about GNOME Keyring auto-reload behavior
    private void show_keyring_auto_reload_info () {
        debug ("SSHAgentDialog: Keys were auto-reloaded by GNOME Keyring");
        
        // For now, just log this information
        // In a future version, we could show this info in the UI
        // The user will see that keys are still there after clicking Remove All
        
        debug ("SSHAgentDialog: GNOME Keyring automatically restored SSH keys after removal");
    }
    
    // Detect if GNOME Keyring is managing SSH keys
    private bool detect_gnome_keyring () {
        var ssh_auth_sock = Environment.get_variable ("SSH_AUTH_SOCK");
        
        // Check if SSH_AUTH_SOCK points to GNOME Keyring
        if (ssh_auth_sock != null && "/keyring/ssh" in ssh_auth_sock) {
            debug ("SSHAgentDialog: Detected GNOME Keyring SSH agent: %s", ssh_auth_sock);
            return true;
        }
        
        // Also check if gnome-keyring-daemon is running
        try {
            string stdout_output, stderr_output;
            int exit_status;
            
            string[] cmd = {"pgrep", "-f", "gnome-keyring-daemon", null};
            bool success = Process.spawn_sync (
                null, cmd, null, SpawnFlags.SEARCH_PATH,
                null, out stdout_output, out stderr_output, out exit_status
            );
            
            if (success && exit_status == 0 && stdout_output.strip () != "") {
                debug ("SSHAgentDialog: Found gnome-keyring-daemon process");
                return true;
            }
        } catch (Error e) {
            debug ("SSHAgentDialog: Error checking for gnome-keyring process: %s", e.message);
        }
        
        debug ("SSHAgentDialog: GNOME Keyring not detected");
        return false;
    }
}