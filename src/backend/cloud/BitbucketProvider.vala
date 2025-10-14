/* BitbucketProvider.vala
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
     * Bitbucket Cloud provider implementation using API tokens
     *
     * NOTE: Currently DISABLED due to Bitbucket API authentication limitations:
     * - App Passwords are deprecated (disabled June 2026)
     * - Workspace/Project API tokens require Premium Bitbucket accounts
     * - Atlassian global API tokens (from id.atlassian.com) return 403 errors
     * - No user-level authentication available for free accounts
     *
     * Future options:
     * - Implement OAuth 2.0 (requires users to create workspace OAuth consumers)
     * - Wait for Atlassian to provide better API token support
     * - Mark as Premium-only feature
     */
    public class BitbucketProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.BITBUCKET; } }

        private HttpClient http_client;
        private string? access_token = null;
        private string? username = null;
        private const string API_BASE = "https://api.bitbucket.org/2.0";

        private int rate_limit_remaining = 5000;
        private DateTime? rate_limit_reset = null;

        public BitbucketProvider() {
            http_client = new HttpClient();
        }

        /**
         * Authenticate with username/email and API token
         * This method accepts both username/email and token directly from the UI
         * The 'user' parameter can be either email or Bitbucket username
         */
        public async bool authenticate_with_username_and_token(string user, string api_token) throws Error {
            if (user == null || user.strip().length == 0) {
                throw new IOError.FAILED("Email or username is required");
            }
            if (api_token == null || api_token.strip().length == 0) {
                throw new IOError.FAILED("API token is required");
            }

            // For Basic Auth, we use the email/username as entered
            var auth_user = user.strip();
            access_token = api_token.strip();

            // Temporarily set username to the auth user for creating headers
            username = auth_user;

            // Verify credentials and fetch the actual Bitbucket username from API
            try {
                yield fetch_username();

                // Store token with the actual Bitbucket username
                yield TokenStorage.store_token("bitbucket", username, access_token);

                return true;
            } catch (Error e) {
                access_token = null;
                username = null;
                throw new IOError.FAILED(@"Failed to authenticate with API token: $(e.message)");
            }
        }

        /**
         * Authenticate with API token
         * This method is called by the UI with the user-provided token
         */
        public async bool authenticate_with_token(string api_token) throws Error {
            if (api_token == null || api_token.strip().length == 0) {
                throw new IOError.FAILED("API token is required");
            }

            // Set the token
            access_token = api_token.strip();

            // Verify token by fetching username
            try {
                yield fetch_username();

                // Store token
                yield TokenStorage.store_token("bitbucket", username, access_token);

                return true;
            } catch (Error e) {
                access_token = null;
                username = null;
                throw new IOError.FAILED(@"Failed to authenticate with API token: $(e.message)");
            }
        }

        /**
         * Legacy authenticate method - not used for Bitbucket (uses API tokens)
         */
        public async bool authenticate() throws Error {
            throw new IOError.FAILED("Bitbucket requires API token authentication. Use authenticate_with_token() instead.");
        }

        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            ensure_authenticated();

            var all_keys = new Gee.ArrayList<CloudKeyMetadata>();
            string? next_url = @"$API_BASE/user/ssh-keys";
            int page_count = 0;
            const int MAX_PAGES = 10; // Limit to 100 keys (10 pages * 10 keys per page)

            // Bitbucket uses paginated responses
            while (next_url != null && page_count < MAX_PAGES) {
                var headers = create_auth_headers();
                var response = yield http_client.get(next_url, headers);
                update_rate_limit(headers);

                var parser = new Json.Parser();
                parser.load_from_data(response);
                var root = parser.get_root().get_object();

                // Bitbucket pagination format: {pagelen, values, next}
                if (root.has_member("values")) {
                    var values = root.get_array_member("values");
                    values.foreach_element((arr, index, node) => {
                        var obj = node.get_object();

                        // Extract UUID (Bitbucket uses UUID key IDs)
                        var uuid = obj.has_member("uuid") ? obj.get_string_member("uuid") : "";

                        var key = new CloudKeyMetadata.full(
                            uuid,
                            obj.has_member("label") ? obj.get_string_member("label") : "Untitled",
                            obj.has_member("key") ? extract_fingerprint(obj.get_string_member("key")) : null,
                            obj.has_member("key") ? detect_key_type(obj.get_string_member("key")) : "Unknown",
                            obj.has_member("created_on") ? parse_datetime(obj.get_string_member("created_on")) : null,
                            null // Bitbucket doesn't provide last_used field
                        );
                        all_keys.add(key);
                    });
                }

                // Check for next page
                if (root.has_member("next") && !root.get_null_member("next")) {
                    next_url = root.get_string_member("next");
                    page_count++;
                } else {
                    next_url = null;
                }
            }

            return all_keys;
        }

        public async void deploy_key(string public_key, string title) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var body = new Json.Builder();
            body.begin_object();
            body.set_member_name("label");
            body.add_string_value(title);
            body.set_member_name("key");
            body.add_string_value(public_key);
            body.end_object();

            var generator = new Json.Generator();
            generator.set_root(body.get_root());
            var json_data = generator.to_data(null);

            yield http_client.post(@"$API_BASE/user/ssh-keys", json_data, headers);
            update_rate_limit(headers);
        }

        public async void remove_key(string key_id) throws Error {
            ensure_authenticated();

            // Bitbucket UUIDs come with curly braces: {uuid}
            // Ensure the format is correct
            var formatted_key_id = key_id;
            if (!key_id.has_prefix("{")) {
                formatted_key_id = @"{$key_id}";
            }

            var headers = create_auth_headers();
            yield http_client.delete(@"$API_BASE/user/ssh-keys/$formatted_key_id", headers);
            update_rate_limit(headers);
        }

        public bool is_authenticated() {
            return access_token != null && username != null;
        }

        public string get_provider_name() {
            return "Bitbucket";
        }

        public async void disconnect() throws Error {
            if (username != null) {
                yield TokenStorage.delete_token("bitbucket", username);
            }
            access_token = null;
            username = null;
        }

        /**
         * Load authentication from stored token
         */
        public async bool load_stored_auth(string stored_username) throws Error {
            var token = yield TokenStorage.retrieve_token("bitbucket", stored_username);
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
            debug(@"Bitbucket: Fetching username from API with auth user: $username");
            var headers = create_auth_headers();

            try {
                debug(@"Bitbucket: Calling $API_BASE/user");
                var response = yield http_client.get(@"$API_BASE/user", headers);
                debug(@"Bitbucket: Got response: $(response.substring(0, int.min(100, response.length)))...");

                var parser = new Json.Parser();
                parser.load_from_data(response);
                var root = parser.get_root().get_object();

                if (root.has_member("username")) {
                    username = root.get_string_member("username");
                    debug(@"Bitbucket: Successfully authenticated as $username");
                } else {
                    debug("Bitbucket: No username field in response");
                    throw new IOError.FAILED("Failed to fetch username from Bitbucket");
                }
            } catch (Error e) {
                warning(@"Bitbucket: Error fetching username: $(e.message)");
                if (e.message.contains("403")) {
                    throw new IOError.FAILED("Permission denied (HTTP 403). Your token has the right scopes, but Bitbucket rejected the request. This might be a workspace access issue.");
                } else if (e.message.contains("401")) {
                    throw new IOError.FAILED("Authentication failed (HTTP 401). Please verify your email/username and API token are correct.");
                } else {
                    throw e;
                }
            }
        }

        private Gee.Map<string, string> create_auth_headers() {
            var headers = new Gee.HashMap<string, string>();
            // Bitbucket API tokens use HTTP Basic Auth: username:token
            var auth_string = @"$username:$access_token";
            // Encode to base64, ensuring no trailing newline
            var base64_auth = Base64.encode(auth_string.data).replace("\n", "").replace("\r", "");
            debug(@"Bitbucket: Auth string length: $(auth_string.length) chars");
            debug(@"Bitbucket: Base64 auth length: $(base64_auth.length) chars");
            headers["Authorization"] = @"Basic $base64_auth";
            headers["Accept"] = "application/json";
            return headers;
        }

        private void ensure_authenticated() throws Error {
            if (!is_authenticated()) {
                throw new IOError.FAILED("Not authenticated with Bitbucket");
            }
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
            // Bitbucket uses X-RateLimit-* headers
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
