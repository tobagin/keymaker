# KeySmith

KeySmith is a GTK4/Libadwaita application designed to provide a user-friendly graphical interface for common SSH key management tasks, such as `ssh-keygen` and `ssh-copy-id`.

## Overview

Managing SSH keys via the command line can be daunting for some users. KeySmith aims to simplify this by offering a clear and intuitive GUI.

## Planned Features

*   **Generate New Keys**: Easily create new SSH key pairs (e.g., Ed25519).
*   **Key Inventory**: List all SSH keys found in `~/.ssh/`, displaying their type and fingerprint.
*   **Copy Public Key**: A simple button to copy a public key to the clipboard for use with services like GitHub or GitLab.
*   **Deploy to Server**: A "Push to Server" feature that utilizes `ssh-copy-id` in the background.

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
