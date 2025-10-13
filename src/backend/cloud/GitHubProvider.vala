/* GitHubProvider.vala
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
     * GitHub cloud provider implementation
     */
    public class GitHubProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.GITHUB; } }

        private HttpClient http_client;
        private string? access_token = null;
        private string? username = null;
        private const string API_BASE = "https://api.github.com";
        private const string AUTH_URL = "https://github.com/login/oauth/authorize";
        private const string TOKEN_URL = "https://github.com/login/oauth/access_token";

        // Default OAuth app credentials (can be overridden in preferences)
        // Get them from: https://github.com/settings/developers
        private const string CLIENT_ID = "Ov23liiiXTBMQuz8VZlI";
        private const string CLIENT_SECRET = "01000fe95bff5ced8d4fdb9ab8a3519843e95ce9";

        private int rate_limit_remaining = 5000;
        private DateTime? rate_limit_reset = null;

        public GitHubProvider() {
            http_client = new HttpClient();
        }

        public async bool authenticate() throws Error {
            // Start OAuth server
            var oauth_server = new GitHubOAuthServer();
            yield oauth_server.start();

            // Generate state for CSRF protection
            var state = generate_random_state();

            // Build authorization URL
            // Using admin:public_key scope to allow both read/write and delete operations
            var auth_url = @"$AUTH_URL?client_id=$CLIENT_ID&scope=admin:public_key&state=$state&redirect_uri=http://localhost:8765/callback";

            // Open browser
            try {
                AppInfo.launch_default_for_uri(auth_url, null);
            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to open browser: $(e.message)");
            }

            // Wait for callback
            var code = yield oauth_server.wait_for_code();
            if (code == null) {
                throw new IOError.FAILED("OAuth authentication failed");
            }

            // Exchange code for token
            var form_data = new Gee.HashMap<string, string>();
            form_data["client_id"] = CLIENT_ID;
            form_data["client_secret"] = CLIENT_SECRET;
            form_data["code"] = code;
            form_data["redirect_uri"] = "http://localhost:8765/callback";

            var headers = new Gee.HashMap<string, string>();
            headers["Accept"] = "application/json";

            var response = yield http_client.post_form(TOKEN_URL, form_data, headers);
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("access_token")) {
                access_token = root.get_string_member("access_token");

                // Get username
                yield fetch_username();

                // Store token
                yield TokenStorage.store_token("github", username, access_token);

                return true;
            } else if (root.has_member("error")) {
                var error = root.get_string_member("error");
                throw new IOError.FAILED(@"GitHub OAuth error: $error");
            }

            throw new IOError.FAILED("Failed to obtain access token");
        }

        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var response = yield http_client.get(@"$API_BASE/user/keys", headers);
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
                    obj.has_member("last_used_at") && !obj.get_null_member("last_used_at") ? parse_datetime(obj.get_string_member("last_used_at")) : null
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

            yield http_client.post(@"$API_BASE/user/keys", json_data, headers);
            update_rate_limit(headers);
        }

        public async void remove_key(string key_id) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            yield http_client.delete(@"$API_BASE/user/keys/$key_id", headers);
            update_rate_limit(headers);
        }

        public bool is_authenticated() {
            return access_token != null && username != null;
        }

        public string get_provider_name() {
            return "GitHub";
        }

        public async void disconnect() throws Error {
            if (username != null) {
                yield TokenStorage.delete_token("github", username);
            }
            access_token = null;
            username = null;
        }

        /**
         * Load authentication from stored token
         */
        public async bool load_stored_auth(string stored_username) throws Error {
            var token = yield TokenStorage.retrieve_token("github", stored_username);
            if (token != null) {
                access_token = token;
                username = stored_username;
                return yield validate_token();
            }
            return false;
        }

        /**
         * Validate current token
         */
        private async bool validate_token() throws Error {
            try {
                yield fetch_username();
                return true;
            } catch (Error e) {
                access_token = null;
                username = null;
                return false;
            }
        }

        private async void fetch_username() throws Error {
            var headers = create_auth_headers();
            var response = yield http_client.get(@"$API_BASE/user", headers);

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("login")) {
                username = root.get_string_member("login");
            } else {
                throw new IOError.FAILED("Failed to fetch username from GitHub");
            }
        }

        private Gee.Map<string, string> create_auth_headers() {
            var headers = new Gee.HashMap<string, string>();
            headers["Authorization"] = @"Bearer $access_token";
            headers["Accept"] = "application/vnd.github+json";
            headers["X-GitHub-Api-Version"] = "2022-11-28";
            return headers;
        }

        private void ensure_authenticated() throws Error {
            if (!is_authenticated()) {
                throw new IOError.FAILED("Not authenticated with GitHub");
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
            // GitHub API returns the full public key string, we need to hash it
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
            // In a real implementation, would extract from response headers
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
