"""Test SSH key scanner backend."""

import pytest
import tempfile
from pathlib import Path
from datetime import datetime
from unittest.mock import Mock, patch

from keymaker.models import SSHKey, SSHKeyType, SSHOperationError
from keymaker.backend.key_scanner import (
    scan_ssh_directory,
    refresh_ssh_key_metadata,
    is_ssh_key_file,
    _extract_comment_from_public_key,
    _extract_bit_size,
    _build_ssh_key_model,
)


class TestScanSSHDirectory:
    """Test SSH directory scanning."""
    
    @pytest.mark.asyncio
    async def test_scan_empty_directory(self):
        """Test scanning empty SSH directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            ssh_dir = Path(tmpdir)
            
            keys = await scan_ssh_directory(ssh_dir)
            
            assert keys == []
    
    @pytest.mark.asyncio
    async def test_scan_directory_not_exists(self):
        """Test scanning non-existent directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            nonexistent_dir = Path(tmpdir) / "nonexistent"
            
            keys = await scan_ssh_directory(nonexistent_dir)
            
            assert keys == []
    
    @pytest.mark.asyncio
    async def test_scan_directory_with_key_pairs(self):
        """Test scanning directory with valid key pairs."""
        with tempfile.TemporaryDirectory() as tmpdir:
            ssh_dir = Path(tmpdir)
            
            # Create Ed25519 key pair
            ed25519_private = ssh_dir / "id_ed25519"
            ed25519_public = ssh_dir / "id_ed25519.pub"
            ed25519_private.touch(mode=0o600)
            ed25519_public.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            # Create RSA key pair
            rsa_private = ssh_dir / "id_rsa"
            rsa_public = ssh_dir / "id_rsa.pub"
            rsa_private.touch(mode=0o600)
            rsa_public.write_text("ssh-rsa AAAAB3NzaC1yc2E user@host")
            
            # Create orphaned public key (no private key)
            orphan_public = ssh_dir / "orphan.pub"
            orphan_public.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 orphan@host")
            
            # Create config file (should be ignored)
            config_file = ssh_dir / "config"
            config_file.write_text("Host example.com\n  User myuser")
            
            with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                    # Mock responses based on key type
                    def mock_key_type_side_effect(path):
                        if "ed25519" in str(path):
                            return SSHKeyType.ED25519
                        elif "rsa" in str(path):
                            return SSHKeyType.RSA
                        return SSHKeyType.ED25519
                    
                    def mock_fingerprint_side_effect(path):
                        if "ed25519" in str(path):
                            return "SHA256:ed25519fingerprint"
                        elif "rsa" in str(path):
                            return "SHA256:rsafingerprint"
                        return "SHA256:defaultfingerprint"
                    
                    mock_get_key_type.side_effect = mock_key_type_side_effect
                    mock_get_fingerprint.side_effect = mock_fingerprint_side_effect
                    
                    keys = await scan_ssh_directory(ssh_dir)
                    
                    # Should find 2 complete key pairs
                    assert len(keys) == 2
                    
                    # Verify Ed25519 key
                    ed25519_key = next(k for k in keys if k.key_type == SSHKeyType.ED25519)
                    assert ed25519_key.private_path == ed25519_private
                    assert ed25519_key.public_path == ed25519_public
                    assert ed25519_key.fingerprint == "SHA256:ed25519fingerprint"
                    assert ed25519_key.comment == "user@host"
                    
                    # Verify RSA key
                    rsa_key = next(k for k in keys if k.key_type == SSHKeyType.RSA)
                    assert rsa_key.private_path == rsa_private
                    assert rsa_key.public_path == rsa_public
                    assert rsa_key.fingerprint == "SHA256:rsafingerprint"
                    assert rsa_key.comment == "user@host"
    
    @pytest.mark.asyncio
    async def test_scan_directory_with_invalid_keys(self):
        """Test scanning directory with invalid keys."""
        with tempfile.TemporaryDirectory() as tmpdir:
            ssh_dir = Path(tmpdir)
            
            # Create invalid key (private exists but public doesn't)
            invalid_private = ssh_dir / "invalid_key"
            invalid_private.touch(mode=0o600)
            
            # Create another invalid key (throws exception during processing)
            error_private = ssh_dir / "error_key"
            error_public = ssh_dir / "error_key.pub"
            error_private.touch(mode=0o600)
            error_public.touch()
            
            with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                    # Mock get_key_type to raise exception for error_key
                    def mock_key_type_side_effect(path):
                        if "error_key" in str(path):
                            raise Exception("Mock error")
                        return SSHKeyType.ED25519
                    
                    mock_get_key_type.side_effect = mock_key_type_side_effect
                    mock_get_fingerprint.return_value = "SHA256:fingerprint"
                    
                    keys = await scan_ssh_directory(ssh_dir)
                    
                    # Should find no valid keys
                    assert len(keys) == 0
    
    @pytest.mark.asyncio
    async def test_scan_default_ssh_directory(self):
        """Test scanning default SSH directory."""
        with patch('pathlib.Path.home') as mock_home:
            with tempfile.TemporaryDirectory() as tmpdir:
                mock_home.return_value = Path(tmpdir)
                
                # Create .ssh directory
                ssh_dir = Path(tmpdir) / ".ssh"
                ssh_dir.mkdir()
                
                # Create a key pair
                private_path = ssh_dir / "id_ed25519"
                public_path = ssh_dir / "id_ed25519.pub"
                private_path.touch(mode=0o600)
                public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
                
                with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                    with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                        mock_get_key_type.return_value = SSHKeyType.ED25519
                        mock_get_fingerprint.return_value = "SHA256:fingerprint"
                        
                        keys = await scan_ssh_directory()  # No directory specified
                        
                        assert len(keys) == 1
                        assert keys[0].key_type == SSHKeyType.ED25519


