#!/bin/bash
# tools/plugins/ubuntu.sh - Plugin Ubuntu via proot-distro

PLUGIN_NAME="ubuntu"
PLUGIN_CATEGORY="distros"
PLUGIN_DESC="Ubuntu 24.04 LTS via proot-distro"

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
_distro() { bash "$HACKLAB_ROOT/scripts/distro.sh" "$@"; }

install() { _distro install ubuntu; }
update()  { _distro update  ubuntu; }
remove()  { _distro remove  ubuntu; }
check()   {
    command -v proot-distro &>/dev/null || return 1
    _distro list 2>/dev/null | grep -q "^ubuntu"
}
