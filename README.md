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

This section guides you through building and running KeySmith from source. For end-users, KeySmith is intended to be distributed as a Flatpak, which will manage dependencies automatically.

### Dependencies

To build KeySmith from source, you will need the following development packages:

*   **Python 3**: (Typically `python3` and `python3-dev` or `python3-devel`)
*   **GTK4**: (`libgtk-4-dev` or similar)
*   **Libadwaita**: (`libadwaita-1-dev` or similar)
*   **Meson Build System**: (`meson`)
*   **Ninja**: (Usually a dependency of Meson, or `ninja-build`)
*   **GLib Schemas Compiler**: `glib-compile-schemas` (Often part of `libglib2.0-dev` or `glib2-devel`)
*   **Desktop File Utilities**: `desktop-file-utils` (for `desktop-file-validate` during development, optional but good practice)
*   **(Optional) Flatpak tools**: `flatpak-builder` (if you intend to build the Flatpak package locally).

The exact package names may vary depending on your Linux distribution.

### Building from Source

Once you have the dependencies installed, you can build KeySmith using Meson:

1.  **Setup the build directory:**
    ```bash
    meson setup builddir
    ```
    (You can replace `builddir` with your preferred build directory name.)

2.  **Compile the project:**
    ```bash
    meson compile -C builddir
    ```

### Running

After successful compilation, you can run KeySmith directly from the build directory:

```bash
./builddir/keysmith
```
(If you used a different build directory name, replace `builddir` accordingly.)

If the application has issues finding its settings (e.g., default key types not loading), you may need to specify the GSettings schema directory when running from the build directory without a system-wide install. First, ensure schemas are compiled in your build output (Meson might do this, or you can run `glib-compile-schemas builddir/data/` if your schemas are output there). Then run:

```bash
GSETTINGS_SCHEMA_DIR=./builddir/data ./builddir/keysmith
```
Adjust the path `builddir/data` if your compiled schemas (`gschemas.compiled`) are located elsewhere within the build directory.

### Running Tests

Basic unit tests are located in the `tests/` directory. You can run them using Python's `unittest` module from the root of the project:

```bash
python3 -m unittest tests.test_keysmith
```

**Note:** Running these tests in some minimal or sandboxed environments might encounter issues related to GObject Introspection (`gi` module) if the environment is not fully set up for GTK application testing. The tests primarily focus on command generation logic and use mocking for UI and subprocess interactions, so they should pass in a development environment where KeySmith itself can run.

## Contributing

Contributions are welcome! Please feel free to fork the repository, make changes, and submit a pull request.

## License

KeySmith is licensed under the GPLv3. See the `COPYING` file for more details.
