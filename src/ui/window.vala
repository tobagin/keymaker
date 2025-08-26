/*
 * Key Maker - Main Application Window
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/window.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/window.ui")]
#endif
public class KeyMaker.Window : Adw.ApplicationWindow {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Gtk.Button generate_button;
    
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    
    [GtkChild]
    private unowned Gtk.MenuButton menu_button;
    
    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;
    
    [GtkChild]
    private unowned Gtk.Box main_box;
    
    private KeyMaker.KeyListWidget key_list;
    private GenericArray<SSHKey> ssh_keys;
    private Settings settings;
    
    
    construct {
        // Initialize settings
#if DEVELOPMENT
        settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
        settings = new Settings ("io.github.tobagin.keysmith");
#endif
        
        // Initialize key list
        ssh_keys = new GenericArray<SSHKey> ();
        
        // Create key list widget and add to main box
        key_list = new KeyMaker.KeyListWidget ();
        main_box.append (key_list);
        
        // Setup actions and signals
        setup_actions ();
        setup_signals ();
        
        // Load keys on startup using simple timeout approach
        Timeout.add_seconds (1, () => {
            load_keys_simple ();
            return false;
        });
    }
    
    public Window (KeyMaker.Application app) {
        Object (application: app);
    }
    
    private void setup_actions () {
        // Generate key action
        var generate_action = new SimpleAction ("generate-key", null);
        generate_action.activate.connect (on_generate_key_action);
        add_action (generate_action);
        
        // Refresh action
        var refresh_action = new SimpleAction ("refresh", null);
        refresh_action.activate.connect (on_refresh_action);
        add_action (refresh_action);
        
        // Help action
        var help_action = new SimpleAction ("help", null);
        help_action.activate.connect (on_help_action);
        add_action (help_action);
    }
    
    private void setup_signals () {
        // Key list signals
        key_list.key_copy_requested.connect (on_key_copy_requested);
        key_list.key_delete_requested.connect (on_key_delete_requested);
        key_list.key_details_requested.connect (on_key_details_requested);
        key_list.key_passphrase_change_requested.connect (on_key_passphrase_change_requested);
        key_list.key_copy_id_requested.connect (on_key_copy_id_requested);
    }
    
    public void on_generate_key_action () {
        var dialog = new KeyMaker.GenerateKeyDialog (this);
        dialog.key_generated.connect (on_key_generated);
        dialog.present (this);
    }
    
    public void on_refresh_action () {
        load_keys_simple ();
    }
    
    public void on_help_action () {
        var dialog = new KeyMaker.HelpDialog (this);
        dialog.present ();
    }
    
    private void on_key_copy_requested (SSHKey ssh_key) {
        copy_public_key_to_clipboard (ssh_key);
    }
    
    private void on_key_delete_requested (SSHKey ssh_key) {
        var confirm_deletions = settings.get_boolean ("confirm-deletions");
        
        if (confirm_deletions) {
            // Show confirmation dialog
            var dialog = new KeyMaker.DeleteKeyDialog (this, ssh_key);
            dialog.key_deleted.connect (on_key_deleted);
            dialog.present ();
        } else {
            // Delete directly without confirmation
            delete_key_directly.begin (ssh_key);
        }
    }
    
    private void on_key_details_requested (SSHKey ssh_key) {
        var dialog = new KeyMaker.KeyDetailsDialog (this, ssh_key);
        dialog.present (this);
    }
    
    private void on_key_passphrase_change_requested (SSHKey ssh_key) {
        var dialog = new KeyMaker.ChangePassphraseDialog (this, ssh_key);
        dialog.passphrase_changed.connect (on_passphrase_changed);
        dialog.present (this);
    }
    
    private void on_key_copy_id_requested (SSHKey ssh_key) {
        var dialog = new KeyMaker.CopyIdDialog (this, ssh_key);
        dialog.present (this);
    }
    
    private void on_key_generated (SSHKey new_key) {
        // Add the new key to our list
        ssh_keys.add (new_key);
        key_list.add_key (new_key);
        
        show_toast (_("SSH key '%s' generated successfully").printf (new_key.get_display_name ()));
    }
    
    private async void delete_key_directly (SSHKey ssh_key) {
        try {
            // Delete the key pair directly
            yield SSHOperations.delete_key_pair (ssh_key);
            
            // Remove from UI and show success message
            on_key_deleted (ssh_key);
            
        } catch (KeyMakerError e) {
            // Show error toast on failure
            show_toast (_("Failed to delete key: %s").printf (e.message));
        }
    }
    
    private void on_key_deleted (SSHKey deleted_key) {
        // Remove the key from our list
        for (int i = 0; i < ssh_keys.length; i++) {
            if (ssh_keys[i] == deleted_key) {
                ssh_keys.remove_index (i);
                break;
            }
        }
        
        key_list.remove_key (deleted_key);
        show_toast (_("SSH key '%s' deleted successfully").printf (deleted_key.get_display_name ()));
    }
    
    private void on_passphrase_changed (SSHKey updated_key) {
        show_toast (_("Passphrase changed for key '%s'").printf (updated_key.get_display_name ()));
    }
    
    
    private void load_keys_simple () {
        debug ("Starting simple file-based key scanning...");
        
        try {
            // Clear existing keys
            ssh_keys.remove_range (0, ssh_keys.length);
            key_list.clear ();
            
            // Simple file-based SSH key detection - no subprocesses at all
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            
            if (!ssh_dir.query_exists ()) {
                debug ("SSH directory does not exist");
                key_list.show_empty_state ();
                return;
            }
            
            debug ("Scanning SSH directory: %s", ssh_dir.get_path ());
            
            try {
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
                            debug ("Found SSH key pair: %s", filename);
                            
                            try {
                                // Get file modification time
                                var file_info = private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                                var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                                var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                                
                                // Detect key type and other properties
                                var key_type = SSHOperations.get_key_type_sync (private_path);
                                var fingerprint = SSHOperations.get_fingerprint_sync (private_path);
                                var bit_size = SSHOperations.extract_bit_size_sync (private_path);
                                
                                // Extract comment from public key file if available
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
                                    debug ("Could not read comment from public key: %s", e.message);
                                }
                                
                                // Create SSH key object with real data
                                var ssh_key = new SSHKey (
                                    private_path,
                                    public_path,
                                    key_type,
                                    fingerprint,
                                    comment,
                                    last_modified,
                                    bit_size ?? -1
                                );
                                
                                ssh_keys.add (ssh_key);
                                key_list.add_key (ssh_key);
                                key_count++;
                                
                            } catch (Error key_error) {
                                debug ("Failed to create SSH key object for %s: %s", filename, key_error.message);
                                continue;
                            }
                        }
                    }
                }
                
                if (key_count == 0) {
                    debug ("No SSH key pairs found");
                    key_list.show_empty_state ();
                } else {
                    debug ("Successfully loaded %d SSH key pairs", key_count);
                }
                
            } catch (Error enum_error) {
                debug ("Failed to enumerate SSH directory: %s", enum_error.message);
                key_list.show_empty_state ();
            }
            
        } catch (Error e) {
            debug ("File-based SSH scanning failed: %s", e.message);
            show_toast (_("Failed to scan SSH keys: %s").printf (e.message));
            key_list.show_empty_state ();
        }
    }
    
    private void copy_public_key_to_clipboard (SSHKey ssh_key) {
        try {
            var content = SSHOperations.get_public_key_content (ssh_key);
            
            var clipboard = get_clipboard ();
            clipboard.set_text (content);
            
            show_toast (_("Public key copied to clipboard"));
            
        } catch (KeyMakerError e) {
            show_toast (_("Failed to copy public key: %s").printf (e.message));
            warning ("Failed to copy public key: %s", e.message);
        }
    }
    
    private void show_toast (string message) {
        var toast = new Adw.Toast (message) {
            timeout = 3
        };
        toast_overlay.add_toast (toast);
    }
    
}