"""Integration tests for Key Maker workflows.

These tests exercise complete workflows including UI interactions,
backend operations, and file system operations in a controlled environment.
"""

import pytest
import tempfile
import asyncio
import os
import shutil
from pathlib import Path
from unittest.mock import patch, Mock
from gi.repository import Gtk, Adw, GLib

from keymaker.models import (
    SSHKey,
    SSHKeyType,
    KeyGenerationRequest,
    PassphraseChangeRequest,
    KeyDeletionRequest,
    SSHOperationError,
)
from keymaker.backend.ssh_operations import (
    generate_key,
    delete_key_pair,
    change_passphrase,
)
from keymaker.backend.key_scanner import scan_ssh_directory
from keymaker.ui.window import KeyMakerWindow
from keymaker.ui.generate_dialog import GenerateKeyDialog


class TestKeyGenerationWorkflow:
    """Test complete key generation workflow."""
    
    def setup_method(self):
        """Set up test environment."""
        # Create temporary SSH directory
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        # Patch Path.home() to use temp directory
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    @pytest.mark.asyncio
    async def test_end_to_end_key_generation(self):
        """Test complete key generation from request to file creation."""
        # Create key generation request
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="test_integration",
            comment="integration-test@keymaker.local",
            passphrase=None
        )
        
        # Mock ssh-keygen subprocess call
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            # Create mock key files
            private_key_path = self.ssh_dir / "test_integration"
            public_key_path = self.ssh_dir / "test_integration.pub"
            
            # Mock process
            mock_process = Mock()
            mock_process.communicate = asyncio.coroutine(
                lambda: (b"Generating key pair\n", b"")
            )
            mock_process.returncode = 0
            mock_exec.return_value = mock_process
            
            # Create the actual files that ssh-keygen would create
            def create_key_files(*args, **kwargs):
                private_key_path.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\n"
                                          "mock_private_key_content\n"
                                          "-----END OPENSSH PRIVATE KEY-----\n")
                private_key_path.chmod(0o600)
                
                public_key_path.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI"
                                         "mock_public_key_content integration-test@keymaker.local\n")
                return mock_process
            
            mock_exec.side_effect = create_key_files
            
            # Mock fingerprint generation
            with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                mock_fingerprint.return_value = "SHA256:mock_fingerprint_hash"
                
                # Execute key generation
                ssh_key = await generate_key(request)
                
                # Verify key object
                assert ssh_key.private_path == private_key_path
                assert ssh_key.public_path == public_key_path
                assert ssh_key.key_type == SSHKeyType.ED25519
                assert ssh_key.fingerprint == "SHA256:mock_fingerprint_hash"
                assert ssh_key.comment == "integration-test@keymaker.local"
                
                # Verify files exist
                assert private_key_path.exists()
                assert public_key_path.exists()
                
                # Verify permissions
                assert oct(private_key_path.stat().st_mode)[-3:] == "600"
    
    @pytest.mark.asyncio 
    async def test_key_generation_with_passphrase(self):
        """Test key generation with passphrase protection."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.RSA,
            filename="test_rsa_protected",
            comment="protected-test@keymaker.local",
            passphrase="test_passphrase_123",
            rsa_bits=2048
        )
        
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            private_key_path = self.ssh_dir / "test_rsa_protected"
            public_key_path = self.ssh_dir / "test_rsa_protected.pub"
            
            def create_protected_key_files(*args, **kwargs):
                # Verify passphrase was passed correctly
                assert "test_passphrase_123" in args[0]
                
                private_key_path.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\n"
                                          "Proc-Type: 4,ENCRYPTED\n"
                                          "mock_encrypted_private_key_content\n"
                                          "-----END OPENSSH PRIVATE KEY-----\n")
                private_key_path.chmod(0o600)
                
                public_key_path.write_text("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB"
                                         "mock_rsa_public_key_content protected-test@keymaker.local\n")
                
                mock_process = Mock()
                mock_process.communicate = asyncio.coroutine(lambda: (b"", b""))
                mock_process.returncode = 0
                return mock_process
            
            mock_exec.side_effect = create_protected_key_files
            
            with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                mock_fingerprint.return_value = "SHA256:mock_rsa_fingerprint"
                
                ssh_key = await generate_key(request)
                
                assert ssh_key.key_type == SSHKeyType.RSA
                assert ssh_key.bit_size == 2048
                assert private_key_path.exists()
                assert public_key_path.exists()
    
    @pytest.mark.asyncio
    async def test_key_generation_error_handling(self):
        """Test error handling during key generation."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="existing_key",
        )
        
        # Create existing key to trigger error
        existing_private = self.ssh_dir / "existing_key"
        existing_private.touch()
        
        with pytest.raises(SSHOperationError) as exc_info:
            await generate_key(request)
        
        assert "already exists" in str(exc_info.value)