class TestBuildSSHKeyModel:
    """Test SSH key model building."""
    
    @pytest.mark.asyncio
    async def test_build_ssh_key_model_success(self):
        """Test successful SSH key model building."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                    mock_get_key_type.return_value = SSHKeyType.ED25519
                    mock_get_fingerprint.return_value = "SHA256:fingerprint"
                    
                    ssh_key = await _build_ssh_key_model(private_path)
                    
                    assert ssh_key is not None
                    assert ssh_key.private_path == private_path
                    assert ssh_key.public_path == public_path
                    assert ssh_key.key_type == SSHKeyType.ED25519
                    assert ssh_key.fingerprint == "SHA256:fingerprint"
                    assert ssh_key.comment == "user@host"
                    assert ssh_key.bit_size is None
    
    @pytest.mark.asyncio
    async def test_build_ssh_key_model_rsa_with_bits(self):
        """Test building RSA key model with bit size."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_rsa"
            public_path = Path(tmpdir) / "id_rsa.pub"
            
            private_path.touch(mode=0o600)
            public_path.write_text("ssh-rsa AAAAB3NzaC1yc2E user@host")
            
            with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                    with patch('keymaker.backend.key_scanner._extract_bit_size') as mock_extract_bits:
                        mock_get_key_type.return_value = SSHKeyType.RSA
                        mock_get_fingerprint.return_value = "SHA256:rsafingerprint"
                        mock_extract_bits.return_value = 4096
                        
                        ssh_key = await _build_ssh_key_model(private_path)
                        
                        assert ssh_key is not None
                        assert ssh_key.key_type == SSHKeyType.RSA
                        assert ssh_key.bit_size == 4096
    
    @pytest.mark.asyncio
    async def test_build_ssh_key_model_failure(self):
        """Test SSH key model building failure."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "invalid_key"
            private_path.touch(mode=0o600)
            
            with patch('keymaker.backend.key_scanner.get_key_type') as mock_get_key_type:
                mock_get_key_type.side_effect = Exception("Mock error")
                
                ssh_key = await _build_ssh_key_model(private_path)
                
                assert ssh_key is None


class TestExtractCommentFromPublicKey:
    """Test comment extraction from public key."""
    
    def test_extract_comment_success(self):
        """Test successful comment extraction."""
        with tempfile.TemporaryDirectory() as tmpdir:
            public_path = Path(tmpdir) / "id_ed25519.pub"
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            comment = _extract_comment_from_public_key(public_path)
            
            assert comment == "user@host"
    
    def test_extract_comment_multi_word(self):
        """Test extracting multi-word comment."""
        with tempfile.TemporaryDirectory() as tmpdir:
            public_path = Path(tmpdir) / "id_ed25519.pub"
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host with spaces")
            
            comment = _extract_comment_from_public_key(public_path)
            
            assert comment == "user@host with spaces"
    
    def test_extract_comment_no_comment(self):
        """Test extracting comment when none exists."""
        with tempfile.TemporaryDirectory() as tmpdir:
            public_path = Path(tmpdir) / "id_ed25519.pub"
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5")
            
            comment = _extract_comment_from_public_key(public_path)
            
            assert comment is None
    
    def test_extract_comment_file_not_found(self):
        """Test extracting comment from non-existent file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            public_path = Path(tmpdir) / "nonexistent.pub"
            
            comment = _extract_comment_from_public_key(public_path)
            
            assert comment is None


