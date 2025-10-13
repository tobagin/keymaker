/* CloudProviderManager.vala
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
     * Singleton manager for cloud provider registry
     *
     * This class maintains a registry of available cloud providers and
     * provides factory methods to instantiate them.
     */
    public class CloudProviderManager : Object {
        private static CloudProviderManager? _instance = null;
        private Gee.HashMap<CloudProviderType, CloudProvider> providers;

        private CloudProviderManager() {
            providers = new Gee.HashMap<CloudProviderType, CloudProvider>();
        }

        /**
         * Get the singleton instance
         */
        public static CloudProviderManager get_instance() {
            if (_instance == null) {
                _instance = new CloudProviderManager();
            }
            return _instance;
        }

        /**
         * Register a cloud provider
         *
         * @param provider the provider to register
         */
        public void register_provider(CloudProvider provider) {
            providers[provider.provider_type] = provider;
        }

        /**
         * Get a provider by type
         *
         * @param type the provider type
         * @return the provider, or null if not registered
         */
        public CloudProvider? get_provider(CloudProviderType type) {
            return providers[type];
        }

        /**
         * Get all registered providers
         *
         * @return list of all providers
         */
        public Gee.List<CloudProvider> get_all_providers() {
            return new Gee.ArrayList<CloudProvider>.wrap(providers.values.to_array());
        }

        /**
         * Check if a provider is registered
         *
         * @param type the provider type
         * @return true if registered
         */
        public bool has_provider(CloudProviderType type) {
            return providers.has_key(type);
        }

        /**
         * Unregister a provider
         *
         * @param type the provider type to remove
         */
        public void unregister_provider(CloudProviderType type) {
            providers.unset(type);
        }
    }
}
