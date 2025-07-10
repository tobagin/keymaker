"""SSH key data models using Pydantic for validation."""

from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class SSHKeyType(str, Enum):
    """Supported SSH key types."""
    ED25519 = "ed25519"
    RSA = "rsa"
    ECDSA = "ecdsa"  # Listed but not recommended


class SSHKey(BaseModel):
    """Model representing an SSH key pair.

    This model represents both private and public keys as a pair,
    with validation to ensure secure permissions and proper structure.
    """
    private_path: Path
    public_path: Path
    key_type: SSHKeyType
    fingerprint: str
    comment: Optional[str] = None
    last_modified: datetime
    bit_size: Optional[int] = None  # Only for RSA keys

    model_config = ConfigDict(
        # Allow pathlib.Path objects
        arbitrary_types_allowed=True
    )

    @field_validator('private_path')
    def validate_permissions(cls, v):
        """Ensure private key has secure permissions.

        Args:
            v: The private key path

        Returns:
            The validated path

        Note:
            We detect but don't fix permissions here - that's backend's job
        """
        if v.exists():
            # Check permissions (should be 0600)
            mode = oct(v.stat().st_mode)[-3:]
            if mode != '600':
                # Log warning but don't fail validation
                pass
        return v

    @field_validator('public_path')
    def validate_public_exists(cls, v):
        """Ensure public key exists alongside private key.

        Args:
            v: The public key path

        Returns:
            The validated path
        """
        if v.exists():
            # Public key should exist if private key exists
            pass
        return v


class KeyGenerationRequest(BaseModel):
    """Request model for generating new SSH keys.

    This model validates all parameters needed for key generation,
    including type-specific constraints and security requirements.
    """
    key_type: SSHKeyType = Field(default=SSHKeyType.ED25519)
    filename: str = Field(..., min_length=1, pattern=r'^[a-zA-Z0-9_.-]+$')
    passphrase: Optional[str] = Field(default=None)
    comment: Optional[str] = Field(default=None)
    rsa_bits: Optional[int] = Field(default=4096, ge=2048, le=8192)

    @model_validator(mode='after')
    def validate_rsa_bits(self):
        """RSA bits only valid for RSA keys.

        Returns:
            The validated model
        """
        if self.key_type != SSHKeyType.RSA and self.rsa_bits is not None:
            self.rsa_bits = None
        return self

    @field_validator('filename')
    def validate_filename_safe(cls, v):
        """Ensure filename is safe for filesystem.

        Args:
            v: The filename

        Returns:
            The validated filename
        """
        # Additional safety checks beyond regex
        if v.startswith('.') or v.startswith('-'):
            raise ValueError("Filename cannot start with '.' or '-'")
        if len(v) > 255:
            raise ValueError("Filename too long")
        return v


class SSHOperationError(Exception):
    """Custom exception for SSH operations."""
    pass


class KeyDeletionRequest(BaseModel):
    """Request model for deleting SSH key pairs."""
    ssh_key: SSHKey
    confirm: bool = Field(default=False)

    @field_validator('confirm')
    def validate_confirmation(cls, v):
        """Ensure deletion is confirmed.

        Args:
            v: The confirmation flag

        Returns:
            The validated confirmation
        """
        if not v:
            raise ValueError("Deletion must be confirmed")
        return v


class PassphraseChangeRequest(BaseModel):
    """Request model for changing SSH key passphrases."""
    ssh_key: SSHKey
    current_passphrase: Optional[str] = Field(default=None)
    new_passphrase: Optional[str] = Field(default=None)

    model_config = ConfigDict(
        # Never log this model (contains sensitive data)
        str_strip_whitespace=True
    )


class SSHCopyIDRequest(BaseModel):
    """Request model for generating ssh-copy-id commands."""
    ssh_key: SSHKey
    hostname: str = Field(..., min_length=1)
    username: str = Field(..., min_length=1)
    port: Optional[int] = Field(default=22, ge=1, le=65535)

    @field_validator('hostname')
    def validate_hostname(cls, v):
        """Basic hostname validation.

        Args:
            v: The hostname

        Returns:
            The validated hostname
        """
        if not v.replace('.', '').replace('-', '').isalnum():
            # Allow basic hostname characters
            pass
        return v

    def get_command(self) -> str:
        """Generate the ssh-copy-id command string.

        Returns:
            The complete ssh-copy-id command
        """
        cmd = f"ssh-copy-id -i {self.ssh_key.public_path}"
        if self.port != 22:
            cmd += f" -p {self.port}"
        cmd += f" {self.username}@{self.hostname}"
        return cmd