class TestKeyDeletionWorkflow:
    """Test complete key deletion workflow."""
    
    def setup_method(self):
        """Set up test environment."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    @pytest.mark.asyncio
    async def test_complete_key_deletion(self):
        """Test complete key pair deletion."""
        # Create test key files
        private_key = self.ssh_dir / "delete_test"
        public_key = self.ssh_dir / "delete_test.pub"
        
        private_key.write_text("mock private key")
        private_key.chmod(0o600)
        public_key.write_text("mock public key")
        
        # Create SSH key object
        ssh_key = SSHKey(
            private_path=private_key,
            public_path=public_key,
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:test_fingerprint",
            last_modified=datetime.now()
        )
        
        # Verify files exist before deletion
        assert private_key.exists()
        assert public_key.exists()
        
        # Delete key pair
        await delete_key_pair(ssh_key)
        
        # Verify files are deleted
        assert not private_key.exists()
        assert not public_key.exists()
    
    @pytest.mark.asyncio
    async def test_partial_key_deletion(self):
        """Test deletion when only private key exists."""
        private_key = self.ssh_dir / "partial_test"
        
        private_key.write_text("mock private key")
        private_key.chmod(0o600)
        
        ssh_key = SSHKey(
            private_path=private_key,
            public_path=self.ssh_dir / "partial_test.pub",  # Doesn't exist
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:test_fingerprint",
            last_modified=datetime.now()
        )
        
        # Should not raise error even if public key doesn't exist
        await delete_key_pair(ssh_key)
        
        assert not private_key.exists()


class TestPassphraseChangeWorkflow:
    """Test passphrase change workflow."""
    
    def setup_method(self):
        """Set up test environment."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    @pytest.mark.asyncio
    async def test_passphrase_change_workflow(self):
        """Test changing key passphrase."""
        # Create test key
        private_key = self.ssh_dir / "passphrase_test"
        private_key.write_text("mock private key")
        private_key.chmod(0o600)
        
        ssh_key = SSHKey(
            private_path=private_key,
            public_path=self.ssh_dir / "passphrase_test.pub",
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:test_fingerprint",
            last_modified=datetime.now()
        )
        
        request = PassphraseChangeRequest(
            ssh_key=ssh_key,
            current_passphrase="old_pass",
            new_passphrase="new_pass"
        )
        
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            mock_process = Mock()
            mock_process.communicate = asyncio.coroutine(
                lambda input_data: (b"Key passphrase changed\n", b"")
            )
            mock_process.returncode = 0
            mock_exec.return_value = mock_process
            
            # Should not raise an error
            await change_passphrase(request)
            
            # Verify ssh-keygen was called with correct parameters
            mock_exec.assert_called_once()
            args = mock_exec.call_args[0]
            assert "ssh-keygen" in args[0]
            assert "-p" in args
            assert str(private_key) in args


