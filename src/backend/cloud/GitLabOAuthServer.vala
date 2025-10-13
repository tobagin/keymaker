/* GitLabOAuthServer.vala
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
     * Local HTTP server for GitLab OAuth callback
     */
    public class GitLabOAuthServer : Object {
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
                // Using listen_all to bind to 0.0.0.0
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

            // Disconnect signal handler
            disconnect(handler_id);

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

            // Delay server stop to allow response to be sent
            Timeout.add(500, () => {
                stop();
                return Source.REMOVE;
            });
        }

        private void send_success_response(Soup.ServerMessage msg) {
            var html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <meta name="color-scheme" content="light dark">
                    <title>Authentication Successful - SSHer</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        @media (prefers-color-scheme: dark) {
                            body {
                                background: #1e1e1e;
                                color: #ffffff;
                            }
                            .container {
                                background: #2d2d2d;
                                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
                            }
                        }
                        @media (prefers-color-scheme: light) {
                            body {
                                background: #ffffff;
                                color: #1e1e1e;
                            }
                            .container {
                                background: #f5f5f5;
                                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                            }
                        }
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                            min-height: 100vh;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                        }
                        .container {
                            border-radius: 20px;
                            padding: 60px 40px;
                            text-align: center;
                            max-width: 500px;
                        }
                        .icon {
                            margin-bottom: 30px;
                            animation: scale-in 0.5s ease-out;
                        }
                        .icon svg {
                            width: 120px;
                            height: 120px;
                        }
                        h1 {
                            font-size: 32px;
                            margin-bottom: 20px;
                            font-weight: 600;
                        }
                        p {
                            font-size: 18px;
                            opacity: 0.8;
                            line-height: 1.6;
                            margin-bottom: 10px;
                        }
                        @keyframes scale-in {
                            from { transform: scale(0); opacity: 0; }
                            to { transform: scale(1); opacity: 1; }
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="icon">
                            <svg height="120" viewBox="0 -46 453 453" width="120" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="a" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#cce6ff"/><stop offset="1" stop-color="#1d98ff"/></linearGradient><linearGradient id="b" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#d0e4fc"/></linearGradient><linearGradient id="c" x1="0" x2="1" y1="0" y2="0"><stop offset="0" stop-color="#0084ff"/><stop offset="1" stop-color="#004fb8"/></linearGradient></defs><path d="M422.395 38.931c0-8.279-6.721-15-15-15h-371c-8.279 0-15 6.721-15 15v236c0 8.279 6.721 15 15 15h371c8.279 0 15-6.721 15-15v-236Z" fill="url(#a)"/><path d="M400.395 71.931h-358v189c0 6.071 4.929 11 11 11h339c4.415 0 8-3.585 8-8v-192Z" fill="url(#b)"/><circle cx="73.395" cy="46.931" r="8" fill="#0084ff"/><circle cx="50.395" cy="46.931" r="8" fill="#55d7ff"/><circle cx="96.395" cy="46.931" r="8" fill="#0bbc00"/><path d="M344.39 177.203c-22.213 0-40.283 18.07-40.282 40.283 0 15.173 8.545 28.988 21.973 35.846l.002 64.158c0 .972.385 1.902 1.073 2.59l14.649 14.65c1.432 1.431 3.748 1.431 5.179 0l14.649-14.649c.688-.688 1.072-1.618 1.072-2.589l-.003-7.326c0-1.118-.51-2.175-1.388-2.871l-4.39-3.479 4.938-5.966c1.123-1.355 1.123-3.313 0-4.668l-4.939-5.966 4.393-3.477c.829-.632 1.32-1.613 1.383-2.657.058-1.045-.329-2.064-1.067-2.802l-4.822-4.822 4.734-4.734c.688-.687 1.072-1.618 1.072-2.589l.087-13.194c13.428-6.852 21.978-20.275 21.972-35.453 0-22.213-18.072-40.284-40.285-40.285Zm10.986 28.637c0 6.059-4.925 10.985-10.985 10.985-6.059 0-10.985-4.926-10.985-10.985 0-6.059 4.926-10.985 10.985-10.985 6.059 0 10.985 4.927 10.985 10.985Z" fill="url(#c)"/><path d="M192.796 162.415c0-2.928-1.83-5.856-4.636-7.076l-44.042-19.764c-.61-.244-1.342-.366-1.952-.366-2.684 0-5.368 2.074-5.246 5.246 0 1.952 1.098 3.904 3.172 4.758l40.87 17.446-40.87 17.324c-1.952.854-3.05 2.684-3.05 4.758 0 3.05 2.562 5.124 5.124 5.124.61 0 1.342-.122 1.952-.366l44.042-19.642c2.806-1.22 4.636-4.148 4.636-7.442Z" fill="#00c400"/><path d="M265.508 213.411c0-2.806-2.318-5.124-5.002-5.124h-60.878c-2.806 0-5.124 2.318-5.124 5.124 0 2.928 2.318 5.246 5.124 5.246h60.878c2.684 0 5.002-2.318 5.002-5.246Z" fill="#00c400"/></svg>
                        </div>
                        <h1>Authentication Successful!</h1>
                        <p>You're all set!<br>You can close this window and return to SSHer.</p>
                    </div>
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
                <head>
                    <meta charset=\"utf-8\">
                    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
                    <meta name=\"color-scheme\" content=\"light dark\">
                    <title>Authentication Failed - SSHer</title>
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        @media (prefers-color-scheme: dark) {
                            body {
                                background: #1e1e1e;
                                color: #ffffff;
                            }
                            .container {
                                background: #2d2d2d;
                                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
                            }
                            .error-details {
                                background: rgba(0, 0, 0, 0.4);
                            }
                        }
                        @media (prefers-color-scheme: light) {
                            body {
                                background: #ffffff;
                                color: #1e1e1e;
                            }
                            .container {
                                background: #f5f5f5;
                                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                            }
                            .error-details {
                                background: rgba(0, 0, 0, 0.05);
                            }
                        }
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif;
                            min-height: 100vh;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                        }
                        .container {
                            border-radius: 20px;
                            padding: 60px 40px;
                            text-align: center;
                            max-width: 500px;
                        }
                        .icon {
                            font-size: 80px;
                            margin-bottom: 20px;
                            animation: shake 0.5s ease-out;
                            color: #ff4444;
                        }
                        h1 {
                            font-size: 32px;
                            margin-bottom: 20px;
                            font-weight: 600;
                            color: #ff4444;
                        }
                        p {
                            font-size: 18px;
                            opacity: 0.8;
                            line-height: 1.6;
                            margin-bottom: 10px;
                        }
                        .error-details {
                            padding: 15px;
                            border-radius: 10px;
                            font-family: monospace;
                            font-size: 14px;
                            margin-top: 20px;
                            word-break: break-word;
                        }
                        @keyframes shake {
                            0%, 100% { transform: translateX(0); }
                            25% { transform: translateX(-10px); }
                            75% { transform: translateX(10px); }
                        }
                    </style>
                </head>
                <body>
                    <div class=\"container\">
                        <div class=\"icon\">✗</div>
                        <h1>Authentication Failed</h1>
                        <p>We couldn't complete the authentication.</p>
                        <div class=\"error-details\">$error</div>
                        <p style=\"margin-top: 20px;\">Please close this window and try again in SSHer.</p>
                    </div>
                </body>
                </html>
            ";
            msg.set_response("text/html", Soup.MemoryUse.COPY, html.data);
            msg.set_status(400, "Bad Request");
        }
    }
}
