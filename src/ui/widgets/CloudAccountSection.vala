/* CloudAccountSection.vala
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

/**
 * Represents a single cloud account section in the UI
 * Each account (e.g., "GitHub (tobagin)", "GitLab (gitlab.gnome.org)") gets its own section
 */
public class KeyMaker.CloudAccountSection : GLib.Object {
    public string account_id { get; construct; }
    public string provider_type { get; construct; } // "github", "gitlab", "bitbucket"
    public string display_name { get; set; } // "GitHub (tobagin)"
    public string username { get; set; }
    public bool is_connected { get; set; default = false; }

    public Adw.ExpanderRow expander_row { get; private set; }
    public Adw.PreferencesGroup group { get; private set; }
    private Gtk.Button connect_button;
    private Gtk.Button disconnect_button;
    private Gtk.Button refresh_button;
    private Gtk.Button deploy_key_button;
    private Gtk.Box loading_box;
    private Gtk.Image provider_icon;

    private CloudProvider provider;
    private CacheManager cache_manager;
    private Gee.List<CloudKeyMetadata>? current_keys = null;
    private Gee.ArrayList<Adw.PreferencesRow> key_rows;
    private Adw.ActionRow? loading_row = null;
    private bool? pending_expanded_state = null;

    public signal void account_removed(string account_id);
    public signal void connection_state_changed();
    public signal void show_toast_requested(string message);
    public signal void show_error_requested(string message);
    public signal void expanded_state_changed(bool is_expanded);

    public CloudProvider get_provider() {
        return provider;
    }

    public CloudAccountSection(string account_id, string provider_type, string display_name, CloudProvider provider) {
        Object(
            account_id: account_id,
            provider_type: provider_type,
            display_name: display_name
        );

        this.provider = provider;
        this.cache_manager = new CacheManager();
        this.key_rows = new Gee.ArrayList<Adw.PreferencesRow>();

        build_ui();
    }

    private void build_ui() {
        // Note: group is kept for backward compatibility but not used anymore
        // All expander rows are added to a single group in CloudProvidersPage
        group = new Adw.PreferencesGroup();

        // Create the expander row
        expander_row = new Adw.ExpanderRow();
        expander_row.title = display_name;
        expander_row.subtitle = _("Disconnected");
        expander_row.enable_expansion = false; // Disabled until connected
        expander_row.add_css_class("icon-dropshadow");

        // Set icon based on provider type
        update_provider_icon();

        // Listen for color scheme changes to update theme-aware icons
        if (provider_type == "github" || provider_type == "aws" || (provider_type == "gitea" && display_name.down().contains("codeberg"))) {
            var style_manager = Adw.StyleManager.get_default();
            style_manager.notify["dark"].connect(() => {
                update_provider_icon();
            });
        }

        // Suffix box with buttons
        var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

        connect_button = new Gtk.Button();
        connect_button.icon_name = "io.github.tobagin.keysmith-connect-symbolic";
        connect_button.tooltip_text = _("Connect");
        connect_button.valign = Gtk.Align.CENTER;
        connect_button.add_css_class("suggested-action");
        connect_button.add_css_class("flat");
        connect_button.clicked.connect(on_connect_clicked);
        suffix_box.append(connect_button);

        disconnect_button = new Gtk.Button();
        disconnect_button.icon_name = "io.github.tobagin.keysmith-disconnect-symbolic";
        disconnect_button.tooltip_text = _("Disconnect");
        disconnect_button.valign = Gtk.Align.CENTER;
        disconnect_button.visible = false;
        disconnect_button.add_css_class("destructive-action");
        disconnect_button.add_css_class("flat");
        disconnect_button.clicked.connect(on_disconnect_clicked);
        suffix_box.append(disconnect_button);

        deploy_key_button = new Gtk.Button();
        deploy_key_button.icon_name = "tab-new-symbolic";
        deploy_key_button.tooltip_text = _("Deploy Key");
        deploy_key_button.valign = Gtk.Align.CENTER;
        deploy_key_button.visible = false;
        deploy_key_button.add_css_class("flat");
        deploy_key_button.clicked.connect(on_deploy_key_clicked);
        suffix_box.append(deploy_key_button);

        refresh_button = new Gtk.Button();
        refresh_button.icon_name = "view-refresh-symbolic";
        refresh_button.tooltip_text = _("Refresh Keys");
        refresh_button.valign = Gtk.Align.CENTER;
        refresh_button.visible = false;
        refresh_button.add_css_class("flat");
        refresh_button.clicked.connect(on_refresh_clicked);
        suffix_box.append(refresh_button);

        // Add remove button (always visible)
        var remove_button = new Gtk.Button();
        remove_button.icon_name = "user-trash-symbolic";
        remove_button.tooltip_text = _("Remove Account");
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.add_css_class("destructive-action");
        remove_button.add_css_class("flat");
        remove_button.clicked.connect(on_remove_clicked);
        suffix_box.append(remove_button);

        expander_row.add_suffix(suffix_box);

        // Listen for expanded state changes
        expander_row.notify["expanded"].connect(() => {
            debug("CloudAccountSection: Expander state changed for %s - expanded=%s", account_id, expander_row.expanded.to_string());
            expanded_state_changed(expander_row.expanded);
        });

        // Create loading box (will be added dynamically when needed)
        loading_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        loading_box.halign = Gtk.Align.CENTER;
        loading_box.valign = Gtk.Align.CENTER;
        loading_box.margin_top = 24;
        loading_box.margin_bottom = 24;

        var spinner = new Gtk.Spinner();
        spinner.spinning = true;
        loading_box.append(spinner);

        var loading_label = new Gtk.Label(_("Loading keys..."));
        loading_label.add_css_class("dim-label");
        loading_box.append(loading_label);

        // Don't add expander to group here - CloudProvidersPage will add it to the single shared group
    }

