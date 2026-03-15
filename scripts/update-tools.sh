#!/bin/bash
# update-tools.sh - Atualiza pacotes do sistema e ferramentas instaladas

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG="$HACKLAB_ROOT/logs/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

update_pkg() {
    log "Atualizando repositórios e pacotes do sistema..."
    pkg update -y >> "$LOG" 2>&1 && pkg upgrade -y >> "$LOG" 2>&1
    log "✓ Sistema atualizado"
}

update_pip() {
    if command -v pip &>/dev/null; then
        log "Atualizando pacotes pip instalados..."
        pip list --outdated --format=freeze 2>/dev/null \
            | cut -d= -f1 \
            | xargs -r pip install --upgrade >> "$LOG" 2>&1 || true
        log "✓ pip atualizado"
    fi
}

update_tools() {
    log "Atualizando ferramentas do HACKLAB-PRO..."
    bash "$HACKLAB_ROOT/tools/manager.sh" update
}

main() {
    log "=== Atualização Iniciada ==="
    update_pkg
    update_pip
    update_tools
    log "=== Atualização Concluída ==="
    echo "✓ Tudo atualizado. Veja detalhes em: $LOG"
}

main "$@"
