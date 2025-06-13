# KeySmith

KeySmith is a GTK4/Libadwaita application designed to provide a user-friendly graphical interface for common SSH key management tasks, such as `ssh-keygen` and `ssh-copy-id`.

## Overview

Managing SSH keys via the command line can be daunting for some users. KeySmith aims to simplify this by offering a clear and intuitive GUI.

## Key Features

KeySmith provides a comprehensive suite for managing local SSH keys through an intuitive graphical interface.

*   **SSH Key Generation:**
    *   Generate new SSH key pairs (Ed25519 or RSA).
    *   Customize filename, comment, and add an optional passphrase.
    *   Defaults for key type (Ed25519/RSA) and RSA bit size (2048, 3072, 4096, 8192) can be set in Application Preferences.
*   **Key Inventory & Listing:**
    *   Automatically scans `~/.ssh` to list all available public keys.
    *   Displays filename, key type, and fingerprint for each key.
    *   A "Refresh" button re-scans the directory.
*   **Core Key Operations (per key):**
    *   **Copy Public Key**: Copies the full public key content to the clipboard.
    *   **Deploy to Server Helper**: Constructs the `ssh-copy-id` command (with the correct key path) and copies it to the clipboard for easy server deployment.
    *   **Change Passphrase**: Add, change, or remove the passphrase of an existing private key using `ssh-keygen -p`.
    *   **Delete Key Pair**: Securely deletes both the public and private key files with a confirmation dialog.
*   **Enhanced Key Details View:**
    *   View detailed information for each key, including:
        *   Full public key content.
        *   Key type and bit size.
        *   Full comment string.
        *   Last modification date of the key file.
*   **Application Preferences:**
    *   Set default key type (Ed25519/RSA) for new key generation.
    *   Set default RSA bit size if RSA is the chosen default type.
    *   Settings are stored via GSettings.

## Future Development

KeySmith is planned to evolve through several phases, adding more advanced workflow integrations and intelligent operations:

*   **Phase 2: Workflow Integration**
    *   Focus on deeper integration with the user's SSH environment.
    *   Key planned features include:
        *   **Full SSH Config Management**: A UI to view, create, and edit `~/.ssh/config` host entries, including mapping keys to hosts.
        *   **SSH Agent Integration**: Manage which keys are loaded into `ssh-agent` and potentially automate loading.
        *   **Interactive `ssh-copy-id`**: Execute `ssh-copy-id` directly within the application.

*   **Phase 3: Intelligent & Connected Operations**
    *   Aim to make KeySmith more proactive and aware of the broader developer ecosystem.
    *   Key planned features include:
        *   **`known_hosts` Management**: A safe UI for viewing and managing entries in `~/.ssh/known_hosts`.
        *   **Direct Cloud Service Integration**: Push public keys directly to services like GitHub, GitLab (via OAuth).
        *   **Key Health & Security Auditing**: A dashboard to audit the user's SSH setup for potential security improvements.

For a more detailed roadmap, please see [Project Vision Document/Wiki Link - Placeholder].

## Technology Stack

*   Python
*   GTK4
*   Libadwaita
*   Meson (build system)
*   Flatpak (packaging)

## Getting Started

(Instructions for building and running will be added here once the initial development is further along.)

## Contributing

Contributions are welcome! Please feel free to fork the repository, make changes, and submit a pull request.

## License

KeySmith is licensed under the GPLv3. See the `COPYING` file for more details.
