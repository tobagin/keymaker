"""Main application window for KeySmith."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

import asyncio

from gi.repository import Adw, GLib, Gtk, Gio

from .. import _
from ..backend import scan_ssh_directory
from ..models import SSHKey
from .generate_dialog import GenerateKeyDialog
from .change_passphrase_dialog import ChangePassphraseDialog
from .copy_id_dialog import CopyIdDialog
from .key_details_dialog import KeyDetailsDialog
from .key_list import KeyListWidget
from .help_dialog import HelpDialog


@Gtk.Template(resource_path='/io/github/tobagin/keysmith/ui/window.ui')
class KeySmithWindow(Adw.ApplicationWindow):
    """Main application window using Adwaita components."""

    __gtype_name__ = 'KeySmithWindow'

    # Template child widgets
    toolbar_view = Gtk.Template.Child()
    header_bar = Gtk.Template.Child()
    generate_button = Gtk.Template.Child()
    refresh_button = Gtk.Template.Child()
    menu_button = Gtk.Template.Child()
    toast_overlay = Gtk.Template.Child()
    main_box = Gtk.Template.Child()

    def __init__(self, application: Adw.Application, **kwargs):
        """Initialize the main window.

        Args:
            application: The Adw.Application instance
            **kwargs: Additional window arguments
        """
        super().__init__(application=application, **kwargs)

        # Initialize async loop reference
        self._loop = None

        # Create key list widget and add to main box
        self.key_list = KeyListWidget()
        self.main_box.append(self.key_list)

        # Setup actions and signals
        self._setup_actions()
        self._setup_signals()

        # Load keys on startup
        GLib.idle_add(self._load_keys_async)

    def _setup_actions(self):
        """Setup window actions."""
        # Generate key action
        generate_action = Gio.SimpleAction.new("generate-key", None)
        generate_action.connect("activate", self._on_generate_key_action)
        self.add_action(generate_action)

        # Refresh action
        refresh_action = Gio.SimpleAction.new("refresh", None)
        refresh_action.connect("activate", self._on_refresh_action)
        self.add_action(refresh_action)
        
        # Help action
        help_action = Gio.SimpleAction.new("help", None)
        help_action.connect("activate", self._on_help_action)
        self.add_action(help_action)

    def _setup_signals(self):
        """Setup widget signals."""
        # Key list signals
        self.key_list.connect("key-copy-requested", self._on_key_copy_requested)
        self.key_list.connect("key-delete-requested", self._on_key_delete_requested)
        self.key_list.connect("key-details-requested", self._on_key_details_requested)
        self.key_list.connect("key-passphrase-change-requested", self._on_key_passphrase_change_requested)
        self.key_list.connect("key-copy-id-requested", self._on_key_copy_id_requested)

    def _on_generate_key_action(self, action: Gio.SimpleAction, parameter):
        """Handle generate key action."""
        dialog = GenerateKeyDialog(self)
        dialog.connect("key-generated", self._on_key_generated)

    def _on_refresh_action(self, action: Gio.SimpleAction, parameter):
        """Handle refresh action."""
        GLib.idle_add(self._load_keys_async)

    def _on_help_action(self, action: Gio.SimpleAction, parameter):
        """Handle help action."""
        HelpDialog(self)

    def _on_key_copy_requested(self, key_list: KeyListWidget, ssh_key: SSHKey):
        """Handle key copy request."""
        try:
            from ..backend import get_public_key_content

            # Get public key content
            public_key_content = get_public_key_content(ssh_key)

            # Copy to clipboard
            clipboard = self.get_clipboard()
            clipboard.set(public_key_content)

            # Show toast notification
            toast = Adw.Toast.new(_("Public key copied to clipboard"))
            toast.set_timeout(2)
            self.toast_overlay.add_toast(toast)

        except Exception as e:
            # Provide user-friendly error message with technical details
            user_message = _("Unable to copy public key to clipboard")
            technical_details = _("Error details: {error}\n\nThis might happen if:\n• The public key file is missing or corrupted\n• The clipboard system is not available\n• File permissions prevent reading the key").format(error=str(e))
            self._show_error_toast(user_message, technical_details)

    def _on_key_delete_requested(self, key_list: KeyListWidget, ssh_key: SSHKey):
        """Handle key delete request."""
        # Show confirmation dialog
        dialog = Adw.MessageDialog.new(
            self,
            _("Delete SSH Key?"),
            _("Are you sure you want to delete the key '{keyname}'?").format(keyname=ssh_key.private_path.name)
        )

        dialog.add_response("cancel", _("Cancel"))
        dialog.add_response("delete", _("Delete"))
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_default_response("cancel")

        dialog.connect("response", self._on_delete_confirmation_response, ssh_key)
        dialog.present()

    def _on_delete_confirmation_response(self, dialog: Adw.MessageDialog, response: str, ssh_key: SSHKey):
        """Handle delete confirmation response."""
        if response == "delete":
            # Delete the key asynchronously
            GLib.idle_add(self._delete_key_async, ssh_key)

        dialog.close()

    def _on_key_details_requested(self, key_list: KeyListWidget, ssh_key: SSHKey):
        """Handle key details request."""
        # Create details dialog using the new KeyDetailsDialog
        dialog = KeyDetailsDialog(self, ssh_key)


    def _on_key_passphrase_change_requested(self, key_list: KeyListWidget, ssh_key: SSHKey):
        """Handle key passphrase change request."""
        dialog = ChangePassphraseDialog(self, ssh_key)
        dialog.connect("passphrase-changed", self._on_passphrase_changed)

    def _on_key_copy_id_requested(self, key_list: KeyListWidget, ssh_key: SSHKey):
        """Handle key copy-id request."""
        dialog = CopyIdDialog(self, ssh_key)
        dialog.connect("key-copied", self._on_key_copied)

    def _on_key_generated(self, dialog: GenerateKeyDialog, ssh_key: SSHKey):
        """Handle new key generation."""
        # Refresh key list
        GLib.idle_add(self._load_keys_async)

        # Show success notification
        toast = Adw.Toast.new(f"SSH key '{ssh_key.private_path.name}' generated successfully")
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

    def _on_passphrase_changed(self, dialog: ChangePassphraseDialog, ssh_key: SSHKey):
        """Handle successful passphrase change."""
        # Show success notification
        toast = Adw.Toast.new(f"Passphrase for '{ssh_key.private_path.name}' changed successfully")
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

    def _on_key_copied(self, dialog: CopyIdDialog, ssh_key: SSHKey):
        """Handle successful key copy to server."""
        # Show success notification
        toast = Adw.Toast.new(f"Key '{ssh_key.private_path.name}' copied to server successfully")
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

    def _load_keys_async(self):
        """Load SSH keys asynchronously."""
        async def load_keys():
            try:
                # Scan SSH directory
                ssh_keys = await scan_ssh_directory()

                # Update UI on main thread
                GLib.idle_add(self._update_key_list, ssh_keys)

            except Exception as e:
                user_message = "Unable to load SSH keys"
                technical_details = f"Error details: {str(e)}\n\nThis might happen if:\n• The ~/.ssh directory doesn't exist or has wrong permissions\n• Some key files are corrupted or have incorrect format\n• Insufficient permissions to read key files\n\nTry refreshing or check your SSH directory permissions."
                GLib.idle_add(self._show_error_toast, user_message, technical_details)

        # Run the async function
        self._run_async(load_keys())

    def _delete_key_async(self, ssh_key: SSHKey):
        """Delete SSH key asynchronously."""
        async def delete_key():
            try:
                from ..backend import delete_key_pair

                # Delete the key pair
                await delete_key_pair(ssh_key)

                # Refresh key list
                GLib.idle_add(self._load_keys_async)

                # Show success notification
                GLib.idle_add(self._show_success_toast, f"Key '{ssh_key.private_path.name}' deleted successfully")

            except Exception as e:
                user_message = "Unable to delete SSH key"
                technical_details = f"Error details: {str(e)}\n\nThis might happen if:\n• Insufficient permissions to delete the key files\n• The key files are currently in use\n• File system is read-only\n\nTry checking file permissions or closing any applications that might be using the key."
                GLib.idle_add(self._show_error_toast, user_message, technical_details)

        # Run the async function
        self._run_async(delete_key())

    def _update_key_list(self, ssh_keys: list[SSHKey]):
        """Update the key list with new keys."""
        self.key_list.set_keys(ssh_keys)

    def _show_error_toast(self, message: str, detailed_message: str = None):
        """Show error toast notification with optional detailed error dialog.
        
        Args:
            message: User-friendly error message
            detailed_message: Optional detailed technical error for advanced users
        """
        toast = Adw.Toast.new(message)
        toast.set_timeout(5)  # Longer timeout for errors
        
        # Add action button for detailed error if provided
        if detailed_message:
            toast.set_button_label("Details")
            toast.connect("button-clicked", self._show_error_details, detailed_message)
        
        self.toast_overlay.add_toast(toast)
    
    def _show_error_details(self, toast: Adw.Toast, detailed_message: str):
        """Show detailed error information in a dialog.
        
        Args:
            toast: The toast that triggered this
            detailed_message: Detailed error information
        """
        dialog = Adw.MessageDialog.new(
            self,
            "Error Details",
            detailed_message
        )
        dialog.add_response("close", "Close")
        dialog.set_default_response("close")
        dialog.present()

    def _show_success_toast(self, message: str):
        """Show success toast notification."""
        toast = Adw.Toast.new(message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)

    def _run_async(self, coro):
        """Run an async coroutine."""
        def run_task():
            try:
                # Create a new event loop for this thread
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                # Run the coroutine
                loop.run_until_complete(coro)
            except Exception as e:
                GLib.idle_add(self._show_error_toast, f"Operation failed: {str(e)}")
            finally:
                # Clean up the loop
                try:
                    loop.close()
                except:
                    pass

        # Run in thread to avoid blocking GTK
        import threading
        thread = threading.Thread(target=run_task)
        thread.daemon = True
        thread.start()
