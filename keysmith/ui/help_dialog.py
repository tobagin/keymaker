"""Help dialog for KeySmith application."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Adw, Gtk, Gio


class HelpDialog(Adw.Dialog):
    """Help dialog with comprehensive KeySmith documentation."""

    def __init__(self, parent: Gtk.Window, **kwargs):
        """Initialize the help dialog.

        Args:
            parent: Parent window
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)
        
        self.set_title("KeySmith Help")
        self.set_content_width(800)
        self.set_content_height(600)
        
        # Create main content
        self._create_content()
        
        # Present to parent
        self.present(parent)
    
    def _create_content(self):
        """Create the help dialog content."""
        # Create header bar
        header_bar = Adw.HeaderBar()
        header_bar.set_title_widget(Adw.WindowTitle(title="KeySmith Help", subtitle="SSH Key Management"))
        
        # Create navigation view
        nav_view = Adw.NavigationView()
        
        # Create main help page
        main_page = self._create_main_page()
        nav_view.add(main_page)
        
        # Create toolbar view
        toolbar_view = Adw.ToolbarView()
        toolbar_view.add_top_bar(header_bar)
        toolbar_view.set_content(nav_view)
        
        self.set_child(toolbar_view)
    
    def _create_main_page(self) -> Adw.NavigationPage:
        """Create the main help page with navigation."""
        page = Adw.NavigationPage()
        page.set_title("Help")
        
        # Create scrolled window
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        # Create main list box
        main_list = Gtk.ListBox()
        main_list.set_selection_mode(Gtk.SelectionMode.NONE)
        main_list.add_css_class("boxed-list")
        
        # Add help sections
        sections = [
            ("Getting Started", "Learn the basics of SSH key management", self._show_getting_started),
            ("Generating Keys", "Create new SSH key pairs", self._show_key_generation),
            ("Managing Keys", "View, copy, and organize your keys", self._show_key_management),
            ("Security Best Practices", "Keep your SSH keys secure", self._show_security),
            ("Troubleshooting", "Common issues and solutions", self._show_troubleshooting),
            ("Keyboard Shortcuts", "Speed up your workflow", self._show_shortcuts),
        ]
        
        for title, subtitle, callback in sections:
            row = Adw.ActionRow()
            row.set_title(title)
            row.set_subtitle(subtitle)
            row.set_activatable(True)
            row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
            row.connect("activated", lambda r, cb=callback: cb())
            main_list.append(row)
        
        # Add about section
        about_group = Adw.PreferencesGroup()
        about_group.set_title("About KeySmith")
        
        about_row = Adw.ActionRow()
        about_row.set_title("About KeySmith")
        about_row.set_subtitle("Version information and credits")
        about_row.set_activatable(True)
        about_row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
        about_row.connect("activated", self._show_about)
        about_group.add(about_row)
        
        # Create main box
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        main_box.set_margin_top(24)
        main_box.set_margin_bottom(24)
        main_box.set_margin_start(24)
        main_box.set_margin_end(24)
        
        # Add content
        main_box.append(main_list)
        main_box.append(about_group)
        
        scrolled.set_child(main_box)
        page.set_child(scrolled)
        
        return page
    
    def _show_getting_started(self):
        """Show getting started help."""
        content = """# Getting Started with KeySmith

KeySmith is a user-friendly application for managing SSH keys on your system. It provides a graphical interface for common SSH key operations without requiring command-line knowledge.

## What are SSH Keys?

SSH keys are cryptographic keys used for secure authentication to remote servers. They consist of a pair:
- **Private key**: Kept secret on your computer
- **Public key**: Shared with servers you want to access

## First Steps

1. **Generate your first key**: Click the "Generate Key" button in the header bar
2. **Choose Ed25519**: This is the recommended key type for new keys
3. **Pick a filename**: Use descriptive names like "github-key" or "server-backup"
4. **Set a passphrase**: Optional but recommended for additional security

## Your SSH Directory

KeySmith manages keys in your `~/.ssh` directory:
- Private keys: `~/.ssh/keyname`
- Public keys: `~/.ssh/keyname.pub`

The application automatically scans this directory and displays all your keys.

## Key Security

- Private keys are set to 600 permissions (readable only by you)
- KeySmith never stores or logs your passphrases
- All cryptographic operations use your system's OpenSSH tools
"""
        self._show_help_page("Getting Started", content)
    
    def _show_key_generation(self):
        """Show key generation help."""
        content = """# Generating SSH Keys

KeySmith supports generating three types of SSH keys:

## Key Types

### Ed25519 (Recommended)
- Modern, secure, and fast
- Fixed key size (no bits to configure)
- Best choice for new keys

### RSA
- Widely supported but older
- Configurable key size (2048, 3072, 4096, or 8192 bits)
- Use 4096 bits for best security/compatibility balance

### ECDSA
- Good security but less commonly used
- Not recommended for new keys

## Generation Options

### Filename
- Choose descriptive names like "github-key" or "work-server"
- Avoid spaces and special characters
- Keys are saved as `~/.ssh/filename` and `~/.ssh/filename.pub`

### Comment
- Optional identifier (usually email address)
- Helps identify keys on remote servers
- Example: "john@company.com" or "personal-laptop"

### Passphrase
- Optional but strongly recommended
- Encrypts the private key file
- Required each time you use the key
- Use a strong, unique passphrase

## After Generation

Once generated, your key appears in the main window. You can:
- Copy the public key to clipboard
- Generate ssh-copy-id commands
- View key details and fingerprint
"""
        self._show_help_page("Key Generation", content)
    
    def _show_key_management(self):
        """Show key management help."""
        content = """# Managing Your SSH Keys

KeySmith provides several tools for managing your existing SSH keys.

## Key List

The main window shows all SSH keys found in your `~/.ssh` directory:
- **Key name**: The filename of your key
- **Key type**: Ed25519, RSA, or ECDSA
- **Fingerprint**: Unique identifier for the key
- **Comment**: Optional description (if set)

## Key Operations

### Copy Public Key
Click the copy button to copy the public key to your clipboard. You can then paste it into:
- GitHub/GitLab SSH key settings
- Server `~/.ssh/authorized_keys` files
- Other services requiring SSH public keys

### View Key Details
Click the info button to see detailed information:
- Full fingerprint
- Key type and bit size
- Creation/modification dates
- File permissions

### Generate ssh-copy-id Command
Click the network button to generate a command for copying your key to a server:
1. Enter the server hostname
2. Enter your username
3. Optionally specify a custom port
4. Copy the generated command and run it in your terminal

### Change Passphrase
Use the context menu to change or remove a key's passphrase:
- Enter current passphrase (if any)
- Enter new passphrase (or leave empty to remove)
- Confirm the new passphrase

### Delete Keys
Use the context menu to securely delete key pairs:
- Confirmation dialog prevents accidental deletion
- Both private and public keys are removed
- This action cannot be undone

## Refresh
Click the refresh button if you've added keys outside of KeySmith or if the list seems out of sync.
"""
        self._show_help_page("Key Management", content)
    
    def _show_security(self):
        """Show security best practices."""
        content = """# Security Best Practices

Follow these guidelines to keep your SSH keys secure:

## Key Generation

1. **Use Ed25519 for new keys**: Modern and secure
2. **Use strong passphrases**: Protect your private keys
3. **Use descriptive filenames**: Easy to identify and manage
4. **Generate separate keys for different purposes**: Work, personal, servers

## Key Storage

1. **Keep private keys private**: Never share or copy private key files
2. **Backup your keys**: Store encrypted backups in secure locations
3. **Use version control**: Consider storing public keys in dotfiles repos
4. **Regular key rotation**: Replace old keys periodically

## Passphrase Security

1. **Use unique passphrases**: Don't reuse passwords
2. **Use a password manager**: Generate and store strong passphrases
3. **Consider ssh-agent**: Avoid typing passphrases repeatedly
4. **Avoid empty passphrases**: Except for automated systems

## Access Control

1. **Limit key usage**: Use different keys for different servers
2. **Review authorized_keys**: Regularly audit which keys have access
3. **Remove unused keys**: Delete old or compromised keys
4. **Monitor key usage**: Check logs for suspicious activity

## Warning Signs

🚨 **Replace keys immediately if**:
- You suspect a key has been compromised
- A device with keys was lost or stolen
- You shared a private key by mistake
- You see unauthorized access in logs

## KeySmith Security

KeySmith follows security best practices:
- Never stores or logs passphrases
- Uses secure file permissions (600 for private keys)
- Delegates all cryptography to OpenSSH tools
- Validates all user inputs
"""
        self._show_help_page("Security Best Practices", content)
    
    def _show_troubleshooting(self):
        """Show troubleshooting help."""
        content = """# Troubleshooting

Common issues and their solutions:

## Keys Not Appearing

**Problem**: Keys don't show up in KeySmith
**Solutions**:
- Click the refresh button
- Check that keys are in `~/.ssh/` directory
- Ensure private and public key pairs exist
- Verify file permissions (private key should be 600)

## Permission Errors

**Problem**: "Permission denied" errors
**Solutions**:
- Check `~/.ssh` directory exists and has 700 permissions
- Verify private keys have 600 permissions
- Run: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*`

## Key Generation Fails

**Problem**: "Key generation failed" error
**Solutions**:
- Check that OpenSSH tools are installed (`ssh-keygen` command)
- Ensure sufficient disk space
- Verify you have write permissions to `~/.ssh`
- Try a different filename if key already exists

## SSH Connection Issues

**Problem**: Can't connect to servers with generated keys
**Solutions**:
- Ensure public key is in server's `~/.ssh/authorized_keys`
- Check server SSH configuration allows key authentication
- Verify key fingerprint matches between client and server
- Test connection with verbose output: `ssh -v user@server`

## Passphrase Problems

**Problem**: Can't change or remove passphrase
**Solutions**:
- Ensure you enter the current passphrase correctly
- Check that the private key file exists and is readable
- Try using ssh-keygen directly: `ssh-keygen -p -f ~/.ssh/keyname`

## Performance Issues

**Problem**: KeySmith is slow with many keys
**Solutions**:
- Organize keys in subdirectories (advanced)
- Remove unused old keys
- Check for corrupted key files
- Report issue if you have >100 keys

## Getting Help

If you're still having trouble:
1. Check the application logs
2. Try the operation with ssh-keygen directly
3. Search existing issues on GitHub
4. Report a new issue with details

## Useful Commands

Debug SSH connections:
```
ssh -v user@hostname
```

Test key authentication:
```
ssh -i ~/.ssh/keyname user@hostname
```

Check key fingerprint:
```
ssh-keygen -lf ~/.ssh/keyname.pub
```

Fix permissions:
```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```
"""
        self._show_help_page("Troubleshooting", content)
    
    def _show_shortcuts(self):
        """Show keyboard shortcuts."""
        content = """# Keyboard Shortcuts

Speed up your workflow with these keyboard shortcuts:

## Global Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+N` | Generate new key |
| `Ctrl+R` | Refresh key list |
| `Ctrl+Q` | Quit application |
| `Ctrl+,` | Open preferences |
| `F1` | Show this help |

## Key List Navigation

| Shortcut | Action |
|----------|--------|
| `↑/↓` | Navigate key list |
| `Enter` | View key details |
| `Ctrl+C` | Copy selected key |
| `Delete` | Delete selected key |
| `F2` | Change passphrase |

## Dialog Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Enter` | Confirm/Generate |
| `Escape` | Cancel/Close |
| `Tab` | Next field |
| `Shift+Tab` | Previous field |

## Tips

- Use `Tab` to navigate between form fields efficiently
- `Enter` in most dialogs confirms the action
- `Escape` always cancels or closes dialogs
- Arrow keys work in all list views

## Accessibility

KeySmith supports standard accessibility features:
- Full keyboard navigation
- Screen reader compatibility
- High contrast themes
- Scalable interface
"""
        self._show_help_page("Keyboard Shortcuts", content)
    
    def _show_about(self):
        """Show about information."""
        content = """# About KeySmith

**Version**: 1.0.3  
**License**: GNU General Public License v3.0 or later

## Description

KeySmith is a modern, user-friendly application for managing SSH keys on Linux systems. It provides a graphical interface for common SSH key operations including generation, management, and deployment.

## Features

- Generate Ed25519, RSA, and ECDSA SSH keys
- Manage existing keys in your ~/.ssh directory
- Copy public keys to clipboard
- Generate ssh-copy-id commands
- Change key passphrases
- Secure key deletion
- Modern GTK4 and Libadwaita interface

## Technology

- **Language**: Python 3.9+
- **GUI Framework**: GTK4 with Libadwaita
- **Build System**: Meson
- **Packaging**: Flatpak

## Security

KeySmith prioritizes security:
- Never stores or logs passphrases
- Delegates cryptography to OpenSSH tools
- Uses secure file permissions
- Validates all user inputs
- No shell injection vulnerabilities

## Contributing

KeySmith is open source software. Contributions are welcome!

- **Source Code**: https://github.com/tobagin/keysmith
- **Bug Reports**: https://github.com/tobagin/keysmith/issues
- **Documentation**: https://github.com/tobagin/keysmith/wiki

## Credits

- Built with GTK4 and Libadwaita
- Uses PyGObject for Python bindings
- Follows GNOME Human Interface Guidelines
- Icons from GNOME icon themes

## Acknowledgments

Thanks to the OpenSSH team for the excellent ssh-keygen and ssh-copy-id tools that power KeySmith's functionality.

---

© 2024 Thiago Fernandes  
Licensed under GPL v3.0 or later
"""
        self._show_help_page("About KeySmith", content)
    
    def _show_help_page(self, title: str, content: str):
        """Show a help page with the given content.
        
        Args:
            title: Page title
            content: Markdown-style content
        """
        # Get navigation view
        toolbar_view = self.get_child()
        nav_view = toolbar_view.get_content()
        
        # Create new page
        page = Adw.NavigationPage()
        page.set_title(title)
        
        # Create scrolled window
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        # Create text view for content
        text_view = Gtk.TextView()
        text_view.set_editable(False)
        text_view.set_cursor_visible(False)
        text_view.set_wrap_mode(Gtk.WrapMode.WORD)
        text_view.set_margin_top(24)
        text_view.set_margin_bottom(24)
        text_view.set_margin_start(24)
        text_view.set_margin_end(24)
        
        # Set content
        buffer = text_view.get_buffer()
        buffer.set_text(content)
        
        scrolled.set_child(text_view)
        page.set_child(scrolled)
        
        # Push page
        nav_view.push(page)