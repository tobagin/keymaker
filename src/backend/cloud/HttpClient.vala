/* HttpClient.vala
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
     * HTTP client wrapper around libsoup for cloud provider API calls
     */
    public class HttpClient : Object {
        private Soup.Session session;
        private const int TIMEOUT_SECONDS = 30;

        public HttpClient() {
            session = new Soup.Session();
            session.timeout = TIMEOUT_SECONDS;
            session.user_agent = @"KeyMaker/$(Config.VERSION)";
        }

        /**
         * Make an async GET request
         */
        public async string get(string url, Gee.Map<string, string>? headers = null) throws Error {
            var message = new Soup.Message("GET", url);
            add_headers(message, headers);

            try {
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                var response = (string) bytes.get_data();
                check_status_code(message, response);
                return response;
            } catch (Error e) {
                throw new IOError.FAILED("GET request failed: %s".printf(e.message));
            }
        }

        /**
         * Make an async POST request
         */
        public async string post(string url, string? body = null, Gee.Map<string, string>? headers = null) throws Error {
            var message = new Soup.Message("POST", url);
            add_headers(message, headers);

            if (body != null) {
                message.set_request_body_from_bytes("application/json", new Bytes(body.data));
            }

            try {
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                var response = (string) bytes.get_data();
                check_status_code(message, response);
                return response;
            } catch (Error e) {
                throw new IOError.FAILED("POST request failed: %s".printf(e.message));
            }
        }

        /**
         * Make an async DELETE request
         */
        public async string delete(string url, Gee.Map<string, string>? headers = null) throws Error {
            var message = new Soup.Message("DELETE", url);
            add_headers(message, headers);

            try {
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                var response = (string) bytes.get_data();
                check_status_code(message, response);
                return response;
            } catch (Error e) {
                throw new IOError.FAILED("DELETE request failed: %s".printf(e.message));
            }
        }

        /**
         * Make an async POST request with form data
         */
        public async string post_form(string url, Gee.Map<string, string> form_data, Gee.Map<string, string>? headers = null) throws Error {
            var message = new Soup.Message("POST", url);

            var form_headers = headers ?? new Gee.HashMap<string, string>();
            form_headers["Content-Type"] = "application/x-www-form-urlencoded";
            add_headers(message, form_headers);

            var form_string = encode_form_data(form_data);
            message.set_request_body_from_bytes("application/x-www-form-urlencoded", new Bytes(form_string.data));

            try {
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                var response = (string) bytes.get_data();
                check_status_code(message, response);
                return response;
            } catch (Error e) {
                throw new IOError.FAILED("POST form request failed: %s".printf(e.message));
            }
        }

        /**
         * Make an async POST request with custom body and headers (for AWS)
         */
        public async string post_form_with_body(string url, string body, Gee.Map<string, string>? headers = null) throws Error {
            var message = new Soup.Message("POST", url);
            add_headers(message, headers);

            if (body.length > 0) {
                message.set_request_body_from_bytes("application/x-www-form-urlencoded", new Bytes(body.data));
            }

            try {
                var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
                var response = (string) bytes.get_data();
                check_status_code(message, response);
                return response;
            } catch (Error e) {
                throw new IOError.FAILED("POST request failed: %s".printf(e.message));
            }
        }

        private void add_headers(Soup.Message message, Gee.Map<string, string>? headers) {
            if (headers != null) {
                foreach (var entry in headers.entries) {
                    message.request_headers.append(entry.key, entry.value);
                }
            }
        }

        private void check_status_code(Soup.Message message, string response_body = "") throws Error {
            var status = message.status_code;
            if (status < 200 || status >= 300) {
                var reason = message.reason_phrase ?? "Unknown error";
                var url = message.get_uri().to_string();

                // Truncate response body if too long
                var truncated_body = response_body;
                if (truncated_body.length > 200) {
                    truncated_body = truncated_body.substring(0, 200) + "...";
                }

                warning(@"HTTP $status error for $(message.method) $url: $reason");
                if (truncated_body.length > 0) {
                    warning(@"Response body: $truncated_body");
                }

                throw new IOError.FAILED(@"HTTP $status: $reason");
            }
        }

        private string encode_form_data(Gee.Map<string, string> data) {
            var parts = new Gee.ArrayList<string>();
            foreach (var entry in data.entries) {
                var key = Uri.escape_string(entry.key, null, true);
                var val = Uri.escape_string(entry.value, null, true);
                parts.add(@"$key=$val");
            }
            return string.joinv("&", parts.to_array());
        }
    }
}
