# Key Maker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Vala](https://img.shields.io/badge/Vala-0.56+-blue.svg)](https://vala.dev/)
[![GTK](https://img.shields.io/badge/GTK-4.18+-blue.svg)](https://www.gtk.org/)
[![Libadwaita](https://img.shields.io/badge/Libadwaita-1.7+-blue.svg)](https://gitlab.gnome.org/GNOME/libadwaita)

Key Maker is a modern, native GTK4/Libadwaita application built with Vala that provides a user-friendly graphical interface for SSH key management tasks. It simplifies the process of generating, managing, and deploying SSH keys through an intuitive GUI while maintaining security best practices and following GNOME design guidelines.

## Features

### 🔑 SSH Key Generation
- Generate Ed25519, RSA, and ECDSA SSH keys with a modern dialog
- Smart filename generation with timestamp-based uniqueness
- Comprehensive validation with real-time error feedback
- Optional passphrase protection with confirmation matching
- Configurable RSA bit sizes (2048, 3072, 4096, 8192)
- Auto-updates filename when changing key types
- Uses preference defaults (key type, RSA bits, comment, passphrase setting)

### 📋 Key Management  
- Automatic scanning and detection of SSH keys in `~/.ssh`
- **Color-coded security indicators**: 🟢 Ed25519 (secure), 🟡 RSA (acceptable), 🔴 ECDSA (not recommended)
- Display real key types, bit sizes, fingerprints, and comments
- Toggle fingerprint visibility in preferences
- One-click public key copying to clipboard
- Generate ssh-copy-id commands for server deployment
- Smart delete confirmation system (can be disabled with safety warning)

### 🔒 Security & Passphrase Management
- Change key passphrases safely
- Never store or log passphrases in memory or files
- Delegate all cryptographic operations to system OpenSSH tools
- Secure file permission handling (600 for private keys)
- Input validation and sanitization

### 🎨 Modern Interface & UX
- Native GTK4 and Libadwaita design with Blueprint UI
- Follows GNOME Human Interface Guidelines
- **Dual build system**: Development and production versions
- Proper dialog centering and modal behavior
- Toast notifications for user feedback
- Comprehensive preferences with real-time validation
- Responsive layout and accessibility support
- **Flatpak packaging** for secure distribution

### ⚙️ Smart Preferences System
- Configurable defaults (key type, RSA bits, comment)
- Show/hide fingerprints toggle
- Delete confirmation settings with safety warnings
- Auto-refresh intervals
- Persistent settings with GSettings
- Real-time preference validation and application

## Screenshots

### Main Interface
![Main Window with Keys](data/screenshots/main-window-with-keys.png)
*Main window showing SSH key management with individual action buttons*

![Main Window - No Keys](data/screenshots/main-window-no-keys.png)
*Clean interface when no SSH keys are present*

### Key Generation
![Key Generation Dialog](data/screenshots/generate-key-without-passphrase.png)
*Key generation dialog with comprehensive options*

![Validation Feedback](data/screenshots/gerenate-ssh-key-passphrase-mismatch.png)
*Real-time validation with helpful error feedback*

### Key Management
![Key Details](data/screenshots/key-details.png)
*Detailed SSH key information and fingerprint*

![Server Deployment](data/screenshots/copy-key-to-server.png)
*Generate ssh-copy-id commands for server deployment*

![Passphrase Management](data/screenshots/change-passphrase.png)
*Secure passphrase management*

![Key Deletion](data/screenshots/delete-key.png)
*Safe key deletion with confirmation*

### Settings
![Preferences](data/screenshots/preferences.png)
*Comprehensive preferences and settings*

## Installation

Key Maker is distributed exclusively via Flatpak for security, consistency, and ease of installation across Linux distributions.

### Prerequisites

**System Dependencies:**
- Flatpak and flatpak-builder
- Development tools for building

**Ubuntu/Debian:**
```bash
sudo apt install flatpak flatpak-builder git
```

**Fedora:**
```bash
sudo dnf install flatpak flatpak-builder git
```

**Arch Linux:**
```bash
sudo pacman -S flatpak flatpak-builder git
```

### Build and Install

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tobagin/keymaker.git
   cd keymaker
   ```

2. **Build Development Version:**
   ```bash
   # Build and install development version with Flatpak
   ./scripts/build.sh --dev
   
   # Run the development version
   flatpak run io.github.tobagin.keysmith.Devel
   ```

3. **Build Production Version:**
   ```bash
   # Build and install production version
   ./scripts/build.sh
   
   # Run the production version  
   flatpak run io.github.tobagin.keysmith
   ```

### Quick Start

For the fastest setup experience:

```bash
git clone https://github.com/tobagin/keymaker.git
cd keymaker
./scripts/build.sh --dev
flatpak run io.github.tobagin.keysmith.Devel
```

The build script automatically handles all dependencies and creates a sandboxed Flatpak application ready to use.

## Usage

### Generating SSH Keys

1. Click the "Generate Key" button in the header bar
2. Select your preferred key type (Ed25519 recommended)
3. Set a filename and comment
4. Optionally add a passphrase for extra security
5. Click "Generate" to create the key pair

### Managing Existing Keys

- **View Keys**: All keys in `~/.ssh` are automatically listed
- **Copy Public Key**: Click the copy button to copy the public key to clipboard
- **Generate ssh-copy-id Command**: Use the network button to generate deployment commands
- **View Details**: Click the info button to see detailed key information
- **Delete Keys**: Use the menu to securely delete key pairs

### Application Preferences

Key Maker provides a comprehensive preferences system:

**Generation Defaults:**
- Default key type (Ed25519/RSA/ECDSA)
- Default RSA bit size (2048/3072/4096/8192)  
- Default comment template
- Use passphrase by default setting

**Interface Options:**
- Show/hide fingerprints in key list
- Auto-refresh interval
- Delete confirmation behavior
- Theme preferences (follows system)

**Security Settings:**
- Confirm key deletions (with safety warning when disabled)
- Secure file permission handling

## Configuration

### GSettings Schema

Key Maker uses GSettings for persistent configuration:

```bash
# View all settings (Development)
gsettings list-recursively io.github.tobagin.keysmith.Devel

# View all settings (Production)  
gsettings list-recursively io.github.tobagin.keysmith

# Change default key type
gsettings set io.github.tobagin.keysmith.Devel default-key-type 'rsa'

# Set default RSA bit size
gsettings set io.github.tobagin.keysmith.Devel default-rsa-bits 4096

# Toggle fingerprint display
gsettings set io.github.tobagin.keysmith.Devel show-fingerprints true

# Configure delete confirmations
gsettings set io.github.tobagin.keysmith.Devel confirm-deletions true
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Run with debug messages
G_MESSAGES_DEBUG=all flatpak run io.github.tobagin.keysmith.Devel

# Or for production version
G_MESSAGES_DEBUG=all flatpak run io.github.tobagin.keysmith
```

## Testing & Development

### Manual Testing

Test the application functionality:

```bash
# Build development version
./scripts/build.sh --dev

# Run with debug output
G_MESSAGES_DEBUG=all flatpak run io.github.tobagin.keysmith.Devel

# Test key generation with different types
# Test preferences saving and loading  
# Test key detection and color coding
# Test delete confirmation behavior
```

### Code Quality

Key Maker uses modern Vala practices:

- **Memory safety**: Automatic memory management with reference counting
- **Type safety**: Strong typing with compile-time checks  
- **Blueprint UI**: Declarative UI definitions with compile-time validation
- **GObject integration**: Native GLib/GTK integration
- **Async/await**: Non-blocking operations for file I/O and subprocess calls

## Security

Key Maker follows strict security practices:

- **Never stores passphrases** - kept only in memory during operations
- **Delegates all cryptography** to system OpenSSH tools (ssh-keygen, ssh-add)
- **Secure file permissions** - private keys automatically set to 600
- **Input sanitization** - all user inputs validated before subprocess calls
- **No shell injection** - direct subprocess execution without shell interpretation
- **Sandboxed execution** - Flatpak provides additional security isolation
- **Minimal permissions** - Only requires SSH directory access and SSH agent socket

## Flatpak Architecture

Key Maker is designed as a Flatpak-first application:

**Development vs Production:**
- Separate app IDs: `io.github.tobagin.keysmith.Devel` vs `io.github.tobagin.keysmith`
- Independent settings and data directories
- Different branding and theming

**Permissions:**
```yaml
finish-args:
  - --share=network           # For ssh-copy-id operations
  - --share=ipc               # Required for GTK
  - --socket=x11              # X11 display access
  - --socket=wayland          # Wayland display access  
  - --socket=ssh-auth         # SSH agent communication
  - --filesystem=~/.ssh:create # SSH directory access
  - --talk-name=org.gnome.keyring     # Keyring integration
  - --talk-name=org.freedesktop.secrets # Secret service
```

## Architecture

Key Maker follows modern Vala/GTK application architecture:

```
src/
├── main.vala                    # Application entry point
├── application.vala             # GtkApplication subclass
├── models/                      # Data models and types
│   ├── enums.vala              # SSH key types and error enums
│   └── ssh-key.vala            # SSH key data structures
├── backend/                     # Core business logic
│   ├── ssh-operations.vala     # SSH key operations (generate, delete, etc.)
│   └── key-scanner.vala        # SSH directory scanning and detection
└── ui/                         # User interface components
    ├── window.vala             # Main application window
    ├── key-list.vala           # Key list container widget
    ├── key-row.vala            # Individual key row with color coding
    └── dialogs/                # Modal dialogs
        ├── generate-dialog.vala         # Key generation
        ├── preferences-dialog.vala      # Application settings
        ├── delete-key-dialog.vala      # Delete confirmation
        ├── key-details-dialog.vala     # Key information
        └── ...                         # Other utility dialogs

data/
├── ui/                         # Blueprint UI definitions
│   ├── *.blp                  # Declarative UI files
│   └── keysmith.gresource.xml # UI resource bundling
├── icons/                      # Application icons
└── *.desktop.in              # Desktop entry templates
```

**Design Patterns:**
- **MVC Architecture**: Clear separation of models, views, and controllers
- **Observer Pattern**: GSettings and UI binding for preferences
- **Async Operations**: Non-blocking file I/O and subprocess execution
- **Resource Management**: Automatic cleanup and error handling

## Future Development

### Phase 2: Workflow Integration
- **SSH Config Management**: Edit `~/.ssh/config` files
- **SSH Agent Integration**: Manage loaded keys
- **Interactive ssh-copy-id**: Execute deployments directly

### Phase 3: Advanced Features
- **known_hosts Management**: Safe host key management
- **Cloud Integration**: Direct GitHub/GitLab key deployment
- **Security Auditing**: Key health and security recommendations

## Contributing

Contributions are welcome! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run the test suite
5. Submit a pull request

### Code Style

- Follow Vala coding conventions
- Use Blueprint for UI definitions
- Add documentation comments for public APIs
- Test changes with both development and production builds
- Ensure proper error handling and memory management
- Follow GNOME Human Interface Guidelines for UI changes

## Support

- **Bug Reports**: [GitHub Issues](https://github.com/tobagin/keymaker/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/tobagin/keymaker/discussions)
- **Documentation**: [Project Wiki](https://github.com/tobagin/keymaker/wiki)

## License

Key Maker is licensed under the GNU General Public License v3.0 or later. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Vala](https://vala.dev/) programming language
- Uses [GTK4](https://www.gtk.org/) and [Libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/) for the modern interface
- UI designed with [Blueprint](https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/) for declarative interface definitions
- Follows [GNOME Human Interface Guidelines](https://developer.gnome.org/hig/) for consistent user experience
- Packaged with [Flatpak](https://flatpak.org/) for secure, cross-distribution deployment
- Inspired by the need for accessible SSH key management tools that follow modern Linux desktop standards
