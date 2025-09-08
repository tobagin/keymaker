/*
 * Key Maker - Emergency Vault Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/emergency_vault_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/emergency_vault_dialog.ui")]
#endif
public class KeyMaker.EmergencyVaultDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Gtk.Button create_backup_button_header;
    
    [GtkChild]
    private unowned Gtk.Button refresh_backups_button;
    
    [GtkChild]
    private unowned Gtk.Button remove_all_backups_button;
    
    [GtkChild]
    private unowned Adw.StatusPage vault_status_page;
    
    [GtkChild]
    private unowned Adw.ViewStack main_view_stack;
    
    [GtkChild]
    private unowned Adw.ViewSwitcher view_switcher;
    
    [GtkChild]
    private unowned Gtk.Button create_backup_status_button;

    [GtkChild]
    private unowned Gtk.ListBox backups_list;
    
    
    private EmergencyVault vault;
    private GenericArray<SSHKey> available_keys;
    private weak Gtk.Window parent_window;
    
    public EmergencyVaultDialog (Gtk.Window parent) {
        Object ();
        this.parent_window = parent;
    }
    
    construct {
        vault = new EmergencyVault ();
        available_keys = new GenericArray<SSHKey> ();
        
        // Delay initialization until the template is loaded
        Idle.add (() => {
            // Set default tab to Emergency Vault status page
            if (main_view_stack != null) {
                main_view_stack.set_visible_child_name ("status");
            }
            setup_signals ();
            refresh_vault_status ();
            populate_backups_list ();
            return false;
        });
    }
    
    private void setup_signals () {
        if (create_backup_button_header != null) {
            create_backup_button_header.clicked.connect (on_create_backup);
        }
        
        if (refresh_backups_button != null) {
            refresh_backups_button.clicked.connect (on_refresh_backups);
        }
        
        if (remove_all_backups_button != null) {
            remove_all_backups_button.clicked.connect (on_remove_all_backups);
        }
        
        if (create_backup_status_button != null) {
            create_backup_status_button.clicked.connect (on_create_backup);
        }
        
        if (vault != null) {
            // Use adapter methods to handle new signal types
            vault.backup_created.connect ((emergency_backup) => {
                var legacy_backup = convert_to_legacy_backup (emergency_backup);
                on_backup_created (legacy_backup);
            });
            vault.backup_restored.connect ((emergency_backup) => {
                var legacy_backup = convert_to_legacy_backup (emergency_backup);
                on_backup_restored (legacy_backup);
            });
            vault.vault_status_changed.connect (on_vault_status_changed);
        }
    }
    
    // Keys will be loaded on-demand when creating backups
    
    private void refresh_vault_status () {
        var status = vault.get_vault_status ();
        
        // Update status page with different icons based on vault health
        switch (status) {
            case VaultStatus.HEALTHY:
                vault_status_page.icon_name = "checkmark-symbolic";
                vault_status_page.description = _("Emergency vault is functioning properly");
                break;
                
            case VaultStatus.WARNING:
                vault_status_page.icon_name = "dialog-warning-symbolic";
                vault_status_page.description = _("Some backups may need attention");
                break;
                
            case VaultStatus.CRITICAL:
                vault_status_page.icon_name = "dialog-error-symbolic";
                vault_status_page.description = _("Multiple backup issues detected");
                break;
                
            case VaultStatus.CORRUPTED:
                vault_status_page.icon_name = "dialog-error-symbolic";
                vault_status_page.description = _("Vault corruption detected - immediate action required");
                break;
        }
    }
    
    private void populate_backups_list () {
        if (main_view_stack == null || backups_list == null) {
            return;
        }
        
        clear_backups_list ();
        
        var backups = vault.get_all_backups_legacy ();
        
        for (int i = 0; i < backups.length; i++) {
            add_backup_row (backups[i]);
        }
    }
    
    private void clear_backups_list () {
        if (backups_list == null) {
            return;
        }
        
        Gtk.Widget? child = backups_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            backups_list.remove (child);
            child = next;
        }
    }
    
    private void add_backup_row (BackupEntry backup) {
        var row = new Adw.ExpanderRow ();
        row.title = backup.name;
        row.subtitle = @"$(backup.backup_type.to_string ()) • $(backup.created_at.format ("%Y-%m-%d %H:%M"))";
        
        // Add type icon
        var type_icon = new Gtk.Image ();
        string icon_name = "";
        switch (backup.backup_type) {
            case BackupType.ENCRYPTED_ARCHIVE:
                icon_name = "package-x-generic-symbolic"; // Archive icon
                break;
            case BackupType.QR_CODE:
                icon_name = "io.github.tobagin.keysmith-qr-code-symbolic";
                break;
            case BackupType.SHAMIR_SECRET_SHARING:
                icon_name = "view-app-grid-symbolic"; // More common grid icon
                break;
            case BackupType.TIME_LOCKED:
                icon_name = "appointment-soon-symbolic"; // Regular time icon for type
                break;
        }
        type_icon.icon_name = icon_name;
        
        
        debug ("EmergencyVaultDialog: Setting backup icon to: %s", icon_name);
        row.add_prefix (type_icon);
        
        // Add status indicator
        var status_icon = new Gtk.Image ();
        if (backup.backup_type == BackupType.TIME_LOCKED) {
            if (backup.is_expired()) {
                status_icon.icon_name = "io.github.tobagin.keysmith-time-unlocked-symbolic";
                status_icon.add_css_class ("success"); // Green unlocked
                status_icon.tooltip_text = "Time lock has expired - backup is available";
            } else {
                status_icon.icon_name = "io.github.tobagin.keysmith-time-locked-symbolic";
                status_icon.add_css_class ("error"); // Red locked
                status_icon.tooltip_text = "Backup is time-locked and not yet available";
            }
        } else if (backup.is_expired ()) {
            status_icon.icon_name = "dialog-warning-symbolic";
            status_icon.add_css_class ("warning");
            status_icon.tooltip_text = "Backup has expired";
        } else if (!backup.backup_file.query_exists ()) {
            status_icon.icon_name = "dialog-error-symbolic";
            status_icon.add_css_class ("error");
            status_icon.tooltip_text = "Backup file missing";
        } else {
            status_icon.icon_name = "checkmark-symbolic";
            status_icon.add_css_class ("success");
            status_icon.tooltip_text = "Backup is healthy";
        }
        row.add_suffix (status_icon);
        
        // Add details to expander
        add_backup_details (row, backup);
        
        backups_list.append (row);
    }
    
    private void add_backup_details (Adw.ExpanderRow row, BackupEntry backup) {
        var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        details_box.margin_start = 12;
        details_box.margin_end = 12;
        details_box.margin_top = 12;
        details_box.margin_bottom = 12;
        
        // Basic info group
        var info_group = new Adw.PreferencesGroup ();
        info_group.title = "Backup Information";
        
        var size_row = new Adw.ActionRow ();
        size_row.title = "File Size";
        size_row.subtitle = backup.get_display_size ();
        info_group.add (size_row);
        
        var keys_row = new Adw.ActionRow ();
        keys_row.title = "Keys Included";
        keys_row.subtitle = @"$(backup.key_fingerprints.length) SSH keys";
        info_group.add (keys_row);
        
        if (backup.description != null) {
            var desc_row = new Adw.ActionRow ();
            desc_row.title = "Description";
            desc_row.subtitle = backup.description;
            info_group.add (desc_row);
        }
        
        if (backup.expires_at != null) {
            var expires_row = new Adw.ActionRow ();
            expires_row.title = "Expires";
            expires_row.subtitle = backup.expires_at.format ("%Y-%m-%d %H:%M:%S");
            info_group.add (expires_row);
        }
        
        details_box.append (info_group);
        
        // Actions group
        var actions_group = new Adw.PreferencesGroup ();
        actions_group.title = "Actions";
        
        var restore_row = new Adw.ActionRow ();
        restore_row.title = "Restore Backup";
        
        // Check if backup is time-locked and not yet expired
        if (backup.backup_type == BackupType.TIME_LOCKED && !backup.is_expired()) {
            restore_row.subtitle = "Backup is time-locked and not yet available";
            restore_row.activatable = false;
            restore_row.add_css_class("dim-label");
        } else {
            restore_row.subtitle = "Restore keys from this backup";
            restore_row.activatable = true;
            restore_row.activated.connect (() => {
                restore_specific_backup (backup);
            });
        }
        
        var restore_icon = new Gtk.Image ();
        restore_icon.icon_name = "document-revert-symbolic";
        restore_row.add_prefix (restore_icon);
        
        var restore_button = new Gtk.Image ();
        restore_button.icon_name = "go-next-symbolic";
        restore_row.add_suffix (restore_button);
        
        actions_group.add (restore_row);
        
        var delete_row = new Adw.ActionRow ();
        delete_row.title = "Delete Backup";
        delete_row.subtitle = "Permanently remove this backup";
        delete_row.activatable = true;
        delete_row.activated.connect (() => {
            delete_backup (backup);
        });
        
        var delete_icon = new Gtk.Image ();
        delete_icon.icon_name = "user-trash-symbolic";
        delete_icon.add_css_class ("error");
        delete_row.add_prefix (delete_icon);
        
        actions_group.add (delete_row);
        
        details_box.append (actions_group);
        row.add_row (details_box);
    }
    
    private void on_create_backup () {
        var dialog = new CreateBackupDialog ((Gtk.Window) this.get_root (), vault);
        dialog.present (this);
    }
    
    
    private void restore_specific_backup (BackupEntry backup) {
        // Check if backup is time-locked
        if (backup.backup_type == BackupType.TIME_LOCKED && backup.expires_at != null) {
            var now = new DateTime.now_local ();
            if (now.compare (backup.expires_at) < 0) {
                // Backup is still locked
                show_time_locked_alert (backup);
                return;
            }
        }
        
        var dialog = new RestoreBackupDialog ((Gtk.Window) this.get_root (), vault, backup);
        dialog.present (this);
    }
    
    private void show_time_locked_alert (BackupEntry backup) {
        var alert = new Adw.AlertDialog (
            _("Backup Still Time-Locked"),
            @"This backup is time-locked and cannot be restored until $(backup.expires_at.format ("%Y-%m-%d at %H:%M")).\n\nTime remaining: $(get_time_remaining (backup.expires_at))"
        );
        
        alert.add_response ("ok", _("OK"));
        alert.set_default_response ("ok");
        alert.set_close_response ("ok");
        
        alert.present (this);
    }
    
    private string get_time_remaining (DateTime expires_at) {
        var now = new DateTime.now_local ();
        var time_span = expires_at.difference (now);
        
        if (time_span <= 0) {
            return "None (expired)";
        }
        
        var days = time_span / TimeSpan.DAY;
        var hours = (time_span % TimeSpan.DAY) / TimeSpan.HOUR;
        var minutes = (time_span % TimeSpan.HOUR) / TimeSpan.MINUTE;
        
        if (days > 0) {
            return @"$(days) days, $(hours) hours";
        } else if (hours > 0) {
            return @"$(hours) hours, $(minutes) minutes";
        } else {
            return @"$(minutes) minutes";
        }
    }
    
    private void delete_backup (BackupEntry backup) {
        var confirm_dialog = new Adw.AlertDialog (
            @"Delete Backup \"$(backup.name)\"?",
            "This will permanently delete the backup file. This action cannot be undone."
        );
        
        confirm_dialog.add_response ("cancel", "Cancel");
        confirm_dialog.add_response ("delete", "Delete Backup");
        confirm_dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        confirm_dialog.set_default_response ("cancel");
        confirm_dialog.set_close_response ("cancel");
        
        confirm_dialog.response.connect ((response) => {
            if (response == "delete") {
                perform_backup_deletion (backup);
            }
        });
        
        confirm_dialog.present (this);
    }
    
    private void perform_backup_deletion (BackupEntry backup) {
        try {
            if (backup.backup_file.query_exists ()) {
                backup.backup_file.delete ();
            }
            
            // Remove from vault
            vault.remove_backup_legacy (backup);
            
            populate_backups_list ();
            refresh_vault_status ();
            
        } catch (Error e) {
            show_error ("Delete Failed", @"Could not delete backup: $(e.message)");
        }
    }
    
    private void on_backup_created (BackupEntry backup) {
        populate_backups_list ();
        refresh_vault_status ();
        
        var toast = new Adw.Toast (@"Backup \"$(backup.name)\" created successfully");
        // Would need access to toast overlay from parent window
    }
    
    private void on_backup_restored (BackupEntry backup) {
        var toast = new Adw.Toast (@"Backup \"$(backup.name)\" restored successfully");
        // Would need access to toast overlay from parent window
        
        // Refresh the main window's key list since new keys were restored
        if (parent_window != null && parent_window is KeyMaker.Window) {
            var main_window = (KeyMaker.Window) parent_window;
            main_window.on_refresh_action ();
            print ("EmergencyVaultDialog: Triggered main window refresh after backup restore\n");
        }
    }
    
    private void on_vault_status_changed (VaultStatus status) {
        refresh_vault_status ();
    }
    
    private void on_refresh_backups () {
        populate_backups_list ();
        refresh_vault_status ();
    }
    
    private void on_remove_all_backups () {
        var backups = vault.get_all_backups ();
        
        if (backups.length == 0) {
            show_error ("No Backups", "There are no backups to remove.");
            return;
        }
        
        var confirm_dialog = new Adw.AlertDialog (
            "Remove All Backups?",
            @"This will permanently delete all $(backups.length) backup files. This action cannot be undone."
        );
        
        confirm_dialog.add_response ("cancel", "Cancel");
        confirm_dialog.add_response ("remove_all", "Remove All Backups");
        confirm_dialog.set_response_appearance ("remove_all", Adw.ResponseAppearance.DESTRUCTIVE);
        confirm_dialog.set_default_response ("cancel");
        confirm_dialog.set_close_response ("cancel");
        
        confirm_dialog.response.connect ((response) => {
            if (response == "remove_all") {
                perform_remove_all_backups ();
            }
        });
        
        confirm_dialog.present (this);
    }
    
    private void perform_remove_all_backups () {
        var backups = vault.get_all_backups_legacy ();
        int deleted_count = 0;
        int failed_count = 0;
        
        for (int i = 0; i < backups.length; i++) {
            try {
                if (backups[i].backup_file.query_exists ()) {
                    backups[i].backup_file.delete ();
                }
                
                vault.remove_backup_legacy (backups[i]);
                deleted_count++;
                
            } catch (Error e) {
                warning ("Failed to delete backup %s: %s", backups[i].name, e.message);
                failed_count++;
            }
        }
        
        populate_backups_list ();
        refresh_vault_status ();
        
        if (failed_count > 0) {
            show_error ("Partial Deletion", @"$(deleted_count) backups removed successfully, but $(failed_count) failed to delete.");
        }
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
    
    private BackupEntry convert_to_legacy_backup (EmergencyBackupEntry emergency_backup) {
        // Convert emergency backup type to legacy type
        BackupType legacy_type;
        switch (emergency_backup.backup_type) {
            case EmergencyBackupType.TIME_LOCKED:
                legacy_type = BackupType.TIME_LOCKED;
                break;
            case EmergencyBackupType.QR_CODE:
                legacy_type = BackupType.QR_CODE;
                break;
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                legacy_type = BackupType.SHAMIR_SECRET_SHARING;
                break;
            default:
                // Map new types to time-locked for legacy compatibility
                legacy_type = BackupType.TIME_LOCKED;
                break;
        }
        
        var legacy_backup = new BackupEntry (emergency_backup.name, legacy_type);
        legacy_backup.id = emergency_backup.id;
        legacy_backup.created_at = emergency_backup.created_at;
        legacy_backup.expires_at = emergency_backup.expires_at;
        legacy_backup.backup_file = emergency_backup.backup_file;
        legacy_backup.key_fingerprints = emergency_backup.key_fingerprints;
        legacy_backup.is_encrypted = emergency_backup.is_encrypted;
        legacy_backup.description = emergency_backup.description;
        legacy_backup.file_size = emergency_backup.file_size;
        legacy_backup.checksum = emergency_backup.checksum;
        legacy_backup.shamir_total_shares = emergency_backup.shamir_total_shares;
        legacy_backup.shamir_threshold = emergency_backup.shamir_threshold;
        
        return legacy_backup;
    }
}