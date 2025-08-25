"""Test SSH operations backend."""

import pytest
import tempfile
import asyncio
from pathlib import Path
from datetime import datetime
from unittest.mock import Mock, patch, AsyncMock

from keymaker.models import (
    SSHKey,
    SSHKeyType,
    KeyGenerationRequest,
    PassphraseChangeRequest,
    SSHOperationError,
)
from keymaker.backend.ssh_operations import (
    generate_key,
    get_fingerprint,
    get_key_type,
    change_passphrase,
    delete_key_pair,
    get_public_key_content,
)


class TestGenerateKey:
    """Test SSH key generation."""
    
    @pytest.mark.asyncio
    async def test_generate_ed25519_key(self):
        """Test Ed25519 key generation."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="test_key",
            comment="test@example.com"
        )
        
        with tempfile.TemporaryDirectory() as tmpdir:
            key_path = Path(tmpdir) / "test_key"
            
            # Mock subprocess execution
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"")
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                # Mock get_fingerprint
                with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                    mock_fingerprint.return_value = "SHA256:abcd1234"
                    
                    # Mock Path.home() to return our temp directory
                    with patch('pathlib.Path.home') as mock_home:
                        mock_home.return_value = Path(tmpdir)
                        
                        # Create .ssh directory
                        ssh_dir = Path(tmpdir) / ".ssh"
                        ssh_dir.mkdir()
                        
                        # Create key files
                        private_path = ssh_dir / "test_key"
                        public_path = ssh_dir / "test_key.pub"
                        private_path.touch(mode=0o600)
                        public_path.touch()
                        
                        ssh_key = await generate_key(request)
                        
                        # Verify command construction
                        call_args = mock_exec.call_args[0]
                        assert call_args[0] == "ssh-keygen"
                        assert "-t" in call_args
                        assert "ed25519" in call_args
                        assert "-f" in call_args
                        assert "-C" in call_args
                        assert "test@example.com" in call_args
                        assert "-N" in call_args
                        assert "-b" not in call_args  # Ed25519 has no bits option
                        
                        # Verify result
                        assert ssh_key.key_type == SSHKeyType.ED25519
                        assert ssh_key.fingerprint == "SHA256:abcd1234"
                        assert ssh_key.comment == "test@example.com"
                        assert ssh_key.bit_size is None
    
    @pytest.mark.asyncio
    async def test_generate_rsa_key(self):
        """Test RSA key generation."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.RSA,
            filename="rsa_key",
            rsa_bits=2048
        )
        
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"")
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                    mock_fingerprint.return_value = "SHA256:rsa1234"
                    
                    with patch('pathlib.Path.home') as mock_home:
                        mock_home.return_value = Path(tmpdir)
                        
                        ssh_dir = Path(tmpdir) / ".ssh"
                        ssh_dir.mkdir()
                        
                        private_path = ssh_dir / "rsa_key"
                        public_path = ssh_dir / "rsa_key.pub"
                        private_path.touch(mode=0o600)
                        public_path.touch()
                        
                        ssh_key = await generate_key(request)
                        
                        # Verify command construction
                        call_args = mock_exec.call_args[0]
                        assert "ssh-keygen" in call_args
                        assert "-t" in call_args
                        assert "rsa" in call_args
                        assert "-b" in call_args
                        assert "2048" in call_args
                        
                        # Verify result
                        assert ssh_key.key_type == SSHKeyType.RSA
                        assert ssh_key.bit_size == 2048
    
    @pytest.mark.asyncio
    async def test_generate_key_with_passphrase(self):
        """Test key generation with passphrase."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="secure_key",
            passphrase="secret123"
        )
        
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"")
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                with patch('keymaker.backend.ssh_operations.get_fingerprint') as mock_fingerprint:
                    mock_fingerprint.return_value = "SHA256:secure1234"
                    
                    with patch('pathlib.Path.home') as mock_home:
                        mock_home.return_value = Path(tmpdir)
                        
                        ssh_dir = Path(tmpdir) / ".ssh"
                        ssh_dir.mkdir()
                        
                        private_path = ssh_dir / "secure_key"
                        public_path = ssh_dir / "secure_key.pub"
                        private_path.touch(mode=0o600)
                        public_path.touch()
                        
                        await generate_key(request)
                        
                        # Verify passphrase is passed to ssh-keygen
                        call_args = mock_exec.call_args[0]
                        assert "-N" in call_args
                        # Find the passphrase argument
                        n_index = call_args.index("-N")
                        assert call_args[n_index + 1] == "secret123"
    
    @pytest.mark.asyncio
    async def test_generate_key_already_exists(self):
        """Test key generation when key already exists."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="existing_key"
        )
        
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch('pathlib.Path.home') as mock_home:
                mock_home.return_value = Path(tmpdir)
                
                ssh_dir = Path(tmpdir) / ".ssh"
                ssh_dir.mkdir()
                
                # Create existing key
                existing_key = ssh_dir / "existing_key"
                existing_key.touch()
                
                with pytest.raises(SSHOperationError, match="already exists"):
                    await generate_key(request)
    
    @pytest.mark.asyncio
    async def test_generate_key_command_fails(self):
        """Test key generation when ssh-keygen fails."""
        request = KeyGenerationRequest(
            key_type=SSHKeyType.ED25519,
            filename="fail_key"
        )
        
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"Key generation failed")
                mock_process.returncode = 1
                mock_exec.return_value = mock_process
                
                with patch('pathlib.Path.home') as mock_home:
                    mock_home.return_value = Path(tmpdir)
                    
                    ssh_dir = Path(tmpdir) / ".ssh"
                    ssh_dir.mkdir()
                    
                    with pytest.raises(SSHOperationError, match="Key generation failed"):
                        await generate_key(request)


