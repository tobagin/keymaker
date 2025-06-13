import sys
import gi
import os
import pathlib
import subprocess

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Gtk, Adw, Gio, GLib, Gdk
import functools # For partial, if needed later, good to have

# Forward declaration for type hinting if GenerateKeyDialog uses KeySmithWindow methods directly
# class KeySmithWindow(Adw.ApplicationWindow): pass


class DeployKeyDialog(Adw.Dialog):
    def __init__(self, parent_window, pub_key_path, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)
        self.parent_window = parent_window
        self.pub_key_path = str(pub_key_path) # Ensure it's a string
        self.set_title("Deploy Key to Server")
        self.set_default_size(400, 200)

        self.add_button("Cancel", Gtk.ResponseType.CANCEL)
        self.add_button("Copy Command", Gtk.ResponseType.ACCEPT) # Changed from OK to ACCEPT for clarity
        self.set_default_response(Gtk.ResponseType.ACCEPT)
        self.connect("response", self.on_dialog_response)

        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin_top=10, margin_bottom=10, margin_start=10, margin_end=10)
        self.set_child(content_box)

        self.remote_address_entry_row = Adw.EntryRow(title="Remote (user@host)")
        self.remote_address_entry_row.set_placeholder_text("e.g., user@example.com")
        content_box.append(self.remote_address_entry_row)

        # Small label explaining what it does
        info_label = Gtk.Label(label="This will copy the ssh-copy-id command to your clipboard.")
        info_label.set_halign(Gtk.Align.START)
        info_label.set_css_classes(["caption"]) # Adwaita style for smaller text
        content_box.append(info_label)


    def on_dialog_response(self, dialog, response_id):
        if response_id == Gtk.ResponseType.ACCEPT:
            remote_address = self.remote_address_entry_row.get_text().strip()
            if not remote_address:
                # Simple validation: show toast on parent, keep dialog open
                self.parent_window.show_toast("Remote address cannot be empty.", priority=Adw.ToastPriority.HIGH)
                # We need to prevent the dialog from closing.
                # One way is to stop the signal emission if using custom buttons.
                # With Adw.Dialog response buttons, this is trickier.
                # For now, the dialog will close. A more robust validation might use an Adw.StatusPage or inline validation.
                # A quick way to "keep it open" is to re-present it, but that's not ideal UX.
                # For this helper, copying an empty command isn't harmful, but good to guide user.
                # Let's assume user will re-open if they make a mistake for now.
                # A better way: connect to "clicked" of the button if it were a custom button.
                # Or, emit a custom signal and stop propagation if validation fails.
                # For Adw.Dialog, we can't easily stop the dialog from closing on response.
                # The toast is the main feedback if empty.
                if not remote_address: # Re-check, as toast is on parent
                    self.close() # Still close if empty, toast is the warning
                    return


            # Construct the command using pathlib for path handling, then convert to string
            ssh_copy_id_command = f"ssh-copy-id -i '{self.pub_key_path}' '{remote_address}'"

            clipboard = Gdk.Display.get_default().get_clipboard()
            clipboard.set_text(ssh_copy_id_command)

            self.parent_window.show_toast(f"ssh-copy-id command copied!")
            self.close()
        else: # Cancel or closed via 'X'
            self.close()


