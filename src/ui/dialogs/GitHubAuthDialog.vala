/* GitHubAuthDialog.vala
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

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/github_auth_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/github_auth_dialog.ui")]
#endif
public class KeyMaker.GitHubAuthDialog : Adw.Window {
    [GtkChild]
    private unowned Adw.StatusPage status_page;

    [GtkChild]
    private unowned Gtk.Spinner auth_spinner;

    [GtkChild]
    private unowned Gtk.Label status_label;

    [GtkChild]
    private unowned Gtk.Button cancel_button;

    private GitHubProvider provider;
    private bool cancelled = false;

    public signal void authentication_completed(bool success, string? error);

    public GitHubAuthDialog(Gtk.Window parent, GitHubProvider provider) {
        Object(transient_for: parent);
        this.provider = provider;

        cancel_button.clicked.connect(() => {
            cancelled = true;
            authentication_completed(false, "Cancelled by user");
            close();
        });
    }

    public async bool authenticate() {
        try {
            status_label.label = _("Opening browser...");

            if (yield provider.authenticate()) {
                status_page.icon_name = "emblem-ok-symbolic";
                status_page.title = _("Authentication Successful");
                status_label.label = _("You can close this window");
                auth_spinner.spinning = false;
                cancel_button.label = _("Close");

                authentication_completed(true, null);
                return true;
            } else {
                show_error(_("Authentication failed"));
                return false;
            }
        } catch (Error e) {
            if (!cancelled) {
                show_error(e.message);
            }
            return false;
        }
    }

    private void show_error(string message) {
        status_page.icon_name = "dialog-error-symbolic";
        status_page.title = _("Authentication Failed");
        status_label.label = message;
        auth_spinner.spinning = false;
        cancel_button.label = _("Close");

        authentication_completed(false, message);
    }
}
