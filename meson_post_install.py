#!/usr/bin/env python3

import os
import subprocess
import sys # Add sys import

def main():
    print("Meson post-install script executed.")

    # Compile GSettings schemas
    # Determine the schemas directory based on environment variables Meson sets
    # or common system paths. Meson's install prefix is key.
    datadir = os.environ.get('MESON_INSTALL_DESTDIR_PREFIX')
    if not datadir:
        # If MESON_INSTALL_DESTDIR_PREFIX is not set (e.g. not in a DESTDIR install)
        # then datadir is just the prefix itself.
        datadir = os.environ.get('MESON_INSTALL_PREFIX', '/usr/local') # Default if not found

    schemas_dir = os.path.join(datadir, 'share', 'glib-2.0', 'schemas')

    print(f"Checking for GSettings schemas in: {schemas_dir}")
    if os.path.isdir(schemas_dir):
        print(f"Compiling GSettings schemas in {schemas_dir}...")
        try:
            subprocess.run(["glib-compile-schemas", schemas_dir], check=True)
            print("GSettings schemas compiled successfully.")
        except FileNotFoundError:
            print("Error: glib-compile-schemas command not found. Please ensure it is installed.", file=sys.stderr)
            # sys.exit(1) # Optionally exit with error
        except subprocess.CalledProcessError as e:
            print(f"Error: Failed to compile GSettings schemas: {e}", file=sys.stderr)
            # sys.exit(1) # Optionally exit with error
        except Exception as e:
            print(f"An unexpected error occurred during schema compilation: {e}", file=sys.stderr)
            # sys.exit(1)
    else:
        print(f"GSettings schemas directory not found: {schemas_dir}. Skipping compilation.", file=sys.stderr)

    # Placeholder for other post-install actions (e.g., updating icon cache, already there)
    # For example, compiling GSettings schemas if they were used.
    # For now, it does nothing more.

if __name__ == "__main__":
    main()
