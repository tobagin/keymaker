/* GCPProvider.vala
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
     * Google Cloud Platform provider implementation
     * Uses Google OAuth 2.0 and OS Login API
     */
    public class GCPProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.GCP; } }

        public string get_provider_name() {
            return "Google Cloud Platform";
        }

        private HttpClient http_client;
        private string? access_token = null;
        private string? refresh_token = null;
        private string? username = null;
        private string? email = null;
        private const string AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth";
        private const string TOKEN_URL = "https://oauth2.googleapis.com/token";
        private const string API_BASE = "https://oslogin.googleapis.com/v1";

        // Hardcoded OAuth credentials for KeySmith app
        private const string CLIENT_ID = "1063475351330-kjdejnrkv12uhp6msk9qq5k67kden5rs.apps.googleusercontent.com";
        private const string CLIENT_SECRET = "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";
        private GCPOAuthServer? oauth_server = null;

        public GCPProvider() {
            http_client = new HttpClient();
        }

        public async bool authenticate() throws Error {

            // Start OAuth server
            oauth_server = new GCPOAuthServer();
            yield oauth_server.start();

            // Generate state for CSRF protection
            var state = generate_random_state();

            // Build authorization URL with compute scope for OS Login API
            // Use loopback IP address as recommended by Google for desktop apps
            var redirect_uri = "http://127.0.0.1:8765/callback";
            var scope = "https://www.googleapis.com/auth/compute https://www.googleapis.com/auth/userinfo.email";
            var auth_url = @"$AUTH_URL?client_id=$CLIENT_ID&response_type=code&scope=$scope&state=$state&redirect_uri=$redirect_uri&access_type=offline";

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
            form_data["client_id"] = CLIENT_ID;
            form_data["client_secret"] = CLIENT_SECRET;
            form_data["code"] = code;
            form_data["grant_type"] = "authorization_code";
            form_data["redirect_uri"] = "http://127.0.0.1:8765/callback";

            var response = yield http_client.post_form(TOKEN_URL, form_data);
            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("access_token")) {
                access_token = root.get_string_member("access_token");

                // Store refresh token if provided
                if (root.has_member("refresh_token")) {
                    refresh_token = root.get_string_member("refresh_token");
                }

                // Get user email
                yield fetch_user_info();

                // Store both access token and refresh token
                yield TokenStorage.store_token("gcp", email, access_token);
                if (refresh_token != null) {
                    yield TokenStorage.store_token("gcp:refresh", email, refresh_token);
                }

                return true;
            } else if (root.has_member("error")) {
                var error = root.get_string_member("error");
                throw new IOError.FAILED(@"Google OAuth error: $error");
            }

            throw new IOError.FAILED("Failed to obtain access token");
        }

        /**
         * Refresh the access token using the refresh token
         */
        private async bool refresh_access_token() throws Error {
            if (refresh_token == null) {
                return false;
            }

            debug("GCPProvider: Refreshing access token");

            var form_data = new Gee.HashMap<string, string>();
            form_data["client_id"] = CLIENT_ID;
            form_data["client_secret"] = CLIENT_SECRET;
            form_data["refresh_token"] = refresh_token;
            form_data["grant_type"] = "refresh_token";

            try {
                var response = yield http_client.post_form(TOKEN_URL, form_data);
                var parser = new Json.Parser();
                parser.load_from_data(response);
                var root = parser.get_root().get_object();

                if (root.has_member("access_token")) {
                    access_token = root.get_string_member("access_token");

                    // Store new access token
                    if (email != null) {
                        yield TokenStorage.store_token("gcp", email, access_token);
                    }

                    debug("GCPProvider: Token refreshed successfully");
                    return true;
                }
            } catch (Error e) {
                warning("GCPProvider: Failed to refresh token: %s", e.message);
            }

            return false;
        }

        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            string response;

            // Use getLoginProfile endpoint to retrieve SSH keys
            try {
                response = yield http_client.get(@"$API_BASE/users/$email/loginProfile", headers);
            } catch (Error e) {
                if (e.message.contains("401")) {
                    debug("GCPProvider: Got 401, attempting token refresh");
                    if (yield refresh_access_token()) {
                        headers = create_auth_headers();
                        try {
                            response = yield http_client.get(@"$API_BASE/users/$email/loginProfile", headers);
                        } catch (Error e2) {
                            if (e2.message.contains("403") || e2.message.contains("OS Login API has not been used")) {
                                throw new IOError.FAILED("OS Login API is not enabled for your GCP project. Please enable it:\n\n1. Visit: https://console.cloud.google.com/apis/library/oslogin.googleapis.com\n2. Select your project\n3. Click 'Enable'\n4. Wait a few minutes for propagation\n\nThen reconnect to GCP in KeySmith.");
                            } else if (e2.message.contains("404")) {
                                throw new IOError.FAILED("OS Login API is not enabled for your GCP project. Please enable it:\n\n1. Visit: https://console.cloud.google.com/apis/library/oslogin.googleapis.com\n2. Select your project\n3. Click 'Enable'\n4. Wait a few minutes for propagation\n\nThen reconnect to GCP in KeySmith.");
                            }
                            throw e2;
                        }
                    } else {
                        throw e;
                    }
                } else if (e.message.contains("403") || e.message.contains("OS Login API has not been used")) {
                    throw new IOError.FAILED("OS Login API is not enabled for your GCP project. Please enable it:\n\n1. Visit: https://console.cloud.google.com/apis/library/oslogin.googleapis.com\n2. Select your project\n3. Click 'Enable'\n4. Wait a few minutes for propagation\n\nThen reconnect to GCP in KeySmith.");
                } else if (e.message.contains("404")) {
                    throw new IOError.FAILED("OS Login API is not enabled for your GCP project. Please enable it:\n\n1. Visit: https://console.cloud.google.com/apis/library/oslogin.googleapis.com\n2. Select your project\n3. Click 'Enable'\n4. Wait a few minutes for propagation\n\nThen reconnect to GCP in KeySmith.");
                } else {
                    throw e;
                }
            }

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root();

            var keys = new Gee.ArrayList<CloudKeyMetadata>();

            // Check if OS Login API is enabled
            if (root.get_node_type() == Json.NodeType.OBJECT) {
                var obj = root.get_object();
                if (obj.has_member("error")) {
                    var error_obj = obj.get_object_member("error");
                    var message = error_obj.get_string_member("message");
                    if (message.contains("OS Login API has not been used")) {
                        throw new IOError.FAILED("OS Login API is not enabled. Please enable it in the GCP Console:\nhttps://console.cloud.google.com/apis/library/oslogin.googleapis.com");
                    }
                    throw new IOError.FAILED(@"GCP API error: $message");
                }

                // Parse SSH keys
                if (obj.has_member("sshPublicKeys")) {
                    var ssh_keys = obj.get_object_member("sshPublicKeys");
                    ssh_keys.foreach_member((obj, name, node) => {
                        var key_obj = node.get_object();
                        var fingerprint = key_obj.get_string_member("fingerprint");
                        var public_key = key_obj.get_string_member("key");

                        // Extract key type from public key
                        string? key_type = null;
                        if (public_key.has_prefix("ssh-rsa ")) {
                            key_type = "RSA";
                        } else if (public_key.has_prefix("ssh-ed25519 ")) {
                            key_type = "Ed25519";
                        } else if (public_key.has_prefix("ecdsa-sha2-")) {
                            key_type = "ECDSA";
                        }

                        var key = new CloudKeyMetadata.full(
                            fingerprint,
                            name,  // Use the key name as title
                            fingerprint,
                            key_type,
                            null,  // GCP doesn't provide created_at
                            null   // GCP doesn't provide last_used_at
                        );
                        keys.add(key);
                    });
                }
            }

            return keys;
        }

        public async void deploy_key(string public_key, string title) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            var body = new Json.Builder();
            body.begin_object();
            body.set_member_name("key");
            body.add_string_value(public_key);
            body.end_object();

            var generator = new Json.Generator();
            generator.set_root(body.get_root());
            var json_data = generator.to_data(null);

            headers["Content-Type"] = "application/json";

            try {
                yield http_client.post(@"$API_BASE/users/$email:importSshPublicKey", json_data, headers);
            } catch (Error e) {
                if (e.message.contains("OS Login API has not been used")) {
                    throw new IOError.FAILED("OS Login API is not enabled. Please enable it in the GCP Console:\nhttps://console.cloud.google.com/apis/library/oslogin.googleapis.com");
                }
                throw e;
            }
        }

        public async void remove_key(string key_id) throws Error {
            ensure_authenticated();

            var headers = create_auth_headers();
            // key_id is the fingerprint for GCP
            yield http_client.delete(@"$API_BASE/users/$email/sshPublicKeys/$key_id", headers);
        }

        public bool is_authenticated() {
            return access_token != null && email != null;
        }

        public async void disconnect() throws Error {
            // Don't delete tokens from storage - just clear from memory
            // This allows reconnecting without re-authenticating
            access_token = null;
            refresh_token = null;
            email = null;
            username = null;
        }

        public async bool load_stored_auth(string stored_email) throws Error {
            var token = yield TokenStorage.retrieve_token("gcp", stored_email);

            if (token != null) {
                access_token = token;
                email = stored_email;

                // Load refresh token if available
                var stored_refresh = yield TokenStorage.retrieve_token("gcp:refresh", stored_email);
                if (stored_refresh != null) {
                    refresh_token = stored_refresh;
                }

                // Verify token is still valid by fetching user info
                try {
                    yield fetch_user_info();
                    return true;
                } catch (Error e) {
                    // Token invalid, try to refresh if we have a refresh token
                    debug("GCPProvider: Token validation failed on load, attempting refresh");
                    if (refresh_token != null) {
                        if (yield refresh_access_token()) {
                            debug("GCPProvider: Token refreshed successfully on load");
                            return true;
                        }
                    }
                    // Refresh failed or no refresh token, clear everything
                    access_token = null;
                    refresh_token = null;
                    email = null;
                    return false;
                }
            }

            return false;
        }

        public string? get_username() {
            return email;
        }

        /**
         * Fetch user information from Google
         */
        private async void fetch_user_info() throws Error {
            var headers = create_auth_headers();
            var response = yield http_client.get("https://www.googleapis.com/oauth2/v2/userinfo", headers);

            var parser = new Json.Parser();
            parser.load_from_data(response);
            var root = parser.get_root().get_object();

            if (root.has_member("email")) {
                email = root.get_string_member("email");
                username = email;
            } else {
                throw new IOError.FAILED("Failed to fetch user email from Google");
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
                throw new IOError.FAILED("Not authenticated with Google Cloud Platform");
            }
        }

        private string generate_random_state() {
            var bytes = new uint8[16];
            for (int i = 0; i < 16; i++) {
                bytes[i] = (uint8) Random.int_range(0, 256);
            }
            return Base64.encode(bytes);
        }
    }
}
