# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-11

### Changed
### Added
- **SSH Management**:
    - **SSH Agent Intelligence**: Better handling of loaded keys.
    - **Key-Service Mapping**: Associate keys with specific services.
    - **SSH Config Editor**: Edit your SSH configuration directly.
    - **SSH Config Editor**: Edit your SSH configuration directly.
    - **Recursive Key Scanning**: Automatically finds keys in subdirectories (up to depth 3).
- **Security & Backups**:
    - **QR Code Backups**: securely export keys as QR codes with security warnings.
    - **Time-locked Backups**: Improved security for backup accessing.
- **UI/UX Enhancements**:
    - **GUI Password Dialog**: Graphical prompt when copying SSH keys to servers.
    - **Visual Coding**: Improved color coding and icons for different key types.
    - **Development Profile**: Distinct icon and style for development builds.
    - Refined About Window and Release Notes viewer.

### Changed
- **Rebranding**: Application renamed to **Keymaker**.
- **Rewrite**: Complete codebase rewrite from Python to Vala for improved performance and native integration.
- **Icons**: Fresh new application icons (Thanks to [Rosabel](https://github.com/oiimrosabel)).
- Unified branding across all components.
- Updated documentation screenshots.
- Changed "What's New" behavior to be on-demand instead of auto-showing.

## [1.0.3] - 2025-07-14

### Fixed
- Fixed 512x512 icon to correct dimensions (was 1024x1024).
- Ensured all icon sizes match their directory specifications.

### Changed
- Improved icon quality and consistency across all sizes.

## [1.0.2] - 2025-07-14

### Changed
- Updated application icon with new branding.
- Improved visual consistency across all icon sizes.
- Enhanced application quality guidelines compliance.

## [1.0.1] - 2025-01-12

### Changed
- Updated developer attribution to Thiago Fernandes.
- Updated copyright notices and translation headers.

## [0.1.0] - 2024-01-01

### Added
- Initial release.
- SSH key generation (Ed25519, RSA, ECDSA).
- Key management and listing.
- Public key copying to clipboard.
- ssh-copy-id command generation.
- Passphrase management.
- GTK4 and Libadwaita interface.