class TestKeyScanningWorkflow:
    """Test key scanning and discovery workflow."""
    
    def setup_method(self):
        """Set up test environment."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    @pytest.mark.asyncio
    async def test_scan_multiple_keys(self):
        """Test scanning directory with multiple key types."""
        # Create various key files
        keys_to_create = [
            ("id_ed25519", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5"),
            ("id_rsa", "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB"),
            ("backup_key", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5"),
        ]
        
        for filename, pub_prefix in keys_to_create:
            private_path = self.ssh_dir / filename
            public_path = self.ssh_dir / f"{filename}.pub"
            
            private_path.write_text(f"-----BEGIN OPENSSH PRIVATE KEY-----\nmock_content\n-----END OPENSSH PRIVATE KEY-----")
            private_path.chmod(0o600)
            public_path.write_text(f"{pub_prefix} mock_content user@host")
        
        # Mock fingerprint and key type detection
        with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint, \
             patch('keymaker.backend.ssh_operations.get_key_type') as mock_key_type:
            
            def mock_fingerprint_func(path):
                if "ed25519" in str(path):
                    return "SHA256:ed25519_fingerprint"
                elif "rsa" in str(path):
                    return "SHA256:rsa_fingerprint"
                else:
                    return "SHA256:backup_fingerprint"
            
            def mock_key_type_func(path):
                if "ed25519" in str(path):
                    return SSHKeyType.ED25519
                elif "rsa" in str(path):
                    return SSHKeyType.RSA
                else:
                    return SSHKeyType.ED25519
            
            mock_fingerprint.side_effect = mock_fingerprint_func
            mock_key_type.side_effect = mock_key_type_func
            
            keys = await scan_ssh_directory()
            
            # Should find all 3 keys
            assert len(keys) == 3
            
            # Verify key types are correctly detected
            key_types = {key.private_path.name: key.key_type for key in keys}
            assert key_types["id_ed25519"] == SSHKeyType.ED25519
            assert key_types["id_rsa"] == SSHKeyType.RSA
            assert key_types["backup_key"] == SSHKeyType.ED25519
    
    @pytest.mark.asyncio
    async def test_scan_empty_directory(self):
        """Test scanning empty SSH directory."""
        keys = await scan_ssh_directory()
        assert len(keys) == 0
    
    @pytest.mark.asyncio
    async def test_scan_with_orphaned_public_keys(self):
        """Test scanning with public keys that have no private counterpart."""
        # Create only public key
        public_only = self.ssh_dir / "orphan.pub"
        public_only.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 orphan@host")
        
        keys = await scan_ssh_directory()
        
        # Should not include orphaned public keys
        assert len(keys) == 0


class TestErrorRecoveryWorkflows:
    """Test error recovery and resilience."""
    
    def setup_method(self):
        """Set up test environment."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    @pytest.mark.asyncio
    async def test_recovery_from_permission_errors(self):
        """Test recovery from permission-related errors."""
        # Create key with wrong permissions
        private_key = self.ssh_dir / "permission_test"
        private_key.write_text("mock private key")
        private_key.chmod(0o644)  # Wrong permissions
        
        ssh_key = SSHKey(
            private_path=private_key,
            public_path=self.ssh_dir / "permission_test.pub",
            key_type=SSHKeyType.ED25519,
            fingerprint="SHA256:test",
            last_modified=datetime.now()
        )
        
        # Deletion should still work despite wrong permissions
        await delete_key_pair(ssh_key)
        assert not private_key.exists()
    
    @pytest.mark.asyncio
    async def test_recovery_from_missing_ssh_directory(self):
        """Test behavior when SSH directory doesn't exist."""
        # Remove SSH directory
        shutil.rmtree(self.ssh_dir)
        
        # Key generation should create the directory
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="auto_create_test"
        )
        
        with patch('asyncio.create_subprocess_exec') as mock_exec:
            def create_dir_and_files(*args, **kwargs):
                # ssh-keygen would create the directory
                self.ssh_dir.mkdir(mode=0o700, exist_ok=True)
                private_key = self.ssh_dir / "auto_create_test"
                public_key = self.ssh_dir / "auto_create_test.pub"
                
                private_key.write_text("mock private key")
                private_key.chmod(0o600)
                public_key.write_text("mock public key")
                
                mock_process = Mock()
                mock_process.communicate = asyncio.coroutine(lambda: (b"", b""))
                mock_process.returncode = 0
                return mock_process
            
            mock_exec.side_effect = create_dir_and_files
            
            with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                mock_fingerprint.return_value = "SHA256:test"
                
                ssh_key = await generate_key(request)
                
                # Directory should be created with correct permissions
                assert self.ssh_dir.exists()
                assert oct(self.ssh_dir.stat().st_mode)[-3:] == "700"
                assert ssh_key.private_path.exists()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])