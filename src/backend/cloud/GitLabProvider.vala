/* GitLabProvider.vala
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
     * GitLab cloud provider implementation
     * Supports both GitLab.com and self-hosted instances
     */
    public class GitLabProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.GITLAB; } }

        private HttpClient http_client;
        private string? access_token = null;
        private string? username = null;
        private string instance_url = "https://gitlab.com";
        private string? client_id = null;
        private string? client_secret = null;
        private GitLabOAuthServer? oauth_server = null;

        private int rate_limit_remaining = 5000;
        private DateTime? rate_limit_reset = null;

        public GitLabProvider() {
            http_client = new HttpClient();
            load_oauth_credentials();
        }

        /**
         * Load OAuth credentials from settings
         */
        private void load_oauth_credentials() {
            try {
                var settings = SettingsManager.app;
                client_id = settings.get_string("cloud-provider-gitlab-client-id");
                client_secret = settings.get_string("cloud-provider-gitlab-client-secret");
            } catch (Error e) {
                warning(@"Failed to load GitLab OAuth credentials: $(e.message)");
            }
        }

        /**
         * Set OAuth credentials
         */
        public void set_oauth_credentials(string client_id, string client_secret) {
            this.client_id = client_id;
            this.client_secret = client_secret;

            // Save to settings
            var settings = SettingsManager.app;
            settings.set_string("cloud-provider-gitlab-client-id", client_id);
            settings.set_string("cloud-provider-gitlab-client-secret", client_secret);
        }

        /**
         * Check if OAuth credentials are configured
         */
        public bool has_oauth_credentials() {
            return client_id != null && client_id.length > 0 &&
                   client_secret != null && client_secret.length > 0;
        }

        /**
         * Set custom instance URL (for self-hosted GitLab)
         */
        public void set_instance_url(string url) {
            instance_url = url.has_suffix("/") ? url.substring(0, url.length - 1) : url;
        }

        /**
         * Get current instance URL
         */
        public string get_instance_url() {
            return instance_url;
        }

        public async bool authenticate() throws Error {
            // Check if OAuth credentials are configured
            if (!has_oauth_credentials()) {
                throw new IOError.FAILED("OAuth credentials not configured. Please configure your GitLab OAuth application first.");
            }

            // Start OAuth server (keep as instance variable to prevent garbage collection)
            oauth_server = new GitLabOAuthServer();
            yield oauth_server.start();

            // Generate state for CSRF protection
            var state = generate_random_state();

            // Build authorization URL
            // Using read_user + api scopes for full access
            var auth_url = @"$instance_url/oauth/authorize?client_id=$client_id&response_type=code&scope=read_user+api&state=$state&redirect_uri=http://localhost:8765/callback";

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

            var response = yield http_client.post_form(@"$instance_url/oauth/token", form_data, headers);
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("access_token")) {
                access_token = root.get_string_member("access_token");

                // Get username
                yield fetch_username();

                // Store token with instance URL
                yield TokenStorage.store_token(@"gitlab:$instance_url", username, access_token);

                return true;
            } else if (root.has_member("error")) {
                var error = root.get_string_member("error");
                var error_desc = root.has_member("error_description") ? root.get_string_member("error_description") : error;
                throw new IOError.FAILED(@"GitLab OAuth error: $error_desc");
            }

            throw new IOError.FAILED("Failed to obtain access token");
        }

        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var response = yield http_client.get(@"$instance_url/api/v4/user/keys", headers);
            update_rate_limit(headers);

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var array = parser.get_root().get_array();

            var keys = new Gee.ArrayList<CloudKeyMetadata>();
            array.foreach_element((arr, index, node) => {
                var obj = node.get_object();
                var key = new CloudKeyMetadata.full(
                    obj.get_int_member("id").to_string(),
                    obj.get_string_member("title"),
                    obj.has_member("key") ? extract_fingerprint(obj.get_string_member("key")) : null,
                    detect_key_type(obj.get_string_member("key")),
                    parse_datetime(obj.get_string_member("created_at")),
                    null // GitLab doesn't provide last_used_at field
                );
                keys.add(key);
            });

            return keys;
        }

        public async void deploy_key(string public_key, string title) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var body = new Json.Builder();
            body.begin_object();
            body.set_member_name("title");
            body.add_string_value(title);
            body.set_member_name("key");
            body.add_string_value(public_key);
            body.end_object();

            var generator = new Json.Generator();
            generator.set_root(body.get_root());
            var json_data = generator.to_data(null);

            yield http_client.post(@"$instance_url/api/v4/user/keys", json_data, headers);
            update_rate_limit(headers);
        }

        public async void remove_key(string key_id) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            yield http_client.delete(@"$instance_url/api/v4/user/keys/$key_id", headers);
            update_rate_limit(headers);
        }

        public bool is_authenticated() {
            return access_token != null && username != null;
        }

        public string get_provider_name() {
            // Show instance domain for self-hosted
            if (instance_url != "https://gitlab.com") {
                try {
                    var uri = Uri.parse(instance_url, UriFlags.NONE);
                    return @"GitLab ($(uri.get_host()))";
                } catch (Error e) {
                    return "GitLab";
                }
            }
            return "GitLab";
        }

        public async void disconnect() throws Error {
            if (username != null) {
                yield TokenStorage.delete_token(@"gitlab:$instance_url", username);
            }
            access_token = null;
            username = null;
        }

        /**
         * Load authentication from stored token
         */
        public async bool load_stored_auth(string stored_username) throws Error {
            var token = yield TokenStorage.retrieve_token(@"gitlab:$instance_url", stored_username);
            if (token != null) {
                access_token = token;
                username = stored_username;

                // Try to validate, but be lenient - keep auth state even if validation fails
                // This allows the user to still attempt operations which will properly fail with
                // a clear error message rather than silently disconnecting
                try {
                    yield validate_token();
                    debug("GitLab token validated successfully for %s", username);
                    return true;
                } catch (Error e) {
                    warning(@"Failed to validate GitLab token for $username: $(e.message)");
                    // Keep the token and username, don't clear them
                    // This way operations will fail with a proper error rather than silent disconnect
                    return true;  // Still return true so UI shows connected state
                }
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

        /**
         * Check GitLab instance version
         */
        public async string? get_instance_version() throws Error {
            try {
                var headers = new Gee.HashMap<string, string>();
                var response = yield http_client.get(@"$instance_url/api/v4/version", headers);

                var parser = new Json.Parser();
                parser.load_from_data(response);
                var root = parser.get_root().get_object();

                if (root.has_member("version")) {
                    return root.get_string_member("version");
                }
            } catch (Error e) {
                warning(@"Failed to get GitLab version: $(e.message)");
            }
            return null;
        }

        /**
         * Check if instance version is supported (>= 13.0)
         */
        public async bool is_version_supported() throws Error {
            var version = yield get_instance_version();
            if (version == null) {
                return false;
            }

            // Parse major version
            var parts = version.split(".");
            if (parts.length > 0) {
                int major = int.parse(parts[0]);
                return major >= 13;
            }

            return false;
        }

        private async void fetch_username() throws Error {
            var headers = create_auth_headers();
            var response = yield http_client.get(@"$instance_url/api/v4/user", headers);

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("username")) {
                username = root.get_string_member("username");
            } else {
                throw new IOError.FAILED("Failed to fetch username from GitLab");
            }
        }

        private Gee.Map<string, string> create_auth_headers() {
            var headers = new Gee.HashMap<string, string>();
            headers["Authorization"] = @"Bearer $access_token";
            headers["Accept"] = "application/json";
            return headers;
        }

        private void ensure_authenticated() throws Error {
            if (!is_authenticated()) {
                throw new IOError.FAILED("Not authenticated with GitLab");
            }
        }

        private string generate_random_state() {
            var bytes = new uint8[16];
            for (int i = 0; i < 16; i++) {
                bytes[i] = (uint8) Random.int_range(0, 256);
            }
            return Base64.encode(bytes);
        }

        private string? extract_fingerprint(string key) {
            // Compute SHA256 fingerprint from public key
            try {
                // Use ssh-keygen to compute fingerprint
                // Create a temporary file with the key
                FileIOStream iostream;
                var temp_file = File.new_tmp("keymaker-XXXXXX.pub", out iostream);
                iostream.close();

                string? etag_out;
                temp_file.replace_contents(key.data, null, false, FileCreateFlags.NONE, out etag_out, null);

                string stdout_str;
                string stderr_str;
                int exit_status;

                // Get fingerprint using ssh-keygen
                Process.spawn_command_line_sync(
                    @"ssh-keygen -lf $(temp_file.get_path())",
                    out stdout_str,
                    out stderr_str,
                    out exit_status
                );

                // Clean up temp file
                temp_file.delete();

                if (exit_status == 0 && stdout_str.length > 0) {
                    // Parse output: "256 SHA256:5og0WHosJU7BCDGHDOB9zbONgKQ8sg8Dinrpw5tjyfI user@host (ED25519)"
                    var parts = stdout_str.strip().split(" ");
                    if (parts.length >= 2 && parts[1].has_prefix("SHA256:")) {
                        return parts[1]; // Return full "SHA256:xxxxx" format
                    }
                }
            } catch (Error e) {
                warning(@"Failed to compute fingerprint: $(e.message)");
            }

            return null;
        }

        private string? detect_key_type(string key) {
            if (key.has_prefix("ssh-rsa")) {
                return "RSA";
            } else if (key.has_prefix("ssh-ed25519")) {
                return "Ed25519";
            } else if (key.has_prefix("ecdsa-")) {
                return "ECDSA";
            }
            return "Unknown";
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

        private void update_rate_limit(Gee.Map<string, string> headers) {
            // GitLab uses RateLimit-* headers instead of X-RateLimit-*
            // For now, just decrement
            rate_limit_remaining--;
        }

        public string? get_username() {
            return username;
        }

        public int get_rate_limit_remaining() {
            return rate_limit_remaining;
        }
    }
}
