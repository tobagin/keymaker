"""SSH key directory scanning and metadata extraction."""

import asyncio
from datetime import datetime
from pathlib import Path
from typing import Optional

from ..models import SSHKey, SSHKeyType, SSHOperationError
from .ssh_operations import get_fingerprint, get_key_type


async def scan_ssh_directory(ssh_dir: Optional[Path] = None) -> list[SSHKey]:
    """Scan SSH directory for key pairs and return SSH key models.

    Args:
        ssh_dir: Directory to scan (defaults to ~/.ssh)

    Returns:
        List of SSH key models found

    Raises:
        SSHOperationError: If scanning fails
    """
    if ssh_dir is None:
        ssh_dir = Path.home() / ".ssh"

    if not ssh_dir.exists():
        return []

    if not ssh_dir.is_dir():
        raise SSHOperationError(f"SSH directory is not a directory: {ssh_dir}")

    try:
        # Find all potential private key files
        private_keys = []

        for file_path in ssh_dir.iterdir():
            if file_path.is_file() and not file_path.name.endswith('.pub'):
                # Skip known non-key files
                if file_path.name in ['config', 'known_hosts', 'authorized_keys']:
                    continue

                # Check if corresponding public key exists
                public_path = file_path.with_suffix('.pub')
                if public_path.exists():
                    private_keys.append(file_path)

        # Build SSH key models for each valid pair
        ssh_keys = []

        for private_path in private_keys:
            try:
                ssh_key = await _build_ssh_key_model(private_path)
                if ssh_key:
                    ssh_keys.append(ssh_key)
            except Exception:
                # Skip invalid keys but log the error
                continue

        return ssh_keys

    except Exception as e:
        raise SSHOperationError(f"Failed to scan SSH directory: {str(e)}")


async def _build_ssh_key_model(private_path: Path) -> Optional[SSHKey]:
    """Build SSH key model from private key file.

    Args:
        private_path: Path to private key file

    Returns:
        SSH key model or None if invalid
    """
    try:
        public_path = private_path.with_suffix('.pub')

        # Get key type
        key_type = await get_key_type(private_path)

        # Get fingerprint
        fingerprint = await get_fingerprint(private_path)

        # Get last modified time
        last_modified = datetime.fromtimestamp(private_path.stat().st_mtime)

        # Extract comment from public key
        comment = _extract_comment_from_public_key(public_path)

        # Extract bit size for RSA keys
        bit_size = None
        if key_type == SSHKeyType.RSA:
            bit_size = await _extract_bit_size(private_path)

        return SSHKey(
            private_path=private_path,
            public_path=public_path,
            key_type=key_type,
            fingerprint=fingerprint,
            comment=comment,
            last_modified=last_modified,
            bit_size=bit_size
        )

    except Exception:
        # Return None for invalid keys
        return None


def _extract_comment_from_public_key(public_path: Path) -> Optional[str]:
    """Extract comment from public key file.

    Args:
        public_path: Path to public key file

    Returns:
        Comment string or None
    """
    try:
        content = public_path.read_text().strip()

        # Public key format: "type key-data comment"
        parts = content.split()
        if len(parts) >= 3:
            # Everything after the key data is the comment
            return ' '.join(parts[2:])

        return None

    except Exception:
        return None


async def _extract_bit_size(key_path: Path) -> Optional[int]:
    """Extract bit size from RSA key.

    Args:
        key_path: Path to key file

    Returns:
        Bit size or None
    """
    try:
        cmd = ["ssh-keygen", "-lf", str(key_path)]

        result = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await result.communicate()

        if result.returncode != 0:
            return None

        # Parse bit size from output
        # Format: "2048 SHA256:... user@host (RSA)"
        output_line = stdout.decode().strip()
        parts = output_line.split()
        if len(parts) >= 1:
            try:
                return int(parts[0])
            except ValueError:
                return None

        return None

    except Exception:
        return None


async def refresh_ssh_key_metadata(ssh_key: SSHKey) -> SSHKey:
    """Refresh metadata for an existing SSH key.

    Args:
        ssh_key: Existing SSH key model

    Returns:
        Updated SSH key model

    Raises:
        SSHOperationError: If key no longer exists or is invalid
    """
    if not ssh_key.private_path.exists():
        raise SSHOperationError(f"Private key no longer exists: {ssh_key.private_path}")

    if not ssh_key.public_path.exists():
        raise SSHOperationError(f"Public key no longer exists: {ssh_key.public_path}")

    try:
        # Get updated metadata
        fingerprint = await get_fingerprint(ssh_key.private_path)
        last_modified = datetime.fromtimestamp(ssh_key.private_path.stat().st_mtime)
        comment = _extract_comment_from_public_key(ssh_key.public_path)

        # Update bit size for RSA keys
        bit_size = ssh_key.bit_size
        if ssh_key.key_type == SSHKeyType.RSA:
            bit_size = await _extract_bit_size(ssh_key.private_path)

        return SSHKey(
            private_path=ssh_key.private_path,
            public_path=ssh_key.public_path,
            key_type=ssh_key.key_type,
            fingerprint=fingerprint,
            comment=comment,
            last_modified=last_modified,
            bit_size=bit_size
        )

    except Exception as e:
        raise SSHOperationError(f"Failed to refresh key metadata: {str(e)}")


def is_ssh_key_file(file_path: Path) -> bool:
    """Check if a file is likely an SSH key file.

    Args:
        file_path: Path to check

    Returns:
        True if file appears to be an SSH key
    """
    if not file_path.is_file():
        return False

    # Skip known non-key files
    if file_path.name in ['config', 'known_hosts', 'authorized_keys']:
        return False

    # Skip .pub files (we look for private keys)
    if file_path.name.endswith('.pub'):
        return False

    # Check if corresponding public key exists
    public_path = file_path.with_suffix('.pub')
    if not public_path.exists():
        return False

    # Basic content check for SSH private key
    try:
        content = file_path.read_text()
        if '-----BEGIN' in content and 'PRIVATE KEY-----' in content:
            return True
    except Exception:
        pass

    return False