    private void on_connect_clicked() {
        authenticate.begin();
    }

    private void on_disconnect_clicked() {
        disconnect_account.begin();
    }

    private void on_refresh_clicked() {
        load_keys.begin(false);
    }

    private void on_deploy_key_clicked() {
        // Get the window reference
        var root = expander_row.get_root();
        if (root == null || !(root is Gtk.Window)) {
            warning("Cannot show deploy dialog: no window found");
            return;
        }

        var window = (Gtk.Window)root;
        var dialog = new CloudKeyDeployDialog(window, provider);

        // Refresh keys list when deployment completes successfully
        dialog.deployment_completed.connect((success) => {
            if (success) {
                load_keys.begin(false);
            }
        });

        dialog.present();
    }

    private void on_remove_clicked() {
        // Show confirmation dialog before removing
        show_remove_confirmation();
    }

    private void show_remove_confirmation() {
        // We need to get the window reference - this is a bit hacky but works
        var root = expander_row.get_root();
        if (root == null || !(root is Gtk.Window)) {
            // Just remove without confirmation if we can't get window
            perform_remove();
            return;
        }

        var window = (Gtk.Window)root;
        var dialog = new Adw.AlertDialog(
            _("Remove Account?"),
            @"Are you sure you want to remove '$display_name'?"
        );

        dialog.body = _("This will disconnect the account and remove it from the list. Your SSH keys on the provider will not be affected.");
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("remove", _("Remove"));
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");

        dialog.response.connect((response_id) => {
            if (response_id == "remove") {
                perform_remove();
            }
        });

        dialog.present(window);
    }

    private void perform_remove() {
        // Disconnect if connected
        if (is_connected) {
            disconnect_account.begin(() => {
                // After disconnect completes, emit the removed signal
                account_removed(account_id);
            });
        } else {
            // Just emit the removed signal immediately
            account_removed(account_id);
        }
    }

    private async void authenticate() {
        show_loading();

        try {
            // For AWS, try to load stored credentials first
            if (provider is AWSProvider) {
                var aws_prov = (AWSProvider)provider;
                if (username != null && username.length > 0) {
                    debug("CloudAccountSection: Attempting to load stored AWS credentials for %s", username);
                    if (yield aws_prov.load_stored_credentials(username)) {
                        is_connected = true;
                        update_ui_connected();
                        connection_state_changed(); // Notify parent to save
                        yield load_keys(false);
                        show_toast_requested(_("Connected successfully"));
                        return;
                    } else {
                        debug("CloudAccountSection: Failed to load stored AWS credentials");
                    }
                }
            }

            // For other providers or if AWS credential loading failed, do normal authentication
            if (yield provider.authenticate()) {
                // Try to get username from provider-specific methods
                username = get_provider_username();
                debug("CloudAccountSection: After authentication, username='%s' for provider_type=%s", username, provider_type);
                is_connected = true;

                update_ui_connected();
                connection_state_changed(); // Notify parent to save
                yield load_keys(false);
                show_toast_requested(_("Connected successfully"));
            }
        } catch (Error e) {
            show_error_requested(@"Authentication failed: $(e.message)");
        }
    }

