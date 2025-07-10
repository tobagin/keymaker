"""SSH key row widget for displaying individual keys in the list."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Adw, Gio, GObject, Gtk

from ..models import SSHKey, SSHKeyType


@Gtk.Template(resource_path='/io/github/tobagin/keysmith/ui/key_row.ui')
class KeyRow(Adw.ActionRow):
    """Individual SSH key row widget using Adwaita ActionRow."""

    __gtype_name__ = 'KeyRow'

    # Template child widgets
    key_icon = Gtk.Template.Child()
    key_type_label = Gtk.Template.Child()
    copy_button = Gtk.Template.Child()
    details_button = Gtk.Template.Child()
    delete_button = Gtk.Template.Child()
    change_passphrase_button = Gtk.Template.Child()
    copy_id_button = Gtk.Template.Child()

    # Define signals
    __gsignals__ = {
        'copy-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'delete-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'details-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'passphrase-change-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'copy-id-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    def __init__(self, ssh_key: SSHKey, **kwargs):
        """Initialize the key row.

        Args:
            ssh_key: The SSH key to display
            **kwargs: Additional ActionRow arguments
        """
        super().__init__(**kwargs)

        self.ssh_key = ssh_key

        # Setup the row content
        self._setup_content()
        self._setup_signals()

    def _setup_content(self):
        """Setup the main content of the row."""
        # Set title and subtitle
        self.set_title(self.ssh_key.private_path.name)
        self.set_subtitle(self._format_subtitle())

        # Set key type icon and label
        self.key_icon.set_from_icon_name(self._get_key_type_icon())
        self.key_icon.set_css_classes(self._get_key_type_classes())
        self.key_type_label.set_text(self._get_key_type_text())
        self.key_type_label.set_css_classes(self._get_key_type_classes())

    def _setup_signals(self):
        """Setup button signals."""
        # Connect button signals
        self.copy_button.connect("clicked", self._on_copy_clicked)
        self.details_button.connect("clicked", self._on_details_clicked)
        self.delete_button.connect("clicked", self._on_delete_clicked)
        self.change_passphrase_button.connect("clicked", self._on_change_passphrase_clicked)
        self.copy_id_button.connect("clicked", self._on_copy_id_clicked)

    def _format_subtitle(self) -> str:
        """Format the subtitle text for the row."""
        parts = []

        # Key type and bit size
        if self.ssh_key.key_type == SSHKeyType.RSA and self.ssh_key.bit_size:
            parts.append(f"{self.ssh_key.key_type.value.upper()} {self.ssh_key.bit_size}")
        else:
            parts.append(self.ssh_key.key_type.value.upper())

        # Fingerprint (shortened)
        if self.ssh_key.fingerprint:
            # Show last 12 characters of fingerprint
            short_fingerprint = self.ssh_key.fingerprint[-12:]
            parts.append(f"...{short_fingerprint}")

        # Comment (if available)
        if self.ssh_key.comment:
            # Truncate long comments
            comment = self.ssh_key.comment
            if len(comment) > 30:
                comment = comment[:27] + "..."
            parts.append(comment)

        return " • ".join(parts)

    def _get_key_type_text(self) -> str:
        """Get the key type text for the label."""
        if self.ssh_key.key_type == SSHKeyType.RSA and self.ssh_key.bit_size:
            return f"{self.ssh_key.key_type.value.upper()}-{self.ssh_key.bit_size}"
        else:
            return self.ssh_key.key_type.value.upper()

    def _get_key_type_icon(self) -> str:
        """Get the icon name for the key type."""
        if self.ssh_key.key_type == SSHKeyType.ED25519:
            return "security-high-symbolic"  # Full shield for most secure
        elif self.ssh_key.key_type == SSHKeyType.RSA:
            return "org.gnome.Settings-device-security-symbolic"  # Shield with keyhole for RSA
        elif self.ssh_key.key_type == SSHKeyType.ECDSA:
            return "security-medium-symbolic"  # Half shield for least recommended
        else:
            return "org.gnome.Settings-device-security-symbolic"  # Default to shield with keyhole

    def _get_key_type_classes(self) -> list[str]:
        """Get CSS classes for the key type label."""
        base_classes = ["caption"]
        
        # Add color class based on key type
        if self.ssh_key.key_type == SSHKeyType.ED25519:
            base_classes.append("success")
        elif self.ssh_key.key_type == SSHKeyType.RSA:
            base_classes.append("accent")
        elif self.ssh_key.key_type == SSHKeyType.ECDSA:
            base_classes.append("warning")
            
        return base_classes


    def _on_copy_clicked(self, button: Gtk.Button):
        """Handle copy button click."""
        self.emit("copy-requested", self.ssh_key)

    def _on_copy_id_clicked(self, button: Gtk.Button):
        """Handle copy ID button click."""
        self.emit("copy-id-requested", self.ssh_key)

    def _on_details_clicked(self, button: Gtk.Button):
        """Handle details button click."""
        self.emit("details-requested", self.ssh_key)

    def _on_change_passphrase_clicked(self, button: Gtk.Button):
        """Handle change passphrase button click."""
        self.emit("passphrase-change-requested", self.ssh_key)

    def _on_delete_clicked(self, button: Gtk.Button):
        """Handle delete button click."""
        self.emit("delete-requested", self.ssh_key)

    def update_key(self, ssh_key: SSHKey):
        """Update the row with new SSH key data.

        Args:
            ssh_key: Updated SSH key data
        """
        self.ssh_key = ssh_key

        # Update content
        self.set_title(self.ssh_key.private_path.name)
        self.set_subtitle(self._format_subtitle())
        
        # Update key type icon and label
        self.key_icon.set_from_icon_name(self._get_key_type_icon())
        self.key_icon.set_css_classes(self._get_key_type_classes())
        self.key_type_label.set_text(self._get_key_type_text())
        self.key_type_label.set_css_classes(self._get_key_type_classes())


    def get_ssh_key(self) -> SSHKey:
        """Get the SSH key associated with this row.

        Returns:
            The SSH key model
        """
        return self.ssh_key
