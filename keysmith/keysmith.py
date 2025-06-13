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


class EditPassphraseDialog(Adw.Dialog):
    def __init__(self, parent_window, pub_key_path_str, pub_key_filename, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)

        self.pub_key_path = pathlib.Path(pub_key_path_str) # Path to the public key
        self.pub_key_filename = pub_key_filename

        # Determine private key filename. ssh-keygen -p -f operates on the private key.
        # The pub_key_path_str is for the .pub file, so we derive the private key path from it.
        if self.pub_key_filename.endswith(".pub"):
            self.priv_key_filename = self.pub_key_filename[:-4]
        else:
            # This case implies pub_key_filename might already be the private key name,
            # or it's a name without .pub extension. Assume it's the base for private key.
            self.priv_key_filename = self.pub_key_filename

        # The actual private key path needed for ssh-keygen -p -f
        self.priv_key_path = self.pub_key_path.with_name(self.priv_key_filename)


        self.set_title("Change SSH Key Passphrase")
        self.set_default_size(450, -1)

        page = Adw.PreferencesPage()
        content_group = Adw.PreferencesGroup()
        page.add(content_group)

        filename_row = Adw.ActionRow(
            title="Key File", # Using ActionRow to display non-editable info
            subtitle=self.priv_key_filename # Display the private key filename
        )
        content_group.add(filename_row)

        self.old_passphrase_entry = Adw.PasswordEntryRow(
            title="Current Passphrase", # "Old" implies it must exist, "Current" is more neutral
            subtitle="Leave blank if key has no current passphrase."
        )
        content_group.add(self.old_passphrase_entry)

        self.new_passphrase_entry = Adw.PasswordEntryRow(
            title="New Passphrase",
            subtitle="Leave blank to remove existing passphrase."
        )
        content_group.add(self.new_passphrase_entry)

        self.confirm_passphrase_entry = Adw.PasswordEntryRow(
            title="Confirm New Passphrase"
        )
        content_group.add(self.confirm_passphrase_entry)

        self.set_child(page)

        self.add_response("cancel", "_Cancel")
        self.change_button = self.add_response("change", "_Change Passphrase")
        # self.change_button.add_css_class("suggested-action") # This is done by ResponseAppearance

        self.set_response_appearance("change", Adw.ResponseAppearance.SUGGESTED)
        self.set_default_response("cancel") # Changed from "change" for safer default

        self.new_passphrase_entry.connect("notify::text", self.validate_passphrases)
        self.confirm_passphrase_entry.connect("notify::text", self.validate_passphrases)

        self.connect("response", self.on_dialog_response)

        self.validate_passphrases() # Initial validation

    def validate_passphrases(self, widget=None, pspec=None): # Added pspec for notify::text
        new_pass = self.new_passphrase_entry.get_text()
        confirm_pass = self.confirm_passphrase_entry.get_text()
        self.set_response_enabled("change", new_pass == confirm_pass)

    def on_dialog_response(self, dialog, response_id):
        parent_window = self.get_transient_for() # KeySmithWindow instance

        if response_id == "change":
            old_passphrase = self.old_passphrase_entry.get_text()
            new_passphrase = self.new_passphrase_entry.get_text()

            if not hasattr(self, 'priv_key_path') or not self.priv_key_path: # Initial check for attribute
                error_body_msg = "Internal error: Private key path not determined."
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, modal=True,
                    heading="Error", body=error_body_msg
                )
                error_dialog.add_response("ok_internal_err", "_Ok")
                error_dialog.set_default_response("ok_internal_err")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
                self.close() # Close the EditPassphraseDialog
                return

            if not self.priv_key_path.exists():
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, modal=True,
                    heading="Error",
                    body=f"Private key file '{self.priv_key_path.name}' not found or is inaccessible. Cannot change passphrase."
                )
                error_dialog.add_response("ok_priv_nf", "_Ok")
                error_dialog.set_default_response("ok_priv_nf")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
                self.close()
                return

            cmd = [
                "ssh-keygen",
                "-p", # Change passphrase
                "-f", str(self.priv_key_path), # Private key file
                "-P", old_passphrase,          # Old passphrase
                "-N", new_passphrase           # New passphrase
            ]

            print(f"Executing command: ssh-keygen -p -f {self.priv_key_path} -P '****' -N '****'") # Avoid logging passphrases

            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=False, timeout=15) # Increased timeout slightly

                if result.returncode == 0:
                    if parent_window and hasattr(parent_window, 'show_toast'):
                        parent_window.show_toast(
                            f"Passphrase for '{self.priv_key_filename}' changed successfully.",
                            Adw.ToastPriority.NORMAL
                        )
                else:
                    error_message = f"Failed to change passphrase for '{self.priv_key_filename}'.\n\n"
                    stderr_lower = result.stderr.lower() if result.stderr else ""

                    if "bad old passphrase" in stderr_lower or "incorrect passphrase" in stderr_lower:
                         error_message = f"The current passphrase provided was incorrect for '{self.priv_key_filename}'."
                    elif "load key" in stderr_lower and "failed" in stderr_lower:
                        error_message += f"Failed to load key '{self.priv_key_filename}'. It might be corrupted or not a valid private key."
                    elif result.stderr and result.stderr.strip(): # Fallback to raw stderr if specific error not matched
                        error_message += f"Details: {result.stderr.strip()}"
                    else:
                        error_message += "Unknown error from ssh-keygen."

                    error_dialog = Adw.MessageDialog(
                        transient_for=parent_window, modal=True,
                        heading="Passphrase Change Failed",
                        body=error_message
                    )
                    error_dialog.add_response("ok_err_change", "_Ok")
                    error_dialog.set_default_response("ok_err_change")
                    error_dialog.connect("response", lambda d, r: d.close())
                    error_dialog.present()
                    print(f"ssh-keygen error (Return Code: {result.returncode}): {result.stderr}")

            except FileNotFoundError:
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, modal=True,
                    heading="Command Error", body="`ssh-keygen` command not found. Please ensure OpenSSH client tools are installed and in your system's PATH."
                )
                error_dialog.add_response("ok_fnf", "_Ok")
                error_dialog.set_default_response("ok_fnf")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
            except subprocess.TimeoutExpired:
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, modal=True,
                    heading="Timeout Error", body=f"The command to change passphrase for '{self.priv_key_filename}' timed out."
                )
                error_dialog.add_response("ok_timeout", "_Ok")
                error_dialog.set_default_response("ok_timeout")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
            except Exception as e:
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, modal=True,
                    heading="Unexpected Error",
                    body=f"An unexpected error occurred while trying to change the passphrase: {str(e)}"
                )
                error_dialog.add_response("ok_unexpected", "_Ok")
                error_dialog.set_default_response("ok_unexpected")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
                print(f"Unexpected error during passphrase change: {e}")

        elif response_id == "cancel":
            if parent_window and hasattr(parent_window, 'show_toast'):
                parent_window.show_toast(
                    f"Passphrase change for '{self.priv_key_filename}' cancelled.",
                    Adw.ToastPriority.NORMAL
                )

        self.close()


