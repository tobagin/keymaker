"""SSH key details dialog."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Adw, Gdk, GObject, Gtk

from ..models import SSHKey


@Gtk.Template(resource_path='/io/github/tobagin/keymaker/ui/key_details_dialog.ui')
class KeyDetailsDialog(Adw.Dialog):
    """SSH key details dialog using Adwaita Dialog."""

    __gtype_name__ = 'KeyDetailsDialog'

    # Template child widgets
    key_type_row = Gtk.Template.Child()
    bit_size_row = Gtk.Template.Child()
    fingerprint_row = Gtk.Template.Child()
    comment_row = Gtk.Template.Child()
    private_path_row = Gtk.Template.Child()
    public_path_row = Gtk.Template.Child()
    modified_row = Gtk.Template.Child()
    public_key_text = Gtk.Template.Child()
    copy_fingerprint_button = Gtk.Template.Child()
    copy_private_path_button = Gtk.Template.Child()
    copy_public_path_button = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, ssh_key: SSHKey, **kwargs):
        """Initialize the SSH key details dialog.

        Args:
            parent: Parent window
            ssh_key: SSH key to show details for
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)

        self.ssh_key = ssh_key

        # Setup content
        self._setup_content()
        self._setup_signals()

        # Present the dialog on the parent window
        self.present(parent)

    def _setup_content(self):
        """Setup the dialog content with SSH key information."""
        # Set dialog title with key name
        self.set_title(f"SSH Key Details: {self.ssh_key.private_path.name}")

        # Key Information
        self.key_type_row.set_subtitle(self.ssh_key.key_type.value.upper())

        if self.ssh_key.bit_size:
            self.bit_size_row.set_subtitle(str(self.ssh_key.bit_size))
            self.bit_size_row.set_visible(True)

        self.fingerprint_row.set_subtitle(self.ssh_key.fingerprint or "Unknown")

        if self.ssh_key.comment:
            self.comment_row.set_subtitle(self.ssh_key.comment)
            self.comment_row.set_visible(True)

        # File Information
        self.private_path_row.set_subtitle(str(self.ssh_key.private_path))
        self.public_path_row.set_subtitle(str(self.ssh_key.public_path))
        self.modified_row.set_subtitle(
            self.ssh_key.last_modified.strftime('%Y-%m-%d %H:%M:%S')
        )

        # Public Key Content
        self._load_public_key_content()

    def _load_public_key_content(self):
        """Load and display the public key content."""
        try:
            if self.ssh_key.public_path.exists():
                content = self.ssh_key.public_path.read_text().strip()
                text_buffer = self.public_key_text.get_buffer()
                text_buffer.set_text(content)
            else:
                text_buffer = self.public_key_text.get_buffer()
                text_buffer.set_text("Public key file not found")
        except Exception:
            text_buffer = self.public_key_text.get_buffer()
            text_buffer.set_text("Error reading public key file")

    def _setup_signals(self):
        """Setup widget signals."""
        self.copy_fingerprint_button.connect("clicked", self._on_copy_fingerprint)
        self.copy_private_path_button.connect("clicked", self._on_copy_private_path)
        self.copy_public_path_button.connect("clicked", self._on_copy_public_path)

    def _on_copy_fingerprint(self, button: Gtk.Button):
        """Handle copy fingerprint button click."""
        if self.ssh_key.fingerprint:
            self._copy_to_clipboard(self.ssh_key.fingerprint)

    def _on_copy_private_path(self, button: Gtk.Button):
        """Handle copy private path button click."""
        self._copy_to_clipboard(str(self.ssh_key.private_path))

    def _on_copy_public_path(self, button: Gtk.Button):
        """Handle copy public path button click."""
        self._copy_to_clipboard(str(self.ssh_key.public_path))


    def _copy_to_clipboard(self, text: str):
        """Copy text to clipboard.
        
        Args:
            text: Text to copy to clipboard
        """
        clipboard = Gdk.Display.get_default().get_clipboard()
        clipboard.set(text)