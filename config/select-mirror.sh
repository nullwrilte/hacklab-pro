#!/bin/bash
# config/select-mirror.sh - Testa latência e aplica o mirror mais rápido

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MIRRORS_FILE="$HACKLAB_ROOT/config/mirrors.list"
LOG="$HACKLAB_ROOT/logs/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Retorna latência em ms de uma URL, ou 9999 se falhar
ping_mirror() {
    local url="$1"
    local host
    host=$(echo "$url" | awk -F/ '{print $3}')
    local ms
    ms=$(curl -o /dev/null -s -w "%{time_connect}" --max-time 5 "$url" 2>/dev/null \
         | awk '{printf "%d", $1*1000}')
    echo "${ms:-9999}"
}

# Lê mirrors de uma seção (termux-main, termux-x11, etc.)
get_mirrors_for() {
    local section="$1"
    grep -v '^\s*#' "$MIRRORS_FILE" | grep -v '^\s*$' | grep "|.*${section}" \
        | sort -t'|' -k1 -n \
        | cut -d'|' -f2
}

find_fastest() {
    local section="$1"
    local best_url="" best_ms=9999

    log "Testando mirrors para: $section"
    while IFS= read -r url; do
        local ms
        ms=$(ping_mirror "$url")
        log "  ${ms}ms — $url"
        if [[ "$ms" -lt "$best_ms" ]]; then
            best_ms="$ms"
            best_url="$url"
        fi
    done < <(get_mirrors_for "$section")

    echo "$best_url"
}

apply_termux_mirror() {
    local url="$1"
    [[ -z "$url" ]] && return
    # Escreve sources.list do Termux
    cat > "$PREFIX/etc/apt/sources.list" <<EOF
# Gerado por hacklab-pro/config/select-mirror.sh
deb $url stable main
EOF
    log "✓ Mirror aplicado: $url"
}

apply_pip_mirror() {
    local url="$1"
    [[ -z "$url" ]] && return
    mkdir -p "$HOME/.config/pip"
    cat > "$HOME/.config/pip/pip.conf" <<EOF
[global]
index-url = $url
EOF
    log "✓ Mirror pip aplicado: $url"
}

main() {
    log "=== Seleção de Mirror ==="

    local fastest_main fastest_pip
    fastest_main=$(find_fastest "termux-main")
    fastest_pip=$(find_fastest "pypi")

    apply_termux_mirror "$fastest_main"
    apply_pip_mirror    "$fastest_pip"

    log "=== Mirror configurado ==="
    echo "✓ Mirror Termux : $fastest_main"
    echo "✓ Mirror pip    : $fastest_pip"
}

main "$@"
