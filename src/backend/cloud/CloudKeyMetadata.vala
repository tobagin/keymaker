/* CloudKeyMetadata.vala
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
     * Metadata for an SSH key stored on a cloud provider
     */
    public class CloudKeyMetadata : Object {
        public string id { get; set; }
        public string title { get; set; }
        public string? fingerprint { get; set; }
        public string? key_type { get; set; }
        public DateTime? created_at { get; set; }
        public DateTime? last_used { get; set; }

        public CloudKeyMetadata(string id, string title) {
            this.id = id;
            this.title = title;
        }

        public CloudKeyMetadata.full(
            string id,
            string title,
            string? fingerprint,
            string? key_type,
            DateTime? created_at = null,
            DateTime? last_used = null
        ) {
            this.id = id;
            this.title = title;
            this.fingerprint = fingerprint;
            this.key_type = key_type;
            this.created_at = created_at;
            this.last_used = last_used;
        }

        /**
         * Get a human-readable representation of the last used time
         */
        public string get_last_used_display() {
            if (last_used == null) {
                return _("Never used");
            }

            var now = new DateTime.now_local();
            var diff = now.difference(last_used);
            var days = (int)(diff / GLib.TimeSpan.DAY);
            var hours = (int)(diff / GLib.TimeSpan.HOUR);
            var minutes = (int)(diff / GLib.TimeSpan.MINUTE);

            if (days > 0) {
                return ngettext("%d day ago", "%d days ago", days).printf(days);
            } else if (hours > 0) {
                return ngettext("%d hour ago", "%d hours ago", hours).printf(hours);
            } else if (minutes > 0) {
                return ngettext("%d minute ago", "%d minutes ago", minutes).printf(minutes);
            } else {
                return _("Just now");
            }
        }
    }
}
