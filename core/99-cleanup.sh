#!/bin/bash
# 99-cleanup.sh - Limpeza final após instalação

LOG="${HACKLAB_ROOT:-$(dirname "$0")/..}/logs/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

clean_pkg_cache() {
    log "Limpando cache de pacotes..."
    pkg clean >> "$LOG" 2>&1 || apt-get clean >> "$LOG" 2>&1 || true
    log "✓ Cache limpo"
}

clean_tmp() {
    log "Limpando arquivos temporários..."
    rm -rf "$TMPDIR"/hacklab-* 2>/dev/null || true
    log "✓ Temporários removidos"
}

fix_permissions() {
    log "Ajustando permissões dos scripts..."
    local root="${HACKLAB_ROOT:-$(dirname "$0")/..}"
    find "$root" -name "*.sh" -exec chmod +x {} \;
    log "✓ Permissões ajustadas"
}

show_summary() {
    local root="${HACKLAB_ROOT:-$(dirname "$0")/..}"
    local log_size
    log_size=$(wc -l < "$LOG" 2>/dev/null || echo "0")
    log "=== Resumo da Instalação ==="
    log "Log: $LOG ($log_size linhas)"
    log "Para iniciar o laboratório: bash $root/scripts/start-lab.sh"
    log "Para parar: bash $root/scripts/stop-lab.sh"
    log "============================================"
}

main() {
    log "=== Limpeza Final ==="
    clean_pkg_cache
    clean_tmp
    fix_permissions
    show_summary
    log "=== Instalação Concluída! ==="
}

main "$@"
