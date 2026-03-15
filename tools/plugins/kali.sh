#!/bin/bash
# tools/plugins/kali.sh - Plugin Kali Linux NetHunter via proot-distro

PLUGIN_NAME="kali"
PLUGIN_CATEGORY="distros"
PLUGIN_DESC="Kali Linux NetHunter via proot-distro"

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
_distro() { bash "$HACKLAB_ROOT/scripts/distro.sh" "$@"; }

install() { _distro install kali; }
update()  { _distro update  kali; }
remove()  { _distro remove  kali; }
check()   {
    command -v proot-distro &>/dev/null || return 1
    _distro list 2>/dev/null | grep -q "^kali"
}
