"""Test UI components."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
from datetime import datetime

# Mock GTK before importing
mock_gtk = MagicMock()
mock_adw = MagicMock()

with patch.dict('sys.modules', {'gi.repository.Gtk': mock_gtk, 'gi.repository.Adw': mock_adw}):
    from keysmith.models import SSHKey, SSHKeyType, KeyGenerationRequest
    from keysmith.ui.key_row import KeyRow
    from keysmith.ui.key_list import KeyListWidget
    from keysmith.ui.generate_dialog import GenerateKeyDialog
    from keysmith.ui.window import KeySmithWindow


class TestKeyRow:
    """Test SSH key row widget."""
    
    def test_key_row_initialization(self):
        """Test key row initialization."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234",
            comment="user@host",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            # Mock the ActionRow methods
            mock_row = Mock()
            mock_row.set_title = Mock()
            mock_row.set_subtitle = Mock()
            mock_row.set_icon_name = Mock()
            mock_row.add_prefix = Mock()
            mock_row.add_suffix = Mock()
            mock_row.insert_action_group = Mock()
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content') as mock_setup:
                with patch('keysmith.ui.key_row.KeyRow._setup_actions') as mock_actions:
                    row = KeyRow(ssh_key)
                    
                    assert row.ssh_key == ssh_key
                    mock_setup.assert_called_once()
                    mock_actions.assert_called_once()
    
    def test_format_subtitle_ed25519(self):
        """Test subtitle formatting for Ed25519 key."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234efgh5678",
            comment="user@host",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content'):
                with patch('keysmith.ui.key_row.KeyRow._setup_actions'):
                    row = KeyRow(ssh_key)
                    
                    subtitle = row._format_subtitle()
                    
                    assert "ED25519" in subtitle
                    assert "...efgh5678" in subtitle
                    assert "user@host" in subtitle
    
    def test_format_subtitle_rsa_with_bits(self):
        """Test subtitle formatting for RSA key with bit size."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_rsa"),
            public_path=Path("/tmp/id_rsa.pub"),
            key_type=SSHKeyType.RSA,
            fingerprint="SHA256:rsa1234567890",
            comment="user@host",
            last_modified=datetime.now(),
            bit_size=4096
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content'):
                with patch('keysmith.ui.key_row.KeyRow._setup_actions'):
                    row = KeyRow(ssh_key)
                    
                    subtitle = row._format_subtitle()
                    
                    assert "RSA 4096" in subtitle
                    assert "...567890" in subtitle
                    assert "user@host" in subtitle
    
    def test_get_key_icon_ed25519(self):
        """Test getting icon for Ed25519 key."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content'):
                with patch('keysmith.ui.key_row.KeyRow._setup_actions'):
                    row = KeyRow(ssh_key)
                    
                    icon = row._get_key_icon()
                    
                    assert icon == "dialog-password-symbolic"
    
    def test_get_key_icon_rsa(self):
        """Test getting icon for RSA key."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_rsa"),
            public_path=Path("/tmp/id_rsa.pub"),
            key_type=SSHKeyType.RSA,
            fingerprint="SHA256:rsa1234",
            last_modified=datetime.now(),
            bit_size=4096
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content'):
                with patch('keysmith.ui.key_row.KeyRow._setup_actions'):
                    row = KeyRow(ssh_key)
                    
                    icon = row._get_key_icon()
                    
                    assert icon == "security-high-symbolic"
    
    def test_update_key(self):
        """Test updating key data."""
        old_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:old1234",
            comment="old@host",
            last_modified=datetime.now()
        )
        
        new_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:new1234",
            comment="new@host",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_row.Adw.ActionRow.__init__') as mock_init:
            mock_init.return_value = None
            
            mock_row = Mock()
            mock_row.set_title = Mock()
            mock_row.set_subtitle = Mock()
            mock_row.set_icon_name = Mock()
            
            with patch('keysmith.ui.key_row.KeyRow._setup_content'):
                with patch('keysmith.ui.key_row.KeyRow._setup_actions'):
                    with patch('keysmith.ui.key_row.KeyRow._update_prefix_badge'):
                        row = KeyRow(old_key)
                        
                        # Mock the methods
                        row.set_title = Mock()
                        row.set_subtitle = Mock()
                        row.set_icon_name = Mock()
                        
                        row.update_key(new_key)
                        
                        assert row.ssh_key == new_key
                        row.set_title.assert_called_once()
                        row.set_subtitle.assert_called_once()
                        row.set_icon_name.assert_called_once()


