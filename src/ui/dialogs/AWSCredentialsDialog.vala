/* AWSCredentialsDialog.vala
 *
 * Copyright 2025 Tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/aws_credentials_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/aws_credentials_dialog.ui")]
#endif
public class KeyMaker.AWSCredentialsDialog : Adw.Window {
    [GtkChild]
    private unowned Adw.EntryRow access_key_entry;

    [GtkChild]
    private unowned Adw.PasswordEntryRow secret_key_entry;

    [GtkChild]
    private unowned Adw.ComboRow region_combo;

    [GtkChild]
    private unowned Gtk.Label error_label;

    [GtkChild]
    private unowned Gtk.Spinner auth_spinner;

    [GtkChild]
    private unowned Gtk.Label status_label;

    [GtkChild]
    private unowned Gtk.Button cancel_button;

    [GtkChild]
    private unowned Gtk.Button connect_button;

    [GtkChild]
    private unowned Gtk.Button documentation_button;

    [GtkChild]
    private unowned Adw.Banner security_warning_banner;

    private AWSProvider provider;
    private bool authenticated = false;

    public signal void credentials_configured(bool success);

    // Region code mapping (combo row index to AWS region code)
    private const string[] REGION_CODES = {
        "us-east-1",
        "us-east-2",
        "us-west-1",
        "us-west-2",
        "eu-west-1",
        "eu-west-2",
        "eu-west-3",
        "eu-central-1",
        "ap-northeast-1",
        "ap-northeast-2",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-south-1",
        "sa-east-1",
        "ca-central-1"
    };

    public AWSCredentialsDialog(Gtk.Window parent, AWSProvider provider) {
        Object(transient_for: parent);
        this.provider = provider;

        // Set up button handlers
        cancel_button.clicked.connect(() => {
            credentials_configured(false);
            close();
        });

        connect_button.clicked.connect(() => {
            validate_and_connect.begin();
        });

        documentation_button.clicked.connect(() => {
            show_iam_policy_example();
        });

        // Set default region (us-east-1)
        region_combo.selected = 0;

        // Load existing region if set
        var current_region = provider.get_region();
        for (int i = 0; i < REGION_CODES.length; i++) {
            if (REGION_CODES[i] == current_region) {
                region_combo.selected = i;
                break;
            }
        }
    }

    private async void validate_and_connect() {
        var access_key = access_key_entry.text.strip();
        var secret_key = secret_key_entry.text.strip();
        var region = REGION_CODES[region_combo.selected];

        // Clear previous errors
        error_label.visible = false;
        error_label.label = "";

        // Validate input
        if (access_key.length == 0) {
            show_error(_("Please enter an Access Key ID"));
            return;
        }

        if (secret_key.length == 0) {
            show_error(_("Please enter a Secret Access Key"));
            return;
        }

        // Validate Access Key ID format
        if (!access_key.has_prefix("AKIA") && !access_key.has_prefix("ASIA")) {
            show_error(_("Invalid Access Key ID format. Must start with AKIA or ASIA."));
            return;
        }

        // Validate Secret Access Key length
        if (secret_key.length != 40) {
            show_error(_("Invalid Secret Access Key length. Must be 40 characters."));
            return;
        }

        // Show loading state
        connect_button.sensitive = false;
        cancel_button.sensitive = false;
        access_key_entry.sensitive = false;
        secret_key_entry.sensitive = false;
        region_combo.sensitive = false;
        auth_spinner.visible = true;
        auth_spinner.spinning = true;
        status_label.visible = true;
        status_label.label = _("Validating credentials...");

        try {
            // Set credentials in provider
            provider.set_credentials(access_key, secret_key, region);

            // Test authentication
            status_label.label = _("Connecting to AWS IAM...");
            var success = yield provider.authenticate();

            if (success) {
                // Success!
                auth_spinner.spinning = false;
                status_label.label = _("Connected successfully!");
                authenticated = true;

                // Close dialog after a short delay
                Timeout.add(1000, () => {
                    credentials_configured(true);
                    close();
                    return Source.REMOVE;
                });
            } else {
                show_error(_("Authentication failed. Please check your credentials."));
                reset_ui();
            }
        } catch (Error e) {
            show_error(e.message);
            reset_ui();
        }
    }

    private void show_error(string message) {
        error_label.label = message;
        error_label.visible = true;
    }

    private void reset_ui() {
        connect_button.sensitive = true;
        cancel_button.sensitive = true;
        access_key_entry.sensitive = true;
        secret_key_entry.sensitive = true;
        region_combo.sensitive = true;
        auth_spinner.visible = false;
        auth_spinner.spinning = false;
        status_label.visible = false;
    }

    private void show_iam_policy_example() {
        var dialog = new Adw.MessageDialog(
            this,
            _("IAM Policy Example"),
            _("Attach this policy to your IAM user to grant the required permissions:")
        );

        var policy = """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetUser",
        "iam:ListSSHPublicKeys",
        "iam:GetSSHPublicKey",
        "iam:UploadSSHPublicKey",
        "iam:DeleteSSHPublicKey"
      ],
      "Resource": "arn:aws:iam::*:user/${aws:username}"
    }
  ]
}""";

        dialog.body = policy;
        dialog.body_use_markup = false;
        dialog.add_response("close", _("Close"));
        dialog.default_response = "close";
        dialog.close_response = "close";

        // Style the body as monospace
        dialog.present();
    }
}
