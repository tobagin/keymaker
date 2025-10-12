/*
 * Key Maker - Emergency Backup Details Dialog
 *
 * Displays comprehensive details for emergency backups with security warnings,
 * time-lock countdown, Shamir secret sharing info, and unlock methods.
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

    public class EmergencyBackupDetailsDialog : Adw.Dialog {
        private EmergencyBackupEntry backup;
        private EmergencyVault vault;
        private uint timeout_id = 0;
        private Gtk.Label? countdown_label = null;

        public signal void restore_requested (EmergencyBackupEntry backup);
        public signal void delete_requested (EmergencyBackupEntry backup);

        public EmergencyBackupDetailsDialog (EmergencyBackupEntry backup, EmergencyVault vault) {
            this.backup = backup;
            this.vault = vault;

            build_ui ();

            // Start countdown timer for time-locked backups
            if (backup.backup_type == EmergencyBackupType.TIME_LOCKED && backup.expires_at != null) {
                start_countdown_timer ();
            }
        }

        ~EmergencyBackupDetailsDialog () {
            stop_countdown_timer ();
        }

        private void build_ui () {
            this.title = backup.name;
            this.content_width = 550;
            this.content_height = 650;

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

            // Security warning (if applicable)
            var warning = create_security_warning ();
            if (warning != null) {
                content_box.append (warning);
            }

            // Backup info section
            content_box.append (create_info_section ());

            // Type-specific section
            content_box.append (create_type_specific_section ());

            // Technical details section
            content_box.append (create_technical_section ());

            scrolled.child = content_box;
            box.append (scrolled);

            // Action buttons at bottom
            box.append (create_action_buttons ());

            return box;
        }

        private Gtk.Widget? create_security_warning () {
            // Show warning for QR code backups
            if (backup.backup_type == EmergencyBackupType.QR_CODE) {
                var banner = new Adw.Banner (_("Security Warning: QR code backups contain unencrypted private keys"));
                banner.button_label = _("Learn More");
                banner.button_clicked.connect (() => {
                    var dialog = new Adw.AlertDialog (
                        _("QR Code Security"),
                        _("QR code backups store your private keys in an unencrypted format that can be scanned with any QR code reader. Anyone who gains access to the QR code image can access your private keys.\n\nRecommendations:\n• Store QR code images in a secure, encrypted location\n• Never share QR codes via email or messaging\n• Consider using time-locked or Shamir secret sharing for better security\n• Print QR codes and store in a secure physical location")
                    );
                    dialog.add_response ("ok", _("I Understand"));
                    dialog.set_default_response ("ok");
                    dialog.present (this);
                });
                return banner;
            }

            return null;
        }

        private Gtk.Widget create_info_section () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Backup Information";

            // Backup type
            var type_row = new Adw.ActionRow ();
            type_row.title = "Type";
            type_row.subtitle = BackupHelpers.get_emergency_backup_type_name (backup.backup_type);

            var type_icon = new Gtk.Image.from_icon_name (BackupHelpers.get_emergency_backup_type_icon (backup.backup_type));
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

        private Gtk.Widget create_type_specific_section () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Security Method";

            switch (backup.backup_type) {
                case EmergencyBackupType.TIME_LOCKED:
                    if (backup.expires_at != null) {
                        var unlock_row = new Adw.ActionRow ();
                        unlock_row.title = "Time Lock Status";

                        var remaining = BackupHelpers.calculate_time_remaining (backup.expires_at);
                        countdown_label = new Gtk.Label ("");
                        countdown_label.add_css_class ("title-2");
                        update_countdown_label (remaining);

                        unlock_row.add_suffix (countdown_label);

                        var clock_icon = new Gtk.Image.from_icon_name ("alarm-symbolic");
                        clock_icon.icon_size = Gtk.IconSize.NORMAL;
                        unlock_row.add_prefix (clock_icon);
                        group.add (unlock_row);

                        var unlock_time_row = new Adw.ActionRow ();
                        unlock_time_row.title = "Unlocks At";
                        unlock_time_row.subtitle = BackupHelpers.format_datetime (backup.expires_at);
                        group.add (unlock_time_row);
                    }
                    break;

                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    var threshold_row = new Adw.ActionRow ();
                    threshold_row.title = "Secret Sharing Threshold";
                    threshold_row.subtitle = @"Requires $(backup.shamir_threshold) of $(backup.shamir_total_shares) shares to restore";

                    var shares_icon = new Gtk.Image.from_icon_name ("view-grid-symbolic");
                    shares_icon.icon_size = Gtk.IconSize.NORMAL;
                    threshold_row.add_prefix (shares_icon);
                    group.add (threshold_row);

                    var explanation_label = new Gtk.Label (
                        @"This backup uses Shamir's Secret Sharing. You need to collect $(backup.shamir_threshold) different shares from the total $(backup.shamir_total_shares) shares to restore the backup."
                    );
                    explanation_label.wrap = true;
                    explanation_label.xalign = 0;
                    explanation_label.add_css_class ("dim-label");
                    explanation_label.margin_top = 12;
                    group.add (explanation_label);
                    break;

                case EmergencyBackupType.QR_CODE:
                    var qr_row = new Adw.ActionRow ();
                    qr_row.title = "QR Code Method";
                    qr_row.subtitle = "Scan QR code to restore backup";

                    var qr_icon = new Gtk.Image.from_icon_name ("qr-code-symbolic");
                    qr_icon.icon_size = Gtk.IconSize.NORMAL;
                    qr_row.add_prefix (qr_icon);
                    group.add (qr_row);
                    break;

                case EmergencyBackupType.TOTP_PROTECTED:
                    var totp_row = new Adw.ActionRow ();
                    totp_row.title = "TOTP Protection";
                    totp_row.subtitle = "Requires time-based one-time password";

                    var totp_icon = new Gtk.Image.from_icon_name ("security-medium-symbolic");
                    totp_icon.icon_size = Gtk.IconSize.NORMAL;
                    totp_row.add_prefix (totp_icon);
                    group.add (totp_row);
                    break;

                case EmergencyBackupType.MULTI_FACTOR:
                    var mfa_row = new Adw.ActionRow ();
                    mfa_row.title = "Multi-Factor Authentication";
                    mfa_row.subtitle = "Requires multiple authentication methods";

                    var mfa_icon = new Gtk.Image.from_icon_name ("emblem-system-symbolic");
                    mfa_icon.icon_size = Gtk.IconSize.NORMAL;
                    mfa_row.add_prefix (mfa_icon);
                    group.add (mfa_row);
                    break;

                case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                    var enc_row = new Adw.ActionRow ();
                    enc_row.title = "Encryption";
                    enc_row.subtitle = "Password-protected encrypted archive";

                    var enc_icon = new Gtk.Image.from_icon_name ("security-high-symbolic");
                    enc_icon.icon_size = Gtk.IconSize.NORMAL;
                    enc_row.add_prefix (enc_icon);
                    group.add (enc_row);
                    break;
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

        private void start_countdown_timer () {
            timeout_id = Timeout.add_seconds (1, update_countdown);
        }

        private void stop_countdown_timer () {
            if (timeout_id > 0) {
                Source.remove (timeout_id);
                timeout_id = 0;
            }
        }

        private bool update_countdown () {
            if (backup.expires_at == null || countdown_label == null) {
                return Source.REMOVE;
            }

            var remaining = BackupHelpers.calculate_time_remaining (backup.expires_at);
            update_countdown_label (remaining);

            if (remaining <= 0) {
                return Source.REMOVE;
            }

            return Source.CONTINUE;
        }

        private void update_countdown_label (TimeSpan remaining) {
            if (countdown_label == null) {
                return;
            }

            countdown_label.label = BackupHelpers.format_time_remaining (remaining);

            if (remaining <= 0) {
                countdown_label.add_css_class ("success");
            } else if (remaining < TimeSpan.DAY) {
                countdown_label.add_css_class ("warning");
            }
        }

        public override void closed () {
            stop_countdown_timer ();
            base.closed ();
        }
    }
}
