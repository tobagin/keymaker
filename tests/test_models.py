"""Test SSH key models."""

import pytest
import tempfile
from pathlib import Path
from datetime import datetime
from pydantic import ValidationError

from keymaker.models import (
    SSHKey,
    SSHKeyType,
    KeyGenerationRequest,
    KeyDeletionRequest,
    PassphraseChangeRequest,
    SSHCopyIDRequest,
    SSHOperationError,
)


class TestSSHKeyType:
    """Test SSH key type enum."""
    
    def test_key_types(self):
        """Test available key types."""
        assert SSHKeyType.ED25519 == "ed25519"
        assert SSHKeyType.RSA == "rsa"
        assert SSHKeyType.ECDSA == "ecdsa"


class TestSSHKey:
    """Test SSH key model."""
    
    def test_valid_ssh_key(self):
        """Test valid SSH key model creation."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            # Create key files
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                comment="test@example.com",
                last_modified=datetime.now(),
                bit_size=None
            )
            
            assert ssh_key.private_path == private_path
            assert ssh_key.public_path == public_path
            assert ssh_key.key_type == SSHKeyType.ED25519
            assert ssh_key.fingerprint == "SHA256:abcd1234"
            assert ssh_key.comment == "test@example.com"
            assert ssh_key.bit_size is None
    
    def test_rsa_key_with_bit_size(self):
        """Test RSA key with bit size."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_rsa"
            public_path = Path(tmpdir) / "id_rsa.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.RSA,
                fingerprint="SHA256:rsa1234",
                last_modified=datetime.now(),
                bit_size=4096
            )
            
            assert ssh_key.key_type == SSHKeyType.RSA
            assert ssh_key.bit_size == 4096


class TestKeyGenerationRequest:
    """Test key generation request model."""
    
    def test_default_ed25519_request(self):
        """Test default Ed25519 key generation request."""
        request = KeyGenerationRequest(filename="test_key")
        
        assert request.key_type == SSHKeyType.ED25519
        assert request.filename == "test_key"
        assert request.passphrase is None
        assert request.comment is None
        assert request.rsa_bits is None  # RSA bits not applicable for Ed25519
    
    def test_rsa_request_with_bits(self):
        """Test RSA key generation request with bits."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.RSA,
            filename="rsa_key",
            rsa_bits=2048
        )
        
        assert request.key_type == SSHKeyType.RSA
        assert request.filename == "rsa_key"
        assert request.rsa_bits == 2048
    
    def test_ed25519_ignores_rsa_bits(self):
        """Test Ed25519 request ignores RSA bits."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="ed25519_key",
            rsa_bits=2048
        )
        
        # RSA bits should be set to None for non-RSA keys
        assert request.rsa_bits is None
    
    def test_invalid_filename(self):
        """Test invalid filename validation."""
        with pytest.raises(ValidationError):
            KeyGenerationRequest(filename="")
        
        with pytest.raises(ValidationError):
            KeyGenerationRequest(filename="invalid/filename")
    
    def test_invalid_rsa_bits(self):
        """Test invalid RSA bits validation."""
        with pytest.raises(ValidationError):
            KeyGenerationRequest(
                key_type=SSHKeyType.RSA,
                filename="test",
                rsa_bits=1024  # Too small
            )
        
        with pytest.raises(ValidationError):
            KeyGenerationRequest(
                key_type=SSHKeyType.RSA,
                filename="test",
                rsa_bits=16384  # Too large
            )
    
    def test_filename_safety_validation(self):
        """Test filename safety validation."""
        # Valid filenames
        valid_names = ["id_ed25519", "my-key", "key.backup", "key123"]
        for name in valid_names:
            request = KeyGenerationRequest(filename=name)
            assert request.filename == name
        
        # Invalid filenames
        with pytest.raises(ValidationError):
            KeyGenerationRequest(filename=".hidden")  # Starts with dot
        
        with pytest.raises(ValidationError):
            KeyGenerationRequest(filename="-invalid")  # Starts with dash
        
        with pytest.raises(ValidationError):
            KeyGenerationRequest(filename="a" * 256)  # Too long


class TestKeyDeletionRequest:
    """Test key deletion request model."""
    
    def test_valid_deletion_request(self):
        """Test valid deletion request."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = KeyDeletionRequest(ssh_key=ssh_key, confirm=True)
            
            assert request.ssh_key == ssh_key
            assert request.confirm is True
    
    def test_deletion_requires_confirmation(self):
        """Test deletion requires confirmation."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            with pytest.raises(ValidationError):
                KeyDeletionRequest(ssh_key=ssh_key, confirm=False)


class TestPassphraseChangeRequest:
    """Test passphrase change request model."""
    
    def test_valid_passphrase_change(self):
        """Test valid passphrase change request."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = PassphraseChangeRequest(
                ssh_key=ssh_key,
                current_passphrase="old_pass",
                new_passphrase="new_pass"
            )
            
            assert request.ssh_key == ssh_key
            assert request.current_passphrase == "old_pass"
            assert request.new_passphrase == "new_pass"
    
    def test_remove_passphrase(self):
        """Test removing passphrase."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = PassphraseChangeRequest(
                ssh_key=ssh_key,
                current_passphrase="old_pass",
                new_passphrase=None
            )
            
            assert request.current_passphrase == "old_pass"
            assert request.new_passphrase is None


class TestSSHCopyIDRequest:
    """Test SSH copy ID request model."""
    
    def test_valid_copy_id_request(self):
        """Test valid copy ID request."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = SSHCopyIDRequest(
                ssh_key=ssh_key,
                hostname="example.com",
                username="user"
            )
            
            assert request.ssh_key == ssh_key
            assert request.hostname == "example.com"
            assert request.username == "user"
            assert request.port == 22
    
    def test_custom_port(self):
        """Test copy ID request with custom port."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = SSHCopyIDRequest(
                ssh_key=ssh_key,
                hostname="example.com",
                username="user",
                port=2222
            )
            
            assert request.port == 2222
    
    def test_get_command_default_port(self):
        """Test get_command with default port."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = SSHCopyIDRequest(
                ssh_key=ssh_key,
                hostname="example.com",
                username="user"
            )
            
            command = request.get_command()
            expected = f"ssh-copy-id -i {public_path} user@example.com"
            assert command == expected
    
    def test_get_command_custom_port(self):
        """Test get_command with custom port."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            request = SSHCopyIDRequest(
                ssh_key=ssh_key,
                hostname="example.com",
                username="user",
                port=2222
            )
            
            command = request.get_command()
            expected = f"ssh-copy-id -i {public_path} -p 2222 user@example.com"
            assert command == expected
    
    def test_invalid_port(self):
        """Test invalid port validation."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            public_path.touch()
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            with pytest.raises(ValidationError):
                SSHCopyIDRequest(
                    ssh_key=ssh_key,
                    hostname="example.com",
                    username="user",
                    port=0  # Invalid port
                )
            
            with pytest.raises(ValidationError):
                SSHCopyIDRequest(
                    ssh_key=ssh_key,
                    hostname="example.com",
                    username="user",
                    port=99999  # Invalid port
                )