class ConfirmDeleteDialog(Adw.Dialog):
    def __init__(self, parent_window, pub_key_path_str, pub_key_filename, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)

        self.pub_key_path = pathlib.Path(pub_key_path_str)
        self.pub_key_filename = pub_key_filename

        # Determine private key filename (remove .pub if present)
        if self.pub_key_filename.endswith(".pub"):
            self.priv_key_filename = self.pub_key_filename[:-4]
        else:
            # Should not happen if we always pass .pub filename, but as a fallback
            self.priv_key_filename = self.pub_key_filename + "_private"

        self.set_title("Confirm Key Deletion")
        self.set_default_size(450, -1) # Width, height auto, adjusted width

        # Content for the dialog
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        content_box.set_margin_top(18) # Increased margin
        content_box.set_margin_bottom(18)
        content_box.set_margin_start(18)
        content_box.set_margin_end(18)

        # Warning Icon and Label
        warning_image = Gtk.Image(icon_name="dialog-warning-symbolic")
        warning_image.set_pixel_size(48) # Use pixel_size for better control
        content_box.append(warning_image)

        main_warning_label = Gtk.Label(wrap=True, justify=Gtk.Justification.CENTER)
        main_warning_label.set_markup("<b>You are about to permanently delete an SSH key pair.</b>")
        content_box.append(main_warning_label)

        files_label = Gtk.Label(wrap=True, justify=Gtk.Justification.CENTER)
        files_text = "The following files will be deleted:\n" # Use \n for newlines in Gtk.Label
        files_text += f"• Public key: <b>{self.pub_key_filename}</b>\n"
        files_text += f"• Private key: <b>{self.priv_key_filename}</b>"
        files_label.set_markup(files_text)
        content_box.append(files_label)

        irreversible_label = Gtk.Label(wrap=True, justify=Gtk.Justification.CENTER,
                                       label="This action is irreversible. Are you sure you want to proceed?")
        content_box.append(irreversible_label)

        self.set_child(content_box)

        # Dialog Actions/Responses
        self.add_response("cancel", "_Cancel")
        delete_response_button = self.add_response("delete", "_Delete Key Pair")
        # delete_response_button.add_css_class("destructive-action") # Provided by ResponseAppearance

        self.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
        self.set_default_response("cancel")
        self.connect("response", self.on_dialog_response)

    def on_dialog_response(self, dialog, response_id):
        parent_window = self.get_transient_for() # KeySmithWindow instance

        if response_id == "delete":
            priv_key_path = self.pub_key_path.with_name(self.priv_key_filename)
            files_deleted_successfully = True
            error_message = ""

            deleted_pub = False
            deleted_priv = False
            pub_existed = self.pub_key_path.exists()
            priv_existed = priv_key_path.exists()

            try:
                # Delete public key
                if pub_existed:
                    os.remove(self.pub_key_path)
                    print(f"Successfully deleted public key: {self.pub_key_path}")
                    deleted_pub = True
                else:
                    print(f"Public key not found, skipping deletion: {self.pub_key_path}")

                # Delete private key
                if priv_existed:
                    os.remove(priv_key_path)
                    print(f"Successfully deleted private key: {priv_key_path}")
                    deleted_priv = True
                else:
                    print(f"Private key not found, skipping deletion: {priv_key_path}")

                if not pub_existed and not priv_existed: # Neither file existed initially
                    error_message = f"Error: Neither public key '{self.pub_key_filename}' nor private key '{self.priv_key_filename}' were found."
                    files_deleted_successfully = False
                elif not deleted_pub and not deleted_priv and (pub_existed or priv_existed): # Files existed but failed to delete (covered by specific exceptions)
                    # This case should ideally be caught by specific exceptions below.
                    # If it's reached, it implies an issue not caught by os.remove exceptions.
                    pass
                elif not (deleted_pub and pub_existed) and not (deleted_priv and priv_existed) and (pub_existed or priv_existed):
                    # This means at least one existed but wasn't deleted, and no specific error was caught
                    # This is a fallback, usually PermissionError etc. would be more specific
                    error_message = "An unknown error occurred during deletion. Not all parts of the key pair were removed."
                    files_deleted_successfully = False


            except FileNotFoundError: # Should ideally not happen if .exists() is checked, but as a safeguard
                error_message = f"Error: File not found during deletion. A key file might have been removed externally."
                files_deleted_successfully = False
            except PermissionError:
                error_message = "Error: Permission denied. Could not delete key files."
                files_deleted_successfully = False
            except Exception as e:
                error_message = f"An unexpected error occurred: {e}"
                files_deleted_successfully = False

            if files_deleted_successfully and (deleted_pub or deleted_priv): # At least one part of pair was deleted
                parent_window.show_toast(
                    f"Key pair for '{self.pub_key_filename}' deleted.",
                    Adw.ToastPriority.NORMAL
                )
                parent_window.refresh_key_list()
            elif files_deleted_successfully and not pub_existed and not priv_existed: # No files existed, but no error deleting them
                 parent_window.show_toast(
                    f"Key pair for '{self.pub_key_filename}' already removed.",
                    Adw.ToastPriority.NORMAL
                )
                 parent_window.refresh_key_list() # Refresh to ensure UI consistency
            else:
                # Show a more prominent error dialog for deletion failure
                error_dialog = Adw.MessageDialog(
                    transient_for=parent_window, # Attach to main window
                    modal=True,
                    heading="Deletion Failed",
                    body=error_message if error_message else "Failed to delete one or both key files." # Default if no specific msg
                )
                error_dialog.add_response("ok_err_delete", "_Ok")
                error_dialog.set_default_response("ok_err_delete")
                error_dialog.connect("response", lambda d, r: d.close())
                error_dialog.present()
                print(f"Deletion failed: {error_message}")

        elif response_id == "cancel":
            if parent_window and hasattr(parent_window, 'show_toast'):
                parent_window.show_toast(
                    f"Deletion of '{self.pub_key_filename}' cancelled.",
                    Adw.ToastPriority.NORMAL
                )

        self.close()


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

            edit_passphrase_button = Gtk.Button(icon_name="dialog-password-symbolic")
            edit_passphrase_button.set_tooltip_text("Change passphrase for this SSH key")
            edit_passphrase_button.set_valign(Gtk.Align.CENTER)
            edit_passphrase_button.connect("clicked", self.show_edit_passphrase_dialog, str(full_path), filename)
            button_box.append(edit_passphrase_button) # Added before delete button

            delete_button = Gtk.Button(icon_name="user-trash-symbolic")
            delete_button.add_css_class("destructive-action")
            delete_button.set_tooltip_text("Delete this SSH key pair (public and private)")
            delete_button.set_valign(Gtk.Align.CENTER)
            delete_button.connect("clicked", self.show_confirm_delete_dialog, str(full_path), filename)
            button_box.append(delete_button)

            row.add_suffix(button_box)
            # row.set_activatable_widget(copy_button) # Activating row for copy might be too much with multiple buttons

        self.key_list_box.append(row)

    def show_confirm_delete_dialog(self, button, pub_key_path_str, pub_key_filename):
        dialog = ConfirmDeleteDialog(self, pub_key_path_str, pub_key_filename)
        dialog.present()

    def show_edit_passphrase_dialog(self, button, pub_key_path_str, pub_key_filename):
        dialog = EditPassphraseDialog(self, pub_key_path_str, pub_key_filename)
        dialog.present()

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
