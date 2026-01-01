/* GCPOAuthServer.vala
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
     * Local HTTP server for GCP OAuth callback
     */
    public class GCPOAuthServer : Object {
        private Soup.Server? server = null;
        private string? authorization_code = null;
        private string? error_message = null;
        private bool callback_received = false;
        private const int PORT = 8765;
        private const int TIMEOUT_SECONDS = 60;
        private uint timeout_id = 0;

        public signal void callback_completed(string? code, string? error);

        /**
         * Start the OAuth callback server
         */
        public async bool start() throws Error {
            try {
                server = new Soup.Server("server-header", "KeyMaker-OAuth/1.0", null);
                server.add_handler("/callback", handle_callback);

                // Bind to all interfaces so browser outside Flatpak can connect
                if (!server.listen_all(PORT, 0)) {
                    throw new IOError.FAILED(@"Failed to bind to port $PORT");
                }

                // Set timeout
                timeout_id = Timeout.add_seconds(TIMEOUT_SECONDS, () => {
                    if (!callback_received) {
                        error_message = "OAuth timeout: No response received";
                        callback_completed(null, error_message);
                        stop();
                    }
                    timeout_id = 0;
                    return Source.REMOVE;
                });

                return true;
            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to start OAuth server: $(e.message)");
            }
        }

        /**
         * Stop the OAuth callback server
         */
        public void stop() {
            if (timeout_id != 0) {
                Source.remove(timeout_id);
                timeout_id = 0;
            }

            if (server != null) {
                server.disconnect();
                server = null;
            }
        }

        /**
         * Wait for OAuth callback
         */
        public async string? wait_for_code() throws Error {
            // Use a simple yield mechanism
            string? result_code = null;
            string? result_error = null;

            ulong handler_id = callback_completed.connect((code, error) => {
                result_code = code;
                result_error = error;
                // Resume the async function
                Idle.add(wait_for_code.callback);
            });

            // Yield and wait for signal
            yield;

            // Disconnect handler
            disconnect(handler_id);

            if (result_error != null) {
                throw new IOError.FAILED(result_error);
            }

            return result_code;
        }

        /**
         * Handle OAuth callback
         */
        private void handle_callback(Soup.Server server, Soup.ServerMessage msg, string path, GLib.HashTable? query) {
            if (callback_received) {
                send_html_response(msg, 200, "Already processed. You can close this window.");
                return;
            }

            callback_received = true;

            // Extract code or error from query parameters
            var uri = msg.get_uri();
            var params = Soup.Form.decode(uri.get_query() ?? "");

            if (params.contains("error")) {
                error_message = params.get("error");
                send_html_response(msg, 400, @"<h1>Authentication Failed</h1><p>Error: $error_message</p>");
                callback_completed(null, error_message);
            } else if (params.contains("code")) {
                authorization_code = params.get("code");
                send_html_response(msg, 200, "<h1>Success!</h1><p>You can close this window and return to the application.</p>");
                callback_completed(authorization_code, null);
            } else {
                error_message = "Invalid callback: no code or error received";
                send_html_response(msg, 400, "<h1>Invalid Request</h1>");
                callback_completed(null, error_message);
            }

            // Stop server after handling callback
            Idle.add(() => {
                stop();
                return Source.REMOVE;
            });
        }

        /**
         * Send HTML response to browser
         */
        private void send_html_response(Soup.ServerMessage msg, uint status, string body_text) {
            var html = @"<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <title>GCP OAuth - KeyMaker</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 600px;
            margin: 100px auto;
            padding: 20px;
            text-align: center;
        }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    $body_text
    <p><small>This window can be closed.</small></p>
</body>
</html>";

            msg.set_status(status, null);
            msg.set_response("text/html", Soup.MemoryUse.COPY, html.data);
        }
    }
}
