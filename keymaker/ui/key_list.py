"""SSH key list widget for displaying all available keys."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from typing import Optional

from gi.repository import Adw, GObject, Gtk

from ..models import SSHKey
from .key_row import KeyRow


@Gtk.Template(resource_path='/io/github/tobagin/keymaker/ui/key_list.ui')
class KeyListWidget(Gtk.Box):
    """Widget displaying list of SSH keys using GTK4 ListBox."""

    __gtype_name__ = 'KeyListWidget'

    # Define signals
    __gsignals__ = {
        'key-copy-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'key-delete-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'key-details-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'key-passphrase-change-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
        'key-copy-id-requested': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    # Template child widgets
    empty_state = Gtk.Template.Child()
    list_scroll = Gtk.Template.Child()
    key_count_label = Gtk.Template.Child()
    key_list_box = Gtk.Template.Child()
    placeholder_row = Gtk.Template.Child()

    def __init__(self, **kwargs):
        """Initialize the key list widget."""
        super().__init__(**kwargs)

        # Store current keys
        self._ssh_keys: list[SSHKey] = []
        self._key_rows: list[KeyRow] = []

        # Setup UI
        self._setup_ui()

    def _setup_ui(self):
        """Setup the key list UI components."""
        # Initially show empty state
        self._update_visibility()
        
        # Update key count
        self._update_key_count()

    def set_keys(self, ssh_keys: list[SSHKey]):
        """Set the list of SSH keys to display.

        Args:
            ssh_keys: List of SSH keys to display
        """
        self._ssh_keys = ssh_keys
        self._refresh_list()

    def _refresh_list(self):
        """Refresh the list display with current keys."""
        # Clear existing rows
        self._clear_list()

        # Add new rows
        for ssh_key in self._ssh_keys:
            self._add_key_row(ssh_key)
        
        # Update UI visibility and key count
        self._update_visibility()
        self._update_key_count()

    def _clear_list(self):
        """Clear all rows from the list."""
        # Remove all children from listbox except placeholder
        child = self.key_list_box.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            if child != self.placeholder_row:  # Keep the placeholder row
                self.key_list_box.remove(child)
            child = next_child

        # Clear row references
        self._key_rows.clear()

    def _add_key_row(self, ssh_key: SSHKey):
        """Add a new key row to the list.

        Args:
            ssh_key: SSH key to add
        """
        # Create key row
        key_row = KeyRow(ssh_key)

        # Connect signals
        key_row.connect("copy-requested", self._on_key_copy_requested)
        key_row.connect("delete-requested", self._on_key_delete_requested)
        key_row.connect("details-requested", self._on_key_details_requested)
        key_row.connect("passphrase-change-requested", self._on_key_passphrase_change_requested)
        key_row.connect("copy-id-requested", self._on_key_copy_id_requested)

        # Add to listbox
        self.key_list_box.append(key_row)

        # Store reference
        self._key_rows.append(key_row)

    def _update_visibility(self):
        """Update visibility of empty state vs. key list."""
        has_keys = len(self._ssh_keys) > 0
        
        # Show/hide appropriate sections
        self.empty_state.set_visible(not has_keys)
        self.list_scroll.set_visible(has_keys)

    def _update_key_count(self):
        """Update the key count label."""
        count = len(self._ssh_keys)
        if count == 0:
            self.key_count_label.set_text("")
        elif count == 1:
            self.key_count_label.set_text("1 key")
        else:
            self.key_count_label.set_text(f"{count} keys")

    def _on_key_copy_requested(self, key_row: KeyRow, ssh_key: SSHKey):
        """Handle key copy request from row."""
        self.emit("key-copy-requested", ssh_key)

    def _on_key_delete_requested(self, key_row: KeyRow, ssh_key: SSHKey):
        """Handle key delete request from row."""
        self.emit("key-delete-requested", ssh_key)

    def _on_key_details_requested(self, key_row: KeyRow, ssh_key: SSHKey):
        """Handle key details request from row."""
        self.emit("key-details-requested", ssh_key)

    def _on_key_passphrase_change_requested(self, key_row: KeyRow, ssh_key: SSHKey):
        """Handle key passphrase change request from row."""
        self.emit("key-passphrase-change-requested", ssh_key)

    def _on_key_copy_id_requested(self, key_row: KeyRow, ssh_key: SSHKey):
        """Handle key copy-id request from row."""
        self.emit("key-copy-id-requested", ssh_key)

    def add_key(self, ssh_key: SSHKey):
        """Add a new SSH key to the list.

        Args:
            ssh_key: SSH key to add
        """
        self._ssh_keys.append(ssh_key)
        self._add_key_row(ssh_key)
        self._update_visibility()
        self._update_key_count()

    def remove_key(self, ssh_key: SSHKey):
        """Remove an SSH key from the list.

        Args:
            ssh_key: SSH key to remove
        """
        # Find and remove from keys list
        try:
            index = self._ssh_keys.index(ssh_key)
            self._ssh_keys.pop(index)

            # Remove corresponding row
            key_row = self._key_rows.pop(index)
            self.key_list_box.remove(key_row)
            
            # Update UI
            self._update_visibility()
            self._update_key_count()

        except (ValueError, IndexError):
            # Key not found, ignore
            pass

    def update_key(self, old_ssh_key: SSHKey, new_ssh_key: SSHKey):
        """Update an existing SSH key in the list.

        Args:
            old_ssh_key: Old SSH key to replace
            new_ssh_key: New SSH key data
        """
        try:
            index = self._ssh_keys.index(old_ssh_key)
            self._ssh_keys[index] = new_ssh_key

            # Update corresponding row
            key_row = self._key_rows[index]
            key_row.update_key(new_ssh_key)

        except (ValueError, IndexError):
            # Key not found, ignore
            pass

    def get_keys(self) -> list[SSHKey]:
        """Get the current list of SSH keys.

        Returns:
            List of current SSH keys
        """
        return self._ssh_keys.copy()

    def find_key_by_path(self, key_path: str) -> Optional[SSHKey]:
        """Find an SSH key by its path.

        Args:
            key_path: Path to the SSH key file

        Returns:
            SSH key if found, None otherwise
        """
        for ssh_key in self._ssh_keys:
            if str(ssh_key.private_path) == key_path:
                return ssh_key
        return None

    def get_selected_key(self) -> Optional[SSHKey]:
        """Get the currently selected SSH key.

        Returns:
            Selected SSH key or None if no selection
        """
        selected_row = self.key_list_box.get_selected_row()
        if selected_row and isinstance(selected_row, KeyRow):
            return selected_row.get_ssh_key()
        return None

    def refresh(self):
        """Refresh the display of all keys."""
        self._refresh_list()

    def is_empty(self) -> bool:
        """Check if the key list is empty.

        Returns:
            True if no keys are present
        """
        return len(self._ssh_keys) == 0

    def get_key_count(self) -> int:
        """Get the number of keys in the list.

        Returns:
            Number of SSH keys
        """
        return len(self._ssh_keys)

    def show_loading(self):
        """Show loading state while keys are being scanned."""
        self.placeholder_row.set_visible(True)
        self.empty_state.set_visible(False)
        self.list_scroll.set_visible(True)
        
    def hide_loading(self):
        """Hide loading state after keys are loaded."""
        self.placeholder_row.set_visible(False)
        self._update_visibility()
