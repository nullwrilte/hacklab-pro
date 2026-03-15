#!/bin/bash
# 00-environment-check.sh - Verifica ambiente Termux e permissões

source "$(dirname "$0")/../ui/progress-bar.sh" 2>/dev/null || true

LOG="${HACKLAB_ROOT:-$(dirname "$0")/..}/logs/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "ERRO: $*"; exit 1; }

check_termux() {
    [[ -n "$PREFIX" && "$PREFIX" == *"com.termux"* ]] || die "Execute dentro do Termux (não da Play Store)."
    log "✓ Termux detectado: $PREFIX"
}

check_not_playstore() {
    if pkg list-installed 2>/dev/null | grep -q "termux-tools"; then
        local ver
        ver=$(dpkg -s termux-tools 2>/dev/null | grep Version | awk '{print $2}')
        log "✓ termux-tools versão: $ver"
    fi
    # Verifica se é versão F-Droid/GitHub (tem acesso a repositórios completos)
    [[ -f "$PREFIX/etc/apt/sources.list" ]] || die "Repositório APT não encontrado. Use Termux do F-Droid/GitHub."
}

check_android_version() {
    local android_ver
    android_ver=$(getprop ro.build.version.release 2>/dev/null || echo "unknown")
    log "✓ Android versão: $android_ver"
    local major=${android_ver%%.*}
    if [[ "$major" -ge 12 ]] 2>/dev/null; then
        log "⚠ Android 12+: Desabilite o Phantom Process Killer nas opções de desenvolvedor."
    fi
}

check_storage() {
    if [[ ! -d "$HOME/storage" ]]; then
        log "Solicitando permissão de armazenamento..."
        termux-setup-storage
        sleep 3
    fi
    log "✓ Armazenamento: OK"
}

check_dependencies() {
    log "Atualizando repositórios..."
    pkg update -y >> "$LOG" 2>&1 || die "Falha ao atualizar repositórios."
    for dep in curl wget dialog proot; do
        if ! command -v "$dep" &>/dev/null; then
            log "Instalando dependência: $dep"
            pkg install -y "$dep" >> "$LOG" 2>&1 || log "⚠ Não foi possível instalar $dep"
        fi
    done
    log "✓ Dependências básicas: OK"
}

check_disk_space() {
    local free_mb
    free_mb=$(df "$PREFIX" | awk 'NR==2 {print int($4/1024)}')
    log "✓ Espaço livre: ${free_mb}MB"
    [[ "$free_mb" -ge 2048 ]] || log "⚠ Recomendado pelo menos 2GB livres (disponível: ${free_mb}MB)"
}

main() {
    mkdir -p "$(dirname "$LOG")"
    log "=== Verificação de Ambiente ==="
    check_termux
    check_not_playstore
    check_android_version
    check_storage
    check_disk_space
    check_dependencies
    log "=== Ambiente OK ==="
}

main "$@"
