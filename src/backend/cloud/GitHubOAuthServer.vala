/* GitHubOAuthServer.vala
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
     * Local HTTP server for OAuth callback
     */
    public class GitHubOAuthServer : Object {
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

                // Bind to localhost only for security
                if (!server.listen_local(PORT, Soup.ServerListenOptions.IPV4_ONLY)) {
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
            // Create a main loop to wait for the callback
            var loop = new MainLoop();
            string? result_code = null;
            string? result_error = null;

            callback_completed.connect((code, error) => {
                result_code = code;
                result_error = error;
                loop.quit();
            });

            // Run the loop
            loop.run();

            if (result_error != null) {
                throw new IOError.FAILED(result_error);
            }

            return result_code;
        }

        private void handle_callback(Soup.Server server, Soup.ServerMessage msg, string path, GLib.HashTable<string, string>? query) {
            callback_received = true;

            if (query != null) {
                unowned string? code = query.lookup("code");
                unowned string? error = query.lookup("error");

                if (code != null) {
                    authorization_code = code;
                    send_success_response(msg);
                    callback_completed(authorization_code, null);
                } else if (error != null) {
                    error_message = @"OAuth error: $error";
                    send_error_response(msg, error_message);
                    callback_completed(null, error_message);
                } else {
                    error_message = "Invalid OAuth callback: missing code or error";
                    send_error_response(msg, error_message);
                    callback_completed(null, error_message);
                }
            } else {
                error_message = "Invalid OAuth callback: no query parameters";
                send_error_response(msg, error_message);
                callback_completed(null, error_message);
            }

            stop();
        }

        private void send_success_response(Soup.ServerMessage msg) {
            var html = """
                <!DOCTYPE html>
                <html>
                <head><title>Authentication Successful</title></head>
                <body style="font-family: sans-serif; text-align: center; padding: 50px;">
                    <h1>✓ Authentication Successful</h1>
                    <p>You can close this window and return to KeyMaker.</p>
                </body>
                </html>
            """;
            msg.set_response("text/html", Soup.MemoryUse.COPY, html.data);
            msg.set_status(200, "OK");
        }

        private void send_error_response(Soup.ServerMessage msg, string error) {
            var html = @"
                <!DOCTYPE html>
                <html>
                <head><title>Authentication Failed</title></head>
                <body style=\"font-family: sans-serif; text-align: center; padding: 50px;\">
                    <h1>✗ Authentication Failed</h1>
                    <p>$error</p>
                    <p>You can close this window and try again in KeyMaker.</p>
                </body>
                </html>
            ";
            msg.set_response("text/html", Soup.MemoryUse.COPY, html.data);
            msg.set_status(400, "Bad Request");
        }
    }
}
