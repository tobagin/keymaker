#!/usr/bin/env bash
# Run the locally installed Keymaker build without touching the system.
# Usage:
#   ./scripts/run-local.sh           # system default language
#   ./scripts/run-local.sh de        # German
#   ./scripts/run-local.sh de_CH     # Swiss German
#   ./scripts/run-local.sh en        # English (force)

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="$ROOT/install"

if [[ ! -x "$PREFIX/bin/keymaker" ]]; then
    echo "Build not found at $PREFIX. Run:"
    echo "  meson setup builddir --prefix=\"\$(pwd)/install\""
    echo "  meson install -C builddir"
    exit 1
fi

LANG_ARG="${1:-}"
case "$LANG_ARG" in
    de)     export LANG=de_DE.UTF-8 LANGUAGE=de ;;
    de_CH)  export LANG=de_CH.UTF-8 LANGUAGE=de_CH:de ;;
    en)     export LANG=C.UTF-8     LANGUAGE=C ;;
    "")     ;;  # use system default
    *)      export LANG="${LANG_ARG}.UTF-8" LANGUAGE="$LANG_ARG" ;;
esac

export GSETTINGS_SCHEMA_DIR="$PREFIX/share/glib-2.0/schemas"
export XDG_DATA_DIRS="$PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

exec "$PREFIX/bin/keymaker" "$@"
