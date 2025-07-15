"""Password input dialog for SSH authentication."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Adw, GObject, Gtk


class PasswordDialog(Adw.MessageDialog):
    """Dialog for entering SSH password."""

    __gtype_name__ = 'PasswordDialog'

    # Define signals
    __gsignals__ = {
        'password-entered': (GObject.SignalFlags.RUN_FIRST, None, (str,)),
        'password-cancelled': (GObject.SignalFlags.RUN_FIRST, None, ()),
    }

    def __init__(self, parent: Gtk.Window, hostname: str, username: str, **kwargs):
        """Initialize the password dialog.

        Args:
            parent: Parent window
            hostname: Remote hostname
            username: Username for authentication
            **kwargs: Additional dialog arguments
        """
        super().__init__(
            transient_for=parent,
            heading="SSH Password Required",
            body=f"Enter password for {username}@{hostname}:",
            **kwargs
        )

        self.hostname = hostname
        self.username = username

        # Create password entry row
        self.password_entry = Adw.PasswordEntryRow()
        self.password_entry.set_title("Password")
        self.password_entry.set_activates_default(True)
        self.password_entry.connect("activate", self._on_password_activate)

        # Create preferences group
        preferences_group = Adw.PreferencesGroup()
        preferences_group.add(self.password_entry)

        # Create content area
        content_area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        content_area.set_margin_top(12)
        content_area.set_margin_bottom(12)
        content_area.set_margin_start(12)
        content_area.set_margin_end(12)
        content_area.append(preferences_group)

        # Set extra child
        self.set_extra_child(content_area)

        # Add responses
        self.add_response("cancel", "Cancel")
        self.add_response("ok", "OK")
        self.set_default_response("ok")
        self.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED)

        # Connect response signal
        self.connect("response", self._on_response)

        # Focus password entry
        self.password_entry.grab_focus()

    def _on_password_activate(self, entry: Gtk.PasswordEntry):
        """Handle password entry activation (Enter key)."""
        self.response("ok")

    def _on_response(self, dialog: Adw.MessageDialog, response: str):
        """Handle dialog response.

        Args:
            dialog: The dialog instance
            response: Response ID
        """
        if response == "ok":
            password = self.password_entry.get_text()
            if password.strip():
                self.emit("password-entered", password)
            else:
                # Don't close dialog if password is empty
                return
        elif response == "cancel":
            self.emit("password-cancelled")

        self.close()

    def get_password(self) -> str:
        """Get the entered password.

        Returns:
            The password entered by the user
        """
        return self.password_entry.get_text()