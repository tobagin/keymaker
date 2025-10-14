/* EmptyStateRow.vala
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
    #if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/empty_state_row.ui")]
    #else
    [GtkTemplate (ui = "/io/github/tobagin/keysmith/empty_state_row.ui")]
    #endif
    public class EmptyStateRow : Adw.ActionRow {
        public EmptyStateRow() {
            Object();
        }
    }
}