class TestGetFingerprint:
    """Test fingerprint extraction."""
    
    @pytest.mark.asyncio
    async def test_get_fingerprint_from_public_key(self):
        """Test getting fingerprint from public key."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch()
            public_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"256 SHA256:abcd1234efgh5678 user@host (ED25519)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                fingerprint = await get_fingerprint(private_path)
                
                assert fingerprint == "SHA256:abcd1234efgh5678"
                
                # Verify it used public key
                call_args = mock_exec.call_args[0]
                assert str(public_path) in call_args
    
    @pytest.mark.asyncio
    async def test_get_fingerprint_from_private_key(self):
        """Test getting fingerprint from private key when public doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            private_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"256 SHA256:private1234 user@host (ED25519)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                fingerprint = await get_fingerprint(private_path)
                
                assert fingerprint == "SHA256:private1234"
                
                # Verify it used private key
                call_args = mock_exec.call_args[0]
                assert str(private_path) in call_args
    
    @pytest.mark.asyncio
    async def test_get_fingerprint_key_not_found(self):
        """Test getting fingerprint when key doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            nonexistent_path = Path(tmpdir) / "nonexistent"
            
            with pytest.raises(SSHOperationError, match="Key file not found"):
                await get_fingerprint(nonexistent_path)
    
    @pytest.mark.asyncio
    async def test_get_fingerprint_command_fails(self):
        """Test getting fingerprint when ssh-keygen fails."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            private_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"",
                    b"Invalid key format"
                )
                mock_process.returncode = 1
                mock_exec.return_value = mock_process
                
                with pytest.raises(SSHOperationError, match="Failed to get fingerprint"):
                    await get_fingerprint(private_path)


class TestGetKeyType:
    """Test key type detection."""
    
    @pytest.mark.asyncio
    async def test_get_key_type_ed25519(self):
        """Test detecting Ed25519 key type."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch()
            public_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"256 SHA256:abcd1234 user@host (ED25519)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                key_type = await get_key_type(private_path)
                
                assert key_type == SSHKeyType.ED25519
    
    @pytest.mark.asyncio
    async def test_get_key_type_rsa(self):
        """Test detecting RSA key type."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_rsa"
            public_path = Path(tmpdir) / "id_rsa.pub"
            
            private_path.touch()
            public_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"4096 SHA256:rsa1234 user@host (RSA)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                key_type = await get_key_type(private_path)
                
                assert key_type == SSHKeyType.RSA
    
    @pytest.mark.asyncio
    async def test_get_key_type_ecdsa(self):
        """Test detecting ECDSA key type."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ecdsa"
            public_path = Path(tmpdir) / "id_ecdsa.pub"
            
            private_path.touch()
            public_path.touch()
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (
                    b"256 SHA256:ecdsa1234 user@host (ECDSA)\n",
                    b""
                )
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                key_type = await get_key_type(private_path)
                
                assert key_type == SSHKeyType.ECDSA


class TestChangePassphrase:
    """Test passphrase change functionality."""
    
    @pytest.mark.asyncio
    async def test_change_passphrase_success(self):
        """Test successful passphrase change."""
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
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"")
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                await change_passphrase(request)
                
                # Verify command construction
                call_args = mock_exec.call_args[0]
                assert "ssh-keygen" in call_args
                assert "-p" in call_args
                assert "-f" in call_args
                assert str(private_path) in call_args
    
    @pytest.mark.asyncio
    async def test_change_passphrase_remove(self):
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
            
            with patch('asyncio.create_subprocess_exec') as mock_exec:
                mock_process = Mock()
                mock_process.communicate.return_value = (b"", b"")
                mock_process.returncode = 0
                mock_exec.return_value = mock_process
                
                await change_passphrase(request)
                
                # Should succeed without error
                mock_exec.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_change_passphrase_key_not_found(self):
        """Test passphrase change when key doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "nonexistent"
            public_path = Path(tmpdir) / "nonexistent.pub"
            
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
            
            with pytest.raises(SSHOperationError, match="Private key not found"):
                await change_passphrase(request)


class TestDeleteKeyPair:
    """Test key pair deletion."""
    
    @pytest.mark.asyncio
    async def test_delete_key_pair_success(self):
        """Test successful key pair deletion."""
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
            
            await delete_key_pair(ssh_key)
            
            # Verify files are deleted
            assert not private_path.exists()
            assert not public_path.exists()
    
    @pytest.mark.asyncio
    async def test_delete_key_pair_partial(self):
        """Test deleting key pair when only one file exists."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            # Only create private key
            private_path.touch(mode=0o600)
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            await delete_key_pair(ssh_key)
            
            # Should succeed without error
            assert not private_path.exists()


class TestGetPublicKeyContent:
    """Test public key content retrieval."""
    
    def test_get_public_key_content_success(self):
        """Test getting public key content."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            
            # Write public key content
            public_key_content = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host"
            public_path.write_text(public_key_content)
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            content = get_public_key_content(ssh_key)
            
            assert content == public_key_content
    
    def test_get_public_key_content_not_found(self):
        """Test getting public key content when file doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            private_path = Path(tmpdir) / "id_ed25519"
            public_path = Path(tmpdir) / "id_ed25519.pub"
            
            private_path.touch(mode=0o600)
            
            ssh_key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint="SHA256:abcd1234",
                last_modified=datetime.now()
            )
            
            with pytest.raises(SSHOperationError, match="Public key not found"):
                get_public_key_content(ssh_key)