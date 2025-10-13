/* CloudProviderType.vala
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
     * Enumeration of supported cloud providers
     */
    public enum CloudProviderType {
        GITHUB,
        GITLAB,
        BITBUCKET,
        AWS,
        AZURE,
        GCP;

        public string to_string() {
            switch (this) {
                case GITHUB:
                    return "github";
                case GITLAB:
                    return "gitlab";
                case BITBUCKET:
                    return "bitbucket";
                case AWS:
                    return "aws";
                case AZURE:
                    return "azure";
                case GCP:
                    return "gcp";
                default:
                    return "unknown";
            }
        }

        public static CloudProviderType? from_string(string str) {
            switch (str.down()) {
                case "github":
                    return GITHUB;
                case "gitlab":
                    return GITLAB;
                case "bitbucket":
                    return BITBUCKET;
                case "aws":
                    return AWS;
                case "azure":
                    return AZURE;
                case "gcp":
                    return GCP;
                default:
                    return null;
            }
        }
    }
}
