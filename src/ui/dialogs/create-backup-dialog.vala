/*
 * Key Maker - Create Backup Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/create_backup_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/create_backup_dialog.ui")]
#endif
public class KeyMaker.CreateBackupDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Adw.EntryRow name_entry;
    
    [GtkChild]
    private unowned Adw.EntryRow description_entry;
    
    [GtkChild]
    private unowned Adw.ComboRow backup_type_combo;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup keys_group;
    
    [GtkChild]
    private unowned Gtk.ListBox keys_list;
    
    [GtkChild]
    private unowned Adw.ComboRow single_key_combo;
    
    [GtkChild]
    private unowned Gtk.Button create_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    
    [GtkChild]
    private unowned Adw.SwitchRow set_expiry_row;
    
    [GtkChild]
    private unowned Adw.ActionRow expiry_row;
    
    [GtkChild]
    private unowned Gtk.Button expiry_button;
    
    [GtkChild]
    private unowned Adw.SpinRow shares_count_row;
    
    [GtkChild]
    private unowned Adw.SpinRow threshold_row;
    
    private EmergencyVault vault;
    private KeySelectionManager key_manager;
    private DateTime? expiry_date;
    private bool programmatic_change = false;
    
    public CreateBackupDialog (Gtk.Window parent, EmergencyVault vault) {
        Object ();
        this.vault = vault;
    }
    
    construct {
        // Create key manager first
        this.key_manager = new KeySelectionManager ();
        print ("CONSTRUCTOR: Created KeySelectionManager\n");
        
        setup_backup_types ();
        setup_signals ();
        setup_key_manager_signals ();
        
        load_ssh_keys_sync ();
        // Don't call populate_keys_list here - it will be called by keys_changed signal
        // This prevents showing placeholder when keys are about to be loaded
        populate_single_key_combo ();
        setup_expiry_controls ();
        update_keys_ui_for_backup_type ();
        update_create_button ();
    }
    
    private void setup_key_manager_signals () {
        key_manager.keys_changed.connect (() => {
            populate_keys_list ();
            populate_single_key_combo ();
            update_create_button ();
        });
        
        key_manager.selection_changed.connect (() => {
            update_create_button ();
        });
    }
    
    private void load_ssh_keys_sync () {
        debug ("CreateBackupDialog: Starting load_ssh_keys_sync");
        
        try {
            key_manager.clear_available_keys ();
            
            // Simple file-based SSH key detection - same as main window
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            
            if (!ssh_dir.query_exists ()) {
                debug ("CreateBackupDialog: SSH directory does not exist");
                return;
            }
            
            debug ("CreateBackupDialog: Scanning SSH directory: %s", ssh_dir.get_path ());
            
            var enumerator = ssh_dir.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
            var key_count = 0;
            
            FileInfo? info;
            while ((info = enumerator.next_file ()) != null) {
                var filename = info.get_name ();
                
                // Look for private key files (no .pub extension) - same logic as main window
                if (filename.has_prefix ("id_") && !filename.has_suffix (".pub")) {
                    var private_path = ssh_dir.get_child (filename);
                    var public_path = File.new_for_path (private_path.get_path () + ".pub");
                    
                    // Check if both private and public key exist
                    if (private_path.query_exists () && public_path.query_exists ()) {
                        debug ("CreateBackupDialog: Found SSH key pair: %s", filename);
                        
                        try {
                            // Get file modification time
                            var file_info = private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                            var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                            var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                            
                            // Detect key type and other properties - same as main window
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
                            
                            // Create SSH key object with real data - same as main window
                            var ssh_key = new SSHKey (
                                private_path,
                                public_path,
                                key_type,
                                fingerprint,
                                comment,
                                last_modified,
                                bit_size ?? -1
                            );
                            
                            key_manager.add_available_key (ssh_key);
                            key_count++;
                            
                        } catch (Error key_error) {
                            debug ("Failed to create SSH key object for %s: %s", filename, key_error.message);
                            continue;
                        }
                    }
                }
            }
            
            if (key_count == 0) {
                debug ("CreateBackupDialog: No SSH key pairs found");
            } else {
                debug ("CreateBackupDialog: Successfully loaded %d SSH key pairs", key_count);
            }
            
        } catch (Error enum_error) {
            debug ("Failed to enumerate SSH directory: %s", enum_error.message);
        }
    }
    
    private void setup_backup_types () {
        var model = new Gtk.StringList (null);
        model.append ("Encrypted Archive");
        model.append ("QR Code");
        model.append ("Shamir Secret Sharing");
        model.append ("Time-Locked");
        
        backup_type_combo.model = model;
        backup_type_combo.selected = 0;
    }
    
    private void setup_signals () {
        create_button.clicked.connect (on_create_backup);
        cancel_button.clicked.connect (() => {
            this.force_close ();
        });
        
        name_entry.changed.connect (update_create_button);
        backup_type_combo.notify["selected"].connect (on_backup_type_changed);
        single_key_combo.notify["selected"].connect (() => {
            debug ("CreateBackupDialog: single_key_combo selection changed to %u", single_key_combo.selected);
            update_create_button ();
        });
        set_expiry_row.notify["active"].connect (on_expiry_toggle);
        expiry_button.clicked.connect (on_set_expiry_date);
    }
    
    private void populate_keys_list () {
        var available_keys = key_manager.get_available_keys ();
        print ("POPULATE_KEYS_LIST: START - available_keys.length=%u\n", available_keys.length);
        debug ("CreateBackupDialog: populate_keys_list() called");
        clear_keys_list ();
        
        // Clear current selection when repopulating
        key_manager.clear_selection ();
        
        print ("CreateBackupDialog: Populating %u keys\n", available_keys.length);
        
        if (available_keys.length == 0) {
            // Show a placeholder row indicating keys will be scanned when creating backup
            var placeholder_row = new Adw.ActionRow ();
            placeholder_row.title = "SSH keys will be detected automatically";
            placeholder_row.subtitle = "Your SSH keys will be scanned when you create the backup";
            
            var icon = new Gtk.Image.from_icon_name ("folder-symbolic");
            icon.icon_size = Gtk.IconSize.NORMAL;
            placeholder_row.add_prefix (icon);
            
            keys_list.append (placeholder_row);
            return;
        }
        
        for (int i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            
            // Select all keys by default
            key_manager.select_key (key);
            
            // Use SwitchRow for cleaner, more accessible UI
            var row = new Adw.SwitchRow ();
            row.title = key.get_display_name ();
            row.subtitle = @"$(key.key_type.to_string ()) • $(key.fingerprint[0:16])...";
            row.active = true; // Selected by default
            
            // Add icon to match main key list with proper styling
            var icon = new Gtk.Image ();
            icon.icon_size = Gtk.IconSize.NORMAL;
            
            // Apply consistent security-level icons with colors
            switch (key.key_type) {
                case SSHKeyType.ED25519:
                    // Green for ED25519 (most secure)
                    icon.add_css_class ("success");
                    icon.icon_name = "security-high-symbolic";
                    break;
                case SSHKeyType.RSA:
                    // Blue/accent for RSA (good compatibility)
                    icon.add_css_class ("accent");
                    icon.icon_name = "security-medium-symbolic";
                    break;
                case SSHKeyType.ECDSA:
                    // Yellow/warning for ECDSA (compatibility issues)
                    icon.add_css_class ("warning");
                    icon.icon_name = "security-low-symbolic";
                    break;
            }
            
            row.add_prefix (icon);
            
            // Connect to the SwitchRow's notify signal for the active property
            row.notify["active"].connect (() => {
                if (row.active) {
                    key_manager.select_key (key);
                } else {
                    key_manager.deselect_key (key);
                }
            });
            
            keys_list.append (row);
        }
        
        print ("POPULATE_KEYS_LIST: END\n");
    }
    
    private void clear_keys_list () {
        print ("CLEAR_KEYS_LIST: Clearing all children from keys_list\n");
        Gtk.Widget? child = keys_list.get_first_child ();
        int removed_count = 0;
        while (child != null) {
            var next = child.get_next_sibling ();
            keys_list.remove (child);
            removed_count++;
            child = next;
        }
        print ("CLEAR_KEYS_LIST: Removed %d children\n", removed_count);
    }
    
    private void setup_expiry_controls () {
        expiry_row.visible = false;
        shares_count_row.visible = false;
        threshold_row.visible = false;
    }
    
    private void populate_single_key_combo () {
        var available_keys = key_manager.get_available_keys ();
        print ("populate_single_key_combo: available_keys.length=%u\n", available_keys.length);
        
        var model = new Gtk.StringList (null);
        
        for (int i = 0; i < available_keys.length; i++) {
            var key = available_keys[i];
            var display_text = @"$(key.get_display_name ()) ($(key.key_type.to_string ()))";
            model.append (display_text);
            print ("Added key to combo: %s\n", display_text);
        }
        
        single_key_combo.model = model;
        if (available_keys.length > 0) {
            single_key_combo.selected = 0;
            print ("Set single_key_combo.selected = 0\n");
        } else {
            single_key_combo.selected = -1;
            print ("Set single_key_combo.selected = -1 (no keys)\n");
        }
    }
    
    private void update_keys_ui_for_backup_type () {
        var selected_type = (BackupType) backup_type_combo.selected;
        
        if (selected_type == BackupType.QR_CODE) {
            // Show single key ComboBox for QR code
            keys_list.visible = false;
            single_key_combo.visible = true;
            keys_group.description = "Select a single key for QR code backup";
        } else {
            // Show multiple key selection list for other types
            keys_list.visible = true;
            single_key_combo.visible = false;
            keys_group.description = "Select which keys to include in the backup";
        }
    }
    
    private void on_backup_type_changed () {
        var available_keys = key_manager.get_available_keys ();
        print ("BACKUP_TYPE_CHANGE_START: available_keys.length=%u\n", available_keys.length);
        var selected_type = (BackupType) backup_type_combo.selected;
        print ("BACKUP_TYPE_CHANGED: %s, available_keys.length=%u\n", selected_type.to_string(), available_keys.length);
        
        // Show/hide controls based on backup type
        shares_count_row.visible = (selected_type == BackupType.SHAMIR_SECRET_SHARING);
        threshold_row.visible = (selected_type == BackupType.SHAMIR_SECRET_SHARING);
        
        // For time-locked backup, expiry is mandatory and toggle should be hidden
        if (selected_type == BackupType.TIME_LOCKED) {
            set_expiry_row.visible = false;  // Hide toggle for time-locked
            set_expiry_row.active = true;    // But ensure expiry is active
            expiry_row.visible = true;       // Always show expiry date setting for time-locked
        } else {
            // For other types, show the expiry toggle and reset to default state
            set_expiry_row.visible = true;
            
            // When switching to Encrypted Archive, turn OFF expiry by default
            // This prevents auto-switching back to Time-Locked
            if (selected_type == BackupType.ENCRYPTED_ARCHIVE) {
                programmatic_change = true;  // Prevent auto-switching
                set_expiry_row.active = false;
                expiry_row.visible = false;
                programmatic_change = false;
                print ("Reset expiry toggle to OFF for ENCRYPTED_ARCHIVE\n");
            }
        }
        
        if (selected_type == BackupType.SHAMIR_SECRET_SHARING) {
            shares_count_row.value = 5.0;
            threshold_row.value = 3.0;
            threshold_row.adjustment.upper = shares_count_row.value;
        }
        
        // Update key selection UI based on backup type  
        update_keys_ui_for_backup_type ();
        
        // Re-populate combo if switching to QR Code and keys were cleared
        if (selected_type == BackupType.QR_CODE) {
            print ("Re-populating combo for QR Code: available_keys.length=%u\n", available_keys.length);
            populate_single_key_combo ();
        }
        
        update_create_button ();
    }
    
    private void on_expiry_toggle () {
        expiry_row.visible = set_expiry_row.active;
        if (!set_expiry_row.active) {
            expiry_date = null;
            expiry_button.label = "Set Expiry Date";
        }
        
        // Only auto-switch backup type if this is a user action, not programmatic
        if (!programmatic_change) {
            // Auto-switch backup type based on expiry toggle
            var current_type = (BackupType) backup_type_combo.selected;
            
            // Only auto-switch for types that support expiry toggle (not QR or Shamir)
            if (current_type == BackupType.ENCRYPTED_ARCHIVE || current_type == BackupType.TIME_LOCKED) {
                if (set_expiry_row.active) {
                    // Expiry turned ON → switch to TIME_LOCKED
                    if (current_type != BackupType.TIME_LOCKED) {
                        backup_type_combo.selected = BackupType.TIME_LOCKED;
                        print ("Auto-switched to TIME_LOCKED backup due to expiry toggle ON\n");
                    }
                } else {
                    // Expiry turned OFF → switch to ENCRYPTED_ARCHIVE  
                    if (current_type != BackupType.ENCRYPTED_ARCHIVE) {
                        backup_type_combo.selected = BackupType.ENCRYPTED_ARCHIVE;
                        print ("Auto-switched to ENCRYPTED_ARCHIVE backup due to expiry toggle OFF\n");
                    }
                }
            }
        } else {
            print ("Skipping auto-switch due to programmatic change\n");
        }
        
        update_create_button ();
    }
    
    private void on_set_expiry_date () {
        show_date_picker_dialog ();
    }
    
    private void show_date_picker_dialog () {
        var dialog = new Adw.AlertDialog ("Set Expiry Date", "Choose when this backup should expire");
        
        // Create date selection using spin buttons (simpler approach)
        var now = new DateTime.now_local ();
        var current_year = now.get_year ();
        
        var date_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        date_box.append (new Gtk.Label ("Date:"));
        
        var year_spin = new Gtk.SpinButton.with_range (current_year, current_year + 10, 1);
        var month_spin = new Gtk.SpinButton.with_range (1, 12, 1);
        var day_spin = new Gtk.SpinButton.with_range (1, 31, 1);
        
        // Set default values
        year_spin.set_value (current_year + 1);
        month_spin.set_value (now.get_month ());
        day_spin.set_value (now.get_day_of_month ());
        
        date_box.append (year_spin);
        date_box.append (new Gtk.Label ("-"));
        date_box.append (month_spin);
        date_box.append (new Gtk.Label ("-"));
        date_box.append (day_spin);
        
        // Create time entry
        var time_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        time_box.append (new Gtk.Label ("Time:"));
        
        var hour_spin = new Gtk.SpinButton.with_range (0, 23, 1);
        var minute_spin = new Gtk.SpinButton.with_range (0, 59, 1);
        hour_spin.set_value (23);
        minute_spin.set_value (59);
        
        time_box.append (hour_spin);
        time_box.append (new Gtk.Label (":"));
        time_box.append (minute_spin);
        
        // Create main container
        var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        container.append (date_box);
        container.append (time_box);
        container.set_margin_top (12);
        container.set_margin_bottom (12);
        container.set_margin_start (12);
        container.set_margin_end (12);
        
        dialog.set_extra_child (container);
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("select", "Select Date");
        dialog.set_response_appearance ("select", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response ("select");
        
        dialog.response.connect ((response) => {
            if (response == "select") {
                expiry_date = new DateTime.local (
                    (int) year_spin.get_value (),
                    (int) month_spin.get_value (),
                    (int) day_spin.get_value (),
                    (int) hour_spin.get_value (),
                    (int) minute_spin.get_value (),
                    0
                );
                expiry_button.label = expiry_date.format ("%Y-%m-%d %H:%M");
                print ("Expiry date set to: %s\n", expiry_date.format ("%Y-%m-%d %H:%M"));
                update_create_button (); // Enable create button now that expiry date is set
            }
        });
        
        dialog.present (this);
    }
    
    
    private void update_create_button () {
        var selected_type = (BackupType) backup_type_combo.selected;
        bool can_create = false;
        
        switch (selected_type) {
            case BackupType.QR_CODE:
                // QR Code: Just check if SSH keys exist on disk
                var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
                bool has_ssh_keys = false;
                if (ssh_dir.query_exists ()) {
                    try {
                        var enumerator = ssh_dir.enumerate_children ("standard::name", FileQueryInfoFlags.NONE);
                        FileInfo file_info;
                        while ((file_info = enumerator.next_file ()) != null) {
                            var name = file_info.get_name ();
                            if (name.has_suffix ("_rsa") || name.has_suffix ("_ed25519") || name.has_suffix ("_ecdsa") || 
                                name == "id_rsa" || name == "id_ed25519" || name == "id_ecdsa") {
                                has_ssh_keys = true;
                                break;
                            }
                        }
                    } catch (Error e) {
                        has_ssh_keys = false;
                    }
                }
                can_create = has_ssh_keys;
                print ("QR_CODE: has_ssh_keys=%s, can_create=%s\n", has_ssh_keys.to_string(), can_create.to_string());
                break;
                
            case BackupType.ENCRYPTED_ARCHIVE:
                // Encrypted Archive: Needs name + selected keys
                can_create = name_entry.text.strip().length > 0 && has_any_key_selected();
                print ("ENCRYPTED_ARCHIVE: has_name=%s, has_keys=%s, can_create=%s\n", 
                       (name_entry.text.strip().length > 0).to_string(), 
                       has_any_key_selected().to_string(), can_create.to_string());
                break;
                
            case BackupType.SHAMIR_SECRET_SHARING:
                // Shamir: Needs name + selected keys
                can_create = name_entry.text.strip().length > 0 && has_any_key_selected();
                break;
                
            case BackupType.TIME_LOCKED:
                // Time-locked: Needs name + selected keys + expiry date
                var has_name = name_entry.text.strip().length > 0;
                var has_keys = has_any_key_selected();
                var has_expiry = (expiry_date != null);
                can_create = has_name && has_keys && has_expiry;
                print ("TIME_LOCKED: has_name=%s, has_keys=%s, has_expiry=%s, can_create=%s\n", 
                       has_name.to_string(), has_keys.to_string(), has_expiry.to_string(), can_create.to_string());
                break;
        }
        
        create_button.sensitive = can_create;
    }
    
    private bool has_any_key_selected () {
        var selected_count = key_manager.get_selected_count ();
        var available_count = key_manager.get_available_count ();
        print ("has_any_key_selected: selected_count=%u, available_count=%u\n", selected_count, available_count);
        
        bool result = selected_count > 0;
        print ("has_any_key_selected: returning %s\n", result.to_string());
        return result;
    }
    
    private void on_create_backup () {
        var name = name_entry.text.strip ();
        var description = get_description_text ();
        var backup_type = (BackupType) backup_type_combo.selected;
        
        // Get selected keys based on backup type
        var selected_key_list = new GenericArray<SSHKey> ();
        var available_keys = key_manager.get_available_keys ();
        var selected_keys = key_manager.get_selected_keys ();
        
        print ("CreateBackupDialog: Getting selected keys, available_keys.length=%u, selected_keys.length=%u\n", 
               available_keys.length, selected_keys.length);
        
        if (backup_type == BackupType.QR_CODE) {
            // For QR code, get the single selected key from ComboBox
            if (available_keys.length > 0 && single_key_combo.selected < available_keys.length) {
                var selected_key = available_keys[single_key_combo.selected];
                selected_key_list.add (selected_key);
                debug ("CreateBackupDialog: Selected single key for QR backup: %s", selected_key.get_display_name());
            }
        } else {
            // For other backup types, use the managed selection
            for (int i = 0; i < selected_keys.length; i++) {
                var key = selected_keys[i];
                debug ("CreateBackupDialog: Adding key %d (%s) to backup", i, key.get_display_name());
                selected_key_list.add (key);
            }
        }
        debug ("CreateBackupDialog: Selected %u keys for backup", selected_key_list.length);
        
        // Create backup entry
        var backup_entry = new BackupEntry (name, backup_type);
        backup_entry.name = name;
        backup_entry.description = description;
        backup_entry.backup_type = backup_type;
        backup_entry.created_at = new DateTime.now_local ();
        backup_entry.expires_at = set_expiry_row.active ? expiry_date : null;
        
        // Set Shamir parameters if applicable
        if (backup_type == BackupType.SHAMIR_SECRET_SHARING) {
            backup_entry.shamir_total_shares = (int) shares_count_row.value;
            backup_entry.shamir_threshold = (int) threshold_row.value;
        }
        
        // Extract key fingerprints
        backup_entry.key_fingerprints = new GenericArray<string> ();
        for (int i = 0; i < selected_key_list.length; i++) {
            backup_entry.key_fingerprints.add (selected_key_list[i].fingerprint);
        }
        
        // Show progress and create backup
        debug ("CreateBackupDialog: Attempting to show progress_page");
        Idle.add (() => {
            main_stack.visible_child_name = "progress_page";
            debug ("CreateBackupDialog: Progress page should now be visible");
            return false;
        });
        create_backup_async.begin (backup_entry, selected_key_list);
    }
    
    private string get_description_text () {
        return description_entry.text.strip ();
    }
    
    private async void create_backup_async (BackupEntry backup_entry, GenericArray<SSHKey> keys) {
        try {
            debug ("CreateBackupDialog: Starting backup creation with %u keys, %u fingerprints", keys.length, backup_entry.key_fingerprints.length);
            yield vault.create_backup (backup_entry, keys);
            debug ("CreateBackupDialog: Backup created successfully - file size: %lld", backup_entry.file_size);
            this.force_close ();
        } catch (KeyMakerError e) {
            debug ("CreateBackupDialog: Backup creation failed: %s", e.message);
            show_error ("Backup Creation Failed", e.message);
            main_stack.visible_child_name = "setup_page";
        }
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}