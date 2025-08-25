"""Main application entry point for Key Maker."""

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

import argparse
import sys
from pathlib import Path

from gi.repository import Adw, Gio, GLib, Gtk

from . import APPLICATION_ID, APPLICATION_NAME, __version__
# Load resources before importing UI
from . import resources
from .ui.window import KeyMakerWindow


class KeyMakerApplication(Adw.Application):
    """Main Key Maker application using Adwaita Application."""

    def __init__(self):
        """Initialize the Key Maker application."""
        super().__init__(
            application_id=APPLICATION_ID,
            flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE
        )

        # Store window reference
        self.window = None

        # Connect signals
        self.connect("command-line", self._on_command_line)
        self.connect("activate", self._on_activate)
        self.connect("startup", self._on_startup)
        self.connect("shutdown", self._on_shutdown)

    def _on_startup(self, app):
        """Handle application startup."""
        # Initialize Adwaita
        Adw.init()

        # Setup GSettings and apply theme
        self._setup_settings()

        # Create application actions
        self._create_actions()

        # Set application info
        GLib.set_application_name(APPLICATION_NAME)
        GLib.set_prgname(APPLICATION_ID)

    def _setup_settings(self):
        """Setup GSettings and apply initial theme."""
        # Get GSettings
        self.settings = Gio.Settings.new(APPLICATION_ID)
        
        # Apply initial theme
        theme = self.settings.get_string("theme")
        self._apply_theme(theme)
        
        # Listen for theme changes
        self.settings.connect("changed::theme", self._on_theme_changed)

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

    def _on_theme_changed(self, settings, key):
        """Handle theme preference change."""
        theme = settings.get_string(key)
        self._apply_theme(theme)

    def _on_activate(self, app):
        """Handle application activation."""
        # Create or present main window
        if self.window is None:
            self.window = KeyMakerWindow(application=self)

        self.window.present()

    def _on_command_line(self, app, command_line):
        """Handle command line arguments."""
        # Parse command line arguments
        parser = argparse.ArgumentParser(
            prog=APPLICATION_ID,
            description="SSH Key Management Application"
        )

        parser.add_argument(
            "--version",
            action="version",
            version=f"{APPLICATION_NAME} {__version__}"
        )

        parser.add_argument(
            "--verbose", "-v",
            action="store_true",
            help="Enable verbose logging"
        )

        # Parse arguments
        args = parser.parse_args(command_line.get_arguments()[1:])

        # Handle verbose flag
        if args.verbose:
            self._setup_logging(verbose=True)

        # Activate the application
        self.activate()

        return 0

    def _on_shutdown(self, app):
        """Handle application shutdown."""
        # Cleanup resources
        if self.window:
            self.window.destroy()
            self.window = None

    def _create_actions(self):
        """Create application actions."""
        # Quit action
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self._on_quit_action)
        self.add_action(quit_action)
        self.set_accels_for_action("app.quit", ["<Control>q"])

        # About action
        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self._on_about_action)
        self.add_action(about_action)

        # Preferences action
        preferences_action = Gio.SimpleAction.new("preferences", None)
        preferences_action.connect("activate", self._on_preferences_action)
        self.add_action(preferences_action)
        self.set_accels_for_action("app.preferences", ["<Control>comma"])

        # Generate key action
        generate_action = Gio.SimpleAction.new("generate-key", None)
        generate_action.connect("activate", self._on_generate_key_action)
        self.add_action(generate_action)
        self.set_accels_for_action("app.generate-key", ["<Control>n"])

        # Refresh action
        refresh_action = Gio.SimpleAction.new("refresh", None)
        refresh_action.connect("activate", self._on_refresh_action)
        self.add_action(refresh_action)
        self.set_accels_for_action("app.refresh", ["<Control>r", "F5"])

        # Help action
        help_action = Gio.SimpleAction.new("help", None)
        help_action.connect("activate", self._on_help_action)
        self.add_action(help_action)
        self.set_accels_for_action("app.help", ["F1"])

    def _on_quit_action(self, action, parameter):
        """Handle quit action."""
        self.quit()

    def _on_about_action(self, action, parameter):
        """Handle about action."""
        # Create about dialog
        about_dialog = Adw.AboutWindow.new()
        about_dialog.set_transient_for(self.window)
        about_dialog.set_modal(True)

        # Set about dialog properties
        about_dialog.set_application_name(APPLICATION_NAME)
        about_dialog.set_application_icon(APPLICATION_ID)
        about_dialog.set_version(__version__)
        about_dialog.set_comments("A modern SSH key management application built with GTK4 and LibAdwaita")
        about_dialog.set_website("https://github.com/tobagin/keymaker")
        about_dialog.set_issue_url("https://github.com/tobagin/keymaker/issues")
        about_dialog.set_support_url("https://github.com/tobagin/keymaker/discussions")

        # Set developers
        about_dialog.set_developers([
            "Thiago Fernandes",
        ])

        # Set designers
        about_dialog.set_designers([
            "Thiago Fernandes",
        ])

        # Set license
        about_dialog.set_license_type(Gtk.License.GPL_3_0)
        about_dialog.set_copyright("© 2025 Thiago Fernandes")

        # Add translator credits if needed
        # about_dialog.set_translator_credits("translator-credits")

        # Present dialog
        about_dialog.present()

    def _on_preferences_action(self, action, parameter):
        """Handle preferences action."""
        from .ui.preferences_dialog import PreferencesDialog
        dialog = PreferencesDialog(self.window)

    def _on_generate_key_action(self, action, parameter):
        """Handle generate key action."""
        if self.window:
            self.window._on_generate_key_action(action, parameter)

    def _on_refresh_action(self, action, parameter):
        """Handle refresh action."""
        if self.window:
            self.window._on_refresh_action(action, parameter)

    def _on_help_action(self, action, parameter):
        """Handle help action."""
        if self.window:
            self.window._on_help_action(action, parameter)

    def _setup_logging(self, verbose: bool = False):
        """Setup application logging."""
        import logging

        # Configure logging level
        level = logging.DEBUG if verbose else logging.INFO

        # Setup logging format
        logging.basicConfig(
            level=level,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

        # Get logger
        logger = logging.getLogger(APPLICATION_ID)
        logger.info(f"Starting {APPLICATION_NAME} {__version__}")

        if verbose:
            logger.debug("Verbose logging enabled")


def main():
    """Main entry point for the application."""
    # Set up environment

    # Ensure SSH directory exists
    ssh_dir = Path.home() / ".ssh"
    ssh_dir.mkdir(mode=0o700, exist_ok=True)

    # Create and run application
    app = KeyMakerApplication()

    # Run the application
    try:
        exit_code = app.run(sys.argv)
        return exit_code
    except KeyboardInterrupt:
        print("\nKey Maker interrupted by user")
        return 130
    except Exception as e:
        print(f"Key Maker encountered an error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