    private string get_provider_username() {
        // Cast to specific provider type to access get_username()
        if (provider is GitHubProvider) {
            var username = ((GitHubProvider)provider).get_username() ?? "";
            debug("CloudAccountSection.get_provider_username: GitHub username='%s'", username);
            return username;
        } else if (provider is GitLabProvider) {
            var username = ((GitLabProvider)provider).get_username() ?? "";
            debug("CloudAccountSection.get_provider_username: GitLab username='%s'", username);
            return username;
        } else if (provider is BitbucketProvider) {
            var username = ((BitbucketProvider)provider).get_username() ?? "";
            debug("CloudAccountSection.get_provider_username: Bitbucket username='%s'", username);
            return username;
        } else if (provider is GiteaProvider) {
            var username = ((GiteaProvider)provider).get_username() ?? "";
            debug("CloudAccountSection.get_provider_username: Gitea username='%s'", username);
            return username;
        } else if (provider is GCPProvider) {
            var username = ((GCPProvider)provider).get_username() ?? "";
            debug("CloudAccountSection.get_provider_username: GCP username='%s'", username);
            return username;
        } else if (provider is AWSProvider) {
            // For AWS, the username is stored in settings after authentication
            var settings = SettingsManager.app;
            var username = settings.get_string("cloud-provider-aws-username");
            debug("CloudAccountSection.get_provider_username: AWS username='%s'", username);
            return username;
        }
        debug("CloudAccountSection.get_provider_username: Unknown provider type, returning empty");
        return "";
    }

    private async void disconnect_account() {
        try {
            yield provider.disconnect();
            cache_manager.clear_cache(provider_type);
            is_connected = false;
            update_ui_disconnected();
            show_toast_requested(_("Disconnected"));

            // Just disconnect - don't remove from UI
            // User can use the Remove button if they want to remove it entirely
        } catch (Error e) {
            show_error_requested(@"Failed to disconnect: $(e.message)");
        }
    }

    private async void load_keys(bool try_cache_first) {
        show_loading();

        try {
            current_keys = yield provider.list_keys();
            cache_manager.cache_keys(provider_type, current_keys);
            display_keys(current_keys);
        } catch (Error e) {
            show_error_requested(@"Failed to load keys: $(e.message)");
        }
    }

    private void display_keys(Gee.List<CloudKeyMetadata> keys) {
        // Remove loading row if present
        if (loading_row != null && loading_row.get_parent() != null) {
            expander_row.remove(loading_row);
        }

        // Clear existing key rows
        foreach (var row in key_rows) {
            if (row.get_parent() != null) {
                expander_row.remove(row);
            }
        }
        key_rows.clear();

        if (keys.size == 0) {
            var empty_row = new Adw.ActionRow();
            empty_row.title = _("No Keys Found");
            empty_row.subtitle = _("Deploy a key to get started");
            empty_row.icon_name = "dialog-information-symbolic";
            empty_row.activatable = false;
            expander_row.add_row(empty_row);
            key_rows.add(empty_row);
        } else {
            foreach (var key in keys) {
                var row = create_key_row(key);
                expander_row.add_row(row);
                key_rows.add(row);
            }
        }

        deploy_key_button.visible = true;
        expander_row.enable_expansion = true;

        // Apply pending expanded state if it was set before expansion was enabled
        if (pending_expanded_state != null) {
            expander_row.expanded = pending_expanded_state;
            debug("CloudAccountSection: Applied pending expanded state %s for %s", pending_expanded_state.to_string(), account_id);
            pending_expanded_state = null;
        }
    }

    private Adw.ActionRow create_key_row(CloudKeyMetadata key) {
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

        // Add prefix icon
        var prefix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        prefix_box.valign = Gtk.Align.CENTER;

        string icon_name = "dialog-password-symbolic";
        string color_class = "accent";

        if (key.key_type != null) {
            var key_type_lower = key.key_type.down();
            if (key_type_lower.contains("ed25519")) {
                icon_name = "security-high-symbolic";
                color_class = "success";
            } else if (key_type_lower.contains("rsa")) {
                icon_name = "security-medium-symbolic";
                color_class = "accent";
            } else if (key_type_lower.contains("ecdsa")) {
                icon_name = "security-low-symbolic";
                color_class = "warning";
            }
        }

        var key_icon = new Gtk.Image.from_icon_name(icon_name);
        key_icon.add_css_class(color_class);
        prefix_box.append(key_icon);
        row.add_prefix(prefix_box);

        // Add suffix with key type and remove button
        var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
        suffix_box.valign = Gtk.Align.CENTER;

        if (key.key_type != null) {
            var type_label = new Gtk.Label(key.key_type);
            type_label.add_css_class("caption");
            type_label.add_css_class(color_class);
            type_label.add_css_class("pill");
            type_label.valign = Gtk.Align.CENTER;
            type_label.margin_end = 6;
            suffix_box.append(type_label);
        }

        var remove_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-remove-symbolic");
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.tooltip_text = _("Remove from ") + display_name;
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
        // Get the window reference
        var root = expander_row.get_root();
        if (root == null || !(root is Gtk.Window)) {
            warning("Cannot show confirmation dialog: no window found");
            return;
        }

        var window = (Gtk.Window)root;

        // Show confirmation dialog
        var dialog = new Adw.AlertDialog(
            _("Remove SSH Key?"),
            _("Are you sure you want to remove '%s' from %s?").printf(key.title, display_name)
        );

        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("remove", _("Remove"));
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");

        dialog.choose.begin(window, null, (obj, res) => {
            try {
                var response = dialog.choose.end(res);
                if (response == "remove") {
                    perform_key_removal.begin(key);
                }
            } catch (Error e) {
                warning(@"Dialog error: $(e.message)");
            }
        });
    }

