"""Resource loading for Key Maker UI."""

import os
from gi.repository import Gio, GLib


def load_ui_resources():
    """Load UI resources from GResource."""
    # Try different resource paths
    resource_paths = [
        # Build directory for development
        os.path.join(os.path.dirname(__file__), "..", "build", "data", "ui", "keymaker-ui.gresource"),
        # Flatpak installed location
        "/app/share/keymaker/keymaker-ui.gresource",
        # System installed location
        "/usr/share/keymaker/keymaker-ui.gresource",
    ]
    
    for resource_path in resource_paths:
        try:
            if os.path.exists(resource_path):
                resource = Gio.Resource.load(resource_path)
                Gio.resources_register(resource)
                return True
        except GLib.Error:
            continue
    
    return False


# Load resources immediately when this module is imported
load_ui_resources()