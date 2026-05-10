# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-05-10

### ✨ New Features
- **Warp Terminal**: Added Warp to the preferred terminal emulator list (#19).
- **SSH Host Options**: Added editor support for `WarnWeakCrypto`, `IdentitiesOnly`, and `IdentityAgent` per-host options (#18).

## [1.3.0] - 2026-02-09

### ✨ New Features
- **Security Keys**: Added support for `ED25519-SK` security keys.
- **Improved Detection**: Enhanced key type and bit size detection for security-backed keys.

### 🎨 UI Refinements
- **Dialogs**: Improved dialog dimensions and removed `raised` bar styles for a cleaner look.
- **Responsiveness**: Further refinements to dialog layouts.

## [1.2.0] - 2026-01-20

### ✨ New Features
- **Mobile UI**: Comprehensive layout adaptation for mobile devices.
- **Navigation**: Refactored architecture to use `Adw.NavigationView`.
- **Backup**: Redesigned Backup page using `Adw.BottomSheet`.

### 🔧 Changed
- **UI**: Updated Hosts and Known Hosts pages for better consistency.
- **Refactoring**: Standardized usage of `Adw.ToolbarView` across pages.

## [1.1.1] - 2026-01-12

### 🏗️ Maintenance
- **Metadata**: Updated application summary, description, and branding colors.
- **Docs**: Refined README with new structure, simplified language, and added badges.
- **Docs**: Clarified build instructions.
## [1.1.0] - 2026-01-11

### ✨ New Features
- **🕵️ Recursive Key Scanning**: Automatically finds keys in subdirectories (up to depth 3).
- **🔗 Key-Service Mapping**: Associate keys with specific services.
- **📝 SSH Config Editor**: Edit your SSH configuration directly.
- **📱 QR Code Backups**: Securely export keys as QR codes with security warnings.
- **⏱️ Time-locked Backups**: Improved security for backup accessing.
- **🔒 GUI Password Dialog**: Graphical prompt when copying SSH keys to servers.
- **🎨 Visual Coding**: Improved color coding and icons for different key types.
- **🛠️ Development Profile**: Distinct icon and style for development builds.

### 🔧 Changed
- **Rebranding**: Application renamed to **Keymaker**.
- **Rewrite**: Complete codebase rewrite from Python to Vala for improved performance and native integration.
- **Icons**: Fresh new application icons (Thanks to [Rosabel](https://github.com/oiimrosabel)).
- **UI**: Refined About Window and Release Notes viewer.
- **Documentation**: Updated documentation screenshots.
- **Behavior**: Changed "What's New" behavior to be on-demand instead of auto-showing.

## [1.0.3] - 2025-07-14

### 🐛 Bug Fixes
- **Icons**: Fixed 512x512 icon to correct dimensions (was 1024x1024).
- **Icons**: Ensured all icon sizes match their directory specifications.

### 🔧 Changed
- **Icons**: Improved icon quality and consistency across all sizes.

## [1.0.2] - 2025-07-14

### 🔧 Changed
- **Icons**: Updated application icon with new branding.
- **UI**: Improved visual consistency across all icon sizes.
- **Quality**: Enhanced application quality guidelines compliance.

## [1.0.1] - 2025-01-12

### 🔧 Changed
- **Attribution**: Updated developer attribution to Thiago Fernandes.
- **Translation**: Updated copyright notices and translation headers.

## [0.1.0] - 2024-01-01

### ✨ Added
- **Initial Release**: First public version of Keymaker.
- **Key Generation**: Support for Ed25519, RSA, and ECDSA keys.
- **Management**: Key listing and management interface.
- **Clipboard**: Public key copying to clipboard.
- **Deployment**: ssh-copy-id command generation.
- **Security**: Passphrase management.
- **UI**: GTK4 and Libadwaita interface.