    private async void perform_key_removal(CloudKeyMetadata key) {
        show_loading();

        try {
            yield provider.remove_key(key.id);
            yield load_keys(false);
            show_toast_requested(@"Removed '$(key.title)'");
        } catch (Error e) {
            show_error_requested(@"Failed to remove key: $(e.message)");
        }
    }

    public void restore_connected_state(string restored_username) {
        // Used when restoring from saved state
        debug("CloudAccountSection.restore_connected_state called for %s: username='%s'", provider_type, restored_username);
        username = restored_username;
        is_connected = true;
        debug("CloudAccountSection: username set to '%s', calling update_ui_connected", username);
        update_ui_connected();
    }

    public void set_expanded_state(bool expanded) {
        // Restore expanded state from settings
        debug("CloudAccountSection: set_expanded_state called for %s - expanded=%s, enable_expansion=%s",
              account_id, expanded.to_string(), expander_row.enable_expansion.to_string());
        if (expander_row.enable_expansion) {
            expander_row.expanded = expanded;
            debug("CloudAccountSection: Set expanded to %s for %s", expanded.to_string(), account_id);
        } else {
            // Store for later - will be applied when keys finish loading
            pending_expanded_state = expanded;
            debug("CloudAccountSection: Stored pending expanded state %s for %s", expanded.to_string(), account_id);
        }
    }

    public void refresh_keys_async() {
        // Public method to trigger key loading
        load_keys.begin(false);
    }

    private void update_ui_connected() {
        if (username != null && username.length > 0) {
            expander_row.subtitle = @"Connected as $username";
        } else {
            expander_row.subtitle = _("Connected");
        }
        connect_button.visible = false;
        disconnect_button.visible = true;
        refresh_button.visible = true;
    }

    private void update_ui_disconnected() {
        expander_row.subtitle = _("Disconnected");
        connect_button.visible = true;
        disconnect_button.visible = false;
        refresh_button.visible = false;
        loading_box.visible = false;
        deploy_key_button.visible = false;
        expander_row.enable_expansion = false;

        // Clear all key rows when disconnected
        foreach (var row in key_rows) {
            if (row.get_parent() != null) {
                expander_row.remove(row);
            }
        }
        key_rows.clear();
    }

    private void show_loading() {
        deploy_key_button.visible = false;

        // Create and add loading row if it doesn't exist
        if (loading_row == null) {
            loading_row = new Adw.ActionRow();
            loading_row.child = loading_box;
            loading_row.activatable = false;
        }

        // Remove existing key rows
        foreach (var row in key_rows) {
            expander_row.remove(row);
        }
        key_rows.clear();

        // Add loading row
        expander_row.add_row(loading_row);
    }

    private void update_provider_icon() {
        string icon_name = get_provider_icon();
        if (icon_name.length > 0) {
            expander_row.icon_name = icon_name;
        }
    }

    private string get_provider_icon() {
        switch (provider_type) {
            case "github":
                var style_manager = Adw.StyleManager.get_default();
                if (style_manager.dark) {
                    return "io.github.tobagin.keysmith-github-colour-dark-mode";
                } else {
                    return "io.github.tobagin.keysmith-github-colour-light-mode";
                }
            case "gitlab":
                return "io.github.tobagin.keysmith-gitlab-colour";
            case "bitbucket":
                return "io.github.tobagin.keysmith-bitbucket-colour";
            case "gitea":
                // Use specific icon based on display name
                if (display_name.down().contains("codeberg")) {
                    var style_manager = Adw.StyleManager.get_default();
                    if (style_manager.dark) {
                        return "io.github.tobagin.keysmith-codeberg-colour-dark-mode";
                    } else {
                        return "io.github.tobagin.keysmith-codeberg-colour-light-mode";
                    }
                } else if (display_name.down().contains("forgejo")) {
                    return "io.github.tobagin.keysmith-forgejo-colour";
                } else {
                    return "io.github.tobagin.keysmith-gittea-colour";
                }
            case "aws":
                var style_manager = Adw.StyleManager.get_default();
                if (style_manager.dark) {
                    return "io.github.tobagin.keysmith-aws-colour-dark-mode";
                } else {
                    return "io.github.tobagin.keysmith-aws-colour-light-mode";
                }
            case "azure":
                return "io.github.tobagin.keysmith-azure-colour";
            case "gcp":
                return "io.github.tobagin.keysmith-gcp-colour";
            default:
                return "";
        }
    }
}