class TestExtractBitSize:
    """Test bit size extraction."""
    
    @pytest.mark.asyncio
    async def test_extract_bit_size_success(self):
        """Test successful bit size extraction."""
        with tempfile.TemporaryDirectory() as tmpdir:
            key_path = Path(tmpdir) / "id_rsa"
            key_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"4096 SHA256:rsafingerprint user@host (RSA)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                bit_size = await _extract_bit_size(key_path)
                
                assert bit_size == 4096
    
    @pytest.mark.asyncio
    async def test_extract_bit_size_failure(self):
        """Test bit size extraction failure."""
        with tempfile.TemporaryDirectory() as tmpdir:
            key_path = Path(tmpdir) / "id_rsa"
            key_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"",
                    b"Invalid key format"
                )
                mock_process.returncode = 1
                mock_exec.return_value = mock_process
                
                bit_size = await _extract_bit_size(key_path)
                
                assert bit_size is None
    
    @pytest.mark.asyncio
    async def test_extract_bit_size_invalid_output(self):
        """Test bit size extraction with invalid output."""
        with tempfile.TemporaryDirectory() as tmpdir:
            key_path = Path(tmpdir) / "id_rsa"
            key_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"invalid output format\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                bit_size = await _extract_bit_size(key_path)
                
                assert bit_size is None


class TestRefreshSSHKeyMetadata:
    """Test SSH key metadata refresh."""
    
    @pytest.mark.asyncio
    async def test_refresh_metadata_success(self):
        """Test successful metadata refresh."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 updated@host")
            
            # Original SSH key
            original_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:old_fingerprint",
                comment="old@host",
                last_modified=datetime.now()
            )
            
            with patch('keymaker.backend.key_scanner.get_fingerprint') as mock_get_fingerprint:
                mock_get_fingerprint.return_value = "SHA256:new_fingerprint"
                
                refreshed_key = await refresh_ssh_key_metadata(original_key)
                
                assert refreshed_key.fingerprint == "SHA256:new_fingerprint"
                assert refreshed_key.comment == "updated@host"
                assert refreshed_key.key_type == SSHKeyType.ED25519
                assert refreshed_key.private_path == private_path
                assert refreshed_key.public_path == public_path
    
    @pytest.mark.asyncio
    async def test_refresh_metadata_private_key_missing(self):
        """Test metadata refresh when private key is missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            # Don't create private key
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:fingerprint",
                last_modified=datetime.now()
            )
            
            with pytest.raises(SSHOperationError, match="Private key no longer exists"):
                await refresh_ssh_key_metadata(ssh_key)
    
    @pytest.mark.asyncio
    async def test_refresh_metadata_public_key_missing(self):
        """Test metadata refresh when public key is missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            # Don't create public key
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:fingerprint",
                last_modified=datetime.now()
            )
            
            with pytest.raises(SSHOperationError, match="Public key no longer exists"):
                await refresh_ssh_key_metadata(ssh_key)


class TestIsSSHKeyFile:
    """Test SSH key file detection."""
    
    def test_is_ssh_key_file_valid_pair(self):
        """Test detecting valid SSH key file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            private_path.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\nkey_data\n-----END OPENSSH PRIVATE KEY-----")
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            assert is_ssh_key_file(private_path) is True
    
    def test_is_ssh_key_file_no_public_key(self):
        """Test detecting SSH key file without public key."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            
            private_path.touch(mode=0o600)
            private_path.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\nkey_data\n-----END OPENSSH PRIVATE KEY-----")
            
            assert is_ssh_key_file(private_path) is False
    
    def test_is_ssh_key_file_config_file(self):
        """Test detecting config file (should not be SSH key)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config"
            config_path.write_text("Host example.com\n  User myuser")
            
            assert is_ssh_key_file(config_path) is False
    
    def test_is_ssh_key_file_public_key(self):
        """Test detecting public key file (should not be SSH key)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            public_path = Path(tmpdir) / "id_ed25519.pub"
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            assert is_ssh_key_file(public_path) is False
    
    def test_is_ssh_key_file_known_hosts(self):
        """Test detecting known_hosts file (should not be SSH key)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            known_hosts_path = Path(tmpdir) / "known_hosts"
            known_hosts_path.write_text("example.com ssh-rsa AAAAB3NzaC1yc2E")
            
            assert is_ssh_key_file(known_hosts_path) is False
    
    def test_is_ssh_key_file_directory(self):
        """Test detecting directory (should not be SSH key)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            dir_path = Path(tmpdir) / "subdir"
            dir_path.mkdir()
            
            assert is_ssh_key_file(dir_path) is False
    
    def test_is_ssh_key_file_invalid_content(self):
        """Test detecting file with invalid SSH key content."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "not_a_key"
            public_path = Path(tmpdir) / "not_a_key.pub"
            
            private_path.write_text("This is not an SSH key")
            public_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")
            
            assert is_ssh_key_file(private_path) is False