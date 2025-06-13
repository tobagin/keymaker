import unittest
import pathlib
from unittest.mock import MagicMock, patch

# Assuming keysmith.py is in the parent directory or PYTHONPATH is set up
# For this subtask, we might need to adjust imports if running directly,
# or assume it's run in an environment where 'keysmith' module is available.
# To handle this for a direct run, we can add the parent dir to path:
import sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

# It might be necessary to import Gtk and Adw for the test file to run standalone
# if the dialogs are instantiated directly.
# from gi.repository import Gtk # Intentionally removed to avoid _gi import error
# from gi.repository import Adw # Not strictly needed if Adw widgets are fully mocked

# Import the classes to be tested
from keysmith.keysmith import GenerateKeyDialog, DeployKeyDialog, KeySmithWindow


class TestCommandGeneration(unittest.TestCase):

    def test_generate_key_command_ed25519_no_passphrase_no_comment(self):
        # Mock necessary parts of the dialog or its parent
        mock_parent_window = MagicMock(spec=KeySmithWindow) # Use spec for better mocking
        # Mock methods that GenerateKeyDialog calls on parent_window
        mock_parent_window.show_toast = MagicMock()
        mock_parent_window.refresh_key_list = MagicMock()

        # We need to ensure that Adw.ComboRow and its model are handled correctly
        # or that the get_selected_item().get_string() path is fully mocked.
        dialog = GenerateKeyDialog(parent_window=mock_parent_window)

        # Mocking the UI elements' return values
        # For Adw.ComboRow, get_selected_item() returns the Gtk.StringObject, then .get_string()
        mock_string_object = MagicMock()
        mock_string_object.get_string = MagicMock(return_value="Ed25519")
        dialog.key_type_row.get_selected_item = MagicMock(return_value=mock_string_object)

        dialog.filename_entry.get_text = MagicMock(return_value="test_ed25519")
        dialog.comment_entry.get_text = MagicMock(return_value="")
        dialog.passphrase_entry.get_text = MagicMock(return_value="")

        with patch('pathlib.Path.home') as mock_home, \
             patch('pathlib.Path.exists') as mock_path_exists, \
             patch('pathlib.Path.mkdir') as mock_mkdir, \
             patch('subprocess.run') as mock_run:

            mock_home.return_value = pathlib.Path("/fake/home")
            # Ensure the full_key_path.exists() check inside do_generate_key returns False
            mock_path_exists.return_value = False
            # Mock subprocess.run to return a successful result
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

            expected_key_path = "/fake/home/.ssh/test_ed25519"

            dialog.do_generate_key()

            mock_run.assert_called_once()
            args, kwargs = mock_run.call_args
            cmd_list = args[0]

            self.assertIn("ssh-keygen", cmd_list)
            self.assertIn("-t", cmd_list)
            self.assertIn("ed25519", cmd_list)
            self.assertIn("-f", cmd_list)
            self.assertIn(expected_key_path, cmd_list)
            self.assertIn("-N", cmd_list)
            # Ensure the passphrase is the element after "-N"
            self.assertEqual("", cmd_list[cmd_list.index("-N") + 1])
            self.assertIn("-C", cmd_list) # Comment is always added, even if empty
            self.assertEqual("", cmd_list[cmd_list.index("-C") + 1])


    def test_generate_key_command_rsa_with_comment_and_passphrase(self):
        mock_parent_window = MagicMock(spec=KeySmithWindow)
        mock_parent_window.show_toast = MagicMock()
        mock_parent_window.refresh_key_list = MagicMock()

        dialog = GenerateKeyDialog(parent_window=mock_parent_window)

        mock_string_object = MagicMock()
        mock_string_object.get_string = MagicMock(return_value="RSA")
        dialog.key_type_row.get_selected_item = MagicMock(return_value=mock_string_object)

        dialog.filename_entry.get_text = MagicMock(return_value="test_rsa")
        dialog.comment_entry.get_text = MagicMock(return_value="test_comment")
        dialog.passphrase_entry.get_text = MagicMock(return_value="test_pass")

        with patch('pathlib.Path.home') as mock_home, \
             patch('pathlib.Path.exists') as mock_path_exists, \
             patch('pathlib.Path.mkdir') as mock_mkdir, \
             patch('subprocess.run') as mock_run:

            mock_home.return_value = pathlib.Path("/fake/home")
            mock_path_exists.return_value = False # Key file does not exist
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

            expected_key_path = "/fake/home/.ssh/test_rsa"

            dialog.do_generate_key()

            mock_run.assert_called_once()
            args, kwargs = mock_run.call_args
            cmd_list = args[0]

            self.assertIn("ssh-keygen", cmd_list)
            self.assertIn("-t", cmd_list)
            self.assertIn("rsa", cmd_list)
            self.assertIn("-f", cmd_list)
            self.assertIn(expected_key_path, cmd_list)
            self.assertIn("-C", cmd_list)
            self.assertIn("test_comment", cmd_list)
            self.assertIn("-N", cmd_list)
            self.assertIn("test_pass", cmd_list)

    def test_deploy_key_command(self):
        mock_parent_window = MagicMock(spec=KeySmithWindow)
        mock_parent_window.show_toast = MagicMock() # DeployKeyDialog calls parent's show_toast

        pub_key_path = "/fake/home/.ssh/id_ed25519.pub"
        dialog = DeployKeyDialog(parent_window=mock_parent_window, pub_key_path=pub_key_path)

        # Corrected from .remote_address_entry to .remote_address_entry_row
        dialog.remote_address_entry_row.get_text = MagicMock(return_value="user@example.com")

        mock_clipboard = MagicMock()
        mock_display = MagicMock()
        mock_display.get_clipboard = MagicMock(return_value=mock_clipboard)

        # Patch Gdk.Display.get_default() which is called inside on_dialog_response
        with patch('keysmith.keysmith.Gdk.Display.get_default', return_value=mock_display):
             # Simulate "Copy Command" button press
            # Gtk.ResponseType.ACCEPT is -3
            dialog.on_dialog_response(dialog, -3) # Replaced Gtk.ResponseType.ACCEPT

        expected_command = f"ssh-copy-id -i '{pub_key_path}' 'user@example.com'"
        mock_clipboard.set_text.assert_called_once_with(expected_command)
        mock_parent_window.show_toast.assert_called_once_with("ssh-copy-id command copied!")


if __name__ == "__main__":
    # Initializing Gtk is generally not needed for non-UI logic tests if UI components
    # are properly mocked or not instantiated. These tests mock Gtk/Adw interactions.
    unittest.main()
