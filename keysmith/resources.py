"""Resource loading for KeySmith UI."""

import os
from gi.repository import Gio, GLib


def load_ui_resources():
    """Load UI resources from GResource."""
    # Try different resource paths
    resource_paths = [
        # Build directory for development
        os.path.join(os.path.dirname(__file__), "..", "build", "data", "ui", "keysmith-ui.gresource"),
        # Flatpak installed location
        "/app/share/keysmith/keysmith-ui.gresource",
        # System installed location
        "/usr/share/keysmith/keysmith-ui.gresource",
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