# Keymaker

Manage SSH keys easily with a modern native app.

<div align="center">

![Keymaker Application](data/screenshots/main-window.png)

<a href="https://flathub.org/apps/io.github.tobagin.keysmith"><img src="https://flathub.org/api/badge" height="110" alt="Get it on Flathub"></a>
<a href="https://ko-fi.com/tobagin"><img src="data/kofi_button.png" height="82" alt="Support me on Ko-Fi"></a>

</div>

## 🎉 Version 1.2.0 - Mobile Adaptation

**Keymaker 1.2.0** brings full mobile support and a refined navigation experience.

### 🆕 What's New in 1.2.0

- **Mobile UI**: Comprehensive layout adaptation for mobile devices.
- **Navigation**: Refactored architecture to use `Adw.NavigationView`.
- **Backup**: Redesigned Backup page using `Adw.BottomSheet`.

For detailed release notes and version history, see [CHANGELOG.md](CHANGELOG.md).

## Features

### Core Features
- **Key Generation**: Create Ed25519, RSA, and ECDSA keys in seconds.
- **Key Management**: View and organize your local SSH keys.
- **Easy Deployment**: Deploy keys to servers with a guidable interface.
- **Clipboard Ready**: Copy public keys with a single click.
- **Security**: Manage passphrases and delete keys securely.

### User Experience
- **Native Design**: Built with GTK4 for a seamless GNOME experience.
- **Responsive**: Adapts to any window size.
- **Dark Mode**: Supports system-wide dark theme.

## Building from Source

```bash
# Clone the repository
git clone https://github.com/tobagin/keymaker.git
cd keymaker

# Build and install development version
./scripts/build.sh --dev
```

## Usage

### Basic Usage

1.  **Generate**: Click the **+** button to create a new key pair.
2.  **Copy**: Use the copy icon to grab your public key.
3.  **Deploy**: Use the server icon to copy the deployment command.

### Preferences

Customize your experience in the Preferences menu:
- Manage backups
- Configure confirmation dialogs

## Privacy & Security

- **Local Only**: Your keys never leave your machine unless you deploy them.
- **Secure Storage**: Passphrases can be stored in your system keyring.
- **No Tracking**: No analytics or telemetry.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Distributed under the GNU General Public License v3.0. See `LICENSE` for more information.

## Acknowledgments

- **Thiago Fernandes**: Developer
- **The GNOME Project**: For the GTK toolkit
- **OpenSSH**: For the underlying tools

## Screenshots

| Main Window | Key Generation | Key Details |
|-------------|----------------|-------------|
| ![Main Window](data/screenshots/main-window.png) | ![Key Generation](data/screenshots/generate-key.png) | ![Key Details](data/screenshots/key-details.png) |

