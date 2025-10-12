/*
 * Key Maker - Backup Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/backup_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/backup_page.ui")]
#endif
public class KeyMaker.BackupPage : Adw.Bin {
    // Regular backups page components
    [GtkChild]
    private unowned Gtk.ListBox regular_backups_list;
    
    [GtkChild]
    private unowned Gtk.Button create_regular_backup_button_header;
    
    [GtkChild]
    private unowned Gtk.Button refresh_regular_button;
    
    [GtkChild]
    private unowned Gtk.Button remove_all_regular_backups_button;
    
    // Emergency vault page components
    [GtkChild]
    private unowned Gtk.ListBox emergency_backups_list;
    
    [GtkChild]
    private unowned Gtk.Button create_emergency_backup_button_header;
    
    [GtkChild]
    private unowned Gtk.Button refresh_emergency_button;
    
    [GtkChild]
    private unowned Gtk.Button remove_all_emergency_backups_button;
    
    // Backend managers
    private BackupManager backup_manager;
    private EmergencyVault emergency_vault;
    private TOTPManager totp_manager;
    private weak Gtk.Window parent_window;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        backup_manager = new BackupManager ();
        emergency_vault = new EmergencyVault ();
        totp_manager = new TOTPManager ();
        
        // Delay initialization until the template is loaded
        Idle.add (() => {
            setup_signals ();
            populate_regular_backups_list ();
            populate_emergency_backups_list ();
            return false;
        });
    }
    
    public void set_parent_window (Gtk.Window parent) {
        this.parent_window = parent;
    }
    
    private void setup_signals () {
        // Regular backups page signals
        if (create_regular_backup_button_header != null) {
            create_regular_backup_button_header.clicked.connect (on_create_regular_backup);
        }
        
        if (refresh_regular_button != null) {
            refresh_regular_button.clicked.connect (on_refresh_regular_backups);
        }
        
        if (remove_all_regular_backups_button != null) {
            remove_all_regular_backups_button.clicked.connect (on_remove_all_regular_backups);
        }
        
        // Emergency vault page signals
        if (create_emergency_backup_button_header != null) {
            create_emergency_backup_button_header.clicked.connect (on_create_emergency_backup);
        }
        
        if (refresh_emergency_button != null) {
            refresh_emergency_button.clicked.connect (on_refresh_emergency_backups);
        }
        
        if (remove_all_emergency_backups_button != null) {
            remove_all_emergency_backups_button.clicked.connect (on_remove_all_emergency_backups);
        }
        
        // Backend signals
        if (backup_manager != null) {
            backup_manager.backup_created.connect (on_regular_backup_created);
            backup_manager.backup_restored.connect (on_regular_backup_restored);
        }
        
        if (emergency_vault != null) {
            emergency_vault.backup_created.connect (on_emergency_backup_created);
            emergency_vault.backup_restored.connect ((backup) => {
                populate_emergency_backups_list ();
            });
        }
    }
    
    private void populate_regular_backups_list () {
        if (regular_backups_list == null) {
            return;
        }
        
        var backups = backup_manager.get_all_backups ();
        
        if (backups.length == 0) {
            // Keep hardcoded placeholder visible
            return;
        }
        
        // Hide hardcoded placeholder and show real backups
        clear_list_box (regular_backups_list);
        for (int i = 0; i < backups.length; i++) {
            add_regular_backup_row (backups[i]);
        }
    }
    
    private void populate_emergency_backups_list () {
        if (emergency_backups_list == null) {
            return;
        }
        
        var backups = emergency_vault.get_all_backups ();
        
        if (backups.length == 0) {
            // Keep hardcoded placeholder visible
            return;
        }
        
        // Hide hardcoded placeholder and show real backups
        clear_list_box (emergency_backups_list);
        for (int i = 0; i < backups.length; i++) {
            add_emergency_backup_row (backups[i]);
        }
    }
    
    private void add_regular_backup_row (RegularBackupEntry backup) {
        var row = new Adw.ActionRow ();
        row.title = backup.name;
        
        // Regular backups always show creation date
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(backup.created_at.format ("%Y-%m-%d %H:%M"))";
        
        // Add type icon with proper sizing
        var type_icon = new Gtk.Image ();
        switch (backup.backup_type) {
            case RegularBackupType.ENCRYPTED_ARCHIVE:
                type_icon.icon_name = "package-x-generic-symbolic";
                break;
            case RegularBackupType.EXPORT_BUNDLE:
                type_icon.icon_name = "folder-download-symbolic";
                break;
            case RegularBackupType.CLOUD_SYNC:
                type_icon.icon_name = "cloud-symbolic";
                break;
        }
        row.add_prefix (type_icon);
        
        // Add health status icon with proper spacing
        var status_icon = new Gtk.Image ();
        status_icon.icon_name = "io.github.tobagin.keysmith-health-symbolic";
        status_icon.icon_size = Gtk.IconSize.NORMAL;
        status_icon.margin_end = 6;
        if (backup.is_expired ()) {
            status_icon.add_css_class ("warning");
            status_icon.tooltip_text = "Backup has expired";
            row.sensitive = false;
        } else if (!backup.backup_file.query_exists ()) {
            status_icon.add_css_class ("error");
            status_icon.tooltip_text = "Backup file missing";
            row.sensitive = false;
        } else {
            status_icon.add_css_class ("success");
            status_icon.tooltip_text = "Backup is healthy";
        }
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        // Add status icon BEFORE buttons
        button_box.append (status_icon);
        
        var view_button = new Gtk.Button ();
        view_button.icon_name = "view-reveal-symbolic";
        view_button.tooltip_text = "View Backup Information";
        view_button.add_css_class ("flat");
        view_button.valign = Gtk.Align.CENTER;
        view_button.clicked.connect (() => show_regular_backup_details (backup));
        button_box.append (view_button);
        
        var restore_button = new Gtk.Button ();
        restore_button.icon_name = "document-revert-symbolic";
        restore_button.tooltip_text = "Restore Backup";
        restore_button.add_css_class ("flat");
        restore_button.valign = Gtk.Align.CENTER;
        restore_button.clicked.connect (() => restore_regular_backup (backup));
        button_box.append (restore_button);
        
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "user-trash-symbolic";
        delete_button.tooltip_text = "Delete Backup";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.clicked.connect (() => delete_regular_backup (backup));
        button_box.append (delete_button);
        
        // Add buttons to suffix (status icon is now in title area)
        row.add_suffix (button_box);
        row.set_data ("backup", backup);
        
        regular_backups_list.append (row);
    }
    
    private void add_emergency_backup_row (EmergencyBackupEntry backup) {
        var row = new Adw.ActionRow ();
        row.title = backup.name;
        
        // Show contextually relevant information based on backup type
        string context_info;
        switch (backup.backup_type) {
            case EmergencyBackupType.TIME_LOCKED:
                if (backup.expires_at != null) {
                    context_info = @"Expires $(backup.expires_at.format ("%Y-%m-%d %H:%M"))";
                } else {
                    context_info = "No expiry date";
                }
                break;
            case EmergencyBackupType.QR_CODE:
                context_info = backup.created_at.format ("%Y-%m-%d %H:%M");
                break;
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                context_info = @"$(backup.shamir_total_shares) pieces";
                break;
            case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                context_info = backup.created_at.format ("%Y-%m-%d %H:%M");
                break;
            default:
                context_info = backup.created_at.format ("%Y-%m-%d %H:%M");
                break;
        }
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(context_info)";
        
        // Add type icon with proper sizing
        var type_icon = new Gtk.Image ();
        // Use time-unlocked icon if time-locked backup has expired
        if (backup.backup_type == EmergencyBackupType.TIME_LOCKED && backup.is_expired ()) {
            type_icon.icon_name = "io.github.tobagin.keysmith-time-unlocked-symbolic";
        } else {
            type_icon.icon_name = backup.backup_type.get_icon_name ();
        }
        row.add_prefix (type_icon);
        
        // Add health status icon with proper spacing
        var status_icon = new Gtk.Image ();
        status_icon.icon_name = "io.github.tobagin.keysmith-health-symbolic";
        status_icon.icon_size = Gtk.IconSize.NORMAL;
        status_icon.margin_end = 6;
        
        if (!backup.backup_file.query_exists ()) {
            status_icon.add_css_class ("error");
            status_icon.tooltip_text = "Backup file missing";
            row.sensitive = false;
        } else if (backup.backup_type == EmergencyBackupType.TIME_LOCKED && backup.expires_at != null) {
            var now = new DateTime.now_local ();
            if (now.compare (backup.expires_at) <= 0) {
                // Still time-locked
                status_icon.add_css_class ("warning");
                status_icon.tooltip_text = "Backup is time-locked";
            } else {
                // Time-locked backup has expired (unlocked) - this is healthy
                status_icon.add_css_class ("success");
                status_icon.tooltip_text = "Backup is unlocked and ready";
            }
        } else {
            status_icon.add_css_class ("success");
            status_icon.tooltip_text = "Backup is healthy";
        }
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        // Add status icon BEFORE buttons
        button_box.append (status_icon);
        
        var view_button = new Gtk.Button ();
        view_button.icon_name = "view-reveal-symbolic";
        view_button.tooltip_text = "View Backup Information";
        view_button.valign = Gtk.Align.CENTER;
        view_button.add_css_class ("flat");
        view_button.clicked.connect (() => show_emergency_backup_details (backup));
        button_box.append (view_button);
        
        var restore_button = new Gtk.Button ();
        restore_button.icon_name = "document-revert-symbolic";
        restore_button.tooltip_text = "Restore Backup";
        restore_button.valign = Gtk.Align.CENTER;
        restore_button.add_css_class ("flat");
        restore_button.clicked.connect (() => restore_emergency_backup (backup));
        button_box.append (restore_button);
        
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "user-trash-symbolic";
        delete_button.tooltip_text = "Delete Backup";
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        // For time-locked backups that haven't expired yet, disable restore and delete buttons
        if (backup.backup_type == EmergencyBackupType.TIME_LOCKED && backup.expires_at != null) {
            var now = new DateTime.now_local ();
            if (now.compare (backup.expires_at) <= 0) {
                // Still time-locked - disable only restore and delete buttons
                restore_button.sensitive = false;
                restore_button.tooltip_text = "Cannot restore time-locked backup until unlock time";
                delete_button.sensitive = false;
                delete_button.tooltip_text = "Cannot delete time-locked backup until unlock time";
            }
            // Note: View button is never disabled - you can always view backup details
        }
        delete_button.clicked.connect (() => delete_emergency_backup (backup));
        button_box.append (delete_button);
        
        // Add buttons to suffix (status icon is now in title area)
        row.add_suffix (button_box);
        row.set_data ("backup", backup);
        
        emergency_backups_list.append (row);
    }
    
    private void clear_list_box (Gtk.ListBox list_box) {
        Gtk.Widget? child = list_box.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            list_box.remove (child);
            child = next;
        }
    }
    
    // Signal handlers
    private void on_create_regular_backup () {
        var window = get_root () as Gtk.Window;
        var dialog = new CreateBackupDialog (window, emergency_vault);
        dialog.present (window);
    }
    
    private void on_create_emergency_backup () {
        var window = get_root () as Gtk.Window;
        var dialog = new CreateBackupDialog (window, emergency_vault);
        dialog.present (window);
    }
    
    private void on_refresh_regular_backups () {
        populate_regular_backups_list ();
    }
    
    private void on_refresh_emergency_backups () {
        populate_emergency_backups_list ();
    }
    
    private void on_remove_all_regular_backups () {
        var window = get_root () as Gtk.Window;
        var alert = new Adw.AlertDialog ("Remove All Regular Backups?", 
                                          "Are you sure you want to remove all regular backups? This action cannot be undone.");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("remove", "Remove All");
        alert.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "remove") {
                remove_all_regular_backups.begin ();
            }
        });
        
        alert.present (window);
    }
    
    private void on_remove_all_emergency_backups () {
        var window = get_root () as Gtk.Window;
        var alert = new Adw.AlertDialog ("Remove All Emergency Backups?", 
                                          "Are you sure you want to remove all emergency backups? This will require authentication and cannot be undone.");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("remove", "Remove All");
        alert.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "remove") {
                show_emergency_auth_and_delete_all ();
            }
        });
        
        alert.present (window);
    }
    
    private void on_regular_backup_created (RegularBackupEntry backup) {
        populate_regular_backups_list ();
        show_toast_requested (@"Regular backup '$(backup.name)' created");
    }
    
    private void on_regular_backup_restored (RegularBackupEntry backup) {
        show_toast_requested (@"Regular backup '$(backup.name)' restored");
    }
    
    private void on_emergency_backup_created (EmergencyBackupEntry backup) {
        populate_emergency_backups_list ();
        show_toast_requested (@"Emergency backup '$(backup.name)' created");
    }
    
    // Action methods
    private void show_regular_backup_details (RegularBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var dialog = new BackupDetailsDialog (backup, backup_manager);

        dialog.restore_requested.connect ((b) => {
            restore_regular_backup (b);
        });

        dialog.delete_requested.connect ((b) => {
            delete_regular_backup (b);
        });

        dialog.present (window);
    }
    
    private void restore_regular_backup (RegularBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var dialog = new RestoreBackupDialog (window);
        dialog.present (window);
    }
    
    private void delete_regular_backup (RegularBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var alert = new Adw.AlertDialog ("Delete Backup?", 
                                          @"Are you sure you want to delete the backup \"$(backup.name)\"?");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("delete", "Delete");
        alert.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "delete") {
                bool success = backup_manager.remove_backup (backup);
                if (success) {
                    populate_regular_backups_list ();
                    show_toast_requested (@"Backup '$(backup.name)' deleted");
                } else {
                    show_error ("Delete Failed", "Could not delete backup");
                }
            }
        });
        
        alert.present (window);
    }
    
    private void show_emergency_backup_details (EmergencyBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var dialog = new EmergencyBackupDetailsDialog (backup, emergency_vault);

        dialog.restore_requested.connect ((b) => {
            restore_emergency_backup (b);
        });

        dialog.delete_requested.connect ((b) => {
            delete_emergency_backup (b);
        });

        dialog.present (window);
    }
    
    private void restore_emergency_backup (EmergencyBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var dialog = new RestoreBackupDialog (window, null, backup);
        dialog.present (window);
    }
    
    private void delete_emergency_backup (EmergencyBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        // For emergency backups, use the same authentication as restore
        var alert = new Adw.AlertDialog ("Delete Emergency Backup?", 
                                          @"Deleting \"$(backup.name)\" requires the same authentication as restoring it. Continue?");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("continue", "Continue");
        alert.set_response_appearance ("continue", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "continue") {
                show_emergency_auth_and_delete_single (backup);
            }
        });
        
        alert.present (window);
    }
    
    
    private void show_error (string title, string message) {
        var window = get_root () as Gtk.Window;
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (window);
    }

    // New bulk deletion methods
    private async void remove_all_regular_backups () {
        var result = yield backup_manager.remove_all_regular_backups ();

        populate_regular_backups_list ();

        var window = get_root () as Gtk.Window;
        BackupHelpers.show_bulk_delete_result (window, result, "regular backups");

        if (result.all_succeeded ()) {
            show_toast_requested (@"Deleted all $(result.success_count) regular backups");
        }
    }

    private void show_emergency_auth_and_delete_all () {
        var window = get_root () as Gtk.Window;
        var auth_dialog = new EmergencyBackupAuthDialog ("Delete All Emergency Backups", "All emergency backups");

        auth_dialog.authentication_result.connect ((success, password) => {
            if (success && password != null) {
                // Attempt deletion with password
                remove_all_emergency_backups.begin (password, auth_dialog);
            }
        });

        auth_dialog.present (window);
    }

    private async void remove_all_emergency_backups (string password, EmergencyBackupAuthDialog auth_dialog) {
        try {
            var result = yield emergency_vault.remove_all_emergency_backups (password);

            auth_dialog.handle_auth_result (result.success_count > 0);

            if (result.success_count > 0) {
                populate_emergency_backups_list ();

                var window = get_root () as Gtk.Window;
                BackupHelpers.show_bulk_delete_result (window, result, "emergency backups");

                if (result.all_succeeded ()) {
                    show_toast_requested (@"Deleted all $(result.success_count) emergency backups");
                }
            }

        } catch (Error e) {
            auth_dialog.handle_auth_result (false);
            show_error ("Deletion Failed", e.message);
        }
    }

    private void show_emergency_auth_and_delete_single (EmergencyBackupEntry backup) {
        var window = get_root () as Gtk.Window;
        var auth_dialog = new EmergencyBackupAuthDialog ("Delete Emergency Backup", backup.name);

        auth_dialog.authentication_result.connect ((success, password) => {
            if (success && password != null) {
                delete_emergency_backup_with_auth.begin (backup, password, auth_dialog);
            }
        });

        auth_dialog.present (window);
    }

    private async void delete_emergency_backup_with_auth (EmergencyBackupEntry backup, string password, EmergencyBackupAuthDialog auth_dialog) {
        try {
            bool deleted = yield emergency_vault.delete_backup (backup, password);

            auth_dialog.handle_auth_result (deleted);

            if (deleted) {
                populate_emergency_backups_list ();
                show_toast_requested (@"Emergency backup '$(backup.name)' deleted");
            }

        } catch (Error e) {
            auth_dialog.handle_auth_result (false);
            show_error ("Deletion Failed", e.message);
        }
    }
}