class GenerateKeyDialog(Adw.Dialog):
    def __init__(self, parent_window, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)
        self.parent_window = parent_window # To call refresh_key_list and show_toast
        self.set_title("Generate New SSH Key")
        # Adw.Dialog uses response buttons.
        self.add_button("Cancel", Gtk.ResponseType.CANCEL)
        self.add_button("Generate", Gtk.ResponseType.OK)
        self.set_default_response(Gtk.ResponseType.OK)
        self.connect("response", self.on_dialog_response)

        self.content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10) # spacing reduced a bit
        self.set_child(self.content_box)

        preferences_group = Adw.PreferencesGroup()
        self.content_box.append(preferences_group)

        # Key Type
        self.key_type_row = Adw.ComboRow(title="Key Type")
        self.key_type_model = Gtk.StringList.new(["Ed25519", "RSA"]) # Add more types if desired
        self.key_type_row.set_model(self.key_type_model)
        self.key_type_row.set_selected(0) # Default to Ed25519
        preferences_group.add(self.key_type_row)

        # Filename
        self.filename_entry = Adw.EntryRow(title="Filename")
        self.filename_entry.set_text("id_ed25519") # Default filename suggestion
        preferences_group.add(self.filename_entry)
        # Connect after filename_entry is created
        self.key_type_row.connect("notify::selected-item", self._on_key_type_changed)

        # Comment
        self.comment_entry = Adw.EntryRow(title="Comment")
        preferences_group.add(self.comment_entry)

        # Passphrase
        self.passphrase_entry = Adw.PasswordEntryRow(title="Passphrase")
        # self.passphrase_entry.set_placeholder_text("Leave blank for no passphrase") # Not available in AdwEntryRow
        self.passphrase_entry.set_show_apply_button(True) # For visibility toggle
        preferences_group.add(self.passphrase_entry)

        # Set dialog size hints if needed, or let it auto-size.
        # self.set_default_size(450, 350) # Adjusted size

    def _on_key_type_changed(self, combo_row, pspec):
        selected_item = combo_row.get_selected_item()
        if selected_item:
            key_type = selected_item.get_string()
            if key_type == "Ed25519":
                self.filename_entry.set_text("id_ed25519")
            elif key_type == "RSA":
                self.filename_entry.set_text("id_rsa")
            # Add more cases if more key types are added

    def on_dialog_response(self, dialog, response_id):
        if response_id == Gtk.ResponseType.OK:
            self.do_generate_key()
        else: # Gtk.ResponseType.CANCEL or closing the dialog (X button)
            self.close()

    def do_generate_key(self):
        key_type_item = self.key_type_row.get_selected_item()
        # get_string() is the correct method for Gtk.StringObject from Gtk.StringList
        key_type = key_type_item.get_string().lower() if key_type_item else None

        if not key_type:
            self.show_error_dialog("Please select a key type.")
            return

        filename = self.filename_entry.get_text().strip()
        if not filename:
            self.show_error_dialog("Filename cannot be empty.")
            # To prevent dialog from closing on OK if validation fails,
            # we might need to stop the response signal or handle it differently.
            # For now, error dialog is shown, but main dialog might still close.
            # A better approach might be to connect to "clicked" of the "Generate" button
            # if using custom buttons, or handle "response" more carefully.
            # For Adw.Dialog, this behavior is standard. User can re-open if needed.
            return

        comment = self.comment_entry.get_text().strip()
        passphrase = self.passphrase_entry.get_text() # No strip for passphrase

        ssh_dir = pathlib.Path.home() / ".ssh"
        if not ssh_dir.exists():
            try:
                # Create ~/.ssh with 700 permissions
                ssh_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            except Exception as e:
                self.show_error_dialog(f"Error creating ~/.ssh directory: {e}")
                return

        full_key_path = ssh_dir / filename

        if full_key_path.exists():
            self.show_error_dialog(f"Error: File already exists at {full_key_path}.\nPlease choose a different filename.")
            return

        cmd = ["ssh-keygen", "-t", key_type, "-f", str(full_key_path), "-C", comment]

        # ssh-keygen requires -N "" for no passphrase, not just omitting -N.
        cmd.extend(["-N", passphrase if passphrase else ""])

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False) # check=False to capture stderr on error
            if result.returncode == 0:
                self.parent_window.show_toast(f"Successfully generated key: {filename}")
                self.parent_window.refresh_key_list()
                self.close() # Close dialog on success
            else:
                error_message = result.stderr.strip() if result.stderr else "Unknown error during key generation."
                # Check for common errors to provide better messages
                if "passphrase is too short" in error_message:
                    error_message = "Passphrase is too short. Please choose a longer one or leave it blank."
                elif "Key D-Bus call timed out" in error_message: # seen with some gnome-keyring issues
                     error_message = "Key generation timed out. This might be an issue with ssh-agent or gnome-keyring."
                self.show_error_dialog(f"Error generating key:\n{error_message}")
        except FileNotFoundError:
            self.show_error_dialog("Error: ssh-keygen command not found. Please ensure OpenSSH client is installed.")
        except Exception as e:
            self.show_error_dialog(f"An unexpected error occurred: {e}")

    def show_error_dialog(self, message):
        # Error dialogs should be transient for this GenerateKeyDialog.
        error_dialog = Adw.MessageDialog(transient_for=self, modal=True)
        error_dialog.set_heading("Key Generation Error")
        error_dialog.set_body(message)
        error_dialog.add_response("ok_error", "OK") # Use a unique response id if needed
        error_dialog.set_default_response("ok_error")
        error_dialog.connect("response", lambda d, r: d.close()) # Simple close on OK
        error_dialog.present()


class KeySmithWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_default_size(600, 400)
        self.set_title("KeySmith")

        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        # self.set_content(self.main_box) will be set to toast_overlay's child

        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)
        self.toast_overlay.set_child(self.main_box)

        header_bar = Adw.HeaderBar()
        self.main_box.append(header_bar)

        refresh_button = Gtk.Button(icon_name="view-refresh-symbolic")
        refresh_button.set_tooltip_text("Refresh SSH key list")
        refresh_button.connect("clicked", self.refresh_key_list)
        header_bar.pack_start(refresh_button)

        generate_button = Gtk.Button(icon_name="document-new-symbolic", label="Generate")
        generate_button.set_tooltip_text("Generate new SSH key pair")
        generate_button.connect("clicked", self.show_generate_key_dialog)
        header_bar.pack_start(generate_button)

        # Container for the list and status page - Gtk.Stack might be better
        # but managing visibility directly is simpler for now.
        self.content_area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, vexpand=True, hexpand=True)
        self.main_box.append(self.content_area)

        self.key_list_box_scrolled_window = Gtk.ScrolledWindow()
        self.key_list_box_scrolled_window.set_vexpand(True)
        self.key_list_box_scrolled_window.set_hexpand(True)
        self.content_area.append(self.key_list_box_scrolled_window)

        self.key_list_box = Gtk.ListBox()
        self.key_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.key_list_box.set_css_classes(["boxed-list"])
        self.key_list_box_scrolled_window.set_child(self.key_list_box)

        # Empty State Status Page
        self.status_page = Adw.StatusPage()
        self.status_page.set_icon_name("dialog-information-symbolic") # Or any other suitable icon
        self.status_page.set_vexpand(True)
        self.status_page.set_hexpand(True)
        self.content_area.append(self.status_page)

        self.refresh_key_list() # Initial load and visibility setup

    def copy_public_key(self, button, pub_key_path):
        try:
            with open(pub_key_path, 'r') as f:
                key_content = f.read()

            clipboard = Gdk.Display.get_default().get_clipboard()
            clipboard.set_text(key_content)

            self.show_toast(f"Copied {pathlib.Path(pub_key_path).name} to clipboard")
        except Exception as e:
            self.show_toast(f"Error copying key: {e}", priority=Adw.ToastPriority.HIGH)

    def show_toast(self, message, priority=Adw.ToastPriority.NORMAL):
        toast = Adw.Toast(title=message)
        toast.set_priority(priority)
        self.toast_overlay.add_toast(toast)

    def show_generate_key_dialog(self, button):
        # Ensure application is available if GenerateKeyDialog needs it (e.g. for app-wide settings)
        # For now, only parent_window is passed.
        dialog = GenerateKeyDialog(parent_window=self)
        dialog.present()

    def add_key_to_list(self, filename, key_type=None, fingerprint=None, full_path=None):
        row = Adw.ActionRow()
        row.set_title(filename)

        subtitle_parts = []
        if key_type and key_type != "N/A":
            subtitle_parts.append(f"Type: {key_type}")
        if fingerprint and fingerprint != "N/A":
            subtitle_parts.append(f"Fingerprint: {fingerprint}")

        row.set_subtitle(" | ".join(subtitle_parts))
        row.set_activatable(False) # We have a specific button for action

        if full_path:
            button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            Gtk.StyleContext.add_class(button_box.get_style_context(), "linked")

            copy_button = Gtk.Button(icon_name="edit-copy-symbolic", label="Copy Key")
            copy_button.set_tooltip_text("Copy public key to clipboard")
            copy_button.set_valign(Gtk.Align.CENTER)
            copy_button.connect("clicked", self.copy_public_key, str(full_path))
            button_box.append(copy_button)

            deploy_button = Gtk.Button(icon_name="network-server-symbolic", label="Deploy Helper")
            deploy_button.set_tooltip_text("Copy ssh-copy-id command to clipboard")
            deploy_button.set_valign(Gtk.Align.CENTER)
            deploy_button.connect("clicked", self.show_deploy_key_dialog, str(full_path))
            button_box.append(deploy_button)

            row.add_suffix(button_box)
            # row.set_activatable_widget(copy_button) # Activating row for copy might be too much with two buttons

        self.key_list_box.append(row)


    def refresh_key_list(self, button=None):
        # Clear existing items from the list_box
        while (child := self.key_list_box.get_first_child()) is not None:
            self.key_list_box.remove(child)

        ssh_dir = pathlib.Path.home() / ".ssh"
        keys_found = False

        if not ssh_dir.exists() or not ssh_dir.is_dir():
            self.status_page.set_title("~/.ssh Directory Not Found")
            self.status_page.set_description("The SSH directory (~/.ssh) could not be found. Keysmith can create it if you generate a new key.")
            # self.status_page.set_icon_name("dialog-error-symbolic") # Optional: more specific icon
            self.key_list_box_scrolled_window.set_visible(False)
            self.status_page.set_visible(True)
            return # Stop here if .ssh dir is not found

        for item in ssh_dir.iterdir():
            if item.is_file() and item.name.endswith(".pub"):
                keys_found = True # A .pub file is found
                try:
                    result = subprocess.run(
                        ["ssh-keygen", "-lf", str(item)],
                        capture_output=True, text=True, check=False
                    )
                    fingerprint_line = result.stdout.strip()
                    if result.returncode == 0 and fingerprint_line:
                        parts = fingerprint_line.split()
                        fingerprint = parts[1] if len(parts) > 1 else "N/A"
                        key_type_comment_part = parts[-1]
                        if key_type_comment_part.startswith('(') and key_type_comment_part.endswith(')'):
                            key_type = key_type_comment_part.strip("()")
                        else:
                            key_type = "Unknown"
                        self.add_key_to_list(item.name, key_type, fingerprint, full_path=item)
                    else:
                        self.add_key_to_list(item.name, "N/A", f"Error: {result.stderr.strip() if result.stderr else 'Could not get fingerprint'}", full_path=item)
                except Exception as e:
                    self.add_key_to_list(item.name, "Error", str(e), full_path=item)

        if not keys_found: # No .pub files were found in the .ssh directory
            self.status_page.set_title("No SSH Keys Found")
            self.status_page.set_description("Press 'Generate Key' to create a new pair, or 'Refresh' if you've added keys manually to ~/.ssh.")
            # self.status_page.set_icon_name("dialog-information-symbolic") # Reset icon if changed above
            self.key_list_box_scrolled_window.set_visible(False)
            self.status_page.set_visible(True)
        else: # Keys were found and added to the list
            self.key_list_box_scrolled_window.set_visible(True)
            self.status_page.set_visible(False)


class KeySmithApplication(Adw.Application):
    def __init__(self, **kwargs):
        super().__init__(application_id="io.github.tobagin.KeySmith",
                         flags=Gio.ApplicationFlags.FLAGS_NONE,
                         **kwargs)

    def do_activate(self):
        win = KeySmithWindow(application=self)
        win.present()

    def do_startup(self):
        Gtk.Application.do_startup(self)

    def do_shutdown(self):
        Gtk.Application.do_shutdown(self)


def main():
    app = KeySmithApplication()
    return app.run(sys.argv)

if __name__ == "__main__":
    sys.exit(main())
