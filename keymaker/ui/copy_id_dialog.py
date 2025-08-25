"""Copy SSH key to server dialog."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

import asyncio
import threading

from gi.repository import Adw, GLib, GObject, Gtk

from ..backend import copy_id_to_server
from ..models import SSHCopyIDRequest, SSHKey, SSHOperationError
from .password_dialog import PasswordDialog


@Gtk.Template(resource_path='/io/github/tobagin/keymaker/ui/copy_id_dialog.ui')
class CopyIdDialog(Adw.Dialog):
    """Copy key to server dialog using Adwaita PreferencesDialog."""

    __gtype_name__ = 'CopyIdDialog'

    # Define signals
    __gsignals__ = {
        'key-copied': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    # Template child widgets
    hostname_row = Gtk.Template.Child()
    username_row = Gtk.Template.Child()
    port_row = Gtk.Template.Child()
    copy_button = Gtk.Template.Child()
    progress_box = Gtk.Template.Child()
    progress_spinner = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, ssh_key: SSHKey, **kwargs):
        """Initialize the copy ID dialog.

        Args:
            parent: Parent window
            ssh_key: SSH key to copy to server
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)

        self.ssh_key = ssh_key
        self._parent_window = parent
        self._copying = False
        self._password = None

        # Setup signals
        self._setup_signals()
        
        # Initial validation
        self._validate_and_update_button()
        
        # Present the dialog on the parent window
        self.present(parent)

    def _setup_signals(self):
        """Setup widget signals."""
        # Connect signals
        self.hostname_row.connect("notify::text", self._on_form_changed)
        self.username_row.connect("notify::text", self._on_form_changed)
        self.port_row.connect("notify::value", self._on_form_changed)
        self.copy_button.connect("clicked", self._on_copy_clicked)

    def _on_form_changed(self, widget, param):
        """Handle any form field change."""
        # Validate form when any field changes
        self._validate_and_update_button()

    def _validate_and_update_button(self):
        """Validate form and update copy button state."""
        if self._copying:
            return
            
        # Check if form is valid
        is_valid = self._is_form_valid()
        self.copy_button.set_sensitive(is_valid)
    
    def _is_form_valid(self) -> bool:
        """Check if the form is valid for key copy."""
        hostname = self.hostname_row.get_text().strip()
        username = self.username_row.get_text().strip()
        
        # Both hostname and username are required
        if not hostname or not username:
            return False
        
        return True


    def _on_copy_clicked(self, button: Gtk.Button):
        """Handle copy button click."""
        if self._copying:
            return

        # The button should only be clickable when form is valid
        # but double-check anyway
        if not self._is_form_valid():
            return

        # Start copy process
        self._start_copy()

    def _start_copy(self):
        """Start the key copy process."""
        self._copying = True

        # Update UI
        self.copy_button.set_sensitive(False)
        self.progress_box.set_visible(True)
        self.progress_spinner.start()

        # Create copy request
        request = self._create_copy_request()

        # Run copy in thread
        thread = threading.Thread(target=self._copy_key_thread, args=(request,))
        thread.daemon = True
        thread.start()

    def _create_copy_request(self) -> SSHCopyIDRequest:
        """Create copy request from form data."""
        hostname = self.hostname_row.get_text().strip()
        username = self.username_row.get_text().strip()
        port = int(self.port_row.get_value())

        return SSHCopyIDRequest(
            ssh_key=self.ssh_key,
            hostname=hostname,
            username=username,
            port=port
        )

    def _copy_key_thread(self, request: SSHCopyIDRequest):
        """Copy key in background thread."""
        try:
            # Create async loop
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            # Copy key to server with password callback
            loop.run_until_complete(copy_id_to_server(request, self._password_callback))

            # Update UI on main thread
            GLib.idle_add(self._on_copy_success)

        except Exception as e:
            # Update UI on main thread
            GLib.idle_add(self._on_copy_error, str(e))

    def _on_copy_success(self):
        """Handle successful key copy."""
        self._copying = False

        # Update UI
        self.copy_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Emit signal
        self.emit("key-copied", self.ssh_key)

        # Close dialog
        self.close()

    def _on_copy_error(self, error_message: str):
        """Handle key copy error."""
        self._copying = False

        # Update UI
        self.copy_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Show error
        self._show_error(f"Key copy failed: {error_message}")

    def _show_error(self, message: str):
        """Show error message."""
        dialog = Adw.MessageDialog.new(
            self._parent_window,
            "Error",
            message
        )

        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")

        dialog.present()

    def _password_callback(self) -> str:
        """Get password from user when needed.

        Returns:
            Password entered by user

        Raises:
            SSHOperationError: If user cancels password dialog
        """
        import threading
        password = None
        exception = None
        dialog_closed = threading.Event()

        def show_password_dialog():
            """Show password dialog on main thread."""
            nonlocal password, exception
            try:
                request = self._create_copy_request()
                password_dialog = PasswordDialog(
                    self._parent_window,
                    request.hostname,
                    request.username
                )

                def on_password_entered(dialog, entered_password):
                    nonlocal password
                    password = entered_password
                    dialog_closed.set()

                def on_password_cancelled(dialog):
                    nonlocal exception
                    exception = SSHOperationError("Password input cancelled by user")
                    dialog_closed.set()

                password_dialog.connect("password-entered", on_password_entered)
                password_dialog.connect("password-cancelled", on_password_cancelled)
                password_dialog.present()

            except Exception as e:
                exception = e
                dialog_closed.set()

        # Show dialog on main thread
        GLib.idle_add(show_password_dialog)

        # Wait for dialog to close
        dialog_closed.wait()

        if exception:
            raise exception
        
        return password or ""