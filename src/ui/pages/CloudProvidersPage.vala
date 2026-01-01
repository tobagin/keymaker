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
    private unowned Gtk.Box accounts_container;

    [GtkChild]
    private unowned Adw.StatusPage empty_state_page;

    private Settings settings;
    private Gee.HashMap<string, CloudAccountSection> account_sections;
    private Gee.ArrayList<string> account_order; // Track insertion order
    private Adw.PreferencesGroup providers_group; // Single group for accordion behavior

    // Provider instances
    private GitHubProvider github_provider;
    private GitLabProvider gitlab_provider;
    private BitbucketProvider bitbucket_provider;
    private GiteaProvider gitea_provider;
    private AWSProvider aws_provider;

    construct {
        settings = SettingsManager.app;
        account_sections = new Gee.HashMap<string, CloudAccountSection>();
        account_order = new Gee.ArrayList<string>();

        // Create single preferences group for all providers
        providers_group = new Adw.PreferencesGroup();
        providers_group.title = _("Cloud Providers");
        accounts_container.append(providers_group);

        // Initialize providers
        github_provider = new GitHubProvider();
        gitlab_provider = new GitLabProvider();
        bitbucket_provider = new BitbucketProvider();
        gitea_provider = new GiteaProvider();
        aws_provider = new AWSProvider();

        // Load existing accounts
        load_accounts.begin();
    }

    private async void load_accounts() {
        debug("=== LOAD ACCOUNTS CALLED ===");
        // Try to load from new multi-account storage first
        var accounts_json = settings.get_string("cloud-accounts");
        debug("Loading JSON from settings:\n%s", accounts_json);

        try {
            var parser = new Json.Parser();
            parser.load_from_data(accounts_json);
            var root = parser.get_root();

            if (root != null && root.get_node_type() == Json.NodeType.ARRAY) {
                var array = root.get_array();
                debug("Found %d accounts in JSON", (int)array.get_length());

                foreach (var element in array.get_elements()) {
                    var obj = element.get_object();

                    var account_id = obj.get_string_member("id");
                    var provider_type = obj.get_string_member("provider_type");
                    var display_name = obj.get_string_member("display_name");
                    var username = obj.get_string_member("username");
                    var was_connected = obj.get_boolean_member("is_connected");
                    var was_expanded = obj.has_member("is_expanded") ? obj.get_boolean_member("is_expanded") : false;
                    var instance_url = obj.has_member("instance_url") ? obj.get_string_member("instance_url") : "";
                    var instance_type = obj.has_member("instance_type") ? obj.get_string_member("instance_type") : "custom";

                    debug("Loading account: id=%s, type=%s, username=%s, was_connected=%s",
                          account_id, provider_type, username, was_connected.to_string());

                    // Create provider based on type
                    CloudProvider? provider = null;

                    if (provider_type == "github") {
                        provider = new GitHubProvider();
                    } else if (provider_type == "gitlab") {
                        var gitlab_prov = new GitLabProvider();
                        if (instance_url.length > 0) {
                            gitlab_prov.set_instance_url(instance_url);

                            // Set OAuth credentials based on instance type
                            string client_id = "";
                            string client_secret = "";

                            if (instance_type == "gitlab.com") {
                                client_id = "e5dc4cacfc592ee14ea5851a4ab98a729e2683542a07f4fc0f9c569ef4917b3b";
                                client_secret = "gloas-d6833be35e80bf99a66210213467c8130d732dafaec60b86bdc6f632fc03f268";
                            } else if (instance_type == "gitlab.gnome.org") {
                                client_id = "2174aa43e0f2e36154d863bcf10d3ae81213b9915b55e89ab412836ff045ea3e";
                                client_secret = "gloas-741417286efeb8b6915018163b99250b8d49eb97cae2faafaca1a85e4bf968ed";
                            } else if (instance_type == "gitlab.freedesktop.org") {
                                client_id = "ddfb39c8929f22cd53165d34247d51425f7f2737934e955458bfe58882158a6c";
                                client_secret = "gloas-af32aaf323216ec55544d157733937f789acdb216dc3efde25697413ec75328b";
                            } else if (instance_type == "salsa.debian.org") {
                                client_id = "51093f2599b4680db128447435a0658f368adb995cd7dc6e24cfbc25dc0432f0";
                                client_secret = "gloas-989d64d8037af96689e71a2f46acefc3ff90fdeb4dc1ed6a787470d566011973";
                            } else {
                                // Custom instance - load from JSON (per-instance storage)
                                if (obj.has_member("oauth_client_id") && obj.has_member("oauth_client_secret")) {
                                    client_id = obj.get_string_member("oauth_client_id");
                                    client_secret = obj.get_string_member("oauth_client_secret");
                                }
                            }

                            if (client_id.length > 0 && client_secret.length > 0) {
                                gitlab_prov.set_oauth_credentials(client_id, client_secret);
                            }
                        }
                        provider = gitlab_prov;
                    } else if (provider_type == "bitbucket") {
                        provider = new BitbucketProvider();
                    } else if (provider_type == "gitea") {
                        var gitea_prov = new GiteaProvider();
                        if (instance_url.length > 0) {
                            gitea_prov.set_instance_url(instance_url);

                            // Set OAuth credentials based on instance type
                            string client_id = "";
                            string client_secret = "";

                            if (instance_type == "gitea.com") {
                                client_id = "aab5f98f-15ca-4ed2-960f-dff26608b144";
                                client_secret = "gto_gk73xynxba4nlpebsewune5tvchtwa2aafqfsuwcqodwfiaiudwq";
                                gitea_prov.set_oauth_credentials(client_id, client_secret, false);
                            } else if (instance_type == "codeberg.org") {
                                // Codeberg uses Forgejo (Gitea fork)
                                client_id = "11c3ba97-5d9f-4a76-ad03-a6fb77b0ba7d";
                                client_secret = "gto_glejgxyyarudktv6jbyrbv6vssibe6thk5v3x4nnrjkcqcnslpta";
                                gitea_prov.set_oauth_credentials(client_id, client_secret, false);
                            } else {
                                // Custom instance - load from JSON (per-instance storage)
                                if (obj.has_member("oauth_client_id") && obj.has_member("oauth_client_secret")) {
                                    client_id = obj.get_string_member("oauth_client_id");
                                    client_secret = obj.get_string_member("oauth_client_secret");
                                }

                                if (client_id.length > 0 && client_secret.length > 0) {
                                    gitea_prov.set_oauth_credentials(client_id, client_secret, false);
                                }
                            }
                        }
                        provider = gitea_prov;
                    } else if (provider_type == "gcp") {
                        provider = new GCPProvider();
                    } else if (provider_type == "aws") {
                        var aws_prov = new AWSProvider();
                        // IAM is global, no region needed
                        provider = aws_prov;
                    }

                    if (provider != null) {
                        // Skip save during load - we'll restore auth state first
                        add_account_section(account_id, provider_type, display_name, provider, username, true);

                        // Auto-connect if was previously connected
                        if (was_connected) {
                            var section = account_sections[account_id];
                            if (section != null) {
                                try {
                                    bool loaded = false;

                                    // Cast to specific provider type to access load_stored_auth
                                    if (provider is GitHubProvider) {
                                        loaded = yield ((GitHubProvider)provider).load_stored_auth(username);
                                    } else if (provider is GitLabProvider) {
                                        loaded = yield ((GitLabProvider)provider).load_stored_auth(username);
                                    } else if (provider is BitbucketProvider) {
                                        loaded = yield ((BitbucketProvider)provider).load_stored_auth(username);
                                    } else if (provider is GiteaProvider) {
                                        loaded = yield ((GiteaProvider)provider).load_stored_auth(username);
                                    } else if (provider is GCPProvider) {
                                        loaded = yield ((GCPProvider)provider).load_stored_auth(username);
                                    } else if (provider is AWSProvider) {
                                        loaded = yield ((AWSProvider)provider).load_stored_credentials(username);
                                    }

                                    if (loaded) {
                                        section.restore_connected_state(username);
                                        // Auto-load keys for restored accounts
                                        section.refresh_keys_async();

                                        // Restore expanded state after keys are loaded
                                        // Use a timeout to ensure enable_expansion is set first
                                        debug("CloudProvidersPage: Account %s was_expanded=%s", account_id, was_expanded.to_string());
                                        if (was_expanded) {
                                            Timeout.add(500, () => {
                                                debug("CloudProvidersPage: Restoring expanded state for %s", account_id);
                                                section.set_expanded_state(was_expanded);
                                                return false;
                                            });
                                        } else {
                                            // Also explicitly set to collapsed if it was collapsed
                                            Timeout.add(500, () => {
                                                debug("CloudProvidersPage: Setting collapsed state for %s", account_id);
                                                section.set_expanded_state(false);
                                                return false;
                                            });
                                        }
                                    } else {
                                        debug("Failed to load stored credentials for %s", account_id);
                                    }
                                } catch (Error e) {
                                    warning(@"Failed to auto-connect $display_name: $(e.message)");
                                }
                            }
                        }
                    }
                }

            }
        } catch (Error e) {
            warning(@"Failed to load accounts from new storage: $(e.message)");
        }

        update_empty_state();
    }

    private void add_account_section(string account_id, string provider_type, string display_name, CloudProvider provider, string? username = null, bool skip_save = false) {
        var section = new CloudAccountSection(account_id, provider_type, display_name, provider);

        if (username != null) {
            section.username = username;
            // If provider is already authenticated, mark section as connected
            if (provider.is_authenticated()) {
                section.restore_connected_state(username);
                debug("CloudProvidersPage: Added section for %s with existing auth", account_id);
                // Auto-load keys for newly added authenticated account
                section.refresh_keys_async();
            }
        }

        // Connect signals
        section.account_removed.connect(on_account_removed);
        section.connection_state_changed.connect(save_accounts);
        section.expanded_state_changed.connect((is_expanded) => {
            save_accounts();
        });
        section.show_toast_requested.connect(show_toast);
        section.show_error_requested.connect(show_error);

        // Add expander row directly to single group (accordion behavior)
        providers_group.add(section.expander_row);

        // Connect accordion behavior - collapse others when this one expands
        section.expander_row.notify["expanded"].connect(() => {
            if (section.expander_row.expanded) {
                collapse_other_sections(account_id);
            }
        });

        account_sections[account_id] = section;
        account_order.add(account_id); // Track insertion order

        update_empty_state();

        // Don't save during initial load - save will happen after auth state is restored
        if (!skip_save) {
            save_accounts();
        }
    }

    private void collapse_other_sections(string current_account_id) {
        // Collapse all other sections when one is expanded (accordion behavior)
        foreach (var entry in account_sections.entries) {
            if (entry.key != current_account_id) {
                entry.value.expander_row.expanded = false;
            }
        }
    }

    private void on_account_removed(string account_id) {
        var section = account_sections[account_id];
        if (section != null) {
            // Remove expander row from the single group
            providers_group.remove(section.expander_row);
            account_sections.unset(account_id);
            account_order.remove(account_id); // Remove from order tracking

            // Clear settings
            // This needs to be expanded for proper multi-account support
            if (section.provider_type == "github") {
                settings.set_boolean("cloud-provider-github-connected", false);
                settings.set_string("cloud-provider-github-username", "");
            } else if (section.provider_type == "gitlab") {
                settings.set_boolean("cloud-provider-gitlab-connected", false);
                settings.set_string("cloud-provider-gitlab-username", "");
            } else if (section.provider_type == "bitbucket") {
                settings.set_boolean("cloud-provider-bitbucket-connected", false);
                settings.set_string("cloud-provider-bitbucket-username", "");
            }

            update_empty_state();
            save_accounts();
        }
    }

    private void update_empty_state() {
        empty_state_page.visible = (account_sections.size == 0);
        providers_group.visible = (account_sections.size > 0);
    }

    public void show_add_account_chooser() {
        var window = (Gtk.Window) this.get_root();

        // Use AlertDialog instead for proper OK/Cancel buttons
        var dialog = new Adw.AlertDialog(_("Add Cloud Account"), null);
        dialog.body = _("Choose a cloud provider to connect");

        // Create combo box with providers
        var provider_row = new Adw.ComboRow();
        provider_row.title = _("Cloud Provider");

        var model = new Gtk.StringList(null);
        model.append("GitHub");
        model.append("GitLab");
        model.append("Bitbucket");
        model.append("Gitea");
        model.append("Forgejo");
        model.append("Google Cloud Platform");
        model.append("AWS IAM");
        provider_row.model = model;
        provider_row.selected = 0; // Default to GitHub

        // Create a preferences group to contain the combo row
        var group = new Adw.PreferencesGroup();
        group.add(provider_row);

        // Set as extra child
        dialog.set_extra_child(group);

        // Add responses
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("ok", _("OK"));
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("ok");
        dialog.set_close_response("cancel");

        dialog.response.connect((response_id) => {
            if (response_id == "ok") {
                var selected = provider_row.selected;

                if (selected == 0) {
                    add_github_account();
                } else if (selected == 1) {
                    show_gitlab_instance_selector();
                } else if (selected == 2) {
                    add_bitbucket_account();
                } else if (selected == 3) {
                    show_gitea_instance_selector();
                } else if (selected == 4) {
                    show_forgejo_instance_selector();
                } else if (selected == 5) {
                    add_gcp_account();
                } else if (selected == 6) {
                    add_aws_account();
                }
            }
        });

        dialog.present(window);
    }

    private void add_github_account() {
        // Create a new GitHub provider instance
        var new_provider = new GitHubProvider();

        // Temporary account ID (will be replaced with username after auth)
        var temp_id = @"github-temp-$(GLib.get_real_time())";
        var display_name = "GitHub";

        add_account_section(temp_id, "github", display_name, new_provider);
    }

    private void add_bitbucket_account() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.MessageDialog(window, _("Connect to Bitbucket"), null);
        dialog.body = _("Use a Bitbucket App Password for authentication.\n\nNote: Atlassian API tokens don't work with Bitbucket API.");
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("connect", _("Connect"));
        dialog.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED);
        dialog.set_default_response("connect");

        // Add entry fields
        var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;
        content_box.margin_start = 12;
        content_box.margin_end = 12;

        var username_entry = new Adw.EntryRow();
        username_entry.title = _("Bitbucket Username");
        content_box.append(username_entry);

        var token_entry = new Adw.PasswordEntryRow();
        token_entry.title = _("App Password");
        content_box.append(token_entry);

        dialog.set_extra_child(content_box);

        dialog.response.connect((response_id) => {
            if (response_id == "connect") {
                var username = username_entry.text.strip();
                var token = token_entry.text.strip();
                if (username.length > 0 && token.length > 0) {
                    // Add Bitbucket account logic here
                    show_toast(_("Bitbucket support coming soon"));
                }
            }
        });

        dialog.present();
    }

    private void show_gitlab_instance_selector() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.PreferencesDialog();
        dialog.set_title(_("Select GitLab Instance"));

        var page = new Adw.PreferencesPage();
        var instance_group = new Adw.PreferencesGroup();
        instance_group.title = _("Select GitLab Instance");
        instance_group.description = _("Choose a pre-configured instance or enter custom credentials");

        // Radio buttons
        Gtk.CheckButton? gitlab_com_radio = null;
        Gtk.CheckButton? gitlab_gnome_radio = null;
        Gtk.CheckButton? gitlab_freedesktop_radio = null;
        Gtk.CheckButton? gitlab_salsa_radio = null;
        Gtk.CheckButton? custom_radio = null;

        // GitLab.com
        var gitlab_com_row = new Adw.ActionRow();
        gitlab_com_row.title = "GitLab.com";
        gitlab_com_row.subtitle = _("Official GitLab cloud service (pre-configured)");
        gitlab_com_radio = new Gtk.CheckButton();
        gitlab_com_radio.valign = Gtk.Align.CENTER;
        gitlab_com_radio.active = true;
        gitlab_com_row.add_prefix(gitlab_com_radio);
        gitlab_com_row.activatable_widget = gitlab_com_radio;
        instance_group.add(gitlab_com_row);

        // GitLab GNOME
        var gitlab_gnome_row = new Adw.ActionRow();
        gitlab_gnome_row.title = "GitLab GNOME";
        gitlab_gnome_row.subtitle = _("GNOME's GitLab instance (pre-configured)");
        gitlab_gnome_radio = new Gtk.CheckButton();
        gitlab_gnome_radio.valign = Gtk.Align.CENTER;
        gitlab_gnome_radio.group = gitlab_com_radio;
        gitlab_gnome_row.add_prefix(gitlab_gnome_radio);
        gitlab_gnome_row.activatable_widget = gitlab_gnome_radio;
        instance_group.add(gitlab_gnome_row);

        // freedesktop.org
        var gitlab_freedesktop_row = new Adw.ActionRow();
        gitlab_freedesktop_row.title = "freedesktop.org";
        gitlab_freedesktop_row.subtitle = _("freedesktop.org GitLab instance (pre-configured)");
        gitlab_freedesktop_radio = new Gtk.CheckButton();
        gitlab_freedesktop_radio.valign = Gtk.Align.CENTER;
        gitlab_freedesktop_radio.group = gitlab_com_radio;
        gitlab_freedesktop_row.add_prefix(gitlab_freedesktop_radio);
        gitlab_freedesktop_row.activatable_widget = gitlab_freedesktop_radio;
        instance_group.add(gitlab_freedesktop_row);

        // Salsa (Debian)
        var gitlab_salsa_row = new Adw.ActionRow();
        gitlab_salsa_row.title = "Salsa (Debian)";
        gitlab_salsa_row.subtitle = _("Debian's GitLab instance (pre-configured)");
        gitlab_salsa_radio = new Gtk.CheckButton();
        gitlab_salsa_radio.valign = Gtk.Align.CENTER;
        gitlab_salsa_radio.group = gitlab_com_radio;
        gitlab_salsa_row.add_prefix(gitlab_salsa_radio);
        gitlab_salsa_row.activatable_widget = gitlab_salsa_radio;
        instance_group.add(gitlab_salsa_row);

        // Custom
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

        // Custom configuration group
        var custom_group = new Adw.PreferencesGroup();
        custom_group.title = _("Custom Instance Configuration");
        custom_group.visible = false;

        var url_row = new Adw.EntryRow();
        url_row.title = _("Instance URL");
        custom_group.add(url_row);

        var client_id_row = new Adw.EntryRow();
        client_id_row.title = _("OAuth Client ID");
        custom_group.add(client_id_row);

        var client_secret_row = new Adw.PasswordEntryRow();
        client_secret_row.title = _("OAuth Client Secret");
        custom_group.add(client_secret_row);

        page.add(custom_group);
        dialog.add(page);

        custom_radio.toggled.connect(() => {
            custom_group.visible = custom_radio.active;
        });

        dialog.closed.connect(() => {
            string url = "";
            string client_id = "";
            string client_secret = "";
            string instance_label = "";

            if (gitlab_com_radio.active) {
                url = "https://gitlab.com";
                client_id = "e5dc4cacfc592ee14ea5851a4ab98a729e2683542a07f4fc0f9c569ef4917b3b";
                client_secret = "gloas-d6833be35e80bf99a66210213467c8130d732dafaec60b86bdc6f632fc03f268";
                instance_label = "gitlab.com";
            } else if (gitlab_gnome_radio.active) {
                url = "https://gitlab.gnome.org";
                client_id = "2174aa43e0f2e36154d863bcf10d3ae81213b9915b55e89ab412836ff045ea3e";
                client_secret = "gloas-741417286efeb8b6915018163b99250b8d49eb97cae2faafaca1a85e4bf968ed";
                instance_label = "gitlab.gnome.org";
            } else if (gitlab_freedesktop_radio.active) {
                url = "https://gitlab.freedesktop.org";
                client_id = "ddfb39c8929f22cd53165d34247d51425f7f2737934e955458bfe58882158a6c";
                client_secret = "gloas-af32aaf323216ec55544d157733937f789acdb216dc3efde25697413ec75328b";
                instance_label = "gitlab.freedesktop.org";
            } else if (gitlab_salsa_radio.active) {
                url = "https://salsa.debian.org";
                client_id = "51093f2599b4680db128447435a0658f368adb995cd7dc6e24cfbc25dc0432f0";
                client_secret = "gloas-989d64d8037af96689e71a2f46acefc3ff90fdeb4dc1ed6a787470d566011973";
                instance_label = "salsa.debian.org";
            } else if (custom_radio.active) {
                url = url_row.text.strip();
                client_id = client_id_row.text.strip();
                client_secret = client_secret_row.text.strip();

                if (url.length == 0 || client_id.length == 0 || client_secret.length == 0) {
                    show_error(_("Please fill in all custom instance fields"));
                    return;
                }

                instance_label = url.replace("https://", "").replace("http://", "");
            }

            if (url.length > 0 && client_id.length > 0 && client_secret.length > 0) {
                add_gitlab_instance(url, client_id, client_secret, instance_label);
            }
        });

        dialog.present(window);
    }

    private void show_gitea_instance_selector() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.PreferencesDialog();
        dialog.set_title(_("Select Gitea Instance"));

        var page = new Adw.PreferencesPage();
        var instance_group = new Adw.PreferencesGroup();
        instance_group.title = _("Select Gitea Instance");
        instance_group.description = _("Choose Gitea.com or enter custom instance credentials");

        // Radio buttons
        Gtk.CheckButton? gitea_com_radio = null;
        Gtk.CheckButton? custom_radio = null;

        // Gitea.com
        var gitea_com_row = new Adw.ActionRow();
        gitea_com_row.title = "Gitea.com";
        gitea_com_row.subtitle = _("Official Gitea cloud service (pre-configured)");
        gitea_com_radio = new Gtk.CheckButton();
        gitea_com_radio.valign = Gtk.Align.CENTER;
        gitea_com_radio.active = true;
        gitea_com_row.add_prefix(gitea_com_radio);
        gitea_com_row.activatable_widget = gitea_com_radio;
        instance_group.add(gitea_com_row);

        // Custom
        var custom_row = new Adw.ActionRow();
        custom_row.title = _("Custom Instance");
        custom_row.subtitle = _("Self-hosted Gitea instance");
        custom_radio = new Gtk.CheckButton();
        custom_radio.valign = Gtk.Align.CENTER;
        custom_radio.group = gitea_com_radio;
        custom_row.add_prefix(custom_radio);
        custom_row.activatable_widget = custom_radio;
        instance_group.add(custom_row);

        page.add(instance_group);

        // Custom configuration group
        var custom_group = new Adw.PreferencesGroup();
        custom_group.title = _("Custom Instance Configuration");
        custom_group.visible = false;

        var url_row = new Adw.EntryRow();
        url_row.title = _("Instance URL");
        custom_group.add(url_row);

        var client_id_row = new Adw.EntryRow();
        client_id_row.title = _("OAuth Client ID");
        custom_group.add(client_id_row);

        var client_secret_row = new Adw.PasswordEntryRow();
        client_secret_row.title = _("OAuth Client Secret");
        custom_group.add(client_secret_row);

        page.add(custom_group);
        dialog.add(page);

        custom_radio.toggled.connect(() => {
            custom_group.visible = custom_radio.active;
        });

        dialog.closed.connect(() => {
            string url = "";
            string client_id = "";
            string client_secret = "";
            string instance_label = "";

            if (gitea_com_radio.active) {
                url = "https://gitea.com";
                client_id = "aab5f98f-15ca-4ed2-960f-dff26608b144";
                client_secret = "gto_gk73xynxba4nlpebsewune5tvchtwa2aafqfsuwcqodwfiaiudwq";
                instance_label = "gitea.com";
            } else if (custom_radio.active) {
                url = url_row.text.strip();
                client_id = client_id_row.text.strip();
                client_secret = client_secret_row.text.strip();

                if (url.length == 0 || client_id.length == 0 || client_secret.length == 0) {
                    show_error(_("Please fill in all fields for custom Gitea instance"));
                    return;
                }

                instance_label = url.replace("https://", "").replace("http://", "");
            }

            if (url.length > 0 && client_id.length > 0 && client_secret.length > 0) {
                add_gitea_instance(url, client_id, client_secret, instance_label);
            }
        });

        dialog.present(window);
    }

    private void add_gitea_instance(string url, string client_id, string client_secret, string instance_label) {
        // Create a new Gitea provider for this instance
        var new_provider = new GiteaProvider();
        new_provider.set_instance_url(url);

        // Save to settings only for custom instances (not pre-configured gitea.com)
        bool is_custom = (instance_label != "gitea.com");
        new_provider.set_oauth_credentials(client_id, client_secret, is_custom);

        // Create temporary account section
        var temp_id = @"gitea-$instance_label-temp-$(GLib.get_real_time())";
        var display_name = @"Gitea ($instance_label)";

        add_account_section(temp_id, "gitea", display_name, new_provider);

        // The section will handle authentication
    }

    private void show_forgejo_instance_selector() {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.PreferencesDialog();
        dialog.set_title(_("Select Forgejo Instance"));

        var page = new Adw.PreferencesPage();
        var instance_group = new Adw.PreferencesGroup();
        instance_group.title = _("Select Forgejo Instance");
        instance_group.description = _("Choose Codeberg or enter custom instance credentials");

        // Radio buttons
        Gtk.CheckButton? codeberg_radio = null;
        Gtk.CheckButton? custom_radio = null;

        // Codeberg.org (Forgejo)
        var codeberg_row = new Adw.ActionRow();
        codeberg_row.title = "Codeberg.org";
        codeberg_row.subtitle = _("Codeberg Forgejo instance (pre-configured)");
        codeberg_radio = new Gtk.CheckButton();
        codeberg_radio.valign = Gtk.Align.CENTER;
        codeberg_radio.active = true;
        codeberg_row.add_prefix(codeberg_radio);
        codeberg_row.activatable_widget = codeberg_radio;
        instance_group.add(codeberg_row);

        // Custom
        var custom_row = new Adw.ActionRow();
        custom_row.title = _("Custom Instance");
        custom_row.subtitle = _("Self-hosted Forgejo instance");
        custom_radio = new Gtk.CheckButton();
        custom_radio.valign = Gtk.Align.CENTER;
        custom_radio.group = codeberg_radio;
        custom_row.add_prefix(custom_radio);
        custom_row.activatable_widget = custom_radio;
        instance_group.add(custom_row);

        page.add(instance_group);

        // Custom configuration group
        var custom_group = new Adw.PreferencesGroup();
        custom_group.title = _("Instance Configuration");
        custom_group.visible = false;

        var url_row = new Adw.EntryRow();
        url_row.title = _("Instance URL");
        custom_group.add(url_row);

        var client_id_row = new Adw.EntryRow();
        client_id_row.title = _("OAuth Client ID");
        custom_group.add(client_id_row);

        var client_secret_row = new Adw.PasswordEntryRow();
        client_secret_row.title = _("OAuth Client Secret");
        custom_group.add(client_secret_row);

        page.add(custom_group);
        dialog.add(page);

        custom_radio.toggled.connect(() => {
            custom_group.visible = custom_radio.active;
        });

        codeberg_radio.toggled.connect(() => {
            custom_group.visible = custom_radio.active;
        });

        dialog.closed.connect(() => {
            string url = "";
            string client_id = "";
            string client_secret = "";
            string instance_label = "";

            if (codeberg_radio.active) {
                // Pre-configured Codeberg.org
                url = "https://codeberg.org";
                client_id = "11c3ba97-5d9f-4a76-ad03-a6fb77b0ba7d";
                client_secret = "gto_glejgxyyarudktv6jbyrbv6vssibe6thk5v3x4nnrjkcqcnslpta";
                instance_label = "codeberg.org";
            } else if (custom_radio.active) {
                url = url_row.text.strip();
                client_id = client_id_row.text.strip();
                client_secret = client_secret_row.text.strip();

                if (url.length == 0 || client_id.length == 0 || client_secret.length == 0) {
                    show_error(_("Please fill in all fields for custom Forgejo instance"));
                    return;
                }

                instance_label = url.replace("https://", "").replace("http://", "");
            }

            if (url.length > 0 && client_id.length > 0 && client_secret.length > 0) {
                add_forgejo_instance(url, client_id, client_secret, instance_label);
            }
        });

        dialog.present(window);
    }

    private void add_forgejo_instance(string url, string client_id, string client_secret, string instance_label) {
        // Create a new Gitea provider for this instance (Forgejo uses Gitea API)
        var new_provider = new GiteaProvider();
        new_provider.set_instance_url(url);

        // Save to settings only for custom instances (not pre-configured codeberg.org)
        bool is_custom = (instance_label != "codeberg.org");
        new_provider.set_oauth_credentials(client_id, client_secret, is_custom);

        // Create temporary account section - use "gitea" provider_type since Forgejo uses Gitea API
        var temp_id = @"gitea-$instance_label-temp-$(GLib.get_real_time())";
        var display_name = @"Forgejo ($instance_label)";

        add_account_section(temp_id, "gitea", display_name, new_provider);

        // The section will handle authentication
    }

    private void add_gcp_account() {
        // GCP now uses hardcoded OAuth credentials, no need for dialog
        var new_provider = new GCPProvider();

        // Create temporary account section
        var temp_id = @"gcp-temp-$(GLib.get_real_time())";
        var display_name = "Google Cloud Platform";

        add_account_section(temp_id, "gcp", display_name, new_provider);

        // The section will handle authentication
    }

    private void add_aws_account() {
        var window = (Gtk.Window) this.get_root();
        var new_provider = new AWSProvider();
        var dialog = new AWSCredentialsDialog(window, new_provider);

        dialog.credentials_configured.connect((success) => {
            if (success) {
                // Get username from settings (set during authentication)
                var username = settings.get_string("cloud-provider-aws-username");
                if (username.length > 0) {
                    var account_id = "aws-" + username;
                    // IAM is global, no need to show region
                    var display_name = "AWS IAM";

                    add_account_section(account_id, "aws", display_name, new_provider, username);

                    // Save to cloud-accounts
                    save_accounts();
                }
            }
        });

        dialog.present();
    }

    private void add_gitlab_instance(string url, string client_id, string client_secret, string instance_label) {
        // Create a new GitLab provider for this instance
        var new_provider = new GitLabProvider();
        new_provider.set_instance_url(url);
        new_provider.set_oauth_credentials(client_id, client_secret);

        // Create temporary account section
        var temp_id = @"gitlab-$instance_label-temp-$(GLib.get_real_time())";
        var display_name = @"GitLab ($instance_label)";

        add_account_section(temp_id, "gitlab", display_name, new_provider);

        // The section will handle authentication
    }

    private void show_error(string message) {
        var window = (Gtk.Window) this.get_root();
        var dialog = new Adw.AlertDialog(_("Error"), message);
        dialog.add_response("ok", _("OK"));
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.DEFAULT);
        dialog.set_default_response("ok");
        dialog.set_close_response("ok");
        dialog.present(window);
    }

    private void show_toast(string message) {
        // Emit signal to window
        debug(@"Toast: $message");
    }

    private void save_accounts() {
        debug("=== SAVE ACCOUNTS CALLED ===");
        var builder = new Json.Builder();
        builder.begin_array();

        // Iterate in insertion order
        foreach (var account_id in account_order) {
            var section = account_sections[account_id];
            if (section == null) continue;

            debug("Saving account: id=%s, type=%s, username=%s, is_connected=%s",
                  section.account_id, section.provider_type, section.username ?? "(null)",
                  section.is_connected.to_string());

            builder.begin_object();
            builder.set_member_name("id");
            builder.add_string_value(section.account_id);

            builder.set_member_name("provider_type");
            builder.add_string_value(section.provider_type);

            builder.set_member_name("display_name");
            builder.add_string_value(section.display_name);

            builder.set_member_name("username");
            builder.add_string_value(section.username ?? "");

            builder.set_member_name("is_connected");
            builder.add_boolean_value(section.is_connected);

            builder.set_member_name("instance_url");
            // For GitLab/Gitea, get the instance URL directly from the provider
            var instance_url = "";
            if (section.provider_type == "gitlab") {
                var provider = section.get_provider();
                if (provider is GitLabProvider) {
                    instance_url = ((GitLabProvider)provider).get_instance_url();
                }
            } else if (section.provider_type == "gitea") {
                var provider = section.get_provider();
                if (provider is GiteaProvider) {
                    instance_url = ((GiteaProvider)provider).get_instance_url();
                }
            }
            builder.add_string_value(instance_url);

            // Save instance type for pre-configured GitLab/Gitea instances
            builder.set_member_name("instance_type");
            var instance_type = "custom"; // default
            if (section.provider_type == "gitlab" && instance_url.length > 0) {
                if (instance_url == "https://gitlab.com") {
                    instance_type = "gitlab.com";
                } else if (instance_url == "https://gitlab.gnome.org") {
                    instance_type = "gitlab.gnome.org";
                } else if (instance_url == "https://gitlab.freedesktop.org") {
                    instance_type = "gitlab.freedesktop.org";
                } else if (instance_url == "https://salsa.debian.org") {
                    instance_type = "salsa.debian.org";
                }
            } else if (section.provider_type == "gitea" && instance_url.length > 0) {
                if (instance_url == "https://gitea.com") {
                    instance_type = "gitea.com";
                } else if (instance_url == "https://codeberg.org") {
                    instance_type = "codeberg.org";
                }
            }
            builder.add_string_value(instance_type);

            // Save OAuth credentials for custom Gitea/Forgejo/GitLab instances
            // Pre-configured instances don't need credentials saved (they're hardcoded)
            var oauth_client_id = "";
            var oauth_client_secret = "";

            if (instance_type == "custom") {
                if (section.provider_type == "gitea") {
                    var provider = section.get_provider();
                    if (provider is GiteaProvider) {
                        var gitea_prov = (GiteaProvider)provider;
                        // Get credentials directly from the provider
                        oauth_client_id = gitea_prov.get_client_id() ?? "";
                        oauth_client_secret = gitea_prov.get_client_secret() ?? "";
                    }
                } else if (section.provider_type == "gitlab") {
                    var provider = section.get_provider();
                    if (provider is GitLabProvider) {
                        var gitlab_prov = (GitLabProvider)provider;
                        // Get credentials directly from the provider
                        oauth_client_id = gitlab_prov.get_client_id() ?? "";
                        oauth_client_secret = gitlab_prov.get_client_secret() ?? "";
                    }
                }
            }

            builder.set_member_name("oauth_client_id");
            builder.add_string_value(oauth_client_id);
            builder.set_member_name("oauth_client_secret");
            builder.add_string_value(oauth_client_secret);

            // Save expanded state
            builder.set_member_name("is_expanded");
            var is_expanded = section.expander_row.expanded;
            builder.add_boolean_value(is_expanded);
            debug("CloudProvidersPage: Saving account %s with is_expanded=%s", section.account_id, is_expanded.to_string());

            builder.end_object();
        }

        builder.end_array();

        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        generator.pretty = true;
        var json_string = generator.to_data(null);

        debug("Saving JSON to settings:\n%s", json_string);
        settings.set_string("cloud-accounts", json_string);
        debug("=== SAVE COMPLETE ===");
    }
}