class TestKeyListWidget:
    """Test SSH key list widget."""
    
    def test_key_list_initialization(self):
        """Test key list initialization."""
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui') as mock_setup:
                key_list = KeyListWidget()
                
                assert key_list._ssh_keys == []
                assert key_list._key_rows == []
                mock_setup.assert_called_once()
    
    def test_set_keys(self):
        """Test setting SSH keys."""
        ssh_keys = [
            SSHKey(
                private_path=Path("/tmp/id_ed25519"),
                public_path=Path("/tmp/id_ed25519.pub"),
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
        ]
        
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui'):
                with patch('keysmith.ui.key_list.KeyListWidget._refresh_list') as mock_refresh:
                    key_list = KeyListWidget()
                    
                    key_list.set_keys(ssh_keys)
                    
                    assert key_list._ssh_keys == ssh_keys
                    mock_refresh.assert_called_once()
    
    def test_add_key(self):
        """Test adding a new SSH key."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui'):
                with patch('keysmith.ui.key_list.KeyListWidget._add_key_row') as mock_add:
                    key_list = KeyListWidget()
                    
                    key_list.add_key(ssh_key)
                    
                    assert ssh_key in key_list._ssh_keys
                    mock_add.assert_called_once_with(ssh_key)
    
    def test_remove_key(self):
        """Test removing an SSH key."""
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234",
            last_modified=datetime.now()
        )
        
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui'):
                key_list = KeyListWidget()
                key_list._ssh_keys = [ssh_key]
                
                mock_row = Mock()
                key_list._key_rows = [mock_row]
                key_list.listbox = Mock()
                
                key_list.remove_key(ssh_key)
                
                assert ssh_key not in key_list._ssh_keys
                assert len(key_list._key_rows) == 0
                key_list.listbox.remove.assert_called_once_with(mock_row)
    
    def test_is_empty(self):
        """Test checking if key list is empty."""
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui'):
                key_list = KeyListWidget()
                
                assert key_list.is_empty() is True
                
                ssh_key = SSHKey(
                    private_path=Path("/tmp/id_ed25519"),
                    public_path=Path("/tmp/id_ed25519.pub"),
                    key_type=SSHKeyType.ED25519,
                    fingerprint="SHA256:abcd1234",
                    last_modified=datetime.now()
                )
                
                key_list._ssh_keys = [ssh_key]
                
                assert key_list.is_empty() is False
    
    def test_get_key_count(self):
        """Test getting key count."""
        with patch('keysmith.ui.key_list.Gtk.Box.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.key_list.KeyListWidget._setup_ui'):
                key_list = KeyListWidget()
                
                assert key_list.get_key_count() == 0
                
                ssh_key = SSHKey(
                    private_path=Path("/tmp/id_ed25519"),
                    public_path=Path("/tmp/id_ed25519.pub"),
                    key_type=SSHKeyType.ED25519,
                    fingerprint="SHA256:abcd1234",
                    last_modified=datetime.now()
                )
                
                key_list._ssh_keys = [ssh_key]
                
                assert key_list.get_key_count() == 1


class TestGenerateKeyDialog:
    """Test key generation dialog."""
    
    def test_dialog_initialization(self):
        """Test dialog initialization."""
        mock_parent = Mock()
        
        with patch('keysmith.ui.generate_dialog.Adw.PreferencesWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.generate_dialog.GenerateKeyDialog._setup_ui') as mock_setup:
                dialog = GenerateKeyDialog(mock_parent)
                
                assert dialog._generating is False
                mock_setup.assert_called_once()
    
    def test_create_generation_request_ed25519(self):
        """Test creating generation request for Ed25519."""
        mock_parent = Mock()
        
        with patch('keysmith.ui.generate_dialog.Adw.PreferencesWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.generate_dialog.GenerateKeyDialog._setup_ui'):
                dialog = GenerateKeyDialog(mock_parent)
                
                # Mock UI components
                dialog.key_type_row = Mock()
                dialog.key_type_row.get_selected.return_value = 0  # Ed25519
                dialog.filename_row = Mock()
                dialog.filename_row.get_text.return_value = "test_key"
                dialog.comment_row = Mock()
                dialog.comment_row.get_text.return_value = "test@host"
                dialog.passphrase_switch = Mock()
                dialog.passphrase_switch.get_active.return_value = False
                
                request = dialog._create_generation_request()
                
                assert request.key_type == SSHKeyType.ED25519
                assert request.filename == "test_key"
                assert request.comment == "test@host"
                assert request.passphrase is None
    
    def test_create_generation_request_rsa(self):
        """Test creating generation request for RSA."""
        mock_parent = Mock()
        
        with patch('keysmith.ui.generate_dialog.Adw.PreferencesWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.generate_dialog.GenerateKeyDialog._setup_ui'):
                dialog = GenerateKeyDialog(mock_parent)
                
                # Mock UI components
                dialog.key_type_row = Mock()
                dialog.key_type_row.get_selected.return_value = 1  # RSA
                dialog.rsa_bits_row = Mock()
                dialog.rsa_bits_row.get_selected.return_value = 2  # 4096 bits
                dialog.filename_row = Mock()
                dialog.filename_row.get_text.return_value = "rsa_key"
                dialog.comment_row = Mock()
                dialog.comment_row.get_text.return_value = "rsa@host"
                dialog.passphrase_switch = Mock()
                dialog.passphrase_switch.get_active.return_value = True
                dialog.passphrase_row = Mock()
                dialog.passphrase_row.get_text.return_value = "secret123"
                
                request = dialog._create_generation_request()
                
                assert request.key_type == SSHKeyType.RSA
                assert request.filename == "rsa_key"
                assert request.comment == "rsa@host"
                assert request.passphrase == "secret123"
                assert request.rsa_bits == 4096
    
    def test_validate_filename(self):
        """Test filename validation."""
        mock_parent = Mock()
        
        with patch('keysmith.ui.generate_dialog.Adw.PreferencesWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.generate_dialog.GenerateKeyDialog._setup_ui'):
                dialog = GenerateKeyDialog(mock_parent)
                
                # Valid filenames
                assert dialog._validate_filename("id_ed25519") is True
                assert dialog._validate_filename("my-key") is True
                assert dialog._validate_filename("key.backup") is True
                assert dialog._validate_filename("key123") is True
                
                # Invalid filenames
                assert dialog._validate_filename("") is False
                assert dialog._validate_filename("invalid/name") is False
                assert dialog._validate_filename("a" * 256) is False


class TestKeySmithWindow:
    """Test main application window."""
    
    def test_window_initialization(self):
        """Test window initialization."""
        mock_app = Mock()
        
        with patch('keysmith.ui.window.Adw.ApplicationWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.window.KeySmithWindow._setup_ui') as mock_setup:
                window = KeySmithWindow(mock_app)
                
                assert window._loop is None
                mock_setup.assert_called_once()
    
    def test_format_key_details(self):
        """Test formatting key details."""
        mock_app = Mock()
        
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_ed25519"),
            public_path=Path("/tmp/id_ed25519.pub"),
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:abcd1234",
            comment="user@host",
            last_modified=datetime.now(),
            bit_size=None
        )
        
        with patch('keysmith.ui.window.Adw.ApplicationWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.window.KeySmithWindow._setup_ui'):
                window = KeySmithWindow(mock_app)
                
                details = window._format_key_details(ssh_key)
                
                assert "Type: ED25519" in details
                assert "SHA256:abcd1234" in details
                assert "user@host" in details
                assert "/tmp/id_ed25519" in details
                assert "/tmp/id_ed25519.pub" in details
    
    def test_format_key_details_rsa_with_bits(self):
        """Test formatting key details for RSA with bit size."""
        mock_app = Mock()
        
        ssh_key = SSHKey(
            private_path=Path("/tmp/id_rsa"),
            public_path=Path("/tmp/id_rsa.pub"),
            key_type=SSHKeyType.RSA,
            fingerprint="SHA256:rsa1234",
            comment="user@host",
            last_modified=datetime.now(),
            bit_size=4096
        )
        
        with patch('keysmith.ui.window.Adw.ApplicationWindow.__init__') as mock_init:
            mock_init.return_value = None
            
            with patch('keysmith.ui.window.KeySmithWindow._setup_ui'):
                window = KeySmithWindow(mock_app)
                
                details = window._format_key_details(ssh_key)
                
                assert "Type: RSA" in details
                assert "Bit Size: 4096" in details
                assert "SHA256:rsa1234" in details