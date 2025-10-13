/* TokenStorage.vala
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
     * Secure token storage using GNOME Secret Service
     */
    public class TokenStorage : Object {
        private static Secret.Schema? _schema = null;

        private static Secret.Schema get_schema() {
            if (_schema == null) {
                _schema = new Secret.Schema(
                    "io.github.tobagin.keysmith.cloud-token",
                    Secret.SchemaFlags.NONE,
                    "service", Secret.SchemaAttributeType.STRING,
                    "account", Secret.SchemaAttributeType.STRING
                );
            }
            return _schema;
        }

        /**
         * Store a token for a cloud provider
         */
        public static async bool store_token(string provider, string username, string token) throws Error {
            var label = @"KeyMaker $provider Token for $username";
            var attributes = new HashTable<string, string>(str_hash, str_equal);
            attributes["service"] = @"keymaker-$provider";
            attributes["account"] = username;

            try {
                yield Secret.password_storev(
                    get_schema(),
                    attributes,
                    Secret.COLLECTION_DEFAULT,
                    label,
                    token,
                    null
                );
                return true;
            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to store token: $(e.message)");
            }
        }

        /**
         * Retrieve a token for a cloud provider
         */
        public static async string? retrieve_token(string provider, string username) throws Error {
            var attributes = new HashTable<string, string>(str_hash, str_equal);
            attributes["service"] = @"keymaker-$provider";
            attributes["account"] = username;

            try {
                return yield Secret.password_lookupv(get_schema(), attributes, null);
            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to retrieve token: $(e.message)");
            }
        }

        /**
         * Delete a token for a cloud provider
         */
        public static async bool delete_token(string provider, string username) throws Error {
            var attributes = new HashTable<string, string>(str_hash, str_equal);
            attributes["service"] = @"keymaker-$provider";
            attributes["account"] = username;

            try {
                return yield Secret.password_clearv(get_schema(), attributes, null);
            } catch (Error e) {
                throw new IOError.FAILED(@"Failed to delete token: $(e.message)");
            }
        }
    }
}
