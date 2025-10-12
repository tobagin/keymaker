/*
 * Key Maker - Backup Center Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/backup_center_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/backup_center_dialog.ui")]
#endif
public class KeyMaker.BackupCenterDialog : Adw.Dialog {
    
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Adw.ViewSwitcher view_switcher;
    
    [GtkChild]
    private unowned Adw.ViewStack main_view_stack;
    
    // Overview page components
    [GtkChild]
    private unowned Adw.StatusPage overview_status_page;
    
    [GtkChild]
    private unowned Adw.ActionRow regular_stats_row;
    
    [GtkChild]
    private unowned Adw.ActionRow emergency_stats_row;
    
    [GtkChild]
    private unowned Gtk.Image vault_status_icon;
    
    [GtkChild]
    private unowned Gtk.Button create_regular_backup_button;
    
    [GtkChild]
    private unowned Gtk.Button create_emergency_backup_button;
    
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
    
    public BackupCenterDialog (Gtk.Window parent) {
        Object ();
        this.parent_window = parent;
    }
    
    construct {
        backup_manager = new BackupManager ();
        emergency_vault = new EmergencyVault ();
        totp_manager = new TOTPManager ();
        
        // Delay initialization until the template is loaded
        Idle.add (() => {
            setup_signals ();
            migrate_legacy_backups ();
            refresh_overview_stats ();
            populate_regular_backups_list ();
            populate_emergency_backups_list ();
            return false;
        });
    }
    
    private void setup_signals () {
        // Overview page signals
        if (create_regular_backup_button != null) {
            create_regular_backup_button.clicked.connect (on_create_regular_backup);
        }
        
        if (create_emergency_backup_button != null) {
            create_emergency_backup_button.clicked.connect (on_create_emergency_backup);
        }
        
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
                refresh_overview_stats ();
                populate_emergency_backups_list ();
            });
            emergency_vault.vault_status_changed.connect (update_vault_health_indicator);
        }
    }
    
    private void refresh_overview_stats () {
        update_regular_backup_stats ();
        update_emergency_backup_stats ();
        update_vault_health_indicator ();
    }
    
    private void update_regular_backup_stats () {
        if (regular_stats_row == null) return;
        
        var backups = backup_manager.get_all_backups ();
        regular_stats_row.title = @"$(backups.length) backups";
        
        if (backups.length > 0) {
            var latest = backups[0];
            regular_stats_row.subtitle = @"Last backup: $(latest.created_at.format ("%Y-%m-%d %H:%M"))";
        } else {
            regular_stats_row.subtitle = "Last backup: Never";
        }
    }
    
    private void update_emergency_backup_stats () {
        if (emergency_stats_row == null) return;
        
        var backups = emergency_vault.get_all_backups_legacy ();
        emergency_stats_row.title = @"$(backups.length) emergency backups";
        
        if (backups.length > 0) {
            emergency_stats_row.subtitle = "Vault status: Active";
        } else {
            emergency_stats_row.subtitle = "Vault status: Empty";
        }
    }
    
    private void update_vault_health_indicator () {
        if (vault_status_icon == null) return;
        
        var backups = emergency_vault.get_all_backups_legacy ();
        
        if (backups.length == 0) {
            vault_status_icon.icon_name = "io.github.tobagin.keysmith-emergency-vault-symbolic";
            vault_status_icon.remove_css_class ("success");
            vault_status_icon.add_css_class ("warning");
        } else {
            vault_status_icon.icon_name = "io.github.tobagin.keysmith-emergency-vault-symbolic";
            vault_status_icon.remove_css_class ("warning");
            vault_status_icon.add_css_class ("success");
        }
    }
    
    private void populate_regular_backups_list () {
        if (regular_backups_list == null) return;
        
        clear_list_box (regular_backups_list);
        
        var backups = backup_manager.get_all_backups ();
        
        if (backups.length == 0) {
            var placeholder_row = new Adw.ActionRow ();
            placeholder_row.title = "No regular backups";
            placeholder_row.subtitle = "Create your first backup to get started";
            
            var placeholder_icon = new Gtk.Image ();
            placeholder_icon.icon_name = "folder-symbolic";
            placeholder_row.add_prefix (placeholder_icon);
            
            var create_button = new Gtk.Button ();
            create_button.label = "Create Backup";
            create_button.add_css_class ("suggested-action");
            create_button.clicked.connect (on_create_regular_backup);
            placeholder_row.add_suffix (create_button);
            
            regular_backups_list.append (placeholder_row);
            return;
        }
        
        for (int i = 0; i < backups.length; i++) {
            add_regular_backup_row (backups[i]);
        }
    }
    
    private void populate_emergency_backups_list () {
        if (emergency_backups_list == null) return;
        
        clear_list_box (emergency_backups_list);
        
        var backups = emergency_vault.get_all_backups_legacy ();
        
        if (backups.length == 0) {
            var placeholder_row = new Adw.ActionRow ();
            placeholder_row.title = "No emergency backups";
            placeholder_row.subtitle = "Create emergency backups for disaster recovery";
            
            var placeholder_icon = new Gtk.Image ();
            placeholder_icon.icon_name = "io.github.tobagin.keysmith-emergency-vault-symbolic";
            placeholder_row.add_prefix (placeholder_icon);
            
            var create_button = new Gtk.Button ();
            create_button.label = "Setup Emergency Vault";
            create_button.add_css_class ("suggested-action");
            create_button.clicked.connect (on_create_emergency_backup);
            placeholder_row.add_suffix (create_button);
            
            emergency_backups_list.append (placeholder_row);
            return;
        }
        
        for (int i = 0; i < backups.length; i++) {
            add_emergency_backup_row (backups[i]);
        }
    }
    
    private void add_regular_backup_row (RegularBackupEntry backup) {
        var row = new Adw.ActionRow ();
        row.title = backup.name;
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(backup.created_at.format ("%Y-%m-%d %H:%M"))";
        
        // Add type icon
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
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        var view_button = new Gtk.Button ();
        view_button.icon_name = "io.github.tobagin.keysmith-view-backup-information-symbolic";
        view_button.tooltip_text = "View Backup Information";
        view_button.add_css_class ("flat");
        view_button.clicked.connect (() => show_regular_backup_details (backup));
        button_box.append (view_button);
        
        var restore_button = new Gtk.Button ();
        restore_button.icon_name = "document-revert-symbolic";
        restore_button.tooltip_text = "Restore Backup";
        restore_button.add_css_class ("flat");
        restore_button.clicked.connect (() => restore_regular_backup (backup));
        button_box.append (restore_button);
        
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "user-trash-symbolic";
        delete_button.tooltip_text = "Delete Backup";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.clicked.connect (() => delete_regular_backup (backup));
        button_box.append (delete_button);
        
        row.add_suffix (button_box);
        row.set_data ("backup", backup);
        
        regular_backups_list.append (row);
    }
    
    private void add_emergency_backup_row (BackupEntry backup) {
        var row = new Adw.ActionRow ();
        row.title = backup.name;
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(backup.created_at.format ("%Y-%m-%d %H:%M"))";
        
        // Add type icon
        var type_icon = new Gtk.Image ();
        switch (backup.backup_type) {
            case BackupType.TIME_LOCKED:
                type_icon.icon_name = "appointment-soon-symbolic";
                break;
            case BackupType.SHAMIR_SECRET_SHARING:
                type_icon.icon_name = "view-app-grid-symbolic";
                break;
            case BackupType.QR_CODE:
                type_icon.icon_name = "io.github.tobagin.keysmith-qr-code-symbolic";
                break;
            case BackupType.ENCRYPTED_ARCHIVE:
                type_icon.icon_name = "package-x-generic-symbolic";
                break;
        }
        row.add_prefix (type_icon);
        
        // Add status indicator
        var status_icon = new Gtk.Image ();
        if (backup.is_expired ()) {
            status_icon.icon_name = "io.github.tobagin.keysmith-health-symbolic";
            status_icon.add_css_class ("warning");
            status_icon.tooltip_text = "Backup has expired";
            row.sensitive = false;
        } else if (!backup.backup_file.query_exists ()) {
            status_icon.icon_name = "io.github.tobagin.keysmith-health-symbolic";
            status_icon.add_css_class ("error");
            status_icon.tooltip_text = "Backup file missing";
            row.sensitive = false;
        } else {
            status_icon.icon_name = "io.github.tobagin.keysmith-health-symbolic";
            status_icon.add_css_class ("success");
            status_icon.tooltip_text = "Backup is ready";
        }
        row.add_prefix (status_icon);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        var view_button = new Gtk.Button ();
        view_button.icon_name = "io.github.tobagin.keysmith-view-backup-information-symbolic";
        view_button.tooltip_text = "View Backup Information";
        view_button.add_css_class ("flat");
        view_button.clicked.connect (() => show_emergency_backup_details (backup));
        button_box.append (view_button);
        
        var restore_button = new Gtk.Button ();
        restore_button.icon_name = "document-revert-symbolic";
        restore_button.tooltip_text = "Restore Backup";
        restore_button.add_css_class ("flat");
        restore_button.clicked.connect (() => restore_emergency_backup (backup));
        button_box.append (restore_button);
        
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "user-trash-symbolic";
        delete_button.tooltip_text = "Delete Backup";
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        // For emergency backups, disable if locked or restricted
        if (backup.backup_type == BackupType.TIME_LOCKED && backup.expires_at != null) {
            var now = new DateTime.now_local ();
            if (now.compare (backup.expires_at) <= 0) {
                delete_button.sensitive = false;
                delete_button.tooltip_text = "Cannot delete time-locked backup until unlock time";
            }
        }
        delete_button.clicked.connect (() => delete_emergency_backup (backup));
        button_box.append (delete_button);
        
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
        var dialog = new CreateBackupDialog (this.parent_window, emergency_vault);
        dialog.present (this);
    }
    
    private void on_create_emergency_backup () {
        var dialog = new CreateBackupDialog (this.parent_window, emergency_vault);
        dialog.present (this);
    }
    
    private void on_refresh_regular_backups () {
        populate_regular_backups_list ();
        update_regular_backup_stats ();
    }
    
    private void on_refresh_emergency_backups () {
        populate_emergency_backups_list ();
        update_emergency_backup_stats ();
        update_vault_health_indicator ();
    }
    
    private void on_remove_all_regular_backups () {
        var alert = new Adw.AlertDialog ("Remove All Regular Backups?", 
                                          "Are you sure you want to remove all regular backups? This action cannot be undone.");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("remove", "Remove All");
        alert.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "remove") {
                // TODO: Implement remove all regular backups
                print ("Remove all regular backups\n");
            }
        });
        
        alert.present (this);
    }
    
    private void on_remove_all_emergency_backups () {
        var alert = new Adw.AlertDialog ("Remove All Emergency Backups?", 
                                          "Are you sure you want to remove all emergency backups? This will require authentication and cannot be undone.");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("remove", "Remove All");
        alert.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "remove") {
                // TODO: Implement remove all emergency backups with authentication
                print ("Remove all emergency backups\n");
            }
        });
        
        alert.present (this);
    }
    
    private void on_regular_backup_created (RegularBackupEntry backup) {
        refresh_overview_stats ();
        populate_regular_backups_list ();
    }
    
    private void on_regular_backup_restored (RegularBackupEntry backup) {
        refresh_overview_stats ();
    }
    
    private void on_emergency_backup_created (EmergencyBackupEntry backup) {
        refresh_overview_stats ();
        populate_emergency_backups_list ();
    }
    
    // Action methods
    private void show_regular_backup_details (RegularBackupEntry backup) {
        // TODO: Implement backup details dialog
        print ("Show regular backup details: %s\n", backup.name);
    }
    
    private void restore_regular_backup (RegularBackupEntry backup) {
        var dialog = new RestoreBackupDialog (this.parent_window);
        dialog.present (this);
    }
    
    private void delete_regular_backup (RegularBackupEntry backup) {
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
                    refresh_overview_stats ();
                    populate_regular_backups_list ();
                } else {
                    show_error ("Delete Failed", "Could not delete backup");
                }
            }
        });
        
        alert.present (this);
    }
    
    private void show_emergency_backup_details (BackupEntry backup) {
        // TODO: Implement emergency backup details dialog
        print ("Show emergency backup details: %s\n", backup.name);
    }
    
    private void restore_emergency_backup (BackupEntry backup) {
        // Convert BackupEntry to EmergencyBackupEntry for the new dialog
        var emergency_backup = new EmergencyBackupEntry (backup.name, EmergencyBackupType.ENCRYPTED_ARCHIVE);
        emergency_backup.created_at = backup.created_at;
        emergency_backup.expires_at = backup.expires_at;
        emergency_backup.backup_file = backup.backup_file;
        emergency_backup.key_fingerprints = backup.key_fingerprints;
        emergency_backup.is_encrypted = backup.is_encrypted;
        emergency_backup.description = backup.description;
        emergency_backup.file_size = backup.file_size;
        emergency_backup.checksum = backup.checksum;
        emergency_backup.shamir_total_shares = backup.shamir_total_shares;
        emergency_backup.shamir_threshold = backup.shamir_threshold;
        
        var dialog = new RestoreBackupDialog (this.parent_window, null, emergency_backup);
        dialog.present (this);
    }
    
    private void delete_emergency_backup (BackupEntry backup) {
        // For emergency backups, use the same authentication as restore
        var alert = new Adw.AlertDialog ("Delete Emergency Backup?", 
                                          @"Deleting \"$(backup.name)\" requires the same authentication as restoring it. Continue?");
        alert.add_response ("cancel", "Cancel");
        alert.add_response ("continue", "Continue");
        alert.set_response_appearance ("continue", Adw.ResponseAppearance.DESTRUCTIVE);
        alert.set_default_response ("cancel");
        
        alert.response.connect ((response) => {
            if (response == "continue") {
                // TODO: Implement authentication dialog for emergency backup deletion
                print ("Delete emergency backup with authentication: %s\n", backup.name);
            }
        });
        
        alert.present (this);
    }
    
    private void migrate_legacy_backups () {
        print ("BackupCenterDialog: Starting legacy backup migration...\n");
        
        try {
            var legacy_backups = emergency_vault.get_all_backups_legacy ();
            print ("BackupCenterDialog: Found %u legacy backups to migrate\n", legacy_backups.length);
            
            for (int i = 0; i < legacy_backups.length; i++) {
                var backup = legacy_backups[i];
                
                // Categorize based on backup type
                switch (backup.backup_type) {
                    case BackupType.ENCRYPTED_ARCHIVE:
                        // This should be a Regular backup
                        migrate_to_regular_backup (backup);
                        break;
                        
                    case BackupType.QR_CODE:
                    case BackupType.SHAMIR_SECRET_SHARING:
                    case BackupType.TIME_LOCKED:
                        // These are Emergency backups - they can stay in EmergencyVault
                        print ("BackupCenterDialog: Emergency backup '%s' type=%s already in correct location\n", 
                               backup.name, backup.backup_type.to_string ());
                        break;
                        
                    default:
                        print ("BackupCenterDialog: Unknown backup type %d for '%s'\n", 
                               backup.backup_type, backup.name);
                        break;
                }
            }
            
            print ("BackupCenterDialog: Migration completed\n");
            
        } catch (Error e) {
            print ("BackupCenterDialog: Migration failed: %s\n", e.message);
        }
    }
    
    private void migrate_to_regular_backup (BackupEntry legacy_backup) {
        try {
            print ("BackupCenterDialog: Migrating '%s' to regular backup\n", legacy_backup.name);
            
            // Create a RegularBackupEntry from the legacy backup
            var regular_backup = new RegularBackupEntry (legacy_backup.name, RegularBackupType.ENCRYPTED_ARCHIVE);
            regular_backup.created_at = legacy_backup.created_at;
            regular_backup.backup_file = legacy_backup.backup_file;
            regular_backup.key_fingerprints = legacy_backup.key_fingerprints;
            regular_backup.is_encrypted = legacy_backup.is_encrypted;
            regular_backup.description = legacy_backup.description;
            regular_backup.file_size = legacy_backup.file_size;
            
            // Add to BackupManager
            backup_manager.add_backup (regular_backup);
            
            print ("BackupCenterDialog: Successfully migrated '%s' to regular backups\n", legacy_backup.name);
            
        } catch (Error e) {
            print ("BackupCenterDialog: Failed to migrate '%s': %s\n", legacy_backup.name, e.message);
        }
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}

