/*
 * Key Maker - Emergency Backup Authentication Dialog
 *
 * Secure authentication dialog for emergency backup operations with
 * rate limiting to prevent brute-force attempts.
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

    public class EmergencyBackupAuthDialog : Adw.Dialog {
        private Gtk.Entry password_entry;
        private Gtk.Button auth_button;
        private Gtk.Label error_label;
        private Gtk.Label countdown_label;
        private int failed_attempts = 0;
        private const int MAX_ATTEMPTS = 3;
        private const int COOLDOWN_SECONDS = 30;
        private uint cooldown_timeout_id = 0;
        private int cooldown_remaining = 0;

        public string password { get; private set; default = ""; }
        public bool authenticated { get; private set; default = false; }

        private string operation_name;
        private string backup_name;

        public signal void authentication_result (bool success, string? password);

        public EmergencyBackupAuthDialog (string operation_name, string backup_name) {
            this.operation_name = operation_name;
            this.backup_name = backup_name;

            build_ui ();
        }

        ~EmergencyBackupAuthDialog () {
            stop_cooldown_timer ();
        }

        private void build_ui () {
            this.title = "Authentication Required";
            this.content_width = 450;
            this.content_height = 400;

            var toolbar_view = new Adw.ToolbarView ();

            var header_bar = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header_bar);

            var content = create_content ();
            toolbar_view.content = content;

            this.child = toolbar_view;
        }

        private Gtk.Widget create_content () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
            box.margin_top = 24;
            box.margin_bottom = 24;
            box.margin_start = 24;
            box.margin_end = 24;

            // Warning banner
            var warning = create_warning_banner ();
            box.append (warning);

            // Operation info
            var info_group = create_info_group ();
            box.append (info_group);

            // Authentication group
            var auth_group = create_auth_group ();
            box.append (auth_group);

            // Error message (initially hidden)
            error_label = new Gtk.Label ("");
            error_label.add_css_class ("error");
            error_label.wrap = true;
            error_label.visible = false;
            box.append (error_label);

            // Cooldown countdown (initially hidden)
            countdown_label = new Gtk.Label ("");
            countdown_label.add_css_class ("warning");
            countdown_label.add_css_class ("title-3");
            countdown_label.visible = false;
            box.append (countdown_label);

            // Action buttons
            var action_bar = create_action_bar ();
            box.append (action_bar);

            return box;
        }

        private Gtk.Widget create_warning_banner () {
            var banner = new Adw.Banner (@"⚠️  Warning: $(operation_name) is irreversible");
            banner.use_markup = true;
            return banner;
        }

        private Gtk.Widget create_info_group () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Operation Details";

            var operation_row = new Adw.ActionRow ();
            operation_row.title = "Operation";
            operation_row.subtitle = operation_name;

            var op_icon = new Gtk.Image.from_icon_name ("edit-delete-symbolic");
            op_icon.icon_size = Gtk.IconSize.NORMAL;
            operation_row.add_prefix (op_icon);
            group.add (operation_row);

            var backup_row = new Adw.ActionRow ();
            backup_row.title = "Backup";
            backup_row.subtitle = backup_name;

            var backup_icon = new Gtk.Image.from_icon_name ("security-high-symbolic");
            backup_icon.icon_size = Gtk.IconSize.NORMAL;
            backup_row.add_prefix (backup_icon);
            group.add (backup_row);

            return group;
        }

        private Gtk.Widget create_auth_group () {
            var group = new Adw.PreferencesGroup ();
            group.title = "Authentication";
            group.description = "Enter the password or passphrase used to create this emergency backup.";

            var password_row = new Adw.EntryRow ();
            password_row.title = "Password";
            password_row.show_apply_button = false;

            password_entry = new Gtk.Entry ();
            password_entry.visibility = false;
            password_entry.input_purpose = Gtk.InputPurpose.PASSWORD;
            password_entry.placeholder_text = "Enter password";
            password_entry.activate.connect (on_authenticate);

            // Add show/hide toggle
            var toggle_button = new Gtk.ToggleButton ();
            toggle_button.icon_name = "view-reveal-symbolic";
            toggle_button.tooltip_text = "Show password";
            toggle_button.valign = Gtk.Align.CENTER;
            toggle_button.toggled.connect (() => {
                password_entry.visibility = toggle_button.active;
                toggle_button.icon_name = toggle_button.active ?
                    "view-conceal-symbolic" : "view-reveal-symbolic";
                toggle_button.tooltip_text = toggle_button.active ?
                    "Hide password" : "Show password";
            });

            password_entry.secondary_icon_name = null;

            // Create a box for the password entry with toggle button
            var entry_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            entry_box.hexpand = true;
            password_entry.hexpand = true;
            entry_box.append (password_entry);
            entry_box.append (toggle_button);

            password_row.add_suffix (entry_box);
            group.add (password_row);

            return group;
        }

        private Gtk.Widget create_action_bar () {
            var action_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            action_bar.homogeneous = true;

            auth_button = new Gtk.Button.with_label ("Authenticate & Continue");
            auth_button.add_css_class ("destructive-action");
            auth_button.clicked.connect (on_authenticate);
            auth_button.sensitive = true;

            var cancel_button = new Gtk.Button.with_label ("Cancel");
            cancel_button.clicked.connect (() => {
                authenticated = false;
                authentication_result (false, null);
                this.close ();
            });

            action_bar.append (auth_button);
            action_bar.append (cancel_button);

            return action_bar;
        }

        private void on_authenticate () {
            var entered_password = password_entry.text.strip ();

            if (entered_password.length == 0) {
                show_error ("Password cannot be empty");
                return;
            }

            // Store the password
            password = entered_password;

            // Signal that authentication was attempted
            // The parent will verify the password and call handle_auth_result
            authentication_result (true, password);
        }

        public void handle_auth_result (bool success) {
            if (success) {
                authenticated = true;
                failed_attempts = 0;
                this.close ();
            } else {
                failed_attempts++;
                password_entry.text = "";  // Clear password for security
                password_entry.grab_focus ();

                if (failed_attempts >= MAX_ATTEMPTS) {
                    start_cooldown ();
                    show_error (@"Too many failed attempts. Please wait $(COOLDOWN_SECONDS) seconds.");
                } else {
                    show_error (@"Authentication failed. Attempt $(failed_attempts) of $(MAX_ATTEMPTS).");

                    // Add shake animation
                    add_css_class ("shake");
                    Timeout.add (500, () => {
                        remove_css_class ("shake");
                        return Source.REMOVE;
                    });
                }
            }
        }

        private void show_error (string message) {
            error_label.label = message;
            error_label.visible = true;
        }

        private void start_cooldown () {
            auth_button.sensitive = false;
            password_entry.sensitive = false;
            cooldown_remaining = COOLDOWN_SECONDS;
            update_countdown_display ();
            countdown_label.visible = true;

            cooldown_timeout_id = Timeout.add_seconds (1, () => {
                cooldown_remaining--;
                update_countdown_display ();

                if (cooldown_remaining <= 0) {
                    end_cooldown ();
                    return Source.REMOVE;
                }

                return Source.CONTINUE;
            });
        }

        private void update_countdown_display () {
            countdown_label.label = @"Cooldown: $(cooldown_remaining) seconds remaining";
        }

        private void end_cooldown () {
            stop_cooldown_timer ();
            auth_button.sensitive = true;
            password_entry.sensitive = true;
            countdown_label.visible = false;
            failed_attempts = 0;
            error_label.visible = false;
            password_entry.grab_focus ();
        }

        private void stop_cooldown_timer () {
            if (cooldown_timeout_id > 0) {
                Source.remove (cooldown_timeout_id);
                cooldown_timeout_id = 0;
            }
        }

        public override void closed () {
            stop_cooldown_timer ();
            base.closed ();
        }
    }
}
