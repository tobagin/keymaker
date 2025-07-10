"""SSH key operations using subprocess for secure command execution."""

import asyncio
from datetime import datetime
from pathlib import Path

from ..models import (
    KeyGenerationRequest,
    PassphraseChangeRequest,
    SSHCopyIDRequest,
    SSHKey,
    SSHKeyType,
    SSHOperationError,
)


async def generate_key(request: KeyGenerationRequest) -> SSHKey:
    """Generate SSH key using ssh-keygen.

    Args:
        request: Key generation parameters

    Returns:
        Created SSH key model

    Raises:
        SSHOperationError: If key generation fails
    """
    # Build key path
    key_path = Path.home() / ".ssh" / request.filename

    # Ensure .ssh directory exists with proper permissions
    ssh_dir = key_path.parent
    ssh_dir.mkdir(mode=0o700, exist_ok=True)

    # Check if key already exists
    if key_path.exists() or key_path.with_suffix(".pub").exists():
        raise SSHOperationError(f"Key {request.filename} already exists")

    # Build command args safely
    cmd = ["ssh-keygen", "-t", request.key_type.value]

    # Add algorithm-specific options
    if request.key_type == SSHKeyType.ED25519:
        # Ed25519 has fixed size, no bits option
        pass
    elif request.key_type == SSHKeyType.RSA:
        cmd.extend(["-b", str(request.rsa_bits)])
    elif request.key_type == SSHKeyType.ECDSA:
        # ECDSA with 256-bit curve (default)
        cmd.extend(["-b", "256"])

    # Add common options
    cmd.extend(["-f", str(key_path)])
    if request.comment:
        cmd.extend(["-C", request.comment])

    # Handle passphrase (-N for new keys)
    passphrase = request.passphrase or ""
    cmd.extend(["-N", passphrase])

    try:
        # Execute ssh-keygen command
        # CRITICAL: Never use shell=True for security
        result = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await result.communicate()

        if result.returncode != 0:
            raise SSHOperationError(f"Key generation failed: {stderr.decode()}")

    except Exception as e:
        raise SSHOperationError(f"Failed to execute ssh-keygen: {str(e)}")

    # Verify permissions (ssh-keygen should set 600 automatically)
    if key_path.exists():
        key_path.chmod(0o600)

    # Get fingerprint for the new key
    fingerprint = await get_fingerprint(key_path)

    return SSHKey(
        private_path=key_path,
        public_path=key_path.with_suffix(".pub"),
        key_type=request.key_type,
        fingerprint=fingerprint,
        comment=request.comment,
        last_modified=datetime.now(),
        bit_size=request.rsa_bits if request.key_type == SSHKeyType.RSA else None
    )


async def get_fingerprint(key_path: Path) -> str:
    """Get SSH key fingerprint using ssh-keygen.

    Args:
        key_path: Path to private or public key

    Returns:
        Key fingerprint string

    Raises:
        SSHOperationError: If fingerprint extraction fails
    """
    # Use public key if available, otherwise private key
    if key_path.with_suffix(".pub").exists():
        target_path = key_path.with_suffix(".pub")
    else:
        target_path = key_path

    if not target_path.exists():
        raise SSHOperationError(f"Key file not found: {target_path}")

    cmd = ["ssh-keygen", "-lf", str(target_path)]

    try:
        result = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await result.communicate()

        if result.returncode != 0:
            raise SSHOperationError(f"Failed to get fingerprint: {stderr.decode()}")

        # Parse fingerprint from output
        # Format: "2048 SHA256:... user@host (RSA)"
        fingerprint_line = stdout.decode().strip()
        parts = fingerprint_line.split()
        if len(parts) >= 2:
            return parts[1]  # SHA256:... part
        else:
            raise SSHOperationError("Unable to parse fingerprint")

    except Exception as e:
        raise SSHOperationError(f"Failed to get fingerprint: {str(e)}")


