/*
 * Key Maker - Backup Details Dialog
 *
 * Displays comprehensive details for regular backups including metadata,
 * encryption status, key list, and action buttons.
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

    public class BackupDetailsDialog : Adw.Dialog {
        private RegularBackupEntry backup;
        private BackupManager backup_manager;

        public signal void restore_requested (RegularBackupEntry backup);
        public signal void delete_requested (RegularBackupEntry backup);

        public BackupDetailsDialog (RegularBackupEntry backup, BackupManager backup_manager) {
            this.backup = backup;
            this.backup_manager = backup_manager;

            build_ui ();
        }

        private void build_ui () {
            this.title = backup.name;
            this.content_width = 500;
            this.content_height = 600;

            var toolbar_view = new Adw.ToolbarView ();

            var header_bar = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header_bar);

            var content = create_content ();
            toolbar_view.content = content;

            this.child = toolbar_view;
        }

        private Gtk.Widget create_content () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Main content in scrolled window
            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
            content_box.margin_top = 24;
            content_box.margin_bottom = 24;
            content_box.margin_start = 24;
            content_box.margin_end = 24;

            // Backup info section
            content_box.append (create_info_section ());

            // Keys section
            content_box.append (create_keys_section ());

            // Technical details section
            content_box.append (create_technical_section ());

            scrolled.child = content_box;
            box.append (scrolled);

            // Action buttons at bottom
            box.append (create_action_buttons ());

            return box;
        }

        private Gtk.Widget create_info_section () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Backup Information";

            // Backup type
            var type_row = new Adw.ActionRow ();
            type_row.title = "Type";
            type_row.subtitle = BackupHelpers.get_backup_type_name (backup.backup_type);

            var type_icon = new Gtk.Image.from_icon_name (BackupHelpers.get_backup_type_icon (backup.backup_type));
            type_icon.icon_size = Gtk.IconSize.NORMAL;
            type_row.add_prefix (type_icon);
            group.add (type_row);

            // Created date
            var created_row = new Adw.ActionRow ();
            created_row.title = "Created";
            created_row.subtitle = BackupHelpers.format_datetime (backup.created_at) + "\n" +
                                    BackupHelpers.format_relative_time (backup.created_at);

            var calendar_icon = new Gtk.Image.from_icon_name ("x-office-calendar-symbolic");
            calendar_icon.icon_size = Gtk.IconSize.NORMAL;
            created_row.add_prefix (calendar_icon);
            group.add (created_row);

            // File size
            var size_row = new Adw.ActionRow ();
            size_row.title = "Size";
            size_row.subtitle = BackupHelpers.format_file_size (backup.file_size);

            var size_icon = new Gtk.Image.from_icon_name ("drive-harddisk-symbolic");
            size_icon.icon_size = Gtk.IconSize.NORMAL;
            size_row.add_prefix (size_icon);
            group.add (size_row);

            // Encryption status
            var encryption_row = new Adw.ActionRow ();
            encryption_row.title = "Encryption";
            encryption_row.subtitle = backup.is_encrypted ? "Encrypted" : "Unencrypted";

            var lock_icon = new Gtk.Image.from_icon_name (
                backup.is_encrypted ? "security-high-symbolic" : "security-low-symbolic"
            );
            lock_icon.icon_size = Gtk.IconSize.NORMAL;
            encryption_row.add_prefix (lock_icon);
            group.add (encryption_row);

            // Cloud sync status (if applicable)
            if (backup.backup_type == RegularBackupType.CLOUD_SYNC && backup.cloud_provider != null) {
                var cloud_row = new Adw.ActionRow ();
                cloud_row.title = "Cloud Provider";
                cloud_row.subtitle = backup.cloud_provider;

                if (backup.last_synced != null) {
                    cloud_row.subtitle += "\nLast synced: " + BackupHelpers.format_relative_time (backup.last_synced);
                } else {
                    cloud_row.subtitle += "\nNever synced";
                }

                var cloud_icon = new Gtk.Image.from_icon_name ("folder-remote-symbolic");
                cloud_icon.icon_size = Gtk.IconSize.NORMAL;
                cloud_row.add_prefix (cloud_icon);
                group.add (cloud_row);
            }

            // Description (if present)
            if (backup.description != null && backup.description.length > 0) {
                var desc_row = new Adw.ActionRow ();
                desc_row.title = "Description";
                desc_row.subtitle = backup.description;

                var desc_icon = new Gtk.Image.from_icon_name ("text-x-generic-symbolic");
                desc_icon.icon_size = Gtk.IconSize.NORMAL;
                desc_row.add_prefix (desc_icon);
                group.add (desc_row);
            }

            return group;
        }

        private Gtk.Widget create_keys_section () {
            var group = new Adw.PreferencesGroup ();
            group.title = @"Included Keys ($(backup.key_fingerprints.length))";

            if (backup.key_fingerprints.length == 0) {
                var empty_label = new Gtk.Label ("No keys in this backup");
                empty_label.add_css_class ("dim-label");
                empty_label.margin_top = 12;
                empty_label.margin_bottom = 12;
                group.add (empty_label);
            } else {
                for (int i = 0; i < backup.key_fingerprints.length; i++) {
                    var fingerprint = backup.key_fingerprints[i];

                    var key_row = new Adw.ActionRow ();
                    key_row.title = BackupHelpers.format_fingerprint (fingerprint);

                    var key_icon = new Gtk.Image.from_icon_name ("dialog-password-symbolic");
                    key_icon.icon_size = Gtk.IconSize.NORMAL;
                    key_row.add_prefix (key_icon);

                    group.add (key_row);
                }
            }

            return group;
        }

        private Gtk.Widget create_technical_section () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Technical Details";

            // Checksum
            var checksum_row = new Adw.ActionRow ();
            checksum_row.title = "Checksum";
            checksum_row.subtitle = backup.checksum;

            var checksum_icon = new Gtk.Image.from_icon_name ("emblem-ok-symbolic");
            checksum_icon.icon_size = Gtk.IconSize.NORMAL;
            checksum_row.add_prefix (checksum_icon);
            group.add (checksum_row);

            // Backup ID
            var id_row = new Adw.ActionRow ();
            id_row.title = "Backup ID";
            id_row.subtitle = backup.id;

            var id_icon = new Gtk.Image.from_icon_name ("view-list-symbolic");
            id_icon.icon_size = Gtk.IconSize.NORMAL;
            id_row.add_prefix (id_icon);
            group.add (id_row);

            // File path
            var path_row = new Adw.ActionRow ();
            path_row.title = "File Location";
            path_row.subtitle = backup.backup_file.get_path ();

            var path_icon = new Gtk.Image.from_icon_name ("folder-open-symbolic");
            path_icon.icon_size = Gtk.IconSize.NORMAL;
            path_row.add_prefix (path_icon);
            group.add (path_row);

            return group;
        }

        private Gtk.Widget create_action_buttons () {
            var action_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            action_bar.margin_top = 12;
            action_bar.margin_bottom = 12;
            action_bar.margin_start = 12;
            action_bar.margin_end = 12;
            action_bar.homogeneous = true;

            var restore_button = new Gtk.Button.with_label ("Restore");
            restore_button.add_css_class ("suggested-action");
            restore_button.clicked.connect (() => {
                restore_requested (backup);
                this.close ();
            });

            var delete_button = new Gtk.Button.with_label ("Delete");
            delete_button.add_css_class ("destructive-action");
            delete_button.clicked.connect (() => {
                delete_requested (backup);
                this.close ();
            });

            var close_button = new Gtk.Button.with_label ("Close");
            close_button.clicked.connect (() => {
                this.close ();
            });

            action_bar.append (restore_button);
            action_bar.append (delete_button);
            action_bar.append (close_button);

            return action_bar;
        }
    }
}
