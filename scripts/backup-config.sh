#!/bin/bash
# backup-config.sh - Faz backup das configurações do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG="$HACKLAB_ROOT/logs/install.log"
BACKUP_DIR="${HOME}/storage/shared/hacklab-backups"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DIR/hacklab-backup_${TIMESTAMP}.tar.gz"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "ERRO: $*"; exit 1; }

check_storage() {
    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        BACKUP_DIR="$HACKLAB_ROOT/backups"
        mkdir -p "$BACKUP_DIR"
    fi
    BACKUP_FILE="$BACKUP_DIR/hacklab-backup_${TIMESTAMP}.tar.gz"
}

collect_targets() {
    local targets=()
    [[ -d "$HACKLAB_ROOT/config" ]]   && targets+=("$HACKLAB_ROOT/config")
    [[ -f "$HOME/.bashrc" ]]          && targets+=("$HOME/.bashrc")
    [[ -f "$HOME/.xinitrc" ]]         && targets+=("$HOME/.xinitrc")
    [[ -d "$HOME/.config/xfce4" ]]    && targets+=("$HOME/.config/xfce4")
    [[ -d "$HOME/.config/i3" ]]       && targets+=("$HOME/.config/i3")
    [[ -d "$HOME/.config/pulse" ]]    && targets+=("$HOME/.config/pulse")
    [[ -f "$PREFIX/etc/profile.d/hacklab-gpu.sh" ]] && \
        targets+=("$PREFIX/etc/profile.d/hacklab-gpu.sh")
    # Imprime um item por linha para preservar espaços nos paths
    printf '%s\n' "${targets[@]}"
}

do_backup() {
    local targets=()
    while IFS= read -r t; do
        targets+=("$t")
    done < <(collect_targets)
    [[ ${#targets[@]} -eq 0 ]] && die "Nenhum arquivo encontrado para backup."

    log "Criando backup em: $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" "${targets[@]}" 2>> "$LOG" || die "Falha ao criar backup."

    local size
    size=$(du -sh "$BACKUP_FILE" | cut -f1)
    log "✓ Backup criado: $BACKUP_FILE ($size)"
    echo "✓ Backup salvo em: $BACKUP_FILE ($size)"
}

# Remove backups com mais de 7 dias
cleanup_old() {
    find "$BACKUP_DIR" -name "hacklab-backup_*.tar.gz" -mtime +7 -delete 2>/dev/null || true
    log "✓ Backups antigos removidos"
}

main() {
    log "=== Backup Iniciado ==="
    check_storage
    do_backup
    cleanup_old
    log "=== Backup Concluído ==="
}

main "$@"
