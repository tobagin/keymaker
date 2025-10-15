/* CloudKeyDeployDialog.vala
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
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/cloud_key_deploy_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/cloud_key_deploy_dialog.ui")]
#endif
public class KeyMaker.CloudKeyDeployDialog : Adw.Window {
    [GtkChild]
    private unowned Gtk.Button deploy_button;

    [GtkChild]
    private unowned Adw.ComboRow key_selector;

    [GtkChild]
    private unowned Adw.ActionRow fingerprint_row;

    [GtkChild]
    private unowned Adw.ActionRow type_row;

    [GtkChild]
    private unowned Gtk.CheckButton show_warning_check;

    [GtkChild]
    private unowned Adw.ActionRow keys_found_row;

    private CloudProvider provider;
    private GenericArray<SSHKey> available_keys;
    private Settings settings;

    public signal void deployment_completed(bool success);

    public CloudKeyDeployDialog(Gtk.Window parent, CloudProvider provider) {
        Object(transient_for: parent);
        this.provider = provider;
        this.settings = SettingsManager.app;

        deploy_button.clicked.connect(on_deploy_clicked);

        // Load available keys
        load_available_keys();

        // Check if warning should be hidden
        if (!settings.get_boolean("cloud-provider-show-deploy-warning")) {
            show_warning_check.active = true;
        }
    }

    private void load_available_keys() {
        load_available_keys_async.begin();
    }

    private async void load_available_keys_async() {
        try {
            var all_keys = yield KeyScanner.scan_ssh_directory(null);
            debug(@"CloudKeyDeployDialog: Found $(all_keys.length) total keys");

            // Get list of keys already on GitHub
            Gee.List<CloudKeyMetadata>? github_keys = null;
            try {
                github_keys = yield provider.list_keys();
                debug(@"CloudKeyDeployDialog: Found $(github_keys.size) keys on GitHub");
            } catch (Error e) {
                warning(@"Failed to fetch GitHub keys: $(e.message)");
                // Continue without filtering - better to show all than none
            }

            // Filter out keys already on GitHub by comparing fingerprints
            available_keys = new GenericArray<SSHKey>();
            for (uint i = 0; i < all_keys.length; i++) {
                var local_key = all_keys[i];
                bool already_deployed = false;

                if (github_keys != null) {
                    foreach (var github_key in github_keys) {
                        // Compare fingerprints (remove SHA256: prefix if present)
                        var local_fp = local_key.fingerprint.replace("SHA256:", "").strip();
                        var github_fp = github_key.fingerprint.replace("SHA256:", "").strip();

                        if (local_fp == github_fp) {
                            already_deployed = true;
                            debug(@"CloudKeyDeployDialog: Key $(local_key.private_path.get_basename()) already on GitHub");
                            break;
                        }
                    }
                }

                if (!already_deployed) {
                    // AWS IAM only supports RSA keys - filter out other types
                    if (provider is AWSProvider) {
                        if (local_key.key_type == SSHKeyType.RSA) {
                            available_keys.add(local_key);
                        } else {
                            debug(@"CloudKeyDeployDialog: Filtering out $(local_key.key_type.to_string()) key for AWS (only RSA supported)");
                        }
                    } else {
                        available_keys.add(local_key);
                    }
                }
            }

            debug(@"CloudKeyDeployDialog: $(available_keys.length) keys available for deployment");

            // Build string list for combo row
            var string_list = new Gtk.StringList(null);
            for (uint i = 0; i < available_keys.length; i++) {
                var key = available_keys[i];
                var key_name = key.private_path.get_basename();
                debug(@"CloudKeyDeployDialog: Adding key $key_name ($(key.key_type))");
                string_list.append(@"$key_name ($(key.key_type))");
            }

            key_selector.model = string_list;

            // Update the count display
            var filtered_count = all_keys.length - available_keys.length;
            var provider_name = provider.get_provider_name();

            if (filtered_count > 0) {
                if (provider is AWSProvider) {
                    keys_found_row.subtitle = @"Found $(available_keys.length) RSA key(s) (AWS IAM only supports RSA)";
                } else {
                    keys_found_row.subtitle = @"Found $(available_keys.length) deployable key(s) ($(filtered_count) already on $provider_name)";
                }
            } else {
                if (provider is AWSProvider) {
                    keys_found_row.subtitle = @"Found $(available_keys.length) RSA key(s) available";
                } else {
                    keys_found_row.subtitle = @"Found $(available_keys.length) SSH key(s) in ~/.ssh/";
                }
            }

            if (available_keys.length > 0) {
                key_selector.selected = 0;
                update_key_details(available_keys[0]);
                debug(@"CloudKeyDeployDialog: Selected first key");
                deploy_button.sensitive = true;
            } else {
                if (all_keys.length > 0) {
                    if (provider is AWSProvider) {
                        keys_found_row.subtitle = _("No RSA keys found. AWS IAM only supports RSA keys (2048+ bits).");
                    } else {
                        keys_found_row.subtitle = @"All keys are already deployed to $provider_name";
                    }
                } else {
                    keys_found_row.subtitle = _("No valid SSH keys found in ~/.ssh/");
                }
                deploy_button.sensitive = false;
            }
        } catch (Error e) {
            warning(@"Failed to load keys: $(e.message)");
            keys_found_row.subtitle = @"Error: $(e.message)";
            deploy_button.sensitive = false;
        }

        // Listen for selection changes
        key_selector.notify["selected"].connect(() => {
            if (key_selector.selected < available_keys.length) {
                update_key_details(available_keys[(int)key_selector.selected]);
            }
        });
    }

    private void update_key_details(SSHKey key) {
        fingerprint_row.subtitle = key.fingerprint ?? _("Unknown");
        var bits_info = key.bit_size > 0 ? @"$(key.bit_size) bits" : "";
        type_row.subtitle = @"$(key.key_type) $bits_info";
    }

    private void on_deploy_clicked() {
        if (key_selector.selected >= available_keys.length) {
            return;
        }

        var selected_key = available_keys[(int)key_selector.selected];

        // Save warning preference
        if (show_warning_check.active) {
            settings.set_boolean("cloud-provider-show-deploy-warning", false);
        }

        deploy_key.begin(selected_key);
    }

    private async void deploy_key(SSHKey key) {
        deploy_button.sensitive = false;

        try {
            // Read public key content
            string public_key_content;
            if (!FileUtils.get_contents(key.public_path.get_path(), out public_key_content)) {
                throw new IOError.FAILED("Failed to read public key file");
            }

            // Extract title from key comment or use filename
            var key_name = key.private_path.get_basename();
            var title = extract_key_title(public_key_content, key_name);

            yield provider.deploy_key(public_key_content.strip(), title);

            deployment_completed(true);
            close();
        } catch (Error e) {
            show_error_dialog(@"Failed to deploy key: $(e.message)");
            deploy_button.sensitive = true;
            deployment_completed(false);
        }
    }

    private string extract_key_title(string key_content, string fallback_name) {
        // Try to extract comment from public key
        var parts = key_content.strip().split(" ");
        if (parts.length >= 3) {
            return parts[2]; // Comment is usually the third part
        }

        // Fallback to filename with timestamp
        var now = new DateTime.now_local();
        return @"KeyMaker Key - $fallback_name ($(now.format("%Y-%m-%d")))";
    }

    private void show_error_dialog(string message) {
        var dialog = new Adw.MessageDialog((Gtk.Window) this.get_root(), _("Deployment Failed"), message);
        dialog.add_response("ok", _("OK"));
        dialog.set_default_response("ok");
        dialog.present();
    }
}
