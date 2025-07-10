"""Preferences dialog for KeySmith settings."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Adw, Gio, GObject, Gtk


@Gtk.Template(resource_path='/io/github/tobagin/keysmith/ui/preferences_dialog.ui')
class PreferencesDialog(Adw.PreferencesDialog):
    """Preferences dialog using Adwaita PreferencesDialog."""

    __gtype_name__ = 'PreferencesDialog'

    # Template child widgets
    theme_row = Gtk.Template.Child()
    default_key_type_row = Gtk.Template.Child()
    default_rsa_bits_row = Gtk.Template.Child()
    default_comment_row = Gtk.Template.Child()
    use_passphrase_by_default_row = Gtk.Template.Child()
    auto_refresh_interval_row = Gtk.Template.Child()
    confirm_deletions_row = Gtk.Template.Child()
    show_fingerprints_row = Gtk.Template.Child()

    def __init__(self, parent: Gtk.Window, **kwargs):
        """Initialize the preferences dialog.

        Args:
            parent: Parent window
            **kwargs: Additional dialog arguments
        """
        super().__init__(**kwargs)

        # Get GSettings
        self.settings = Gio.Settings.new("io.github.tobagin.keysmith")

        # Setup bindings and signals
        self._setup_bindings()
        self._setup_signals()

        # Present the dialog on the parent window
        self.present(parent)

    def _setup_bindings(self):
        """Setup GSettings bindings to UI controls."""
        # Theme mapping
        theme_value = self.settings.get_string("theme")
        theme_index = {"auto": 0, "light": 1, "dark": 2}.get(theme_value, 0)
        self.theme_row.set_selected(theme_index)

        # Key type mapping
        key_type_value = self.settings.get_string("default-key-type")
        key_type_index = {"ed25519": 0, "rsa": 1, "ecdsa": 2}.get(key_type_value, 0)
        self.default_key_type_row.set_selected(key_type_index)

        # RSA bits mapping
        rsa_bits_value = self.settings.get_int("default-rsa-bits")
        rsa_bits_index = {2048: 0, 3072: 1, 4096: 2, 8192: 3}.get(rsa_bits_value, 2)
        self.default_rsa_bits_row.set_selected(rsa_bits_index)

        # Bind simple properties
        self.settings.bind(
            "default-comment",
            self.default_comment_row,
            "text",
            Gio.SettingsBindFlags.DEFAULT
        )

        self.settings.bind(
            "use-passphrase-by-default",
            self.use_passphrase_by_default_row,
            "active",
            Gio.SettingsBindFlags.DEFAULT
        )

        self.settings.bind(
            "auto-refresh-interval",
            self.auto_refresh_interval_row,
            "value",
            Gio.SettingsBindFlags.DEFAULT
        )

        self.settings.bind(
            "confirm-deletions",
            self.confirm_deletions_row,
            "active",
            Gio.SettingsBindFlags.DEFAULT
        )

        self.settings.bind(
            "show-fingerprints",
            self.show_fingerprints_row,
            "active",
            Gio.SettingsBindFlags.DEFAULT
        )

    def _setup_signals(self):
        """Setup widget signals."""
        # Connect change signals for complex mappings
        self.theme_row.connect("notify::selected", self._on_theme_changed)
        self.default_key_type_row.connect("notify::selected", self._on_key_type_changed)
        self.default_rsa_bits_row.connect("notify::selected", self._on_rsa_bits_changed)

    def _on_theme_changed(self, widget, param):
        """Handle theme selection change."""
        selected = self.theme_row.get_selected()
        theme_map = {0: "auto", 1: "light", 2: "dark"}
        theme_value = theme_map.get(selected, "auto")
        
        self.settings.set_string("theme", theme_value)
        self._apply_theme(theme_value)

    def _on_key_type_changed(self, widget, param):
        """Handle key type selection change."""
        selected = self.default_key_type_row.get_selected()
        type_map = {0: "ed25519", 1: "rsa", 2: "ecdsa"}
        key_type = type_map.get(selected, "ed25519")
        
        self.settings.set_string("default-key-type", key_type)
        
        # Show/hide RSA bits row based on selection
        self.default_rsa_bits_row.set_visible(key_type == "rsa")

    def _on_rsa_bits_changed(self, widget, param):
        """Handle RSA bits selection change."""
        selected = self.default_rsa_bits_row.get_selected()
        bits_map = {0: 2048, 1: 3072, 2: 4096, 3: 8192}
        bits_value = bits_map.get(selected, 4096)
        
        self.settings.set_int("default-rsa-bits", bits_value)

    def _apply_theme(self, theme: str):
        """Apply the theme to the application.
        
        Args:
            theme: Theme ("auto", "light", or "dark")
        """
        style_manager = Adw.StyleManager.get_default()
        
        if theme == "light":
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_LIGHT)
        elif theme == "dark":
            style_manager.set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        else:  # auto
            style_manager.set_color_scheme(Adw.ColorScheme.DEFAULT)