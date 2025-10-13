/* CloudProvider.vala
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
     * Interface for cloud provider implementations
     *
     * This interface defines the contract that all cloud providers must implement
     * to support SSH key management operations.
     */
    public interface CloudProvider : Object {
        /**
         * The type of this cloud provider
         */
        public abstract CloudProviderType provider_type { get; }

        /**
         * Authenticate with the cloud provider
         *
         * This may launch an OAuth flow, prompt for credentials, or validate
         * existing stored credentials.
         *
         * @return true if authentication succeeded
         * @throws Error if authentication fails
         */
        public abstract async bool authenticate() throws Error;

        /**
         * List all SSH keys for the authenticated user
         *
         * @return list of CloudKeyMetadata objects
         * @throws Error if the API call fails or user is not authenticated
         */
        public abstract async Gee.List<CloudKeyMetadata> list_keys() throws Error;

        /**
         * Deploy a public SSH key to the cloud provider
         *
         * @param public_key the SSH public key content (e.g., "ssh-rsa AAA...")
         * @param title the title/label for the key
         * @throws Error if deployment fails
         */
        public abstract async void deploy_key(string public_key, string title) throws Error;

        /**
         * Remove an SSH key from the cloud provider
         *
         * @param key_id the provider-specific key identifier
         * @throws Error if removal fails
         */
        public abstract async void remove_key(string key_id) throws Error;

        /**
         * Check if the user is currently authenticated
         *
         * @return true if authenticated
         */
        public abstract bool is_authenticated();

        /**
         * Get the display name of this provider
         *
         * @return the provider name (e.g., "GitHub", "GitLab")
         */
        public abstract string get_provider_name();

        /**
         * Disconnect from the provider (clear stored credentials)
         */
        public abstract async void disconnect() throws Error;
    }
}
