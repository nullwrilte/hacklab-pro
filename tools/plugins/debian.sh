#!/bin/bash
# tools/plugins/debian.sh - Plugin Debian via proot-distro

PLUGIN_NAME="debian"
PLUGIN_CATEGORY="distros"
PLUGIN_DESC="Debian 12 Bookworm via proot-distro"

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
_distro() { bash "$HACKLAB_ROOT/scripts/distro.sh" "$@"; }

install() { _distro install debian; }
update()  { _distro update  debian; }
remove()  { _distro remove  debian; }
check()   {
    command -v proot-distro &>/dev/null || return 1
    _distro list 2>/dev/null | grep -q "^debian"
}
