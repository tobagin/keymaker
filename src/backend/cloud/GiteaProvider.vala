/* GiteaProvider.vala
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

namespace KeyMaker {

    /**
     * Gitea cloud provider implementation
     *
     * Supports both gitea.com and self-hosted Gitea instances
     * Uses OAuth 2.0 for authentication
     */
    public class GiteaProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.GITEA; } }

        private HttpClient http_client;
        private string? access_token = null;
        private string? username = null;
        private string instance_url = "https://gitea.com";
        private string? client_id = null;
        private string? client_secret = null;
        private GiteaOAuthServer? oauth_server = null;

        /**
         * Get the configured OAuth client ID (read-only)
         */
        public string? get_client_id() {
            return client_id;
        }

        /**
         * Get the configured OAuth client secret (read-only)
         */
        public string? get_client_secret() {
            return client_secret;
        }

        public GiteaProvider() {
            http_client = new HttpClient();
            load_oauth_credentials();
        }

        /**
         * Load OAuth credentials from settings
         */
        private void load_oauth_credentials() {
            try {
                var settings = SettingsManager.app;
                client_id = settings.get_string("cloud-provider-gitea-client-id");
                client_secret = settings.get_string("cloud-provider-gitea-client-secret");
            } catch (Error e) {
                warning(@"Failed to load Gitea OAuth credentials: $(e.message)");
            }
        }

        /**
         * Set the Gitea instance URL
         */
        public void set_instance_url(string url) {
            this.instance_url = url.has_suffix("/") ? url.substring(0, url.length - 1) : url;
        }

        /**
         * Get the instance URL
         */
        public string get_instance_url() {
            return instance_url;
        }

        /**
         * Set OAuth credentials
         */
        public void set_oauth_credentials(string client_id, string client_secret, bool save_to_settings = false) {
            this.client_id = client_id;
            this.client_secret = client_secret;

            // Only save to settings for custom instances (not pre-configured)
            if (save_to_settings) {
                var settings = SettingsManager.app;
                settings.set_string("cloud-provider-gitea-client-id", client_id);
                settings.set_string("cloud-provider-gitea-client-secret", client_secret);
            }
        }

        /**
         * Check if OAuth credentials are configured
         */
        public bool has_oauth_credentials() {
            return client_id != null && client_id.length > 0 &&
                   client_secret != null && client_secret.length > 0;
        }

        /**
         * Authenticate with OAuth 2.0 flow
         */
        public async bool authenticate() throws Error {
            // Check if OAuth credentials are configured
            if (!has_oauth_credentials()) {
                throw new IOError.FAILED("OAuth credentials not configured. Please configure your Gitea OAuth application first.");
            }

            // Start OAuth server (keep as instance variable to prevent garbage collection)
            oauth_server = new GiteaOAuthServer();
            yield oauth_server.start();

            // Generate state for CSRF protection
            var state = generate_random_state();

            // Build authorization URL
            var auth_url = @"$instance_url/login/oauth/authorize?client_id=$client_id&response_type=code&state=$state&redirect_uri=http://localhost:8765/callback";

            // Open browser
            try {
                AppInfo.launch_default_for_uri(auth_url, null);
            } catch (Error e) {
                oauth_server.stop();
                oauth_server = null;
                throw new IOError.FAILED(@"Failed to open browser: $(e.message)");
            }

            // Wait for callback
            var code = yield oauth_server.wait_for_code();
            if (code == null) {
                oauth_server = null;
                throw new IOError.FAILED("OAuth authentication failed");
            }

            // Clean up server
            oauth_server.stop();
            oauth_server = null;

            // Exchange code for token
            var form_data = new Gee.HashMap<string, string>();
            form_data["client_id"] = client_id;
            form_data["client_secret"] = client_secret;
            form_data["code"] = code;
            form_data["grant_type"] = "authorization_code";
            form_data["redirect_uri"] = "http://localhost:8765/callback";

            var headers = new Gee.HashMap<string, string>();
            headers["Accept"] = "application/json";

            var response = yield http_client.post_form(@"$instance_url/login/oauth/access_token", form_data, headers);
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("access_token")) {
                access_token = root.get_string_member("access_token");

                // Get username
                yield fetch_username();

                // Store token with instance URL
                yield TokenStorage.store_token(@"gitea:$instance_url", username, access_token);

                return true;
            } else if (root.has_member("error")) {
                var error = root.get_string_member("error");
                var error_desc = root.has_member("error_description") ? root.get_string_member("error_description") : error;
                throw new IOError.FAILED(@"Gitea OAuth error: $error_desc");
            }

            throw new IOError.FAILED("Failed to obtain access token");
        }

        /**
         * List all SSH public keys for the authenticated user
         */
        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var response = yield http_client.get(@"$instance_url/api/v1/user/keys", headers);

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var array = parser.get_root().get_array();

            var keys = new Gee.ArrayList<CloudKeyMetadata>();
            array.foreach_element((arr, index, node) => {
                var obj = node.get_object();

                // Extract key type from the public key string
                string? key_type = null;
                if (obj.has_member("key")) {
                    var pub_key = obj.get_string_member("key");
                    if (pub_key.has_prefix("ssh-rsa ")) {
                        key_type = "RSA";
                    } else if (pub_key.has_prefix("ssh-ed25519 ")) {
                        key_type = "Ed25519";
                    } else if (pub_key.has_prefix("ecdsa-sha2-nistp256 ")) {
                        key_type = "ECDSA 256";
                    } else if (pub_key.has_prefix("ecdsa-sha2-nistp384 ")) {
                        key_type = "ECDSA 384";
                    } else if (pub_key.has_prefix("ecdsa-sha2-nistp521 ")) {
                        key_type = "ECDSA 521";
                    }
                }

                var key = new CloudKeyMetadata.full(
                    obj.get_int_member("id").to_string(),
                    obj.get_string_member("title"),
                    obj.has_member("fingerprint") ? obj.get_string_member("fingerprint") : null,
                    key_type,
                    parse_datetime(obj.get_string_member("created_at")),
                    null   // last_used not provided
                );
                keys.add(key);
            });

            return keys;
        }

        /**
         * Deploy an SSH public key to Gitea
         */
        public async void deploy_key(string public_key, string title) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var body = new Json.Builder();
            body.begin_object();
            body.set_member_name("title");
            body.add_string_value(title);
            body.set_member_name("key");
            body.add_string_value(public_key);
            body.set_member_name("read_only");
            body.add_boolean_value(false);
            body.end_object();

            var generator = new Json.Generator();
            generator.set_root(body.get_root());
            var json_data = generator.to_data(null);

            yield http_client.post(@"$instance_url/api/v1/user/keys", json_data, headers);
        }

        /**
         * Remove an SSH public key from Gitea
         */
        public async void remove_key(string key_id) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            yield http_client.delete(@"$instance_url/api/v1/user/keys/$key_id", headers);
        }

        /**
         * Check if currently authenticated
         */
        public bool is_authenticated() {
            return access_token != null && username != null;
        }

        /**
         * Get the display name of this provider
         */
        public string get_provider_name() {
            // Show instance domain for self-hosted
            if (instance_url != "https://gitea.com" && instance_url != "https://codeberg.org") {
                try {
                    var uri = Uri.parse(instance_url, UriFlags.NONE);
                    return @"Gitea ($(uri.get_host()))";
                } catch (Error e) {
                    return "Gitea";
                }
            }
            return "Gitea";
        }

        /**
         * Disconnect from the provider (clear stored credentials)
         */
        public async void disconnect() throws Error {
            if (username != null) {
                yield TokenStorage.delete_token(@"gitea:$instance_url", username);
            }
            access_token = null;
            username = null;
        }

        /**
         * Load authentication from stored token
         */
        public async bool load_stored_auth(string stored_username) throws Error {
            debug("GiteaProvider: load_stored_auth called for username=%s, instance_url=%s", stored_username, instance_url);
            debug("GiteaProvider: TokenStorage key will be: gitea:%s", instance_url);

            var token = yield TokenStorage.retrieve_token(@"gitea:$instance_url", stored_username);

            if (token != null) {
                debug("GiteaProvider: Token retrieved successfully, length=%d", (int)token.length);
                access_token = token;
                username = stored_username;

                // Try to validate, but be lenient
                try {
                    yield validate_token();
                    debug("Gitea token validated successfully for %s", username);
                    return true;
                } catch (Error e) {
                    warning(@"Failed to validate Gitea token for $username: $(e.message)");
                    return true;  // Still return true so UI shows connected state
                }
            } else {
                debug("GiteaProvider: No token found in storage for gitea:%s username=%s", instance_url, stored_username);
            }
            return false;
        }

        /**
         * Validate current token
         */
        private async bool validate_token() throws Error {
            yield fetch_username();
            return true;
        }

        private async void fetch_username() throws Error {
            debug("GiteaProvider.fetch_username: Fetching username from %s/api/v1/user", instance_url);
            var headers = create_auth_headers();
            var response = yield http_client.get(@"$instance_url/api/v1/user", headers);
            debug("GiteaProvider.fetch_username: Got response: %s", response.substring(0, int.min(200, response.length)));

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("login")) {
                username = root.get_string_member("login");
                debug("GiteaProvider.fetch_username: Set username='%s'", username);
            } else {
                debug("GiteaProvider.fetch_username: Response has no 'login' field");
                throw new IOError.FAILED("Failed to fetch username from Gitea");
            }
        }

        private Gee.Map<string, string> create_auth_headers() {
            var headers = new Gee.HashMap<string, string>();
            headers["Authorization"] = @"token $access_token";
            headers["Accept"] = "application/json";
            return headers;
        }

        private void ensure_authenticated() throws Error {
            if (!is_authenticated()) {
                throw new IOError.FAILED("Not authenticated with Gitea");
            }
        }

        private string generate_random_state() {
            var bytes = new uint8[16];
            for (int i = 0; i < 16; i++) {
                bytes[i] = (uint8) Random.int_range(0, 256);
            }
            return Base64.encode(bytes);
        }

        public string? get_username() {
            return username;
        }

        private DateTime? parse_datetime(string? iso8601) {
            if (iso8601 == null) return null;
            try {
                var tv = TimeVal();
                if (tv.from_iso8601(iso8601)) {
                    return new DateTime.from_unix_utc(tv.tv_sec);
                }
            } catch (Error e) {
                warning(@"Failed to parse datetime: $(e.message)");
            }
            return null;
        }

        /**
         * Throw user-friendly Gitea errors
         */
        private void throw_gitea_error(string message) throws Error {
            if ("401" in message || "Unauthorized" in message) {
                throw new IOError.PERMISSION_DENIED(
                    _("Unauthorized. Please reconnect to Gitea.")
                );
            }

            if ("403" in message || "Forbidden" in message) {
                throw new IOError.PERMISSION_DENIED(
                    _("Forbidden. Check your Gitea permissions.")
                );
            }

            if ("404" in message || "Not Found" in message) {
                throw new IOError.NOT_FOUND(
                    _("Resource not found. Check your Gitea instance URL.")
                );
            }

            // Generic error
            throw new IOError.FAILED(
                _("Gitea API error: %s").printf(message)
            );
        }
    }
}
