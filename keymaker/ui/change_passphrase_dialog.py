"""Change passphrase dialog for SSH keys."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

import asyncio
import threading

from gi.repository import Adw, GLib, GObject, Gtk

from ..backend import change_passphrase
from ..models import PassphraseChangeRequest, SSHKey, SSHOperationError


@Gtk.Template(resource_path='/io/github/tobagin/keymaker/ui/change_passphrase_dialog.ui')
class ChangePassphraseDialog(Adw.Dialog):
    """Change passphrase dialog using Adwaita PreferencesDialog."""

    __gtype_name__ = 'ChangePassphraseDialog'

    # Define signals
    __gsignals__ = {
        'passphrase-changed': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    # Template child widgets
    current_passphrase_row = Gtk.Template.Child()
    new_passphrase_row = Gtk.Template.Child()
    confirm_passphrase_row = Gtk.Template.Child()
    change_button = Gtk.Template.Child()
    progress_box = Gtk.Template.Child()
    progress_spinner = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, ssh_key: SSHKey, **kwargs):
        """Initialize the change passphrase dialog.

        Args:
            parent: Parent window
            ssh_key: SSH key to change passphrase for
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)

        self.ssh_key = ssh_key
        self._changing = False
        
        # Track which fields have been touched by the user
        self._current_passphrase_touched = False
        self._new_passphrase_touched = False
        self._confirm_passphrase_touched = False

        # Setup signals
        self._setup_signals()
        
        # Initial validation
        self._validate_and_update_button()
        
        # Present the dialog on the parent window
        self.present(parent)

    def _setup_signals(self):
        """Setup widget signals."""
        # Connect signals
        self.current_passphrase_row.connect("notify::text", self._on_current_passphrase_changed)
        self.new_passphrase_row.connect("notify::text", self._on_new_passphrase_changed)
        self.confirm_passphrase_row.connect("notify::text", self._on_confirm_passphrase_changed)
        self.change_button.connect("clicked", self._on_change_clicked)

    def _on_current_passphrase_changed(self, widget, param):
        """Handle current passphrase field change."""
        self._current_passphrase_touched = True
        self._validate_and_update_button()
    
    def _on_new_passphrase_changed(self, widget, param):
        """Handle new passphrase field change."""
        self._new_passphrase_touched = True
        self._validate_and_update_button()
    
    def _on_confirm_passphrase_changed(self, widget, param):
        """Handle confirm passphrase field change."""
        self._confirm_passphrase_touched = True
        self._validate_and_update_button()

    def _validate_and_update_button(self):
        """Validate form and update change button state."""
        if self._changing:
            return
            
        # Check if form is valid
        is_valid = self._is_form_valid()
        self.change_button.set_sensitive(is_valid)
    
    def _is_form_valid(self) -> bool:
        """Check if the form is valid for passphrase change."""
        # All fields must be explicitly touched by the user
        if not (self._current_passphrase_touched and 
                self._new_passphrase_touched and 
                self._confirm_passphrase_touched):
            return False
        
        # Get field values
        new_passphrase = self.new_passphrase_row.get_text()
        confirm_passphrase = self.confirm_passphrase_row.get_text()
        
        # New passphrases must match
        if new_passphrase != confirm_passphrase:
            return False
        
        # All validation checks passed
        return True


    def _on_change_clicked(self, button: Gtk.Button):
        """Handle change button click."""
        if self._changing:
            return

        # The button should only be clickable when form is valid
        # but double-check anyway
        if not self._is_form_valid():
            return

        # Start passphrase change
        self._start_change()

    def _start_change(self):
        """Start the passphrase change process."""
        self._changing = True

        # Update UI
        self.change_button.set_sensitive(False)
        self.progress_box.set_visible(True)
        self.progress_spinner.start()

        # Create change request
        request = self._create_change_request()

        # Run change in thread
        thread = threading.Thread(target=self._change_passphrase_thread, args=(request,))
        thread.daemon = True
        thread.start()

    def _create_change_request(self) -> PassphraseChangeRequest:
        """Create passphrase change request from form data."""
        current_passphrase = self.current_passphrase_row.get_text()
        new_passphrase = self.new_passphrase_row.get_text()

        return PassphraseChangeRequest(
            ssh_key=self.ssh_key,
            current_passphrase=current_passphrase if current_passphrase else None,
            new_passphrase=new_passphrase if new_passphrase else None
        )

    def _change_passphrase_thread(self, request: PassphraseChangeRequest):
        """Change passphrase in background thread."""
        try:
            # Create async loop
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            # Change passphrase
            loop.run_until_complete(change_passphrase(request))

            # Update UI on main thread
            GLib.idle_add(self._on_change_success)

        except Exception as e:
            # Update UI on main thread
            GLib.idle_add(self._on_change_error, str(e))

    def _on_change_success(self):
        """Handle successful passphrase change."""
        self._changing = False

        # Update UI
        self.change_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Emit signal
        self.emit("passphrase-changed", self.ssh_key)

        # Close dialog
        self.close()

    def _on_change_error(self, error_message: str):
        """Handle passphrase change error."""
        self._changing = False

        # Update UI
        self.change_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Show error
        self._show_error(f"Passphrase change failed: {error_message}")

    def _show_error(self, message: str):
        """Show error message."""
        dialog = Adw.MessageDialog.new(
            self,
            "Error",
            message
        )

        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")

        dialog.present()