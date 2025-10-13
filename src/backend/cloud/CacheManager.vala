/* CacheManager.vala
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
     * Manager for caching cloud provider key metadata
     */
    public class CacheManager : Object {
        private Settings settings;
        private const int CACHE_EXPIRY_HOURS = 24;

        public CacheManager() {
            settings = SettingsManager.app;
        }

        /**
         * Cache key list for a provider
         */
        public void cache_keys(string provider, Gee.List<CloudKeyMetadata> keys) {
            var cache_json = settings.get_string("cloud-provider-cache");
            Json.Parser parser = new Json.Parser();

            Json.Node root_node;
            try {
                parser.load_from_data(cache_json);
                root_node = parser.get_root();
            } catch (Error e) {
                root_node = new Json.Node(Json.NodeType.OBJECT);
                root_node.set_object(new Json.Object());
            }

            var root = root_node.get_object();

            // Create provider cache object
            var provider_cache = new Json.Object();
            provider_cache.set_string_member("timestamp", new DateTime.now_utc().to_string());

            var keys_array = new Json.Array();
            foreach (var key in keys) {
                var key_obj = new Json.Object();
                key_obj.set_string_member("id", key.id);
                key_obj.set_string_member("title", key.title);
                if (key.fingerprint != null)
                    key_obj.set_string_member("fingerprint", key.fingerprint);
                if (key.key_type != null)
                    key_obj.set_string_member("key_type", key.key_type);
                if (key.created_at != null)
                    key_obj.set_string_member("created_at", key.created_at.to_string());
                if (key.last_used != null)
                    key_obj.set_string_member("last_used", key.last_used.to_string());

                keys_array.add_object_element(key_obj);
            }
            provider_cache.set_array_member("keys", keys_array);

            root.set_object_member(provider, provider_cache);

            var generator = new Json.Generator();
            generator.set_root(root_node);
            settings.set_string("cloud-provider-cache", generator.to_data(null));
        }

        /**
         * Retrieve cached keys for a provider
         */
        public Gee.List<CloudKeyMetadata>? get_cached_keys(string provider) {
            var cache_json = settings.get_string("cloud-provider-cache");

            try {
                var parser = new Json.Parser();
                parser.load_from_data(cache_json);
                var root = parser.get_root().get_object();

                if (!root.has_member(provider))
                    return null;

                var provider_cache = root.get_object_member(provider);
                var timestamp_str = provider_cache.get_string_member("timestamp");
                var timestamp = new DateTime.from_iso8601(timestamp_str, null);

                // Check if cache is expired
                var now = new DateTime.now_utc();
                var diff = now.difference(timestamp);
                if (diff > CACHE_EXPIRY_HOURS * TimeSpan.HOUR) {
                    return null;
                }

                var keys_array = provider_cache.get_array_member("keys");
                var keys = new Gee.ArrayList<CloudKeyMetadata>();

                keys_array.foreach_element((arr, index, node) => {
                    var obj = node.get_object();
                    var key = new CloudKeyMetadata(
                        obj.get_string_member("id"),
                        obj.get_string_member("title")
                    );

                    if (obj.has_member("fingerprint"))
                        key.fingerprint = obj.get_string_member("fingerprint");
                    if (obj.has_member("key_type"))
                        key.key_type = obj.get_string_member("key_type");
                    if (obj.has_member("created_at"))
                        key.created_at = new DateTime.from_iso8601(obj.get_string_member("created_at"), null);
                    if (obj.has_member("last_used"))
                        key.last_used = new DateTime.from_iso8601(obj.get_string_member("last_used"), null);

                    keys.add(key);
                });

                return keys;
            } catch (Error e) {
                warning(@"Failed to retrieve cached keys: $(e.message)");
                return null;
            }
        }

        /**
         * Clear cache for a provider
         */
        public void clear_cache(string provider) {
            var cache_json = settings.get_string("cloud-provider-cache");

            try {
                var parser = new Json.Parser();
                parser.load_from_data(cache_json);
                var root = parser.get_root().get_object();

                if (root.has_member(provider)) {
                    root.remove_member(provider);

                    var generator = new Json.Generator();
                    generator.set_root(parser.get_root());
                    settings.set_string("cloud-provider-cache", generator.to_data(null));
                }
            } catch (Error e) {
                warning(@"Failed to clear cache: $(e.message)");
            }
        }
    }
}
