"""Key generation dialog for creating new SSH keys."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

import asyncio
import threading

from gi.repository import Adw, Gio, GLib, GObject, Gtk

from ..backend import generate_key
from ..models import KeyGenerationRequest, SSHKey, SSHKeyType


@Gtk.Template(resource_path='/io/github/tobagin/keysmith/ui/generate_dialog.ui')
class GenerateKeyDialog(Adw.Dialog):
    """Key generation dialog using Adwaita PreferencesDialog."""

    __gtype_name__ = 'GenerateKeyDialog'

    # Define signals
    __gsignals__ = {
        'key-generated': (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    # Template child widgets
    key_type_row = Gtk.Template.Child()
    rsa_bits_row = Gtk.Template.Child()
    filename_row = Gtk.Template.Child()
    comment_row = Gtk.Template.Child()
    passphrase_switch = Gtk.Template.Child()
    passphrase_row = Gtk.Template.Child()
    passphrase_confirm_row = Gtk.Template.Child()
    generate_button = Gtk.Template.Child()
    progress_box = Gtk.Template.Child()
    progress_spinner = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, **kwargs):
        """Initialize the key generation dialog.

        Args:
            parent: Parent window
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)

        # Initialize form state
        self._generating = False

        # Get GSettings and apply defaults
        self.settings = Gio.Settings.new("io.github.tobagin.keysmith")
        self._apply_defaults()

        # Setup signals
        self._setup_signals()
        
        # Initial validation
        self._validate_and_update_button()
        
        # Present the dialog on the parent window
        self.present(parent)

    def _apply_defaults(self):
        """Apply default values from GSettings."""
        # Default key type
        default_key_type = self.settings.get_string("default-key-type")
        key_type_index = {"ed25519": 0, "rsa": 1, "ecdsa": 2}.get(default_key_type, 0)
        self.key_type_row.set_selected(key_type_index)

        # Default RSA bits
        default_rsa_bits = self.settings.get_int("default-rsa-bits")
        rsa_bits_index = {2048: 0, 3072: 1, 4096: 2, 8192: 3}.get(default_rsa_bits, 2)
        self.rsa_bits_row.set_selected(rsa_bits_index)

        # Default comment
        default_comment = self.settings.get_string("default-comment")
        if default_comment:
            self.comment_row.set_text(default_comment)
        else:
            # Fall back to user@hostname if no default comment is set
            self.comment_row.set_text(f"{GLib.get_user_name()}@{GLib.get_host_name()}")

        # Default passphrase usage
        use_passphrase_default = self.settings.get_boolean("use-passphrase-by-default")
        self.passphrase_switch.set_active(use_passphrase_default)

        # Update filename based on selected key type
        self._update_filename_for_key_type(key_type_index)

        # Show/hide RSA bits row if RSA is selected
        self.rsa_bits_row.set_visible(key_type_index == 1)

    def _update_filename_for_key_type(self, key_type_index: int):
        """Update the filename based on the selected key type.
        
        Args:
            key_type_index: Index of the selected key type (0=Ed25519, 1=RSA, 2=ECDSA)
        """
        filename_map = {0: "id_ed25519", 1: "id_rsa", 2: "id_ecdsa"}
        self.filename_row.set_text(filename_map.get(key_type_index, "id_ed25519"))

    def _setup_signals(self):
        """Setup widget signals."""
        # Connect signals
        self.key_type_row.connect("notify::selected", self._on_key_type_changed)
        self.filename_row.connect("notify::text", self._on_filename_changed)
        self.comment_row.connect("notify::text", self._on_form_changed)
        self.passphrase_switch.connect("notify::active", self._on_passphrase_switch_changed)
        self.passphrase_row.connect("notify::text", self._on_form_changed)
        self.passphrase_confirm_row.connect("notify::text", self._on_form_changed)
        self.generate_button.connect("clicked", self._on_generate_clicked)


    def _on_key_type_changed(self, combo_row: Adw.ComboRow, param):
        """Handle key type change."""
        selected = combo_row.get_selected()

        # Show/hide RSA bit size row
        self.rsa_bits_row.set_visible(selected == 1)  # RSA
        
        # Update filename for the selected key type
        self._update_filename_for_key_type(selected)
        
        # Validate form after key type change
        self._validate_and_update_button()

    def _on_filename_changed(self, entry_row: Adw.EntryRow, param):
        """Handle filename change."""
        # Validate form when filename changes
        self._validate_and_update_button()
    
    def _on_form_changed(self, widget, param):
        """Handle any form field change."""
        # Validate form when any field changes
        self._validate_and_update_button()

    def _on_passphrase_switch_changed(self, switch_row: Adw.SwitchRow, param):
        """Handle passphrase switch change."""
        active = switch_row.get_active()

        # Show/hide passphrase rows
        self.passphrase_row.set_visible(active)
        self.passphrase_confirm_row.set_visible(active)
        
        # Clear passphrase fields when disabling
        if not active:
            self.passphrase_row.set_text("")
            self.passphrase_confirm_row.set_text("")
        
        # Validate form after switch change
        self._validate_and_update_button()

    def _validate_and_update_button(self):
        """Validate form and update generate button state."""
        if self._generating:
            return
            
        # Check if form is valid
        is_valid = self._is_form_valid()
        self.generate_button.set_sensitive(is_valid)
        
        # Provide visual feedback for validation
        self._update_validation_feedback()
    
    def _is_form_valid(self) -> bool:
        """Check if the form is valid for key generation."""
        # Check filename
        filename = self.filename_row.get_text()
        if not self._validate_filename(filename):
            return False
        
        # Check passphrase requirements if enabled
        if self.passphrase_switch.get_active():
            passphrase = self.passphrase_row.get_text()
            confirm = self.passphrase_confirm_row.get_text()
            
            # Passphrase is required when protection is enabled
            if not passphrase:
                return False
                
            # Passphrases must match
            if passphrase != confirm:
                return False
        
        return True

    def _update_validation_feedback(self):
        """Update visual feedback for form validation."""
        # Validate filename and provide feedback
        filename = self.filename_row.get_text()
        if filename and not self._validate_filename(filename):
            self.filename_row.add_css_class("error")
            if not filename:
                self.filename_row.set_title("Filename (required)")
            elif len(filename) > 255:
                self.filename_row.set_title("Filename (too long)")
            else:
                self.filename_row.set_title("Filename (invalid characters)")
        else:
            self.filename_row.remove_css_class("error")
            self.filename_row.set_title("Filename")
        
        # Validate passphrase matching
        if self.passphrase_switch.get_active():
            passphrase = self.passphrase_row.get_text()
            confirm = self.passphrase_confirm_row.get_text()
            
            if passphrase and confirm and passphrase != confirm:
                self.passphrase_confirm_row.add_css_class("error")
                self.passphrase_confirm_row.set_title("Confirm Passphrase (must match)")
            else:
                self.passphrase_confirm_row.remove_css_class("error")
                self.passphrase_confirm_row.set_title("Confirm Passphrase")

    def _on_generate_clicked(self, button: Gtk.Button):
        """Handle generate button click."""
        if self._generating:
            return

        # The button should only be clickable when form is valid
        # but double-check anyway
        if not self._is_form_valid():
            return

        # Start key generation
        self._start_generation()

    def _validate_filename(self, filename: str) -> bool:
        """Validate filename input."""
        if not filename:
            return False

        # Check for invalid characters
        import re
        if not re.match(r'^[a-zA-Z0-9_.-]+$', filename):
            return False

        # Check length
        if len(filename) > 255:
            return False

        return True


    def _start_generation(self):
        """Start the key generation process."""
        self._generating = True

        # Update UI
        self.generate_button.set_sensitive(False)
        self.progress_box.set_visible(True)
        self.progress_spinner.start()

        # Create generation request
        request = self._create_generation_request()

        # Run generation in thread
        thread = threading.Thread(target=self._generate_key_thread, args=(request,))
        thread.daemon = True
        thread.start()

    def _create_generation_request(self) -> KeyGenerationRequest:
        """Create key generation request from form data."""
        # Get key type
        key_type_index = self.key_type_row.get_selected()
        if key_type_index == 0:
            key_type = SSHKeyType.ED25519
        elif key_type_index == 1:
            key_type = SSHKeyType.RSA
        else:
            key_type = SSHKeyType.ECDSA

        # Get RSA bits
        rsa_bits = None
        if key_type == SSHKeyType.RSA:
            rsa_bits_index = self.rsa_bits_row.get_selected()
            rsa_bits_map = {0: 2048, 1: 3072, 2: 4096, 3: 8192}
            rsa_bits = rsa_bits_map.get(rsa_bits_index, 4096)

        # Get passphrase
        passphrase = None
        if self.passphrase_switch.get_active():
            passphrase = self.passphrase_row.get_text()
            if not passphrase:
                passphrase = None

        # Get comment
        comment = self.comment_row.get_text()
        if not comment:
            comment = None

        return KeyGenerationRequest(
            key_type=key_type,
            filename=self.filename_row.get_text(),
            passphrase=passphrase,
            comment=comment,
            rsa_bits=rsa_bits
        )

    def _generate_key_thread(self, request: KeyGenerationRequest):
        """Generate key in background thread."""
        try:
            # Create async loop
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            # Generate key
            ssh_key = loop.run_until_complete(generate_key(request))

            # Update UI on main thread
            GLib.idle_add(self._on_generation_success, ssh_key)

        except Exception as e:
            # Update UI on main thread
            GLib.idle_add(self._on_generation_error, str(e))

    def _on_generation_success(self, ssh_key: SSHKey):
        """Handle successful key generation."""
        self._generating = False

        # Update UI
        self.generate_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Emit signal
        self.emit("key-generated", ssh_key)

        # Close dialog
        self.close()

    def _on_generation_error(self, error_message: str):
        """Handle key generation error."""
        self._generating = False

        # Update UI
        self.generate_button.set_sensitive(True)
        self.progress_box.set_visible(False)
        self.progress_spinner.stop()

        # Show user-friendly error with guidance
        self._show_generation_error(error_message)

    def _show_generation_error(self, technical_error: str):
        """Show user-friendly error message with guidance."""
        # Provide user-friendly error messages based on common issues
        user_message = "Unable to generate SSH key"
        guidance = ""
        
        if "already exists" in technical_error.lower():
            user_message = "SSH key already exists"
            guidance = "A key with this filename already exists. Please choose a different filename or delete the existing key first."
        elif "permission" in technical_error.lower():
            user_message = "Permission denied"
            guidance = "KeySmith doesn't have permission to create files in the SSH directory. Please check that ~/.ssh directory exists and has proper permissions (700)."
        elif "ssh-keygen" in technical_error.lower():
            user_message = "SSH tools not available"
            guidance = "The ssh-keygen command is not available on your system. Please install OpenSSH client tools."
        elif "invalid" in technical_error.lower() or "validation" in technical_error.lower():
            user_message = "Invalid key parameters"
            guidance = "The key generation parameters are invalid. Please check the filename and other settings."
        else:
            guidance = "This might happen if:\n• The ~/.ssh directory doesn't exist or has wrong permissions\n• OpenSSH tools are not installed\n• Insufficient disk space\n• The filename contains invalid characters"
        
        detailed_message = f"{guidance}\n\nTechnical details: {technical_error}"
        
        dialog = Adw.MessageDialog.new(
            self,
            user_message,
            detailed_message
        )

        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")
        dialog.present()
