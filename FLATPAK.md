# Flatpak Packaging for Key Maker

This document explains how to build and test Key Maker using Flatpak, both for local development and for distribution.

## Manifests

Two Flatpak manifests are provided:

1. **`io.github.tobagin.keysmith.yml`** - For git tags/releases
   - Uses `type: git` with specific tag and commit
   - Suitable for building releases and submission to Flathub

2. **`io.github.tobagin.keysmith-local.yml`** - For local development
   - Uses `type: dir` with `path: .` to build from local source
   - Suitable for testing changes during development

## Prerequisites

Install Flatpak and the required runtime/SDK:

```bash
# Install Flatpak (if not already installed)
sudo dnf install flatpak flatpak-builder

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install GNOME 48 runtime and SDK
flatpak install flathub org.gnome.Platform/x86_64/48
flatpak install flathub org.gnome.Sdk/x86_64/48
```

## Building from Local Source

For development and testing:

```bash
# Create build directory
mkdir -p build-flatpak

# Build the application
flatpak-builder build-flatpak io.github.tobagin.keysmith-local.yml --force-clean

# Install locally for testing
flatpak-builder --user --install build-flatpak io.github.tobagin.keysmith-local.yml --force-clean

# Run the application
flatpak run io.github.tobagin.keysmith
```

## Building from Git Tag

For releases:

```bash
# Update the git manifest with correct tag and commit
# Then build:
mkdir -p build-flatpak-git

flatpak-builder build-flatpak-git io.github.tobagin.keysmith.yml --force-clean

# Install locally for testing
flatpak-builder --user --install build-flatpak-git io.github.tobagin.keysmith.yml --force-clean

# Run the application
flatpak run io.github.tobagin.keysmith
```

## Permissions Explained

The manifests include these permissions following Flathub security guidelines:

- `--filesystem=~/.ssh:create` - Access to SSH directory (essential for SSH key management)
- `--filesystem=host:ro` - Read-only access to host filesystem (for key deployment)
- `--share=network` - Network access (for ssh-copy-id operations)
- `--talk-name=org.freedesktop.secrets` - Access to secret service (for secure passphrase handling)
- `--talk-name=org.gnome.keyring` - Access to GNOME keyring (for credential management)

## Dependencies

The manifests include all required Python dependencies:

- **typing_extensions** - Type hints support
- **annotated_types** - Type annotations
- **pydantic_core** - Core validation library
- **pydantic** - Data validation and settings management
- **python_dotenv** - Environment variable management

All dependencies are installed from verified PyPI wheels with SHA256 checksums.

## Testing

After installation, test the application:

```bash
# Run the application
flatpak run io.github.tobagin.keysmith

# Check if it can access SSH directory
ls -la ~/.ssh/

# Test key generation (if directory exists)
# Use the application UI to generate a test key
```

## Distribution

For Flathub submission:

1. Use the git manifest (`io.github.tobagin.keysmith.yml`)
2. Update the git tag and commit hash to match your release
3. Test thoroughly with the git manifest
4. Submit to Flathub following their guidelines

## Troubleshooting

### Build Issues

If the build fails:

```bash
# Check build logs (for local development)
flatpak-builder --verbose build-flatpak io.github.tobagin.keysmith-local.yml --force-clean

# Or for git version
flatpak-builder --verbose build-flatpak io.github.tobagin.keysmith.yml --force-clean

# Clean and rebuild
rm -rf build-flatpak
flatpak-builder build-flatpak io.github.tobagin.keysmith-local.yml --force-clean
```

### Runtime Issues

If the application fails to start:

```bash
# Check runtime installation
flatpak list --runtime

# Reinstall runtime if needed
flatpak install --reinstall flathub org.gnome.Platform/x86_64/48
```

### Permission Issues

If SSH operations fail:

```bash
# Check sandbox permissions
flatpak run --command=sh io.github.tobagin.keysmith
ls -la ~/.ssh/
```

## Development Notes

- The manifests use GNOME 48 runtime for latest features
- Python dependencies are installed via pip with specific wheel files
- Build system uses Meson as configured in the project
- All dependencies follow Flathub security guidelines