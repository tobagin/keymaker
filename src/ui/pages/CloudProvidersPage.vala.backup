/* CloudProvidersPage.vala
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
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/cloud_providers_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/cloud_providers_page.ui")]
#endif
public class KeyMaker.CloudProvidersPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Button connect_button;

    [GtkChild]
    private unowned Gtk.Label connection_status_label;

    [GtkChild]
    private unowned Gtk.Button disconnect_button;

    [GtkChild]
    private unowned Gtk.Button refresh_button;

    [GtkChild]
    private unowned Gtk.ListBox keys_list_box;

    [GtkChild]
    private unowned Adw.StatusPage empty_state;

    [GtkChild]
    private unowned Gtk.Box loading_box;

    [GtkChild]
    private unowned Gtk.Button deploy_key_button;

    [GtkChild]
    private unowned Adw.Banner error_banner;

    private GitHubProvider github_provider;
    private CacheManager cache_manager;
    private Settings settings;
    private Gee.List<CloudKeyMetadata>? current_keys = null;

    construct {
        github_provider = new GitHubProvider();
        cache_manager = new CacheManager();
        settings = SettingsManager.app;

        // Wire up signals
        connect_button.clicked.connect(on_connect_clicked);
        disconnect_button.clicked.connect(on_disconnect_clicked);
        refresh_button.clicked.connect(on_refresh_clicked);
        deploy_key_button.clicked.connect(on_deploy_key_clicked);
        error_banner.button_clicked.connect(on_refresh_clicked);

        // Load initial state
        load_initial_state.begin();
    }

    private async void load_initial_state() {
        var is_connected = settings.get_boolean("cloud-provider-github-connected");
        var username = settings.get_string("cloud-provider-github-username");

        if (is_connected && username.length > 0) {
            try {
                if (yield github_provider.load_stored_auth(username)) {
                    update_ui_connected(username);
                    yield load_keys(true); // Try from cache first
                } else {
                    // Token invalid, disconnect
                    yield disconnect();
                }
            } catch (Error e) {
                warning(@"Failed to load stored auth: $(e.message)");
                update_ui_disconnected();
            }
        } else {
            update_ui_disconnected();
        }
    }

    private void on_connect_clicked() {
        authenticate.begin();
    }

    private void on_disconnect_clicked() {
        disconnect.begin();
    }

    private void on_refresh_clicked() {
        load_keys.begin(false); // Force refresh from API
    }

    private void on_deploy_key_clicked() {
        show_deploy_dialog();
    }

    private async void authenticate() {
        show_loading();

        try {
            if (yield github_provider.authenticate()) {
                var username = github_provider.get_username();
                settings.set_boolean("cloud-provider-github-connected", true);
                settings.set_string("cloud-provider-github-username", username ?? "");

                update_ui_connected(username ?? "");
                yield load_keys(false);

                show_toast(_("Connected to GitHub successfully"));
            }
        } catch (Error e) {
            show_error(@"Authentication failed: $(e.message)");
        }
    }

    private async void disconnect() {
        try {
            yield github_provider.disconnect();
            settings.set_boolean("cloud-provider-github-connected", false);
            settings.set_string("cloud-provider-github-username", "");
            cache_manager.clear_cache("github");

            update_ui_disconnected();
            show_toast(_("Disconnected from GitHub"));
        } catch (Error e) {
            show_error(@"Failed to disconnect: $(e.message)");
        }
    }

    private async void load_keys(bool try_cache_first) {
        show_loading();
        error_banner.revealed = false;

        // Always fetch fresh data from GitHub
        try {
            current_keys = yield github_provider.list_keys();
            cache_manager.cache_keys("github", current_keys);
            display_keys(current_keys);
        } catch (Error e) {
            show_error(@"Failed to load keys: $(e.message)");
        }
    }

    private void display_keys(Gee.List<CloudKeyMetadata> keys) {
        // Clear existing
        Gtk.Widget? child = keys_list_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            keys_list_box.remove(child);
            child = next;
        }

        if (keys.size == 0) {
            show_empty_state();
            return;
        }

        foreach (var key in keys) {
            var row = create_key_row(key);
            keys_list_box.append(row);
        }

        loading_box.visible = false;
        keys_list_box.visible = true;
        deploy_key_button.visible = true;
    }

    private Gtk.Widget create_key_row(CloudKeyMetadata key) {
        var row = new Adw.ActionRow();
        row.title = key.title;
        row.activatable = false;

        // Build subtitle
        var subtitle_parts = new Gee.ArrayList<string>();
        if (key.fingerprint != null) {
            subtitle_parts.add(key.fingerprint.substring(0, int.min(20, key.fingerprint.length)) + "...");
        }
        if (key.last_used != null) {
            subtitle_parts.add(_("Last used: ") + key.get_last_used_display());
        }
        row.subtitle = string.joinv(" • ", subtitle_parts.to_array());

        // Add prefix icon with color coding based on key type
        var prefix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        prefix_box.valign = Gtk.Align.CENTER;

        string icon_name = "dialog-password-symbolic";
        string color_class = "accent";

        // Map key type to icon and color (matching KeyRow logic)
        if (key.key_type != null) {
            var key_type_lower = key.key_type.down();
            if (key_type_lower.contains("ed25519")) {
                icon_name = "security-high-symbolic";
                color_class = "success"; // Green for ED25519 (most secure)
            } else if (key_type_lower.contains("rsa")) {
                icon_name = "security-medium-symbolic";
                color_class = "accent"; // Blue for RSA (good compatibility)
            } else if (key_type_lower.contains("ecdsa")) {
                icon_name = "security-low-symbolic";
                color_class = "warning"; // Yellow for ECDSA (compatibility issues)
            }
        }

        var key_icon = new Gtk.Image.from_icon_name(icon_name);
        key_icon.add_css_class(color_class);
        prefix_box.append(key_icon);

        row.add_prefix(prefix_box);

        // Add suffix with key type label and remove button
        var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
        suffix_box.valign = Gtk.Align.CENTER;

        // Key type label with matching color
        if (key.key_type != null) {
            var type_label = new Gtk.Label(key.key_type);
            type_label.add_css_class("caption");
            type_label.add_css_class(color_class);
            type_label.add_css_class("pill");
            type_label.valign = Gtk.Align.CENTER;
            type_label.margin_end = 6;
            suffix_box.append(type_label);
        }

        // Remove button (matching destructive action style from KeyRow)
        var remove_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-remove-symbolic");
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.tooltip_text = _("Remove from GitHub");
        remove_button.add_css_class("flat");
        remove_button.add_css_class("destructive-action");
        remove_button.clicked.connect(() => {
            remove_key.begin(key);
        });

        suffix_box.append(remove_button);
        row.add_suffix(suffix_box);

        return row;
    }

    private async void remove_key(CloudKeyMetadata key) {
        var dialog = new Adw.MessageDialog((Gtk.Window) this.get_root(), _("Remove Key?"), null);
        dialog.body = @"Remove '$(key.title)' from GitHub? This cannot be undone.";
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("remove", _("Remove"));
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");

        dialog.response.connect((response) => {
            if (response == "remove") {
                perform_key_removal.begin(key);
            }
        });

        dialog.present();
    }

    private async void perform_key_removal(CloudKeyMetadata key) {
        show_loading();

        try {
            yield github_provider.remove_key(key.id);
            yield load_keys(false);
            show_toast(@"Removed '$(key.title)' from GitHub");
        } catch (Error e) {
            show_error(@"Failed to remove key: $(e.message)");
        }
    }

    private void show_deploy_dialog() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new CloudKeyDeployDialog(window, github_provider);

        dialog.deployment_completed.connect((success) => {
            if (success) {
                // Reload keys to show the newly deployed key
                load_keys.begin(false);
            }
        });

        dialog.present();
    }

    private void update_ui_connected(string username) {
        connect_button.visible = false;
        connection_status_label.label = @"Connected as $username";
        connection_status_label.visible = true;
        disconnect_button.visible = true;
        refresh_button.visible = true;
    }

    private void update_ui_disconnected() {
        connect_button.visible = true;
        connection_status_label.visible = false;
        disconnect_button.visible = false;
        refresh_button.visible = false;
        keys_list_box.visible = false;
        empty_state.visible = false;
        loading_box.visible = false;
        deploy_key_button.visible = false;
    }

    private void show_loading() {
        loading_box.visible = true;
        keys_list_box.visible = false;
        empty_state.visible = false;
        deploy_key_button.visible = false;
        error_banner.revealed = false;
    }

    private void show_empty_state() {
        empty_state.visible = true;
        keys_list_box.visible = false;
        loading_box.visible = false;
        deploy_key_button.visible = true;
    }

    private void show_error(string message) {
        error_banner.title = message;
        error_banner.revealed = true;
        loading_box.visible = false;
    }

    private void show_toast(string message) {
        var toast = new Adw.Toast(message);
        toast.timeout = 3;

        var window = (Adw.ApplicationWindow) this.get_root();
        if (window != null) {
            // Try to get toast overlay
            // In practice, would need proper window reference
            // For now, just print
            debug(@"Toast: $message");
        }
    }
}
