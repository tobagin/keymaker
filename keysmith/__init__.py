"""KeySmith - SSH Key Management Application.

A GTK4/Libadwaita application for managing SSH keys with an intuitive GUI.
"""

import gettext
import locale
import os
from pathlib import Path

__version__ = "1.0.1"
__author__ = "Thiago Fernandes"
__license__ = "GPL-3.0-or-later"

# Application constants
APPLICATION_ID = "io.github.tobagin.keysmith"
APPLICATION_NAME = "KeySmith"

# Set up translations
def setup_translations():
    """Set up gettext translations for the application."""
    try:
        # Try to set locale from environment
        locale.setlocale(locale.LC_ALL, '')
    except locale.Error:
        # Fallback to C locale
        locale.setlocale(locale.LC_ALL, 'C')
    
    # Determine locale directory
    # Check for installed location first
    system_locale_dir = "/usr/share/locale"
    local_locale_dir = Path(__file__).parent.parent / "po" / "locale"
    build_locale_dir = Path(__file__).parent.parent / "builddir" / "po"
    
    locale_dir = None
    for potential_dir in [system_locale_dir, build_locale_dir, local_locale_dir]:
        if Path(potential_dir).exists():
            locale_dir = str(potential_dir)
            break
    
    if locale_dir:
        # Set up gettext
        gettext.bindtextdomain(APPLICATION_ID, locale_dir)
        gettext.textdomain(APPLICATION_ID)
        # bind_textdomain_codeset is not always available
        try:
            gettext.bind_textdomain_codeset(APPLICATION_ID, 'UTF-8')
        except AttributeError:
            # Not available on all systems
            pass
    
    return gettext.gettext

# Set up translation function
_ = setup_translations()
