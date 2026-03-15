#!/bin/bash
# restore-config.sh - Restaura backup de configurações do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG="$HACKLAB_ROOT/logs/install.log"
BACKUP_DIR="${HOME}/storage/shared/hacklab-backups"
[[ -d "$BACKUP_DIR" ]] || BACKUP_DIR="$HACKLAB_ROOT/backups"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "ERRO: $*"; exit 1; }

list_backups() {
    local backups=()
    while IFS= read -r f; do
        backups+=("$f")
    done < <(find "$BACKUP_DIR" -name "hacklab-backup_*.tar.gz" -type f | sort -r)
    echo "${backups[@]}"
}

select_backup() {
    local -a backups
    read -ra backups <<< "$(list_backups)"
    [[ ${#backups[@]} -eq 0 ]] && die "Nenhum backup encontrado em $BACKUP_DIR"

    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return
    fi

    echo "Backups disponíveis:"
    for i in "${!backups[@]}"; do
        local size
        size=$(du -sh "${backups[$i]}" | cut -f1)
        echo "  $((i+1))) $(basename "${backups[$i]}") ($size)"
    done

    read -rp "Escolha o backup [1]: " choice
    local idx=$(( ${choice:-1} - 1 ))
    echo "${backups[$idx]}"
}

do_restore() {
    local backup_file="$1"
    [[ -f "$backup_file" ]] || die "Arquivo não encontrado: $backup_file"

    log "Restaurando: $backup_file"
    echo "⚠ Isso sobrescreverá as configurações atuais."
    read -rp "Confirmar? [s/N]: " confirm
    [[ "${confirm,,}" == "s" ]] || { echo "Cancelado."; exit 0; }

    tar -xzf "$backup_file" -C / 2>> "$LOG" || die "Falha ao restaurar backup."
    log "✓ Backup restaurado com sucesso"
    echo "✓ Configurações restauradas. Reinicie o lab para aplicar."
}

main() {
    log "=== Restauração Iniciada ==="
    local backup_file
    backup_file=$(select_backup "${1:-}")
    do_restore "$backup_file"
    log "=== Restauração Concluída ==="
}

main "$@"
