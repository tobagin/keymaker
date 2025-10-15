/* AWSProvider.vala
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
     * AWS IAM cloud provider implementation
     *
     * This provider implements SSH public key management for AWS IAM users.
     * Unlike GitHub/GitLab, AWS uses API key authentication instead of OAuth.
     */
    public class AWSProvider : Object, CloudProvider {
        public CloudProviderType provider_type { get { return CloudProviderType.AWS; } }

        private HttpClient http_client;
        private string? access_key_id = null;
        private string? secret_access_key = null;
        private string? username = null;
        private string region = "us-east-1";

        private const string IAM_ENDPOINT = "https://iam.amazonaws.com/";
        private const string IAM_SERVICE = "iam";
        private const string API_VERSION = "2010-05-08";
        private const int MAX_KEYS = 5; // AWS IAM limit

        // Secret Service keys
        private const string SECRET_SERVICE_ACCESS_KEY_ID = "keymaker-aws-access-key-id";
        private const string SECRET_SERVICE_SECRET_ACCESS_KEY = "keymaker-aws-secret-access-key";

        private TokenStorage token_storage;
        private Settings settings;

        public AWSProvider() {
            http_client = new HttpClient();
            token_storage = new TokenStorage();
            settings = SettingsManager.app;

            // Load region from settings
            region = settings.get_string("cloud-provider-aws-region");
            if (region.length == 0) {
                region = "us-east-1";
            }
        }

        /**
         * Set AWS credentials (used by credentials dialog)
         */
        public void set_credentials(string access_key_id, string secret_access_key, string region) {
            this.access_key_id = access_key_id;
            this.secret_access_key = secret_access_key;
            this.region = region;
        }

        /**
         * Get current region
         */
        public string get_region() {
            return region;
        }

        /**
         * Authenticate with AWS IAM
         *
         * Validates credentials by calling iam:GetUser and stores them if valid.
         */
        public async bool authenticate() throws Error {
            if (access_key_id == null || secret_access_key == null) {
                throw new IOError.INVALID_ARGUMENT(_("AWS credentials not set"));
            }

            // Validate credentials format
            if (!access_key_id.has_prefix("AKIA") && !access_key_id.has_prefix("ASIA")) {
                throw new IOError.INVALID_ARGUMENT(_("Invalid Access Key ID format. Must start with AKIA or ASIA."));
            }

            if (secret_access_key.length != 40) {
                throw new IOError.INVALID_ARGUMENT(_("Invalid Secret Access Key length. Must be 40 characters."));
            }

            try {
                // Call iam:GetUser to validate credentials and get username
                var params = new Gee.HashMap<string, string>();
                params["Action"] = "GetUser";
                params["Version"] = API_VERSION;

                var response = yield make_aws_request("POST", "/", params, "");

                // Parse XML response to extract username
                username = parse_get_user_response(response);

                if (username == null || username.length == 0) {
                    throw new IOError.FAILED(_("Failed to retrieve IAM username"));
                }

                // Store credentials in Secret Service
                yield store_credentials();

                // Store username and region in settings (needed for retrieval)
                // Note: NOT setting cloud-provider-aws-connected to avoid legacy storage conflicts
                settings.set_string("cloud-provider-aws-username", username);
                settings.set_string("cloud-provider-aws-region", region);
                settings.set_string("cloud-provider-aws-access-key-id", access_key_id);

                return true;
            } catch (Error e) {
                throw_aws_error(e.message);
                return false; // Unreachable, but compiler needs it
            }
        }

        /**
         * List all SSH public keys for the authenticated user
         */
        public async Gee.List<CloudKeyMetadata> list_keys() throws Error {
            if (!is_authenticated()) {
                throw new IOError.NOT_CONNECTED(_("Not authenticated with AWS"));
            }

            var keys = new Gee.ArrayList<CloudKeyMetadata>();

            try {
                // Call iam:ListSSHPublicKeys
                var list_params = new Gee.HashMap<string, string>();
                list_params["Action"] = "ListSSHPublicKeys";
                list_params["UserName"] = username;
                list_params["Version"] = API_VERSION;

                var list_response = yield make_aws_request("POST", "/", list_params, "");

                // Parse key IDs from response
                var key_ids = parse_list_ssh_public_keys_response(list_response);

                // Get details for each key
                foreach (var key_id in key_ids) {
                    var get_params = new Gee.HashMap<string, string>();
                    get_params["Action"] = "GetSSHPublicKey";
                    get_params["UserName"] = username;
                    get_params["SSHPublicKeyId"] = key_id;
                    get_params["Encoding"] = "SSH";
                    get_params["Version"] = API_VERSION;

                    var get_response = yield make_aws_request("POST", "/", get_params, "");
                    var key_metadata = parse_get_ssh_public_key_response(get_response);

                    if (key_metadata != null) {
                        keys.add(key_metadata);
                    }
                }

            } catch (Error e) {
                throw_aws_error(e.message);
            }

            return keys;
        }

        /**
         * Deploy a public SSH key to AWS IAM
         */
        public async void deploy_key(string public_key, string title) throws Error {
            if (!is_authenticated()) {
                throw new IOError.NOT_CONNECTED(_("Not authenticated with AWS"));
            }

            // Trim and normalize the public key
            var cleaned_key = public_key.strip().replace("\r\n", "\n").replace("\r", "\n");

            // Remove trailing newlines
            while (cleaned_key.has_suffix("\n")) {
                cleaned_key = cleaned_key.substring(0, cleaned_key.length - 1);
            }

            // AWS IAM only supports RSA keys (minimum 2048 bits)
            // ED25519 and ECDSA are NOT supported by AWS IAM
            if (!cleaned_key.has_prefix("ssh-rsa ")) {
                if (cleaned_key.has_prefix("ssh-ed25519 ")) {
                    throw new IOError.NOT_SUPPORTED(_("AWS IAM does not support ED25519 keys. Only RSA keys (2048 bits or higher) are supported.\n\nNote: ED25519 keys work with AWS Transfer Family and EC2, but not IAM."));
                } else if (cleaned_key.has_prefix("ecdsa-sha2-nistp")) {
                    throw new IOError.NOT_SUPPORTED(_("AWS IAM does not support ECDSA keys. Only RSA keys (2048 bits or higher) are supported.\n\nNote: ECDSA keys work with AWS Transfer Family, but not IAM."));
                } else {
                    throw new IOError.INVALID_ARGUMENT(_("Invalid SSH public key format. AWS IAM only supports RSA keys in ssh-rsa format."));
                }
            }

            // AWS is strict: format must be exactly "type key-data [optional-email]"
            // Split by any whitespace and filter empty parts
            var parts_raw = cleaned_key.split(" ");
            var parts = new Gee.ArrayList<string>();
            foreach (var part in parts_raw) {
                if (part.length > 0) {
                    parts.add(part);
                }
            }

            string final_key;

            if (parts.size == 2) {
                // Just type and key - perfect
                final_key = @"$(parts[0]) $(parts[1])";
            } else if (parts.size >= 3) {
                // Has comment - keep only if it looks like a real email (not just user@hostname)
                var comment = parts[2];

                // Check if it's a proper email with a domain extension (contains @ and a dot after @)
                bool is_email = false;
                if (comment.contains("@")) {
                    var at_pos = comment.index_of("@");
                    var after_at = comment.substring(at_pos + 1);
                    // Real email should have a dot after @ (like user@example.com, not user@hostname)
                    if (after_at.contains(".")) {
                        is_email = true;
                    }
                }

                if (is_email) {
                    final_key = @"$(parts[0]) $(parts[1]) $comment";
                } else {
                    // Drop non-email comment (AWS doesn't accept user@hostname format)
                    final_key = @"$(parts[0]) $(parts[1])";
                    debug("Dropping non-email comment: %s", comment);
                }
            } else if (parts.size == 1) {
                throw new IOError.INVALID_ARGUMENT(_("Invalid SSH public key format. Key appears to be incomplete."));
            } else {
                final_key = cleaned_key;
            }

            debug("=== AWS Key Upload Debug ===");
            debug("Original key length: %d, Parts count: %d", public_key.length, parts.size);
            debug("Key type: %s, Key data length: %d", parts[0], parts[1].length);
            if (parts.size >= 3) {
                debug("Comment: %s", parts[2]);
            }
            debug("Final key length: %d", final_key.length);
            // Show first 80 chars to see the format
            debug("Final key preview: %s...", final_key.substring(0, int.min(80, final_key.length)));

            try {
                var params = new Gee.HashMap<string, string>();
                params["Action"] = "UploadSSHPublicKey";
                params["UserName"] = username;
                params["SSHPublicKeyBody"] = final_key;
                params["Version"] = API_VERSION;

                debug("Sending AWS request with key type: %s", parts[0]);
                yield make_aws_request("POST", "/", params, "");

            } catch (Error e) {
                throw_aws_error(e.message);
            }
        }

        /**
         * Remove an SSH key from AWS IAM
         */
        public async void remove_key(string key_id) throws Error {
            if (!is_authenticated()) {
                throw new IOError.NOT_CONNECTED(_("Not authenticated with AWS"));
            }

            try {
                var params = new Gee.HashMap<string, string>();
                params["Action"] = "DeleteSSHPublicKey";
                params["UserName"] = username;
                params["SSHPublicKeyId"] = key_id;
                params["Version"] = API_VERSION;

                yield make_aws_request("POST", "/", params, "");

            } catch (Error e) {
                throw_aws_error(e.message);
            }
        }

        /**
         * Check if authenticated
         */
        public bool is_authenticated() {
            if (access_key_id == null || secret_access_key == null || username == null) {
                // Try to load from storage
                try {
                    load_credentials.begin((obj, res) => {
                        try {
                            load_credentials.end(res);
                        } catch (Error e) {
                            // Ignore errors during load
                        }
                    });
                } catch (Error e) {
                    return false;
                }
            }

            return access_key_id != null && secret_access_key != null && username != null;
        }

        /**
         * Get provider display name
         */
        public string get_provider_name() {
            return _("AWS IAM");
        }

        /**
         * Disconnect and clear credentials
         */
        public async void disconnect() throws Error {
            try {
                // Clear from Secret Service
                if (access_key_id != null) {
                    yield token_storage.delete_token(SECRET_SERVICE_ACCESS_KEY_ID, access_key_id);
                    yield token_storage.delete_token(SECRET_SERVICE_SECRET_ACCESS_KEY, access_key_id);
                }

                // Clear from memory (security best practice)
                access_key_id = null;
                secret_access_key = null;
                username = null;

                // Clear from settings
                settings.set_boolean("cloud-provider-aws-connected", false);
                settings.set_string("cloud-provider-aws-username", "");
                settings.set_string("cloud-provider-aws-access-key-id", "");

            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to disconnect: $(e.message)");
            }
        }

        /**
         * Load credentials from Secret Service (used for auto-connect)
         */
        public async bool load_stored_credentials(string stored_username) throws Error {
            this.username = stored_username;

            // Load region from settings
            region = settings.get_string("cloud-provider-aws-region");
            if (region.length == 0) {
                region = "us-east-1";
            }

            yield load_credentials();

            return access_key_id != null && secret_access_key != null;
        }

        // Private helper methods

        /**
         * Make an AWS API request with Signature V4 authentication
         */
        private async string make_aws_request(
            string method,
            string path,
            Gee.Map<string, string> params,
            string payload
        ) throws Error {
            var timestamp = AWSRequestSigner.get_iso8601_timestamp();

            // For IAM API, parameters go in the POST body, not query string
            var body = AWSRequestSigner.build_query_string(params);

            // Sign the request (empty query string, body contains params)
            var authorization = AWSRequestSigner.sign_request(
                method,
                "iam.amazonaws.com",
                path,
                "", // Empty query string for IAM API
                body, // Body contains the form-encoded parameters
                access_key_id,
                secret_access_key,
                region,
                IAM_SERVICE,
                timestamp
            );

            // Build headers
            var headers = new Gee.HashMap<string, string>();
            headers["Authorization"] = authorization;
            headers["X-Amz-Date"] = timestamp;
            headers["Host"] = "iam.amazonaws.com";
            headers["Content-Type"] = "application/x-www-form-urlencoded";

            // Make request - parameters in body, not URL
            var url = IAM_ENDPOINT;

            debug("=== AWS Request ===");
            debug("URL: %s", url);
            debug("Method: %s", method);
            debug("Body: %s", body);
            debug("Headers:");
            foreach (var entry in headers.entries) {
                if (entry.key == "Authorization") {
                    debug("  %s: %s...", entry.key, entry.value.substring(0, 50));
                } else {
                    debug("  %s: %s", entry.key, entry.value);
                }
            }

            var response = yield http_client.post_form_with_body(url, body, headers);

            debug("=== AWS Response (first 500 chars) ===");
            debug("%s", response.length > 500 ? response.substring(0, 500) : response);

            // Check for AWS errors in response
            if (response.contains("<ErrorResponse>") || response.contains("<Error>")) {
                var error_code = extract_xml_value(response, "Code");
                var error_message = extract_xml_value(response, "Message");
                debug("AWS Error - Code: %s, Message: %s", error_code, error_message);
                throw new IOError.FAILED(@"AWS Error [$error_code]: $error_message");
            }

            return response;
        }

        /**
         * Store credentials in Secret Service
         */
        private async void store_credentials() throws Error {
            yield token_storage.store_token(SECRET_SERVICE_ACCESS_KEY_ID, access_key_id, access_key_id);
            yield token_storage.store_token(SECRET_SERVICE_SECRET_ACCESS_KEY, access_key_id, secret_access_key);
        }

        /**
         * Load credentials from Secret Service
         */
        private async void load_credentials() throws Error {
            // Load access key ID from settings
            var stored_username = settings.get_string("cloud-provider-aws-username");
            if (stored_username.length == 0) {
                throw new IOError.NOT_FOUND(_("No stored AWS credentials found"));
            }

            // Try to find the access key ID - we need to search for it
            // For now, we'll store the access key ID in settings as a workaround
            var stored_access_key_id = settings.get_string("cloud-provider-aws-access-key-id");
            if (stored_access_key_id.length == 0) {
                throw new IOError.NOT_FOUND(_("No stored AWS credentials found"));
            }

            access_key_id = stored_access_key_id;
            secret_access_key = yield token_storage.retrieve_token(SECRET_SERVICE_SECRET_ACCESS_KEY, access_key_id);
            username = stored_username;
        }

        // XML parsing helpers

        /**
         * Parse GetUser response to extract username
         */
        private string? parse_get_user_response(string xml) {
            return extract_xml_value(xml, "UserName");
        }

        /**
         * Parse ListSSHPublicKeys response to extract key IDs
         */
        private Gee.List<string> parse_list_ssh_public_keys_response(string xml) {
            var key_ids = new Gee.ArrayList<string>();

            // Simple XML parsing - extract all SSHPublicKeyId values
            var start_tag = "<SSHPublicKeyId>";
            var end_tag = "</SSHPublicKeyId>";

            int pos = 0;
            while ((pos = xml.index_of(start_tag, pos)) != -1) {
                pos += start_tag.length;
                int end_pos = xml.index_of(end_tag, pos);
                if (end_pos != -1) {
                    var key_id = xml.substring(pos, end_pos - pos);
                    key_ids.add(key_id);
                    pos = end_pos;
                }
            }

            return key_ids;
        }

        /**
         * Parse GetSSHPublicKey response to extract key metadata
         */
        private CloudKeyMetadata? parse_get_ssh_public_key_response(string xml) {
            var key_id = extract_xml_value(xml, "SSHPublicKeyId");
            var fingerprint = extract_xml_value(xml, "Fingerprint");
            var upload_date = extract_xml_value(xml, "UploadDate");
            var status = extract_xml_value(xml, "Status");
            var key_body = extract_xml_value(xml, "SSHPublicKeyBody");

            if (key_id == null) {
                return null;
            }

            // Parse upload date if available
            DateTime? created = null;
            if (upload_date != null && upload_date.length > 0) {
                // AWS format: 2025-01-15T12:34:56Z
                var time_val = new TimeVal();
                if (time_val.from_iso8601(upload_date)) {
                    created = new DateTime.from_unix_utc(time_val.tv_sec);
                }
            }

            var title = @"AWS IAM Key";
            if (status != null && status.length > 0) {
                title = @"AWS IAM Key ($status)";
            }

            var metadata = new CloudKeyMetadata.full(
                key_id,
                title,
                fingerprint,
                null, // key_type - not provided by AWS IAM API
                created,
                null  // last_used - not provided by AWS IAM API
            );

            return metadata;
        }

        /**
         * Extract value from XML tag
         */
        private string? extract_xml_value(string xml, string tag_name) {
            var start_tag = @"<$tag_name>";
            var end_tag = @"</$tag_name>";

            int start_pos = xml.index_of(start_tag);
            if (start_pos == -1) {
                return null;
            }

            start_pos += start_tag.length;
            int end_pos = xml.index_of(end_tag, start_pos);
            if (end_pos == -1) {
                return null;
            }

            return xml.substring(start_pos, end_pos - start_pos);
        }

        /**
         * Throw user-friendly AWS error
         */
        private void throw_aws_error(string error_message) throws Error {
            if (error_message.contains("AccessDenied")) {
                throw new IOError.PERMISSION_DENIED(_("Access denied. Ensure your IAM user has the required permissions (iam:ListSSHPublicKeys, iam:UploadSSHPublicKey, iam:DeleteSSHPublicKey, iam:GetSSHPublicKey)."));
            } else if (error_message.contains("InvalidClientTokenId")) {
                throw new IOError.INVALID_ARGUMENT(_("Invalid Access Key ID. Please check your credentials."));
            } else if (error_message.contains("SignatureDoesNotMatch")) {
                throw new IOError.INVALID_ARGUMENT(_("Invalid Secret Access Key. Please check your credentials."));
            } else if (error_message.contains("NoSuchEntity")) {
                throw new IOError.NOT_FOUND(_("User or key not found."));
            } else if (error_message.contains("LimitExceeded")) {
                throw new IOError.FAILED(_("AWS limit reached (5 keys maximum). Delete a key to upload a new one."));
            } else {
                throw new IOError.FAILED(error_message);
            }
        }
    }
}