async def get_key_type(key_path: Path) -> SSHKeyType:
    """Determine SSH key type from key file.

    Args:
        key_path: Path to SSH key file

    Returns:
        SSH key type

    Raises:
        SSHOperationError: If key type cannot be determined
    """
    # Use public key if available
    if key_path.with_suffix(".pub").exists():
        target_path = key_path.with_suffix(".pub")
    else:
        target_path = key_path

    if not target_path.exists():
        raise SSHOperationError(f"Key file not found: {target_path}")

    cmd = ["ssh-keygen", "-lf", str(target_path)]

    try:
        result = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await result.communicate()

        if result.returncode != 0:
            raise SSHOperationError(f"Failed to determine key type: {stderr.decode()}")

        # Parse key type from output
        # Format: "2048 SHA256:... user@host (RSA)"
        output_line = stdout.decode().strip()
        if "(RSA)" in output_line:
            return SSHKeyType.RSA
        elif "(ED25519)" in output_line:
            return SSHKeyType.ED25519
        elif "(ECDSA)" in output_line:
            return SSHKeyType.ECDSA
        else:
            raise SSHOperationError("Unknown key type")

    except Exception as e:
        raise SSHOperationError(f"Failed to determine key type: {str(e)}")


async def change_passphrase(request: PassphraseChangeRequest) -> None:
    """Change SSH key passphrase using ssh-keygen.

    Args:
        request: Passphrase change parameters

    Raises:
        SSHOperationError: If passphrase change fails
    """
    key_path = request.ssh_key.private_path

    if not key_path.exists():
        raise SSHOperationError(f"Private key not found: {key_path}")

    cmd = ["ssh-keygen", "-p", "-f", str(key_path)]

    try:
        # Create process with stdin pipe for passphrase input
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Prepare input: old passphrase, new passphrase, confirm new passphrase
        input_data = ""
        if request.current_passphrase:
            input_data += request.current_passphrase + "\n"
        else:
            input_data += "\n"  # Empty for no current passphrase

        if request.new_passphrase:
            input_data += request.new_passphrase + "\n"
            input_data += request.new_passphrase + "\n"  # Confirm
        else:
            input_data += "\n\n"  # Empty for no new passphrase

        stdout, stderr = await process.communicate(input_data.encode())

        if process.returncode != 0:
            raise SSHOperationError(f"Passphrase change failed: {stderr.decode()}")

    except Exception as e:
        raise SSHOperationError(f"Failed to change passphrase: {str(e)}")


async def delete_key_pair(ssh_key: SSHKey) -> None:
    """Delete SSH key pair (both private and public keys).

    Args:
        ssh_key: SSH key to delete

    Raises:
        SSHOperationError: If deletion fails
    """
    errors = []

    # Delete private key
    if ssh_key.private_path.exists():
        try:
            ssh_key.private_path.unlink()
        except Exception as e:
            errors.append(f"Failed to delete private key: {str(e)}")

    # Delete public key
    if ssh_key.public_path.exists():
        try:
            ssh_key.public_path.unlink()
        except Exception as e:
            errors.append(f"Failed to delete public key: {str(e)}")

    if errors:
        raise SSHOperationError("; ".join(errors))


async def copy_id_to_server(request: SSHCopyIDRequest) -> None:
    """Copy SSH key to remote server using ssh-copy-id.

    Args:
        request: SSH copy-id parameters

    Raises:
        SSHOperationError: If copy operation fails
    """
    if not request.ssh_key.public_path.exists():
        raise SSHOperationError(f"Public key not found: {request.ssh_key.public_path}")

    # Build target specification
    target = f"{request.username}@{request.hostname}"
    if request.port != 22:
        target = f"-p {request.port} {target}"

    cmd = ["ssh-copy-id", "-i", str(request.ssh_key.public_path)]
    if request.port != 22:
        cmd.extend(["-p", str(request.port)])
    cmd.append(f"{request.username}@{request.hostname}")

    try:
        # Execute ssh-copy-id command
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await process.communicate()

        if process.returncode != 0:
            raise SSHOperationError(f"Failed to copy key to server: {stderr.decode()}")

    except Exception as e:
        raise SSHOperationError(f"Failed to execute ssh-copy-id: {str(e)}")


def get_public_key_content(ssh_key: SSHKey) -> str:
    """Get public key content for clipboard copying.

    Args:
        ssh_key: SSH key to read

    Returns:
        Public key content as string

    Raises:
        SSHOperationError: If public key cannot be read
    """
    if not ssh_key.public_path.exists():
        raise SSHOperationError(f"Public key not found: {ssh_key.public_path}")

    try:
        return ssh_key.public_path.read_text().strip()
    except Exception as e:
        raise SSHOperationError(f"Failed to read public key: {str(e)}")
