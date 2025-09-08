/*
 * Key Maker - Restore Backup Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/restore_backup_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/restore_backup_dialog.ui")]
#endif
public class KeyMaker.RestoreBackupDialog : Adw.Dialog {
    
    [GtkChild]
    private unowned Adw.NavigationView main_navigation;
    
    [GtkChild]
    private unowned Adw.NavigationPage selection_page;
    
    [GtkChild]
    private unowned Adw.NavigationPage progress_page;
    
    [GtkChild]
    private unowned Gtk.ListBox backups_list;
    
    [GtkChild]
    private unowned Gtk.Button restore_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    
    [GtkChild]
    private unowned Adw.EntryRow passphrase_entry;
    
    [GtkChild]
    private unowned Gtk.TextView shares_view;
    
    [GtkChild]
    private unowned Adw.SwitchRow overwrite_existing_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow backup_existing_row;
    
    [GtkChild]
    private unowned Gtk.ProgressBar restore_progress;
    
    [GtkChild]
    private unowned Gtk.Label restore_status_label;
    
    private EmergencyVault vault;
    private EmergencyBackupEntry? selected_backup;
    
    public RestoreBackupDialog (Gtk.Window parent, EmergencyVault? vault = null, EmergencyBackupEntry? specific_backup = null) {
        Object ();
        this.selected_backup = specific_backup;
    }
    
    construct {
        vault = new EmergencyVault ();
        
        // Use realize signal to ensure the template is fully loaded
        this.realize.connect_after (() => {
            setup_signals ();
            populate_backups_list ();
            update_restore_button ();
            setup_restore_options ();
        });
    }
    
    private void setup_signals () {
        restore_button.clicked.connect (on_restore_backup);
        cancel_button.clicked.connect (() => {
            this.force_close ();
        });
        
        backups_list.row_selected.connect (on_backup_selected);
        passphrase_entry.changed.connect (update_restore_button);
    }
    
    private void populate_backups_list () {
        clear_backups_list ();
        
        // If a specific backup is selected, only show that one
        if (selected_backup != null) {
            add_backup_row (selected_backup);
            // Pre-select this backup and start restore immediately
            backups_list.select_row (backups_list.get_row_at_index (0));
            // Hide the backup selection UI and show authentication instead
            var backup_group = backups_list.get_parent () as Adw.PreferencesGroup;
            if (backup_group != null) {
                backup_group.title = @"Restoring: $(selected_backup.name)";
                backup_group.description = @"$(selected_backup.backup_type.to_string ()) backup from $(selected_backup.created_at.format ("%Y-%m-%d %H:%M"))";
            }
            return;
        }
        
        // Use the same method as EmergencyVaultDialog
        var backups = vault.get_all_backups ();
        
        print ("RestoreBackupDialog: Found %u backups\n", backups.length);
        
        if (backups.length == 0) {
            var row = new Adw.ActionRow ();
            row.title = "No Backups Available";
            row.subtitle = "Create a backup first before you can restore";
            row.sensitive = false;
            backups_list.append (row);
            return;
        }
        
        for (int i = 0; i < backups.length; i++) {
            var backup = backups[i];
            add_backup_row (backup);
        }
    }
    
    private void clear_backups_list () {
        Gtk.Widget? child = backups_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            backups_list.remove (child);
            child = next;
        }
    }
    
    private void add_backup_row (EmergencyBackupEntry backup) {
        var row = new Adw.ActionRow ();
        row.title = backup.name;
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(backup.created_at.format ("%Y-%m-%d %H:%M"))";
        
        // Add type icon
        var type_icon = new Gtk.Image ();
        switch (backup.backup_type) {
            case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                type_icon.icon_name = "package-x-generic-symbolic";
                break;
            case EmergencyBackupType.QR_CODE:
                type_icon.icon_name = "io.github.tobagin.keysmith-qr-code-symbolic";
                break;
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                type_icon.icon_name = "view-app-grid-symbolic";
                break;
            case EmergencyBackupType.TIME_LOCKED:
                type_icon.icon_name = "appointment-soon-symbolic";
                break;
        }
        row.add_prefix (type_icon);
        
        // Add status indicator
        var status_icon = new Gtk.Image ();
        if (backup.is_expired ()) {
            status_icon.icon_name = "dialog-warning-symbolic";
            status_icon.add_css_class ("warning");
            status_icon.tooltip_text = "Backup has expired";
            row.sensitive = false;
        } else if (!backup.backup_file.query_exists ()) {
            status_icon.icon_name = "dialog-error-symbolic";
            status_icon.add_css_class ("error");
            status_icon.tooltip_text = "Backup file missing";
            row.sensitive = false;
        } else {
            status_icon.icon_name = "checkmark-symbolic";
            status_icon.add_css_class ("success");
            status_icon.tooltip_text = "Backup is ready for restore";
        }
        row.add_suffix (status_icon);
        
        // Store backup reference
        row.set_data ("backup", backup);
        
        backups_list.append (row);
    }
    
    private void setup_restore_options () {
        overwrite_existing_row.active = false;
        backup_existing_row.active = true;
        
        // Hide authentication controls initially
        passphrase_entry.visible = false;
        shares_view.visible = false;
    }
    
    private void on_backup_selected (Gtk.ListBoxRow? row) {
        if (row == null) {
            selected_backup = null;
            update_restore_button ();
            return;
        }
        
        selected_backup = (EmergencyBackupEntry?) row.get_data<EmergencyBackupEntry> ("backup");
        if (selected_backup == null) {
            return;
        }
        
        // Show appropriate authentication controls
        setup_authentication_controls ();
        update_restore_button ();
    }
    
    private void setup_authentication_controls () {
        passphrase_entry.visible = false;
        shares_view.visible = false;
        
        if (selected_backup == null) return;
        
        switch (selected_backup.backup_type) {
            case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                // Note: Current implementation doesn't actually encrypt, so passphrase not needed
                passphrase_entry.visible = false;
                break;
                
            case EmergencyBackupType.TIME_LOCKED:
                passphrase_entry.visible = true;
                passphrase_entry.title = "Backup Passphrase";
                break;
                
            case EmergencyBackupType.QR_CODE:
                // QR codes might be encrypted too
                passphrase_entry.visible = true;
                passphrase_entry.title = "QR Code Passphrase (if encrypted)";
                break;
                
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                shares_view.visible = true;
                var buffer = shares_view.buffer;
                buffer.text = @"Enter $(selected_backup.shamir_threshold) of $(selected_backup.shamir_total_shares) secret shares (one per line):";
                break;
        }
    }
    
    
    private void update_restore_button () {
        bool can_restore = selected_backup != null;
        
        if (can_restore && selected_backup != null) {
            switch (selected_backup.backup_type) {
                case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                    // Current implementation doesn't actually encrypt, so no passphrase needed
                    can_restore = true;
                    break;
                    
                case EmergencyBackupType.TIME_LOCKED:
                    can_restore = passphrase_entry.text.length > 0;
                    break;
                    
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    can_restore = count_shamir_shares () >= selected_backup.shamir_threshold;
                    break;
                    
                case EmergencyBackupType.QR_CODE:
                    // QR codes can be restored without passphrase if not encrypted
                    can_restore = true;
                    break;
            }
        }
        
        restore_button.sensitive = can_restore;
    }
    
    private int count_shamir_shares () {
        var buffer = shares_view.buffer;
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, false);
        
        var lines = text.split ("\n");
        int count = 0;
        
        foreach (var line in lines) {
            if (line.strip ().length > 0 && !line.contains ("Enter") && !line.contains ("shares")) {
                count++;
            }
        }
        
        return count;
    }
    
    private void on_restore_backup () {
        if (selected_backup == null) return;
        
        print ("RestoreBackupDialog: Starting restore for backup: %s\n", selected_backup.name);
        
        // Check if the NavigationView is properly initialized
        if (main_navigation == null) {
            print ("RestoreBackupDialog: main_navigation is null\n");
            show_error ("UI Error", "Dialog not properly initialized");
            return;
        }
        
        // Switch to progress page using NavigationView
        try {
            print ("RestoreBackupDialog: Pushing progress_page to navigation\n");
            main_navigation.push (progress_page);
            
            if (restore_status_label != null) {
                restore_status_label.label = "Initializing restore...";
                print ("RestoreBackupDialog: Set status label\n");
            } else {
                print ("RestoreBackupDialog: restore_status_label is null\n");
            }
            
            if (restore_progress != null) {
                restore_progress.fraction = 0.0;
                print ("RestoreBackupDialog: Set progress fraction\n");
            } else {
                print ("RestoreBackupDialog: restore_progress is null\n");
            }
            
            print ("RestoreBackupDialog: Starting perform_restore_async\n");
            perform_restore_async.begin ();
            
        } catch (Error e) {
            print ("RestoreBackupDialog: Failed to start restore: %s\n", e.message);
            show_error ("Restore Error", @"Failed to start restore: $(e.message)");
        }
    }
    
    private async void perform_restore_async () {
        try {
            print ("RestoreBackupDialog: perform_restore_async started\n");
            
            if (restore_status_label != null) {
                restore_status_label.label = "Validating backup...";
                print ("RestoreBackupDialog: Status set to 'Validating backup...'\n");
            }
            if (restore_progress != null) {
                restore_progress.fraction = 0.2;
                print ("RestoreBackupDialog: Progress set to 0.2\n");
            }
            
            Timeout.add (500, () => {
                perform_restore_async.callback ();
                return false;
            });
            yield;
            
            if (restore_status_label != null) {
                restore_status_label.label = "Decrypting backup...";
                print ("RestoreBackupDialog: Status set to 'Decrypting backup...'\n");
            }
            if (restore_progress != null) {
                restore_progress.fraction = 0.4;
                print ("RestoreBackupDialog: Progress set to 0.4\n");
            }
            
            // Prepare restore parameters
            print ("RestoreBackupDialog: Preparing restore parameters\n");
            var restore_params = new RestoreParams ();
            restore_params.overwrite_existing = overwrite_existing_row.active;
            restore_params.backup_existing = backup_existing_row.active;
            print ("RestoreBackupDialog: Restore params - overwrite: %s, backup: %s\n", restore_params.overwrite_existing.to_string(), restore_params.backup_existing.to_string());
            
            print ("RestoreBackupDialog: Selected backup type: %s\n", selected_backup.backup_type.to_string());
            switch (selected_backup.backup_type) {
                case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                case EmergencyBackupType.TIME_LOCKED:
                    restore_params.passphrase = passphrase_entry.text;
                    print ("RestoreBackupDialog: Using passphrase for encrypted/time-locked backup\n");
                    break;
                    
                case EmergencyBackupType.QR_CODE:
                    if (passphrase_entry.text.length > 0) {
                        restore_params.passphrase = passphrase_entry.text;
                        print ("RestoreBackupDialog: Using passphrase for QR backup: %s\n", restore_params.passphrase);
                    } else {
                        print ("RestoreBackupDialog: No passphrase provided for QR backup\n");
                        restore_params.passphrase = "";
                    }
                    break;
                    
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    restore_params.shamir_shares = get_shamir_shares ();
                    print ("RestoreBackupDialog: Using Shamir secret shares\n");
                    break;
            }
            
            print ("RestoreBackupDialog: Restore parameters prepared successfully\n");
            
            if (restore_status_label != null) {
                restore_status_label.label = "Restoring keys...";
                print ("RestoreBackupDialog: Status set to 'Restoring keys...'\n");
            }
            if (restore_progress != null) {
                restore_progress.fraction = 0.8;
                print ("RestoreBackupDialog: Progress set to 0.8\n");
            }
            
            print ("RestoreBackupDialog: Calling vault.restore_backup\n");
            switch (selected_backup.backup_type) {
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    yield vault.restore_backup (selected_backup, null, null, restore_params.shamir_shares);
                    break;
                default:
                    yield vault.restore_backup (selected_backup, restore_params.passphrase);
                    break;
            }
            print ("RestoreBackupDialog: vault.restore_backup completed successfully\n");
            
            // Trigger a key refresh in the main application
            print ("RestoreBackupDialog: Triggering key list refresh\n");
            var app = (KeyMaker.Application) GLib.Application.get_default ();
            if (app.window != null) {
                app.window.refresh_keys ();
            }
            
            if (restore_status_label != null) {
                restore_status_label.label = "Restore completed successfully";
                print ("RestoreBackupDialog: Status set to 'Restore completed successfully'\n");
            }
            if (restore_progress != null) {
                restore_progress.fraction = 1.0;
                print ("RestoreBackupDialog: Progress set to 1.0\n");
            }
            
            Timeout.add (1000, () => {
                print ("RestoreBackupDialog: Closing dialog after successful restore\n");
                this.force_close ();
                return false;
            });
            
        } catch (KeyMakerError e) {
            print ("RestoreBackupDialog: KeyMakerError during restore: %s\n", e.message);
            show_error ("Restore Failed", e.message);
        } catch (Error e) {
            print ("RestoreBackupDialog: General error during restore: %s\n", e.message);
            show_error ("Restore Failed", @"An error occurred: $(e.message)");
        }
    }
    
    private GenericArray<string> get_shamir_shares () {
        var buffer = shares_view.buffer;
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, false);
        
        var shares = new GenericArray<string> ();
        var lines = text.split ("\n");
        
        foreach (var line in lines) {
            var trimmed = line.strip ();
            if (trimmed.length > 0 && !trimmed.contains ("Enter") && !trimmed.contains ("shares")) {
                shares.add (trimmed);
            }
        }
        
        return shares;
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}

public class RestoreParams {
    public string? passphrase;
    public GenericArray<string>? shamir_shares;
    public bool overwrite_existing;
    public bool backup_existing;
    
    public RestoreParams () {
        overwrite_existing = false;
        backup_existing = true;
    }
}
