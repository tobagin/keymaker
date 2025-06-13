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

from datetime import datetime # For date formatting, if used directly in KeyDetailsDialog

# Schema ID, should match the gschema.xml and meson.build
# This should also be the application ID for Adw.Application
SETTINGS_SCHEMA_ID = "io.github.tobagin.KeySmith"

# Forward declare for type hints if used before definition in file
# class KeySmithWindow: pass # Assuming it's defined later or imported

class PreferencesDialog(Adw.PreferencesWindow):
    def __init__(self, parent_window, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)
        self.set_search_enabled(False) # No search needed for these few settings
        self.set_title("Preferences")
        self.set_default_size(480, 320) # Adjusted height slightly

        # Initialize GSettings
        try:
            self.settings = Gio.Settings.new(SETTINGS_SCHEMA_ID)
        except GLib.Error as e:
            print(f"Error loading GSettings schema {SETTINGS_SCHEMA_ID}: {e}")
            self.settings = None
            # Consider showing an error message in the dialog if settings can't be loaded
            # For now, widgets will be created but bindings might fail or be skipped.

        page = Adw.PreferencesPage()
        self.add(page)

        # --- Default Key Generation Settings ---
        group = Adw.PreferencesGroup(title="New Key Defaults")
        page.add(group)

        # Default Key Type
        key_type_model = Gtk.StringList.new(["Ed25519", "RSA"])
        self.default_key_type_row = Adw.ComboRow(
            title="Default Key Type",
            model=key_type_model,
        )
        group.add(self.default_key_type_row)

        if self.settings:
            current_default_type = self.settings.get_string("default-key-type")
            for i, item_str_obj in enumerate(key_type_model): # Use item_str_obj
                if item_str_obj.get_string() == current_default_type:
                    self.default_key_type_row.set_selected(i)
                    break

            self.default_key_type_row.connect("notify::selected-item", self.on_default_key_type_changed) # notify::selected-item is better for Adw.ComboRow
            self.settings.connect(f"changed::default-key-type", self.on_gsettings_key_type_changed)

        # Default RSA Bit Size
        rsa_bits_model = Gtk.StringList.new(["2048", "3072", "4096", "8192"])
        self.default_rsa_bits_row = Adw.ComboRow(
            title="Default RSA Bit Size",
            subtitle="Applies when 'RSA' is the default key type.",
            model=rsa_bits_model,
        )
        group.add(self.default_rsa_bits_row)

        if self.settings:
            current_default_bits = self.settings.get_int("default-rsa-bits")
            for i, item_str_obj in enumerate(rsa_bits_model):
                if item_str_obj.get_string() == str(current_default_bits):
                    self.default_rsa_bits_row.set_selected(i)
                    break

            self.default_rsa_bits_row.connect("notify::selected-item", self.on_default_rsa_bits_changed) # notify::selected-item
            self.settings.connect(f"changed::default-rsa-bits", self.on_gsettings_rsa_bits_changed)

        self.update_rsa_bits_sensitivity() # Call after both rows are initialized

    def on_default_key_type_changed(self, combo_row, pspec):
        if not self.settings: return
        selected_item_obj = combo_row.get_selected_item() # Returns Gtk.StringObject
        if selected_item_obj:
            new_type = selected_item_obj.get_string()
            self.settings.set_string("default-key-type", new_type)
        self.update_rsa_bits_sensitivity()

    def on_gsettings_key_type_changed(self, settings, key_name):
        current_default_type = settings.get_string(key_name)
        model = self.default_key_type_row.get_model()
        for i, item_str_obj in enumerate(model):
            if item_str_obj.get_string() == current_default_type:
                if self.default_key_type_row.get_selected() != i:
                    self.default_key_type_row.set_selected(i)
                break
        # Sensitivity update will be triggered by the set_selected causing notify::selected-item if it changes,
        # or we can call it explicitly if there's a chance it doesn't change but sensitivity still needs update.
        # self.update_rsa_bits_sensitivity() # Already called by the row's signal if selection changes.

    def on_default_rsa_bits_changed(self, combo_row, pspec):
        if not self.settings: return
        selected_item_obj = combo_row.get_selected_item()
        if selected_item_obj:
            new_bits_str = selected_item_obj.get_string()
            try:
                self.settings.set_int("default-rsa-bits", int(new_bits_str))
            except ValueError:
                print(f"Error: Could not convert RSA bits '{new_bits_str}' to int.")

    def on_gsettings_rsa_bits_changed(self, settings, key_name):
        current_default_bits = settings.get_int(key_name)
        model = self.default_rsa_bits_row.get_model()
        for i, item_str_obj in enumerate(model):
            if item_str_obj.get_string() == str(current_default_bits):
                if self.default_rsa_bits_row.get_selected() != i:
                    self.default_rsa_bits_row.set_selected(i)
                break

    def update_rsa_bits_sensitivity(self):
        is_rsa_selected = False
        if self.settings: # Check if settings are available
             # Check if default_key_type_row and its selected_item are not None
            selected_item_obj = self.default_key_type_row.get_selected_item()
            if selected_item_obj:
                is_rsa_selected = (selected_item_obj.get_string() == "RSA")

        self.default_rsa_bits_row.set_sensitive(is_rsa_selected)


