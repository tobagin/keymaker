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
    private unowned Gtk.Button create_backup_button;
    
    [GtkChild]
    private unowned Adw.StatusPage vault_status_page;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Gtk.Box backups_page;
    
    [GtkChild]
    private unowned Gtk.ListBox backups_list;
    
    [GtkChild]
    private unowned Gtk.Label vault_status_label;
    
    [GtkChild]
    private unowned Gtk.Image vault_status_icon;
    
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
            setup_signals ();
            refresh_vault_status ();
            populate_backups_list ();
            return false;
        });
    }
    
    private void setup_signals () {
        if (create_backup_button != null) {
            create_backup_button.clicked.connect (on_create_backup);
        }
        
        if (vault != null) {
            vault.backup_created.connect (on_backup_created);
            vault.backup_restored.connect (on_backup_restored);
            vault.vault_status_changed.connect (on_vault_status_changed);
        }
    }
    
    // Keys will be loaded on-demand when creating backups
    
    private void refresh_vault_status () {
        if (vault_status_label == null || vault_status_icon == null || vault_status_page == null) {
            return;
        }
        
        var status = vault.get_vault_status ();
        
        vault_status_label.label = status.to_string ();
        vault_status_icon.icon_name = status.get_icon_name ();
        
        // Update status page styling
        vault_status_icon.remove_css_class ("success");
        vault_status_icon.remove_css_class ("warning");
        vault_status_icon.remove_css_class ("error");
        
        vault_status_label.remove_css_class ("success");
        vault_status_label.remove_css_class ("warning");
        vault_status_label.remove_css_class ("error");
        
        switch (status) {
            case VaultStatus.HEALTHY:
                vault_status_icon.add_css_class ("success");
                vault_status_label.add_css_class ("success");
                vault_status_page.description = "Emergency vault is functioning properly";
                break;
                
            case VaultStatus.WARNING:
                vault_status_icon.add_css_class ("warning");
                vault_status_label.add_css_class ("warning");
                vault_status_page.description = "Some backups may need attention";
                break;
                
            case VaultStatus.CRITICAL:
                vault_status_icon.add_css_class ("error");
                vault_status_label.add_css_class ("error");
                vault_status_page.description = "Multiple backup issues detected";
                break;
                
            case VaultStatus.CORRUPTED:
                vault_status_icon.add_css_class ("error");
                vault_status_label.add_css_class ("error");
                vault_status_page.description = "Vault corruption detected - immediate action required";
                break;
        }
    }
    
    private void populate_backups_list () {
        if (vault_status_page == null || main_stack == null || backups_list == null) {
            return;
        }
        
        clear_backups_list ();
        
        var backups = vault.get_all_backups ();
        
        if (backups.length == 0) {
            vault_status_page.title = "No Emergency Backups";
            vault_status_page.description = "Create encrypted backups to protect against key loss";
            vault_status_page.icon_name = "folder-symbolic";
            main_stack.visible_child = vault_status_page;
        } else {
            for (int i = 0; i < backups.length; i++) {
                add_backup_row (backups[i]);
            }
            main_stack.visible_child = backups_page;
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
                icon_name = "qr-code-symbolic";
                break;
            case BackupType.SHAMIR_SECRET_SHARING:
                icon_name = "view-app-grid-symbolic"; // More common grid icon
                break;
            case BackupType.TIME_LOCKED:
                icon_name = "appointment-soon-symbolic"; // More common time icon
                break;
        }
        type_icon.icon_name = icon_name;
        debug ("EmergencyVaultDialog: Setting backup icon to: %s", icon_name);
        row.add_prefix (type_icon);
        
        // Add status indicator
        var status_icon = new Gtk.Image ();
        if (backup.is_expired ()) {
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
        restore_row.subtitle = "Restore keys from this backup";
        restore_row.activatable = true;
        restore_row.activated.connect (() => {
            restore_specific_backup (backup);
        });
        
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
            vault.remove_backup (backup);
            
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
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}