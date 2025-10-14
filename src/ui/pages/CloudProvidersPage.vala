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
    // PreferencesGroups
    [GtkChild]
    private unowned Adw.PreferencesGroup github_group;

    [GtkChild]
    private unowned Adw.PreferencesGroup gitlab_group;

    [GtkChild]
    private unowned Adw.PreferencesGroup bitbucket_group;

    // GitHub widgets
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
    private unowned Gtk.Box loading_box;

    [GtkChild]
    private unowned Gtk.Button deploy_key_button;

    [GtkChild]
    private unowned Adw.Banner error_banner;

    // GitLab widgets
    [GtkChild]
    private unowned Gtk.Button gitlab_configure_button;

    [GtkChild]
    private unowned Gtk.Button gitlab_connect_button;

    [GtkChild]
    private unowned Gtk.Label gitlab_connection_status_label;

    [GtkChild]
    private unowned Gtk.Button gitlab_disconnect_button;

    [GtkChild]
    private unowned Gtk.Button gitlab_refresh_button;

    [GtkChild]
    private unowned Gtk.ListBox gitlab_keys_list_box;

    [GtkChild]
    private unowned Gtk.Box gitlab_loading_box;

    [GtkChild]
    private unowned Gtk.Button gitlab_deploy_key_button;

    // Bitbucket widgets
    [GtkChild]
    private unowned Gtk.Button bitbucket_connect_button;

    [GtkChild]
    private unowned Gtk.Label bitbucket_connection_status_label;

    [GtkChild]
    private unowned Gtk.Button bitbucket_disconnect_button;

    [GtkChild]
    private unowned Gtk.Button bitbucket_refresh_button;

    [GtkChild]
    private unowned Gtk.ListBox bitbucket_keys_list_box;

    [GtkChild]
    private unowned Gtk.Box bitbucket_loading_box;

    [GtkChild]
    private unowned Gtk.Button bitbucket_deploy_key_button;

    private GitHubProvider github_provider;
    private GitLabProvider gitlab_provider;
    private BitbucketProvider bitbucket_provider;
    private CacheManager cache_manager;
    private Settings settings;
    private Gee.List<CloudKeyMetadata>? current_keys = null;
    private Gee.List<CloudKeyMetadata>? gitlab_current_keys = null;
    private Gee.List<CloudKeyMetadata>? bitbucket_current_keys = null;

    construct {
        github_provider = new GitHubProvider();
        gitlab_provider = new GitLabProvider();
        bitbucket_provider = new BitbucketProvider();
        cache_manager = new CacheManager();
        settings = SettingsManager.app;

        // Wire up GitHub signals
        connect_button.clicked.connect(on_connect_clicked);
        disconnect_button.clicked.connect(on_disconnect_clicked);
        refresh_button.clicked.connect(on_refresh_clicked);
        deploy_key_button.clicked.connect(on_deploy_key_clicked);
        error_banner.button_clicked.connect(on_refresh_clicked);

        // Wire up GitLab signals
        gitlab_configure_button.clicked.connect(on_gitlab_configure_clicked);
        gitlab_connect_button.clicked.connect(on_gitlab_connect_clicked);
        gitlab_disconnect_button.clicked.connect(on_gitlab_disconnect_clicked);
        gitlab_refresh_button.clicked.connect(on_gitlab_refresh_clicked);
        gitlab_deploy_key_button.clicked.connect(on_gitlab_deploy_key_clicked);

        // Wire up Bitbucket signals
        bitbucket_connect_button.clicked.connect(on_bitbucket_connect_clicked);
        bitbucket_disconnect_button.clicked.connect(on_bitbucket_disconnect_clicked);
        bitbucket_refresh_button.clicked.connect(on_bitbucket_refresh_clicked);
        bitbucket_deploy_key_button.clicked.connect(on_bitbucket_deploy_key_clicked);

        // Load initial state
        load_initial_state.begin();
    }

    private async void load_initial_state() {
        // Load GitHub state
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

        // Load GitLab state
        var gitlab_is_connected = settings.get_boolean("cloud-provider-gitlab-connected");
        var gitlab_username = settings.get_string("cloud-provider-gitlab-username");
        var gitlab_instance_url = settings.get_string("cloud-provider-gitlab-instance-url");

        // Set instance URL if provided
        if (gitlab_instance_url.length > 0) {
            gitlab_provider.set_instance_url(gitlab_instance_url);
        }

        if (gitlab_is_connected && gitlab_username.length > 0) {
            try {
                if (yield gitlab_provider.load_stored_auth(gitlab_username)) {
                    update_gitlab_ui_connected(gitlab_username);
                    yield load_gitlab_keys(true); // Try from cache first
                } else {
                    // Token invalid, disconnect
                    yield gitlab_disconnect();
                }
            } catch (Error e) {
                warning(@"Failed to load stored GitLab auth: $(e.message)");
                update_gitlab_ui_disconnected();
            }
        } else {
            update_gitlab_ui_disconnected();
        }

        // Load Bitbucket state
        var bitbucket_is_connected = settings.get_boolean("cloud-provider-bitbucket-connected");
        var bitbucket_username = settings.get_string("cloud-provider-bitbucket-username");

        if (bitbucket_is_connected && bitbucket_username.length > 0) {
            try {
                if (yield bitbucket_provider.load_stored_auth(bitbucket_username)) {
                    update_bitbucket_ui_connected(bitbucket_username);
                    yield load_bitbucket_keys(true); // Try from cache first
                } else {
                    // Token invalid, disconnect
                    yield bitbucket_disconnect();
                }
            } catch (Error e) {
                warning(@"Failed to load stored Bitbucket auth: $(e.message)");
                update_bitbucket_ui_disconnected();
            }
        } else {
            update_bitbucket_ui_disconnected();
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

    // GitLab signal handlers
    private void on_gitlab_configure_clicked() {
        show_gitlab_configure_dialog();
    }

    private void on_gitlab_connect_clicked() {
        gitlab_authenticate.begin();
    }

    private void on_gitlab_disconnect_clicked() {
        gitlab_disconnect.begin();
    }

    private void on_gitlab_refresh_clicked() {
        load_gitlab_keys.begin(false); // Force refresh from API
    }

    private void on_gitlab_deploy_key_clicked() {
        show_gitlab_deploy_dialog();
    }

    // Bitbucket signal handlers
    private void on_bitbucket_connect_clicked() {
        show_bitbucket_token_dialog();
    }

    private void on_bitbucket_disconnect_clicked() {
        bitbucket_disconnect.begin();
    }

    private void on_bitbucket_refresh_clicked() {
        load_bitbucket_keys.begin(false); // Force refresh from API
    }

    private void on_bitbucket_deploy_key_clicked() {
        show_bitbucket_deploy_dialog();
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

    // GitLab authentication methods
    private async void gitlab_authenticate() {
        show_gitlab_loading();

        try {
            if (yield gitlab_provider.authenticate()) {
                var username = gitlab_provider.get_username();
                var instance_url = gitlab_provider.get_instance_url();
                settings.set_boolean("cloud-provider-gitlab-connected", true);
                settings.set_string("cloud-provider-gitlab-username", username ?? "");
                settings.set_string("cloud-provider-gitlab-instance-url", instance_url);

                update_gitlab_ui_connected(username ?? "");
                yield load_gitlab_keys(false);

                show_toast(_("Connected to GitLab successfully"));
            }
        } catch (Error e) {
            show_error(@"GitLab authentication failed: $(e.message)");
        }
    }

    private async void gitlab_disconnect() {
        try {
            yield gitlab_provider.disconnect();
            settings.set_boolean("cloud-provider-gitlab-connected", false);
            settings.set_string("cloud-provider-gitlab-username", "");
            settings.set_string("cloud-provider-gitlab-instance-url", "");
            cache_manager.clear_cache("gitlab");

            update_gitlab_ui_disconnected();
            show_toast(_("Disconnected from GitLab"));
        } catch (Error e) {
            show_error(@"Failed to disconnect from GitLab: $(e.message)");
        }
    }

    // Bitbucket authentication methods
    private async void bitbucket_authenticate_with_username_token(string username, string api_token) {
        show_bitbucket_loading();

        try {
            if (yield bitbucket_provider.authenticate_with_username_and_token(username, api_token)) {
                settings.set_boolean("cloud-provider-bitbucket-connected", true);
                settings.set_string("cloud-provider-bitbucket-username", username);

                update_bitbucket_ui_connected(username);
                yield load_bitbucket_keys(false);

                show_toast(_("Connected to Bitbucket successfully"));
            }
        } catch (Error e) {
            show_error(@"Bitbucket authentication failed: $(e.message)");
        }
    }

    private async void bitbucket_authenticate_with_token(string api_token) {
        show_bitbucket_loading();

        try {
            if (yield bitbucket_provider.authenticate_with_token(api_token)) {
                var username = bitbucket_provider.get_username();
                settings.set_boolean("cloud-provider-bitbucket-connected", true);
                settings.set_string("cloud-provider-bitbucket-username", username ?? "");

                update_bitbucket_ui_connected(username ?? "");
                yield load_bitbucket_keys(false);

                show_toast(_("Connected to Bitbucket successfully"));
            }
        } catch (Error e) {
            show_error(@"Bitbucket authentication failed: $(e.message)");
        }
    }

    private async void bitbucket_disconnect() {
        try {
            yield bitbucket_provider.disconnect();
            settings.set_boolean("cloud-provider-bitbucket-connected", false);
            settings.set_string("cloud-provider-bitbucket-username", "");
            cache_manager.clear_cache("bitbucket");

            update_bitbucket_ui_disconnected();
            show_toast(_("Disconnected from Bitbucket"));
        } catch (Error e) {
            show_error(@"Failed to disconnect from Bitbucket: $(e.message)");
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

    private async void load_gitlab_keys(bool try_cache_first) {
        show_gitlab_loading();
        error_banner.revealed = false;

        // Always fetch fresh data from GitLab
        try {
            gitlab_current_keys = yield gitlab_provider.list_keys();
            cache_manager.cache_keys("gitlab", gitlab_current_keys);
            display_gitlab_keys(gitlab_current_keys);
        } catch (Error e) {
            show_error(@"Failed to load GitLab keys: $(e.message)");
        }
    }

    private async void load_bitbucket_keys(bool try_cache_first) {
        show_bitbucket_loading();
        error_banner.revealed = false;

        // Always fetch fresh data from Bitbucket
        try {
            bitbucket_current_keys = yield bitbucket_provider.list_keys();
            cache_manager.cache_keys("bitbucket", bitbucket_current_keys);
            display_bitbucket_keys(bitbucket_current_keys);
        } catch (Error e) {
            show_error(@"Failed to load Bitbucket keys: $(e.message)");
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
            // Add empty state row
            var empty_row = new EmptyStateRow();
            keys_list_box.append(empty_row);
        } else {
            foreach (var key in keys) {
                var row = create_key_row(key, "github");
                keys_list_box.append(row);
            }
        }

        loading_box.visible = false;
        keys_list_box.visible = true;
        deploy_key_button.visible = true;
    }

    private void display_gitlab_keys(Gee.List<CloudKeyMetadata> keys) {
        // Clear existing
        Gtk.Widget? child = gitlab_keys_list_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            gitlab_keys_list_box.remove(child);
            child = next;
        }

        if (keys.size == 0) {
            // Add empty state row
            var empty_row = new EmptyStateRow();
            gitlab_keys_list_box.append(empty_row);
        } else {
            foreach (var key in keys) {
                var row = create_key_row(key, "gitlab");
                gitlab_keys_list_box.append(row);
            }
        }

        gitlab_loading_box.visible = false;
        gitlab_keys_list_box.visible = true;
        gitlab_deploy_key_button.visible = true;
    }

    private void display_bitbucket_keys(Gee.List<CloudKeyMetadata> keys) {
        // Clear existing
        Gtk.Widget? child = bitbucket_keys_list_box.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            bitbucket_keys_list_box.remove(child);
            child = next;
        }

        if (keys.size == 0) {
            // Add empty state row
            var empty_row = new EmptyStateRow();
            bitbucket_keys_list_box.append(empty_row);
        } else {
            foreach (var key in keys) {
                var row = create_key_row(key, "bitbucket");
                bitbucket_keys_list_box.append(row);
            }
        }

        bitbucket_loading_box.visible = false;
        bitbucket_keys_list_box.visible = true;
        bitbucket_deploy_key_button.visible = true;
    }

    private Gtk.Widget create_key_row(CloudKeyMetadata key, string provider_name) {
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
        string provider_display = provider_name == "github" ? "GitHub" : (provider_name == "gitlab" ? "GitLab" : "Bitbucket");
        remove_button.tooltip_text = @"Remove from $provider_display";
        remove_button.add_css_class("flat");
        remove_button.add_css_class("destructive-action");
        remove_button.clicked.connect(() => {
            remove_key.begin(key, provider_name);
        });

        suffix_box.append(remove_button);
        row.add_suffix(suffix_box);

        return row;
    }

    private async void remove_key(CloudKeyMetadata key, string provider_name) {
        string provider_display = provider_name == "github" ? "GitHub" : (provider_name == "gitlab" ? "GitLab" : "Bitbucket");
        var dialog = new Adw.MessageDialog((Gtk.Window) this.get_root(), _("Remove Key?"), null);
        dialog.body = @"Remove '$(key.title)' from $provider_display? This cannot be undone.";
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("remove", _("Remove"));
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");

        dialog.response.connect((response) => {
            if (response == "remove") {
                perform_key_removal.begin(key, provider_name);
            }
        });

        dialog.present();
    }

    private async void perform_key_removal(CloudKeyMetadata key, string provider_name) {
        if (provider_name == "github") {
            show_loading();
        } else if (provider_name == "gitlab") {
            show_gitlab_loading();
        } else {
            show_bitbucket_loading();
        }

        try {
            if (provider_name == "github") {
                yield github_provider.remove_key(key.id);
                yield load_keys(false);
                show_toast(@"Removed '$(key.title)' from GitHub");
            } else if (provider_name == "gitlab") {
                yield gitlab_provider.remove_key(key.id);
                yield load_gitlab_keys(false);
                show_toast(@"Removed '$(key.title)' from GitLab");
            } else {
                yield bitbucket_provider.remove_key(key.id);
                yield load_bitbucket_keys(false);
                show_toast(@"Removed '$(key.title)' from Bitbucket");
            }
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

    private void show_gitlab_deploy_dialog() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new CloudKeyDeployDialog(window, gitlab_provider);

        dialog.deployment_completed.connect((success) => {
            if (success) {
                // Reload keys to show the newly deployed key
                load_gitlab_keys.begin(false);
            }
        });

        dialog.present();
    }

    private void show_bitbucket_deploy_dialog() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new CloudKeyDeployDialog(window, bitbucket_provider);

        dialog.deployment_completed.connect((success) => {
            if (success) {
                // Reload keys to show the newly deployed key
                load_bitbucket_keys.begin(false);
            }
        });

        dialog.present();
    }

    private void show_gitlab_configure_dialog() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.PreferencesDialog();
        dialog.set_title(_("Configure GitLab"));

        // Create main page
        var page = new Adw.PreferencesPage();

        // Instance Selection Group
        var instance_group = new Adw.PreferencesGroup();
        instance_group.title = _("Select GitLab Instance");
        instance_group.description = _("Choose a pre-configured instance or enter custom credentials");

        // Radio buttons for instance selection
        Gtk.CheckButton? gitlab_com_radio = null;
        Gtk.CheckButton? gitlab_gnome_radio = null;
        Gtk.CheckButton? gitlab_freedesktop_radio = null;
        Gtk.CheckButton? gitlab_salsa_radio = null;
        Gtk.CheckButton? custom_radio = null;

        // GitLab.com option
        var gitlab_com_row = new Adw.ActionRow();
        gitlab_com_row.title = "GitLab.com";
        gitlab_com_row.subtitle = _("Official GitLab cloud service (pre-configured)");
        gitlab_com_radio = new Gtk.CheckButton();
        gitlab_com_radio.valign = Gtk.Align.CENTER;
        gitlab_com_row.add_prefix(gitlab_com_radio);
        gitlab_com_row.activatable_widget = gitlab_com_radio;
        instance_group.add(gitlab_com_row);

        // GitLab GNOME option
        var gitlab_gnome_row = new Adw.ActionRow();
        gitlab_gnome_row.title = "GitLab GNOME";
        gitlab_gnome_row.subtitle = _("GNOME's GitLab instance (pre-configured)");
        gitlab_gnome_radio = new Gtk.CheckButton();
        gitlab_gnome_radio.valign = Gtk.Align.CENTER;
        gitlab_gnome_radio.group = gitlab_com_radio;
        gitlab_gnome_row.add_prefix(gitlab_gnome_radio);
        gitlab_gnome_row.activatable_widget = gitlab_gnome_radio;
        instance_group.add(gitlab_gnome_row);

        // freedesktop.org GitLab option
        var gitlab_freedesktop_row = new Adw.ActionRow();
        gitlab_freedesktop_row.title = "freedesktop.org";
        gitlab_freedesktop_row.subtitle = _("freedesktop.org GitLab instance (pre-configured)");
        gitlab_freedesktop_radio = new Gtk.CheckButton();
        gitlab_freedesktop_radio.valign = Gtk.Align.CENTER;
        gitlab_freedesktop_radio.group = gitlab_com_radio;
        gitlab_freedesktop_row.add_prefix(gitlab_freedesktop_radio);
        gitlab_freedesktop_row.activatable_widget = gitlab_freedesktop_radio;
        instance_group.add(gitlab_freedesktop_row);

        // Salsa (Debian) GitLab option
        var gitlab_salsa_row = new Adw.ActionRow();
        gitlab_salsa_row.title = "Salsa (Debian)";
        gitlab_salsa_row.subtitle = _("Debian's GitLab instance (pre-configured)");
        gitlab_salsa_radio = new Gtk.CheckButton();
        gitlab_salsa_radio.valign = Gtk.Align.CENTER;
        gitlab_salsa_radio.group = gitlab_com_radio;
        gitlab_salsa_row.add_prefix(gitlab_salsa_radio);
        gitlab_salsa_row.activatable_widget = gitlab_salsa_radio;
        instance_group.add(gitlab_salsa_row);

        // Custom option
        var custom_row = new Adw.ActionRow();
        custom_row.title = _("Custom Instance");
        custom_row.subtitle = _("Self-hosted or other GitLab instance");
        custom_radio = new Gtk.CheckButton();
        custom_radio.valign = Gtk.Align.CENTER;
        custom_radio.group = gitlab_com_radio;
        custom_row.add_prefix(custom_radio);
        custom_row.activatable_widget = custom_radio;
        instance_group.add(custom_row);

        page.add(instance_group);

        // Custom Configuration Group (initially hidden)
        var custom_group = new Adw.PreferencesGroup();
        custom_group.title = _("Custom Instance Configuration");
        custom_group.visible = false;

        // Instance URL row
        var url_row = new Adw.EntryRow();
        url_row.title = _("Instance URL");
        url_row.text = "";
        custom_group.add(url_row);

        // Client ID row
        var client_id_row = new Adw.EntryRow();
        client_id_row.title = _("OAuth Client ID");
        client_id_row.text = "";
        custom_group.add(client_id_row);

        // Client Secret row
        var client_secret_row = new Adw.PasswordEntryRow();
        client_secret_row.title = _("OAuth Client Secret");
        client_secret_row.text = "";
        custom_group.add(client_secret_row);

        // Instructions expander
        var instructions_row = new Adw.ExpanderRow();
        instructions_row.title = _("How to get OAuth credentials");
        instructions_row.subtitle = _("Click to view setup instructions");

        var instructions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        instructions_box.margin_top = 12;
        instructions_box.margin_bottom = 12;
        instructions_box.margin_start = 12;
        instructions_box.margin_end = 12;

        var step1 = new Gtk.Label(_("1. Go to your GitLab instance → Settings → Applications"));
        step1.wrap = true;
        step1.xalign = 0;
        instructions_box.append(step1);

        var step2 = new Gtk.Label(_("2. Create a new application with redirect URI:"));
        step2.wrap = true;
        step2.xalign = 0;
        instructions_box.append(step2);

        var redirect_uri = new Gtk.Label("   http://localhost:8765/callback");
        redirect_uri.xalign = 0;
        redirect_uri.add_css_class("monospace");
        instructions_box.append(redirect_uri);

        var step3 = new Gtk.Label(_("3. Select scopes: read_user, api"));
        step3.wrap = true;
        step3.xalign = 0;
        instructions_box.append(step3);

        var step4 = new Gtk.Label(_("4. Copy the Application ID and Secret"));
        step4.wrap = true;
        step4.xalign = 0;
        instructions_box.append(step4);

        instructions_row.add_row(instructions_box);
        custom_group.add(instructions_row);

        page.add(custom_group);
        dialog.add(page);

        // Show/hide custom group based on selection
        custom_radio.toggled.connect(() => {
            custom_group.visible = custom_radio.active;
        });

        // Load current configuration
        var current_url = settings.get_string("cloud-provider-gitlab-instance-url");
        var current_client_id = settings.get_string("cloud-provider-gitlab-client-id");
        var current_client_secret = settings.get_string("cloud-provider-gitlab-client-secret");

        // Pre-select based on current configuration
        if (current_url == "https://gitlab.com") {
            gitlab_com_radio.active = true;
        } else if (current_url == "https://gitlab.gnome.org") {
            gitlab_gnome_radio.active = true;
        } else if (current_url == "https://gitlab.freedesktop.org") {
            gitlab_freedesktop_radio.active = true;
        } else if (current_url == "https://salsa.debian.org") {
            gitlab_salsa_radio.active = true;
        } else {
            custom_radio.active = true;
            url_row.text = current_url;
            client_id_row.text = current_client_id;
            client_secret_row.text = current_client_secret;
        }

        // Save button
        dialog.closed.connect(() => {
            string url = "";
            string client_id = "";
            string client_secret = "";

            if (gitlab_com_radio.active) {
                // GitLab.com pre-configured
                url = "https://gitlab.com";
                client_id = "e5dc4cacfc592ee14ea5851a4ab98a729e2683542a07f4fc0f9c569ef4917b3b";
                client_secret = "gloas-d6833be35e80bf99a66210213467c8130d732dafaec60b86bdc6f632fc03f268";
            } else if (gitlab_gnome_radio.active) {
                // GitLab GNOME pre-configured (separate OAuth app)
                url = "https://gitlab.gnome.org";
                client_id = "2174aa43e0f2e36154d863bcf10d3ae81213b9915b55e89ab412836ff045ea3e";
                client_secret = "gloas-741417286efeb8b6915018163b99250b8d49eb97cae2faafaca1a85e4bf968ed";
            } else if (gitlab_freedesktop_radio.active) {
                // freedesktop.org pre-configured (separate OAuth app)
                url = "https://gitlab.freedesktop.org";
                client_id = "ddfb39c8929f22cd53165d34247d51425f7f2737934e955458bfe58882158a6c";
                client_secret = "gloas-af32aaf323216ec55544d157733937f789acdb216dc3efde25697413ec75328b";
            } else if (gitlab_salsa_radio.active) {
                // Salsa (Debian) pre-configured
                url = "https://salsa.debian.org";
                client_id = "51093f2599b4680db128447435a0658f368adb995cd7dc6e24cfbc25dc0432f0";
                client_secret = "gloas-989d64d8037af96689e71a2f46acefc3ff90fdeb4dc1ed6a787470d566011973";
            } else if (custom_radio.active) {
                // Custom instance
                url = url_row.text.strip();
                client_id = client_id_row.text.strip();
                client_secret = client_secret_row.text.strip();

                if (url.length == 0 || client_id.length == 0 || client_secret.length == 0) {
                    show_error(_("Please fill in all custom instance fields"));
                    return;
                }
            }

            if (url.length > 0 && client_id.length > 0 && client_secret.length > 0) {
                settings.set_string("cloud-provider-gitlab-instance-url", url);
                gitlab_provider.set_instance_url(url);
                gitlab_provider.set_oauth_credentials(client_id, client_secret);

                var instance_name = url.replace("https://", "").replace("http://", "");
                show_toast(_("GitLab configuration saved for %s").printf(instance_name));
            }
        });

        dialog.present(window);
    }

    private void show_gitlab_com_instructions() {
        show_gitlab_register_instructions("https://gitlab.com");
    }

    private void show_gitlab_register_instructions(string instance_url) {
        var window = (Gtk.Window) this.get_root();
        var instance_name = instance_url.replace("https://", "").replace("http://", "");
        var settings_url = @"$instance_url/-/user_settings/applications";

        var dialog = new Adw.MessageDialog(window, _("OAuth Setup Required"), null);
        dialog.body = _("To use %s, you need to register your own OAuth application:\n\n1. Go to: %s\n2. Create a new application:\n   • Name: KeyMaker\n   • Redirect URI: http://localhost:8765/callback\n   • Scopes: read_user, api\n3. Copy the Application ID and Secret\n4. Click 'Configure Custom' and enter your credentials").printf(instance_name, settings_url);
        dialog.add_response("ok", _("OK"));
        dialog.add_response("custom", _("Configure Custom"));
        dialog.set_response_appearance("custom", Adw.ResponseAppearance.SUGGESTED);

        dialog.response.connect((response) => {
            if (response == "custom") {
                show_gitlab_configure_dialog();
            }
        });

        dialog.present();
    }

    // GitHub UI methods
    private void update_ui_connected(string username) {
        github_group.description = @"Connected as $username";
        connect_button.visible = false;
        connection_status_label.visible = false;
        disconnect_button.visible = true;
        refresh_button.visible = true;
    }

    private void update_ui_disconnected() {
        github_group.description = _("Disconnected");
        connect_button.visible = true;
        connection_status_label.visible = false;
        disconnect_button.visible = false;
        refresh_button.visible = false;
        keys_list_box.visible = false;
        loading_box.visible = false;
        deploy_key_button.visible = false;
    }

    private void show_loading() {
        loading_box.visible = true;
        keys_list_box.visible = false;
        deploy_key_button.visible = false;
        error_banner.revealed = false;
    }

    // GitLab UI methods
    private void update_gitlab_ui_connected(string username) {
        gitlab_group.description = @"Connected as $username";
        gitlab_connect_button.visible = false;
        gitlab_connection_status_label.visible = false;
        gitlab_disconnect_button.visible = true;
        gitlab_refresh_button.visible = true;
    }

    private void update_gitlab_ui_disconnected() {
        gitlab_group.description = _("Disconnected");
        gitlab_connect_button.visible = true;
        gitlab_connection_status_label.visible = false;
        gitlab_disconnect_button.visible = false;
        gitlab_refresh_button.visible = false;
        gitlab_keys_list_box.visible = false;
        gitlab_loading_box.visible = false;
        gitlab_deploy_key_button.visible = false;
    }

    private void show_gitlab_loading() {
        gitlab_loading_box.visible = true;
        gitlab_keys_list_box.visible = false;
        gitlab_deploy_key_button.visible = false;
        error_banner.revealed = false;
    }

    // Bitbucket UI methods
    private void update_bitbucket_ui_connected(string username) {
        bitbucket_group.description = @"Connected as $username";
        bitbucket_connect_button.visible = false;
        bitbucket_connection_status_label.visible = false;
        bitbucket_disconnect_button.visible = true;
        bitbucket_refresh_button.visible = true;
    }

    private void update_bitbucket_ui_disconnected() {
        bitbucket_group.description = _("Disconnected");
        bitbucket_connect_button.visible = true;
        bitbucket_connection_status_label.visible = false;
        bitbucket_disconnect_button.visible = false;
        bitbucket_refresh_button.visible = false;
        bitbucket_keys_list_box.visible = false;
        bitbucket_loading_box.visible = false;
        bitbucket_deploy_key_button.visible = false;
    }

    private void show_bitbucket_loading() {
        bitbucket_loading_box.visible = true;
        bitbucket_keys_list_box.visible = false;
        bitbucket_deploy_key_button.visible = false;
        error_banner.revealed = false;
    }

    private void show_bitbucket_token_dialog() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.MessageDialog(window, _("Connect to Bitbucket"), null);
        dialog.body = _("Use a Bitbucket App Password for authentication.\n\nNote: Atlassian API tokens don't work with Bitbucket API.");
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("connect", _("Connect"));
        dialog.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("connect");

        // Add to dialog
        var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;
        content_box.margin_start = 12;
        content_box.margin_end = 12;

        // Username entry
        var username_entry = new Adw.EntryRow();
        username_entry.title = _("Bitbucket Username");
        username_entry.show_apply_button = false;
        content_box.append(username_entry);

        // Create token entry
        var token_entry = new Adw.PasswordEntryRow();
        token_entry.title = _("App Password");
        token_entry.show_apply_button = false;

        // Instructions button
        var instructions_button = new Gtk.Button.with_label(_("Create App Password"));
        instructions_button.valign = Gtk.Align.CENTER;
        instructions_button.clicked.connect(() => {
            try {
                AppInfo.launch_default_for_uri("https://bitbucket.org/account/settings/app-passwords/", null);
            } catch (Error e) {
                warning(@"Failed to open URL: $(e.message)");
            }
        });
        token_entry.add_suffix(instructions_button);
        content_box.append(token_entry);

        // Instructions
        var info_label = new Gtk.Label(_("How to create an App Password:\n\n1. Enter your Bitbucket username (from Settings → Personal)\n2. Click \"Create App Password\" button above\n3. Create a new password with 'Account: Read' permission\n4. Copy and paste the generated password above"));
        info_label.wrap = true;
        info_label.xalign = 0;
        info_label.add_css_class("dim-label");
        content_box.append(info_label);

        dialog.set_extra_child(content_box);

        dialog.response.connect((response_id) => {
            if (response_id == "connect") {
                var username = username_entry.text.strip();
                var token = token_entry.text.strip();
                if (username.length > 0 && token.length > 0) {
                    bitbucket_authenticate_with_username_token.begin(username, token);
                } else {
                    show_error(_("Both username and API token are required"));
                }
            }
        });

        dialog.present();
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