class KeyDetailsDialog(Adw.Dialog):
    def __init__(self, parent_window, pub_key_path_str, pub_key_filename, **kwargs):
        super().__init__(transient_for=parent_window, modal=True, **kwargs)

        self.pub_key_path = pathlib.Path(pub_key_path_str)
        self.pub_key_filename = pub_key_filename

        self.set_title("SSH Key Details")
        self.set_default_size(550, 450) # Adjusted width slightly

        page = Adw.PreferencesPage()
        group = Adw.PreferencesGroup()
        page.add(group)

        # Filename (already known)
        self.filename_row = Adw.ActionRow(title="Filename", subtitle=self.pub_key_filename)
        group.add(self.filename_row)

        # Key Type (placeholder, will be filled by data fetching)
        self.key_type_row = Adw.ActionRow(title="Key Type", subtitle="Loading...")
        group.add(self.key_type_row)

        # Bit Size (placeholder)
        self.bit_size_row = Adw.ActionRow(title="Bit Size", subtitle="Loading...")
        group.add(self.bit_size_row)

        # Creation Date (placeholder)
        self.creation_date_row = Adw.ActionRow(title="Last Modified Date", subtitle="Loading...") # Changed to Last Modified
        group.add(self.creation_date_row)

        # Full Comment (placeholder, using ExpanderRow for potentially long comments)
        self.comment_expander = Adw.ExpanderRow(
            title="Comment",
            subtitle="Loading..."
        )
        # Use a Box to avoid ActionRow's inherent styling if just a label is needed.
        comment_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.comment_label = Gtk.Label(wrap=True, xalign=0, selectable=True,
                                       css_classes=['body'], # Use Adwaita text style
                                       margin_top=6, margin_bottom=6, margin_start=6, margin_end=6)
        comment_box.append(self.comment_label)
        self.comment_expander.add_row(comment_box) # Add the box as a row
        group.add(self.comment_expander)


        # Full Public Key (using ExpanderRow and TextView)
        self.pubkey_expander = Adw.ExpanderRow(
            title="Full Public Key Content" # More descriptive title
        )

        pubkey_text_view = Gtk.TextView(
            editable=False,
            wrap_mode=Gtk.WrapMode.WORD_CHAR,
            monospace=True,
            cursor_visible=False,
            left_margin=6, right_margin=6, top_margin=6, bottom_margin=6
        )
        self.pubkey_buffer = pubkey_text_view.get_buffer()
        self.pubkey_buffer.set_text("Loading public key content...")

        scrolled_window = Gtk.ScrolledWindow(
            height_request=150,
            hscrollbar_policy=Gtk.PolicyType.NEVER,
            vscrollbar_policy=Gtk.PolicyType.AUTOMATIC
        )
        scrolled_window.set_child(pubkey_text_view)
        # Adw.ExpanderRow.add_row expects a Gtk.ListBoxRow or Adw.PreferencesRow.
        # To embed custom content like a ScrolledWindow, we can wrap it in an ActionRow
        # or just add the ScrolledWindow if the theme handles it well (often it does).
        # For more control and consistent padding, ActionRow is safer.
        pubkey_content_row = Adw.ActionRow()
        pubkey_content_row.set_child(scrolled_window)
        self.pubkey_expander.add_row(pubkey_content_row)
        group.add(self.pubkey_expander)

        self.set_child(page)

        self.add_response("close", "_Close")
        self.set_default_response("close")
        self.connect("response", lambda dialog, response_id: self.close())

    def update_details(self, details_data):
        self.key_type_row.set_subtitle(details_data.get("key_type", "N/A"))
        self.bit_size_row.set_subtitle(str(details_data.get("bit_size", "N/A"))) # Ensure string
        self.creation_date_row.set_subtitle(details_data.get("creation_date", "N/A"))

        full_comment = details_data.get("full_comment", "N/A")
        is_error_comment = "error" in full_comment.lower() or \
                           "failed" in full_comment.lower() or \
                           "not found" in full_comment.lower() or \
                           full_comment == "N/A" or \
                           full_comment == "Could not parse details from ssh-keygen."

        if full_comment and full_comment != "No comment":
            comment_lines = full_comment.splitlines()
            first_line = comment_lines[0] if comment_lines else ""

            if is_error_comment or full_comment == "N/A":
                self.comment_expander.set_subtitle(first_line) # Show error or N/A directly
            else: # Actual comment content
                self.comment_expander.set_subtitle(first_line[:70] + "..." if len(first_line) > 70 else first_line)

            self.comment_expander.set_visible(True)
            # Expand if it's an error, multi-line, or long. Collapse for "N/A" unless it's an error message.
            self.comment_expander.set_expanded(is_error_comment or len(comment_lines) > 1 or len(full_comment) > 70)
        else: # "No comment" or empty string
            self.comment_expander.set_subtitle("No comment")
            self.comment_expander.set_visible(True)
            self.comment_expander.set_expanded(False)
        self.comment_label.set_text(full_comment if full_comment else "")

        public_key_content = details_data.get("public_key_content", "Error loading key content.")
        self.pubkey_buffer.set_text(public_key_content)

        is_error_pubkey = "error" in public_key_content.lower() or \
                          "failed" in public_key_content.lower() or \
                          "not found" in public_key_content.lower() or \
                          public_key_content == "Could not load public key content."

        # Auto-expand if content is not a known error/placeholder and is somewhat long, or if it is an error.
        self.pubkey_expander.set_expanded(is_error_pubkey or (public_key_content and len(public_key_content) > 100 and not public_key_content.startswith("Could not load")))


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
        self.parent_window = parent_window
        self.set_title("Generate New SSH Key")
        self.set_default_size(450, -1) # Auto height

        # Initialize GSettings
        try:
            self.settings = Gio.Settings.new(SETTINGS_SCHEMA_ID)
        except GLib.Error as e:
            print(f"Error loading GSettings schema {SETTINGS_SCHEMA_ID} in GenerateKeyDialog: {e}")
            self.settings = None

        # Retrieve defaults from GSettings
        self.gsettings_default_key_type = "Ed25519" # Fallback
        self.gsettings_default_rsa_bits = 4096    # Fallback
        if self.settings:
            self.gsettings_default_key_type = self.settings.get_string("default-key-type")
            self.gsettings_default_rsa_bits = self.settings.get_int("default-rsa-bits")

        page = Adw.PreferencesPage()
        content_group = Adw.PreferencesGroup(title="Key Properties") # Changed title
        page.add(content_group)
        self.set_child(page)


        # Key Type Adw.ComboRow
        key_type_model = Gtk.StringList.new(["Ed25519", "RSA"])
        self.key_type_combo_row = Adw.ComboRow(title="Key Type", model=key_type_model)
        content_group.add(self.key_type_combo_row)

        for i, item_str_obj in enumerate(key_type_model):
            if item_str_obj.get_string() == self.gsettings_default_key_type:
                self.key_type_combo_row.set_selected(i)
                break

        # RSA Bit Size Adw.ComboRow - NEW
        rsa_bits_model = Gtk.StringList.new(["2048", "3072", "4096", "8192"])
        self.rsa_bits_combo_row = Adw.ComboRow(
            title="RSA Bit Size",
            model=rsa_bits_model,
            subtitle="Only applies if Key Type is RSA."
        )
        content_group.add(self.rsa_bits_combo_row)

        for i, item_str_obj in enumerate(rsa_bits_model):
            if item_str_obj.get_string() == str(self.gsettings_default_rsa_bits):
                self.rsa_bits_combo_row.set_selected(i)
                break

        self.key_type_combo_row.connect("notify::selected-item", self.on_key_type_selection_changed)

        # Filename Adw.EntryRow
        self.filename_entry = Adw.EntryRow(title="Filename")
        content_group.add(self.filename_entry)

        # Comment Adw.EntryRow
        self.comment_entry = Adw.EntryRow(title="Comment (Optional)")
        content_group.add(self.comment_entry)

        # Passphrase Adw.PasswordEntryRow
        self.passphrase_entry = Adw.PasswordEntryRow(title="Passphrase (Optional)")
        self.passphrase_entry.set_show_apply_button(True)
        content_group.add(self.passphrase_entry)

        self.add_response("cancel", "_Cancel")
        generate_button = self.add_response("generate", "_Generate")
        generate_button.get_style_context().add_class("suggested-action") # Adw.Dialog doesn't use set_response_appearance
        self.set_default_response("generate")
        self.connect("response", self.on_dialog_response)

        self.on_key_type_selection_changed(self.key_type_combo_row) # Call once to set initial state
        # self.update_rsa_bits_row_visibility() # Called by on_key_type_selection_changed

    def on_key_type_selection_changed(self, combo_row, pspec=None):
        selected_item_obj = combo_row.get_selected_item()
        if not selected_item_obj: return

        key_type = selected_item_obj.get_string()
        if key_type == "Ed25519":
            self.filename_entry.set_text("id_ed25519")
        elif key_type == "RSA":
            self.filename_entry.set_text("id_rsa")
        else:
            self.filename_entry.set_text("id_unknown_type")

        self.update_rsa_bits_row_visibility()

    def update_rsa_bits_row_visibility(self):
        selected_item_obj = self.key_type_combo_row.get_selected_item()
        is_rsa = False
        if selected_item_obj:
            key_type = selected_item_obj.get_string()
            is_rsa = (key_type == "RSA")

        self.rsa_bits_combo_row.set_visible(is_rsa)
        self.rsa_bits_combo_row.set_sensitive(is_rsa)

    def on_dialog_response(self, dialog, response_id):
        if response_id == "generate": # Changed from Gtk.ResponseType.OK
            self.do_generate_key()
        else:
            self.close()

    def do_generate_key(self):
        key_type_item_obj = self.key_type_combo_row.get_selected_item()
        if not key_type_item_obj:
            self.show_error_dialog("Please select a key type.")
            return
        key_type = key_type_item_obj.get_string() # No .lower() here, use as is for display, lower for cmd

        filename = self.filename_entry.get_text().strip()
        if not filename:
            self.show_error_dialog("Filename cannot be empty.")
            return

        comment = self.comment_entry.get_text().strip()
        passphrase = self.passphrase_entry.get_text()

        ssh_dir = pathlib.Path.home() / ".ssh"
        if not ssh_dir.exists():
            try:
                ssh_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            except Exception as e:
                self.show_error_dialog(f"Error creating ~/.ssh directory: {str(e)}")
                return

        # Note: filename_entry might not have .pub, but ssh-keygen creates both.
        # We are defining the base name for the key pair.
        full_key_path_base = ssh_dir / filename

        # Check if either potential private or public key file exists to prevent overwrite
        # This check might need refinement if user explicitly adds .pub to filename_entry
        if full_key_path_base.exists() or full_key_path_base.with_suffix(".pub").exists():
            self.show_error_dialog(f"Error: File '{filename}' or '{filename}.pub' already exists in ~/.ssh.\nPlease choose a different filename.")
            return

        cmd = ["ssh-keygen", "-t", key_type.lower()]

        if key_type == "RSA":
            rsa_bits_item_obj = self.rsa_bits_combo_row.get_selected_item()
            if rsa_bits_item_obj:
                rsa_bits = rsa_bits_item_obj.get_string()
                cmd.extend(["-b", rsa_bits])
            else: # Should not happen if row is visible and has a default
                cmd.extend(["-b", str(self.gsettings_default_rsa_bits)])

        cmd.extend(["-f", str(full_key_path_base), "-C", comment])
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

        # main_box will hold HeaderBar and content_area (which holds list/status page)
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        self.toast_overlay = Adw.ToastOverlay()
        self.toast_overlay.set_child(self.main_box) # main_box is child of overlay
        self.set_content(self.toast_overlay) # overlay is content of window

        header_bar = Adw.HeaderBar()
        # self.main_box.append(header_bar) # Prepend for correct order
        self.main_box.prepend(header_bar)


        refresh_button = Gtk.Button(icon_name="view-refresh-symbolic")
        refresh_button.set_tooltip_text("Refresh SSH key list")
        refresh_button.connect("clicked", self.refresh_key_list)
        header_bar.pack_start(refresh_button)

        generate_button = Gtk.Button(icon_name="document-new-symbolic", label="Generate")
        generate_button.set_tooltip_text("Generate new SSH key pair")
        generate_button.connect("clicked", self.show_generate_key_dialog)
        header_bar.pack_start(generate_button) # Added to start, after refresh

        # Create MenuButton for primary menu
        menu_button = Gtk.MenuButton(
            icon_name="open-menu-symbolic",
            tooltip_text="Main Menu"
        )
        header_bar.pack_end(menu_button) # Add to the end of the header bar

        menu_model = Gio.Menu()
        menu_model.append("Preferences", "app.preferences")
        menu_model.append("About KeySmith", "app.about")
        menu_model.append("Quit", "app.quit")
        menu_button.set_menu_model(menu_model)

        # Container for the list and status page
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

            # Add Details button as a separate suffix, not part of the linked group
            details_button = Gtk.Button(icon_name="dialog-information-symbolic")
            details_button.set_tooltip_text("View key details")
            details_button.set_valign(Gtk.Align.CENTER)
            # Optionally make it flat if desired, but default Adw.ActionRow suffix styling is usually good
            # details_button.add_css_class("flat")
            details_button.connect("clicked", self.show_key_details_dialog, str(full_path), filename)
            row.add_suffix(details_button)


        self.key_list_box.append(row)

    def show_confirm_delete_dialog(self, button, pub_key_path_str, pub_key_filename):
        dialog = ConfirmDeleteDialog(self, pub_key_path_str, pub_key_filename)
        dialog.present()

    def show_edit_passphrase_dialog(self, button, pub_key_path_str, pub_key_filename):
        dialog = EditPassphraseDialog(self, pub_key_path_str, pub_key_filename)
        dialog.present()

    def show_key_details_dialog(self, button, pub_key_path_str, pub_key_filename):
        dialog = KeyDetailsDialog(self, pub_key_path_str, pub_key_filename)
        dialog.present()

        # Data fetching logic will be added in the next step (Plan Step 3)
        # For now, the dialog will show "Loading..."
        # Example of how it might be called later:
        # self.fetch_and_display_key_details(dialog, pub_key_path_str)
        # print(f"KeyDetailsDialog presented for {pub_key_filename}. Data loading pending.")
        self.fetch_and_display_key_details(dialog, pub_key_path_str)

    def fetch_and_display_key_details(self, dialog_instance, pub_key_path_str):
        pub_key_path = pathlib.Path(pub_key_path_str)
        details_data = {
            "key_type": "N/A",
            "bit_size": "N/A",
            "full_comment": "N/A", # Default to N/A, changed if found
            "creation_date": "N/A",
            "public_key_content": "Could not load public key content."
        }

        # 1. Read Public Key File Content
        try:
            if pub_key_path.exists() and pub_key_path.is_file():
                with open(pub_key_path, "r") as f:
                    details_data["public_key_content"] = f.read().strip()
            else:
                details_data["public_key_content"] = "Public key file not found or is not a file."
        except Exception as e:
            details_data["public_key_content"] = f"Error reading public key file: {str(e)}"
            print(f"Error reading {pub_key_path}: {e}")

        # 2. Run ssh-keygen -lf <keyfile> for bit size, type, and full comment
        if pub_key_path.exists() and pub_key_path.is_file():
            try:
                cmd = ["ssh-keygen", "-lf", str(pub_key_path)]
                result = subprocess.run(cmd, capture_output=True, text=True, check=False, timeout=5)

                if result.returncode == 0 and result.stdout:
                    parts = result.stdout.strip().split(" ", 2) # bits, fingerprint, comment_and_type
                    if len(parts) >= 3:
                        details_data["bit_size"] = parts[0]
                        # parts[1] is fingerprint
                        comment_and_type_part = parts[2].strip()

                        known_key_types = ["RSA", "DSA", "ECDSA", "ED25519",
                                           "SSH_DSS_KEY", "SSH_RSA_KEY",
                                           "SSK_ECDSA_KEY", "SSH_ED25519_KEY"] # Add more variations if found

                        if comment_and_type_part.endswith(")") and "(" in comment_and_type_part:
                            type_start_index = comment_and_type_part.rfind("(")
                            potential_type = comment_and_type_part[type_start_index+1:-1]
                            # Check if this potential type is known or looks like a type
                            if potential_type.upper() in known_key_types or \
                               any(kt.startswith(potential_type.upper()) for kt in known_key_types) or \
                               len(potential_type) < 15: # Heuristic: types are usually short
                                details_data["key_type"] = potential_type
                                details_data["full_comment"] = comment_and_type_part[:type_start_index].strip()
                            else: # Parentheses might be part of the comment itself
                                details_data["key_type"] = "Unknown"
                                details_data["full_comment"] = comment_and_type_part
                        else: # No parentheses for type
                            words = comment_and_type_part.split()
                            if words and words[-1].upper() in known_key_types:
                                details_data["key_type"] = words[-1]
                                details_data["full_comment"] = " ".join(words[:-1]).strip()
                            elif words and words[0].upper() in known_key_types and ' ' not in words[0]: # e.g. "RSA user@host"
                                details_data["key_type"] = words[0]
                                details_data["full_comment"] = " ".join(words[1:]).strip()
                            else: # Assume all of it is a comment, or type is not clearly separable
                                details_data["key_type"] = "Unknown"
                                details_data["full_comment"] = comment_and_type_part

                        if not details_data["full_comment"] and details_data["full_comment"] != "": # If after parsing, comment is empty string
                            details_data["full_comment"] = "No comment"
                        elif details_data["full_comment"] == "" and details_data["key_type"] == comment_and_type_part : # Case where entire part was taken as type
                            details_data["full_comment"] = "No comment"


                    else: # len(parts) < 3
                        print(f"Could not parse `ssh-keygen -lf` output (not enough parts) for {pub_key_path}: {result.stdout.strip()}")
                        details_data["full_comment"] = "Could not parse details from ssh-keygen output."
                else:
                    stderr_msg = result.stderr.strip() if result.stderr else "Unknown error"
                    print(f"ssh-keygen -lf failed for {pub_key_path}: {stderr_msg}")
                    details_data["full_comment"] = f"Failed to get details via ssh-keygen: {stderr_msg}"
                    # key_type and bit_size remain N/A

            except FileNotFoundError:
                details_data["full_comment"] = "ssh-keygen command not found."
            except subprocess.TimeoutExpired:
                details_data["full_comment"] = "ssh-keygen command timed out while fetching details."
            except Exception as e:
                details_data["full_comment"] = f"Error running ssh-keygen for details: {str(e)}"
                print(f"Error running ssh-keygen for {pub_key_path}: {e}")
        else:
            details_data["full_comment"] = "Public key file not found for ssh-keygen processing."


        # 3. Get File Timestamp (Last Modified)
        try:
            if pub_key_path.exists() and pub_key_path.is_file(): # Re-check existence for safety
                mod_timestamp = os.path.getmtime(pub_key_path)
                # Use datetime.fromtimestamp (note: 'datetime' is the module, 'datetime' is also the class)
                mod_date_obj = datetime.fromtimestamp(mod_timestamp)
                details_data["creation_date"] = mod_date_obj.strftime("%Y-%m-%d %H:%M:%S")
            elif not pub_key_path.exists(): # If it was deleted in the meantime or never existed
                 details_data["creation_date"] = "File no longer exists."
            else: # Path is not a file
                details_data["creation_date"] = "Path is not a file."

        except Exception as e:
            details_data["creation_date"] = f"Error getting file date: {str(e)}"
            print(f"Error getting mtime for {pub_key_path}: {e}")

        GLib.idle_add(dialog_instance.update_details, details_data)


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
        super().__init__(application_id=SETTINGS_SCHEMA_ID, # Use the constant
                         flags=Gio.ApplicationFlags.FLAGS_NONE,
                         **kwargs)
        self.win = None # Keep a reference to the main window

    def do_activate(self):
        # Create and present the main window
        if not self.win:
            self.win = KeySmithWindow(application=self)
        self.win.present()

    def do_startup(self):
        Adw.Application.do_startup(self) # Use Adw.Application for startup

        # Create "preferences" action
        preferences_action = Gio.SimpleAction.new("preferences", None)
        preferences_action.connect("activate", self.on_preferences_action)
        self.add_action(preferences_action)

        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self.on_about_action)
        self.add_action(about_action)

        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self.on_quit_action)
        self.add_action(quit_action)
        self.set_accels_for_action("app.quit", ["<Control>q"])


    def on_preferences_action(self, action, param):
        # Create and show the preferences dialog
        prefs_dialog = PreferencesDialog(parent_window=self.get_active_window())
        prefs_dialog.present()

    def on_about_action(self, action, param):
        # Ensure your application ID matches your icon name if it's used here
        app_icon_name = self.get_application_id() # e.g., "io.github.tobagin.KeySmith"

        about_dialog = Adw.AboutWindow(
            transient_for=self.get_active_window(),
            application_name="KeySmith",
            application_icon=app_icon_name,
            developer_name="tobagin", # Replace with actual name or remove if not desired
            version="0.1.0", # TODO: Get from a central place, e.g. meson.build project version
            # website="https://github.com/tobagin/KeySmith", # Uncomment when available
            # issue_url="https://github.com/tobagin/KeySmith/issues", # Uncomment when available
            copyright="© 2024 Your Name or Project" # Replace
        )
        # Example: Add more details if desired
        # about_dialog.set_developers(["Your Name <your.email@example.com>"])
        # about_dialog.set_license_type(Gtk.License.GPL_3_0_ONLY) # Or your chosen license
        # about_dialog.set_comments("A simple utility to manage SSH keys.")
        about_dialog.present()

    def on_quit_action(self, action, param):
        self.quit()

    def do_shutdown(self):
        Adw.Application.do_shutdown(self) # Use Adw.Application for shutdown


def main():
    app = KeySmithApplication()
    return app.run(sys.argv)

if __name__ == "__main__":
    sys.exit(main())
