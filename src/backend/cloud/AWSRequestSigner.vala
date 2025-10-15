/* AWSRequestSigner.vala
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
     * AWS Signature Version 4 request signer
     *
     * This class implements the AWS Signature Version 4 signing algorithm
     * used for authenticating requests to AWS services.
     */
    public class AWSRequestSigner : Object {
        private const string ALGORITHM = "AWS4-HMAC-SHA256";
        private const string AWS4_REQUEST = "aws4_request";

        /**
         * Sign an AWS API request using Signature Version 4
         *
         * @param method HTTP method (e.g., "POST", "GET")
         * @param host AWS service host (e.g., "iam.amazonaws.com")
         * @param uri Request URI path (e.g., "/")
         * @param query_string URL-encoded query string (e.g., "Action=ListUsers&Version=2010-05-08")
         * @param payload Request body
         * @param access_key_id AWS Access Key ID
         * @param secret_access_key AWS Secret Access Key
         * @param region AWS region (e.g., "us-east-1")
         * @param service AWS service name (e.g., "iam")
         * @param timestamp ISO8601 timestamp (e.g., "20250101T120000Z")
         * @return Authorization header value
         */
        public static string sign_request(
            string method,
            string host,
            string uri,
            string query_string,
            string payload,
            string access_key_id,
            string secret_access_key,
            string region,
            string service,
            string timestamp
        ) {
            // Extract date from timestamp (YYYYMMDD)
            var date = timestamp.substring(0, 8);

            // Step 1: Create canonical request
            var canonical_request = create_canonical_request(
                method,
                uri,
                query_string,
                host,
                timestamp,
                payload
            );

            // Step 2: Create string to sign
            var credential_scope = @"$date/$region/$service/$AWS4_REQUEST";
            var hashed_canonical_request = sha256_hex(canonical_request);
            var string_to_sign = @"$ALGORITHM\n$timestamp\n$credential_scope\n$hashed_canonical_request";

            // Step 3: Calculate signing key
            var signing_key = get_signature_key(secret_access_key, date, region, service);

            // Step 4: Calculate signature
            var signature = hmac_sha256_hex(signing_key, string_to_sign);

            // Step 5: Create authorization header
            var signed_headers = "content-type;host;x-amz-date";
            var authorization = @"$ALGORITHM Credential=$access_key_id/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature";

            debug("String to Sign: %s", string_to_sign.replace("\n", "\\n"));
            debug("Signature: %s", signature);
            debug("Authorization: %s", authorization);

            return authorization;
        }

        /**
         * Create canonical request string
         */
        private static string create_canonical_request(
            string method,
            string uri,
            string query_string,
            string host,
            string timestamp,
            string payload
        ) {
            // Canonical headers must be sorted alphabetically
            var canonical_headers = @"content-type:application/x-www-form-urlencoded\nhost:$host\nx-amz-date:$timestamp\n";
            var signed_headers = "content-type;host;x-amz-date";
            var payload_hash = sha256_hex(payload);

            var canonical_request = @"$method\n$uri\n$query_string\n$canonical_headers\n$signed_headers\n$payload_hash";

            // Debug logging
            debug("=== AWS Signature Debug ===");
            debug("Method: %s", method);
            debug("URI: %s", uri);
            debug("Query String: %s", query_string);
            debug("Canonical Headers: %s", canonical_headers.replace("\n", "\\n"));
            debug("Signed Headers: %s", signed_headers);
            debug("Payload: %s", payload);
            debug("Payload Hash: %s", payload_hash);
            debug("Canonical Request: %s", canonical_request.replace("\n", "\\n"));

            return canonical_request;
        }

        /**
         * Derive signing key using HMAC chain
         */
        private static uint8[] get_signature_key(string key, string date, string region, string service) {
            var k_date = hmac_sha256(("AWS4" + key).data, date.data);
            var k_region = hmac_sha256(k_date, region.data);
            var k_service = hmac_sha256(k_region, service.data);
            var k_signing = hmac_sha256(k_service, AWS4_REQUEST.data);
            return k_signing;
        }

        /**
         * Compute HMAC-SHA256
         */
        private static uint8[] hmac_sha256(uint8[] key, uint8[] data) {
            var hmac = new Hmac(ChecksumType.SHA256, key);
            hmac.update(data);

            uint8[] buffer = new uint8[32]; // SHA256 produces 32 bytes
            size_t digest_len = 32;
            hmac.get_digest(buffer, ref digest_len);

            return buffer[0:digest_len];
        }

        /**
         * Compute HMAC-SHA256 and return hex string
         */
        private static string hmac_sha256_hex(uint8[] key, string data) {
            var digest = hmac_sha256(key, data.data);
            return bytes_to_hex(digest);
        }

        /**
         * Compute SHA256 hash and return hex string
         */
        private static string sha256_hex(string data) {
            var checksum = new Checksum(ChecksumType.SHA256);
            checksum.update(data.data, data.length);
            return checksum.get_string();
        }

        /**
         * Convert byte array to hex string
         */
        private static string bytes_to_hex(uint8[] bytes) {
            var builder = new StringBuilder();
            foreach (var b in bytes) {
                builder.append_printf("%02x", b);
            }
            return builder.str;
        }

        /**
         * Generate ISO8601 timestamp for AWS requests
         *
         * @return timestamp in format "YYYYMMDDTHHmmssZ"
         */
        public static string get_iso8601_timestamp() {
            var now = new DateTime.now_utc();
            return now.format("%Y%m%dT%H%M%SZ");
        }

        /**
         * URL-encode a string for AWS parameters
         *
         * AWS uses RFC 3986 encoding (stricter than standard URL encoding)
         */
        public static string url_encode(string input) {
            var builder = new StringBuilder();

            for (int i = 0; i < input.length; i++) {
                char c = input[i];

                // Unreserved characters (RFC 3986)
                if ((c >= 'A' && c <= 'Z') ||
                    (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9') ||
                    c == '-' || c == '_' || c == '.' || c == '~') {
                    builder.append_c(c);
                } else {
                    // Percent-encode everything else
                    builder.append_printf("%%%02X", (uint8)c);
                }
            }

            return builder.str;
        }

        /**
         * Build query string from parameter map
         *
         * @param params Map of parameter names to values
         * @return URL-encoded query string sorted by parameter name
         */
        public static string build_query_string(Gee.Map<string, string> params) {
            var sorted_keys = new Gee.ArrayList<string>();
            sorted_keys.add_all(params.keys);
            sorted_keys.sort();

            var builder = new StringBuilder();
            bool first = true;

            foreach (var key in sorted_keys) {
                if (!first) {
                    builder.append_c('&');
                }
                first = false;

                builder.append(url_encode(key));
                builder.append_c('=');
                builder.append(url_encode(params[key]));
            }

            return builder.str;
        }
    }
}
