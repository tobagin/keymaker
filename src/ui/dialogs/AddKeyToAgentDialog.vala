/*
 * SSHer - Add Key to Agent Dialog
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
    
    // Cancel button removed from UI
    
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
        // cancel_button.clicked.connect (on_cancel_clicked); // Removed cancel button
        keys_list.row_selected.connect (on_key_selected);
        enable_timeout_row.notify["active"].connect (on_timeout_toggled);
    }
    
    private void populate_keys_list () {
        debug ("AddKeyToAgentDialog: Starting to populate keys list directly");
        
        // Initialize the array if it's null
        if (available_keys == null) {
            debug ("AddKeyToAgentDialog: Initializing available_keys array");
            available_keys = new GenericArray<SSHKey> ();
        } else {
            // Clear existing keys
            available_keys.remove_range (0, available_keys.length);
        }
        
        // Load keys directly using the same approach as main window
        load_keys_directly ();
        
        debug ("AddKeyToAgentDialog: Loaded %u keys directly", available_keys.length);
        
        // Now populate the UI with loaded keys
        for (int i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            debug ("AddKeyToAgentDialog: Processing key: %s", key.get_display_name ());
            
            // Skip if key is already loaded in agent (using synchronous check)
            bool is_loaded = is_key_loaded_in_agent_sync (key.fingerprint);
            debug ("AddKeyToAgentDialog: Key %s is loaded in agent: %s", key.get_display_name (), is_loaded.to_string ());
            if (is_loaded) {
                continue;
            }
            
            debug ("AddKeyToAgentDialog: Adding key row for: %s", key.get_display_name ());
            var row = create_key_row (key);
            keys_list.append (row);
        }
        
        debug ("AddKeyToAgentDialog: Finished populating keys list");
    }
    
    private void load_keys_directly () {
        debug ("AddKeyToAgentDialog: Starting direct key loading");
        
        try {
            // Simple file-based SSH key detection - same as main window
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            
            if (!ssh_dir.query_exists ()) {
                debug ("AddKeyToAgentDialog: SSH directory does not exist");
                return;
            }
            
            debug ("AddKeyToAgentDialog: Scanning SSH directory: %s", ssh_dir.get_path ());
            
            var enumerator = ssh_dir.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
            var key_count = 0;
            
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                var filename = info.get_name ();
                
                // Look for private key files (no .pub extension)
                if (filename.has_prefix ("id_") && !filename.has_suffix (".pub")) {
                    var private_path = ssh_dir.get_child (filename);
                    var public_path = File.new_for_path (private_path.get_path () + ".pub");
                    
                    // Check if both private and public key exist
                    if (private_path.query_exists () && public_path.query_exists ()) {
                        debug ("AddKeyToAgentDialog: Found SSH key pair: %s", filename);
                        
                        try {
                            // Get file modification time
                            var file_info = private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                            var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                            var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                            
                            // Detect key type and other properties
                            var key_type = SSHOperations.get_key_type_sync (private_path);
                            var fingerprint = SSHOperations.get_fingerprint_sync (private_path);
                            var bit_size = SSHOperations.extract_bit_size_sync (private_path);
                            
                            // Extract comment from public key file
                            string? comment = null;
                            try {
                                uint8[] contents;
                                public_path.load_contents (null, out contents, null);
                                var public_key_content = ((string) contents).strip ();
                                var parts = public_key_content.split (" ");
                                if (parts.length >= 3) {
                                    comment = parts[2]; // Third part is usually the comment
                                }
                            } catch (Error e) {
                                debug ("AddKeyToAgentDialog: Error reading comment: %s", e.message);
                            }
                            
                            // Create SSH key object
                            var ssh_key = new SSHKey (
                                private_path,
                                public_path,
                                key_type,
                                fingerprint,
                                comment,
                                last_modified,
                                bit_size
                            );
                            
                            available_keys.add (ssh_key);
                            key_count++;
                            
                            debug ("AddKeyToAgentDialog: Successfully loaded key: %s", filename);
                            
                        } catch (Error e) {
                            debug ("AddKeyToAgentDialog: Error loading key %s: %s", filename, e.message);
                        }
                    }
                }
            }
            
            debug ("AddKeyToAgentDialog: Successfully loaded %d SSH key pairs", key_count);
            
        } catch (Error e) {
            debug ("AddKeyToAgentDialog: Error during key loading: %s", e.message);
        }
    }
    
    private Gtk.Widget create_key_row (SSHKey key) {
        var row = new Adw.ActionRow ();
        row.title = key.comment != null && key.comment != "" ? key.comment : key.private_path.get_basename ();
        row.subtitle = @"$(key.key_type.to_string ()) - $(key.fingerprint)";
        
        // Add key type icon - using same icons as main window
        var type_icon = new Gtk.Image ();
        switch (key.key_type) {
            case SSHKeyType.ED25519:
                // Green for ED25519 (most secure)
                type_icon.icon_name = key.key_type.get_icon_name ();
                type_icon.add_css_class ("success");
                break;
            case SSHKeyType.RSA:
                // Blue/accent for RSA (good compatibility)
                type_icon.icon_name = key.key_type.get_icon_name ();
                type_icon.add_css_class ("accent");
                break;
            case SSHKeyType.ECDSA:
                // Yellow/warning for ECDSA (compatibility issues)
                type_icon.icon_name = key.key_type.get_icon_name ();
                type_icon.add_css_class ("warning");
                break;
        }
        row.add_prefix (type_icon);
        
        // Store key reference
        row.set_data ("ssh-key", key);
        
        return row;
    }
    
    private void on_key_selected (Gtk.ListBoxRow? row) {
        if (row != null) {
            selected_key = (SSHKey?) row.get_data<SSHKey> ("ssh-key");
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
            
            // Use synchronous version to avoid async subprocess crashes
            add_key_to_agent_sync (selected_key.private_path, timeout);
            
            close ();
            
        } catch (Error e) {
            // Show error message
            warning ("Failed to add key to agent: %s", e.message);
            
            // Reset button state
            add_button.sensitive = true;
            add_button.child = new Gtk.Label ("Add to Agent");
        }
    }
    
    // Synchronous version to avoid async subprocess crashes
    private void add_key_to_agent_sync (File private_key_path, int? timeout_seconds = null) throws Error {
        debug ("AddKeyToAgentDialog: Adding key to agent synchronously: %s", private_key_path.get_path ());
        
        var cmd_list = new GenericArray<string> ();
        cmd_list.add ("ssh-add");
        
        if (timeout_seconds != null && timeout_seconds > 0) {
            cmd_list.add ("-t");
            cmd_list.add (timeout_seconds.to_string ());
        }
        
        cmd_list.add (private_key_path.get_path ());
        
        string[] cmd = new string[cmd_list.length + 1];
        for (int i = 0; i < cmd_list.length; i++) {
            cmd[i] = cmd_list[i];
        }
        cmd[cmd_list.length] = null;
        
        debug ("AddKeyToAgentDialog: Executing command: %s", string.joinv (" ", cmd));
        
        // Use synchronous subprocess to avoid crashes
        string stdout_output, stderr_output;
        int exit_status;
        
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
        
        if (exit_status != 0) {
            debug ("AddKeyToAgentDialog: ssh-add failed with exit status %d", exit_status);
            debug ("AddKeyToAgentDialog: stderr: %s", stderr_output);
            throw new IOError.FAILED ("ssh-add failed: %s".printf (stderr_output.strip ()));
        }
        
        debug ("AddKeyToAgentDialog: Successfully added key to SSH agent");
    }
    
    // Synchronous method to check if a key is already loaded in SSH agent
    private bool is_key_loaded_in_agent_sync (string fingerprint) {
        try {
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
            
            if (!success || exit_status != 0) {
                // Agent not available or no keys loaded
                return false;
            }
            
            // Check if our fingerprint is in the output
            return stdout_output.contains (fingerprint);
            
        } catch (Error e) {
            debug ("AddKeyToAgentDialog: Error checking if key is loaded: %s", e.message);
            return false;
        }
    }
    
    private void on_cancel_clicked () {
        close ();
    }
}