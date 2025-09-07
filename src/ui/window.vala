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
    private unowned Gtk.MenuButton menu_button;
    
    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;
    
    [GtkChild]
    private unowned Gtk.Box main_box;
    
    private KeyMaker.KeyListWidget key_list;
    private GenericArray<SSHKey> ssh_keys;
    private Settings settings;
    private Cancellable? refresh_cancellable;
    
    
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
        
        // Initial refresh is scheduled by Application after presenting the window
    }
    
    public Window (KeyMaker.Application app) {
        Object (application: app);
    }
    
    private void setup_actions () {
        // Generate key action
        var generate_action = new SimpleAction ("generate-key", null);
        generate_action.activate.connect (on_generate_key_action);
        add_action (generate_action);
        
        // Add existing key action
        var add_existing_action = new SimpleAction ("add-existing-key", null);
        add_existing_action.activate.connect (on_add_existing_key_action);
        add_action (add_existing_action);
        
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
        dialog.key_list_needs_refresh.connect (on_key_list_refresh_needed);
        dialog.present (this);
    }
    
    public void on_add_existing_key_action () {
        var dialog = new Gtk.FileDialog ();
        dialog.title = _("Add Existing SSH Key");
        dialog.modal = true;
        
        // Add filter for SSH private keys
        var filter = new Gtk.FileFilter ();
        filter.name = _("SSH Private Keys");
        filter.add_pattern ("id_*");
        filter.add_pattern ("*_rsa");
        filter.add_pattern ("*_ed25519");
        filter.add_pattern ("*_ecdsa");
        filter.add_pattern ("*_dsa"); // Legacy support
        
        var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));
        filter_list.append (filter);
        dialog.set_filters (filter_list);
        
        dialog.open.begin (this, null, (obj, res) => {
            try {
                var file = dialog.open.end (res);
                add_existing_key_async.begin (file);
            } catch (Error e) {
                // User cancelled or error occurred
            }
        });
    }
    
    public void on_refresh_action () {
        refresh_keys ();
    }
    
    private void on_key_list_refresh_needed () {
        refresh_keys ();
    }
    
    public void on_help_action () {
        KeyMaker.HelpDialog.show (this);
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
            dialog.show.begin ();
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
        // Refresh the key list to ensure everything is properly updated
        // This handles any filesystem changes that might have occurred
        refresh_keys ();
        
        show_toast (_("SSH key '%s' generated successfully").printf (new_key.get_display_name ()));
    }
    
    public GenericArray<SSHKey> get_ssh_keys () {
        return ssh_keys;
    }

    // Public entry to trigger an async refresh from other components
    public void refresh_keys () {
        refresh_key_list_async.begin ();
    }

    private async void refresh_key_list_async () {
        // Cancel any in-flight scan
        if (refresh_cancellable != null) {
            try { refresh_cancellable.cancel (); } catch (Error e) { }
        }
        refresh_cancellable = new Cancellable ();

        debug ("Window: starting async key scan");
        try {
            var keys = yield KeyMaker.KeyScanner.scan_ssh_directory_with_cancellable (null, refresh_cancellable);

            // Replace current list
            ssh_keys.remove_range (0, ssh_keys.length);
            key_list.clear ();
            for (int i = 0; i < keys.length; i++) {
                ssh_keys.add (keys[i]);
                key_list.add_key (keys[i]);
            }

            if (keys.length == 0) {
                key_list.show_empty_state ();
            }

            debug ("Window: async key scan complete: %d keys", keys.length);
        } catch (IOError.CANCELLED e) {
            debug ("Window: key scan cancelled");
        } catch (KeyMakerError e) {
            show_toast (_("Failed to scan SSH keys: %s").printf (e.message));
            key_list.clear ();
            key_list.show_empty_state ();
        } catch (Error e) {
            show_toast (_("Failed to scan SSH keys: %s").printf (e.message));
            key_list.clear ();
            key_list.show_empty_state ();
        }
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
        // Refresh the key list to update button tooltips and UI state
        key_list.refresh_key (updated_key);
        show_toast (_("Passphrase changed for key '%s'").printf (updated_key.get_display_name ()));
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
    
    private async void add_existing_key_async (File key_file) {
        try {
            var ssh_dir = KeyMaker.Filesystem.ssh_dir ();
            var filename = key_file.get_basename ();
            var destination = ssh_dir.get_child (filename);
            
            // Check if key already exists in .ssh directory
            if (destination.query_exists ()) {
                show_toast (_("Key '%s' already exists in SSH directory").printf (filename));
                return;
            }
            
            // Copy the private key
            yield key_file.copy_async (destination, FileCopyFlags.NONE, Priority.DEFAULT, null, null);
            
            // Set proper permissions on private key
            KeyMaker.Filesystem.chmod_private (destination);
            
            // Check if corresponding public key exists and copy it
            var public_key_name = filename + ".pub";
            var source_public = key_file.get_parent ().get_child (public_key_name);
            
            if (source_public.query_exists ()) {
                var dest_public = ssh_dir.get_child (public_key_name);
                if (!dest_public.query_exists ()) {
                    yield source_public.copy_async (dest_public, FileCopyFlags.NONE, Priority.DEFAULT, null, null);
                    KeyMaker.Filesystem.chmod_public (dest_public);
                }
            }
            
            // Refresh the key list to show the new key
            refresh_keys ();
            show_toast (_("SSH key '%s' added successfully").printf (filename));
            
        } catch (Error e) {
            show_toast (_("Failed to add SSH key: %s").printf (e.message));
            warning ("Failed to add SSH key: %s", e.message);
        }
    }
    
    private void show_toast (string message) {
        var toast = new Adw.Toast (message) {
            timeout = 3
        };
        toast_overlay.add_toast (toast);
    }
    
}
