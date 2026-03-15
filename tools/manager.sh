#!/bin/bash
# tools/manager.sh - Gerencia instalação e atualização de ferramentas

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TOOL_LIST="$HACKLAB_ROOT/tools/tool-list.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"
LOG="$HACKLAB_ROOT/logs/install.log"

source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die()  { log "ERRO: $*"; exit 1; }

[[ -f "$TOOL_LIST" ]] || die "tool-list.conf não encontrado: $TOOL_LIST"
mkdir -p "$(dirname "$INSTALLED_DB")" "$(dirname "$LOG")"

# ── Helpers ──────────────────────────────────────────────────────────────────

# Lê linhas válidas do conf (ignora comentários e vazias)
read_tools() {
    grep -v '^\s*#' "$TOOL_LIST" | grep -v '^\s*$'
}

# Retorna campo N (1-based) de uma linha do conf
field() { echo "$1" | cut -d: -f"$2"; }

is_installed() {
    local name="$1"
    grep -q "^${name}$" "$INSTALLED_DB" 2>/dev/null
}

mark_installed() {
    local name="$1"
    is_installed "$name" || echo "$name" >> "$INSTALLED_DB"
}

mark_removed() {
    local name="$1"
    sed -i "/^${name}$/d" "$INSTALLED_DB" 2>/dev/null || true
}

# ── Ações ────────────────────────────────────────────────────────────────────

install_tool() {
    local line="$1"
    local name category desc cmd_install
    name=$(field "$line" 1)
    category=$(field "$line" 2)
    desc=$(field "$line" 3)
    cmd_install=$(field "$line" 4)

    if is_installed "$name"; then
        log "  ↷ $name já instalado, pulando"
        return 0
    fi

    log "  ▶ Instalando $name ($category) — $desc"
    if eval "$cmd_install" >> "$LOG" 2>&1; then
        mark_installed "$name"
        step_ok "$name instalado"
    else
        step_warn "$name falhou (verifique $LOG)"
    fi
}

update_tool() {
    local line="$1"
    local name cmd_update
    name=$(field "$line" 1)
    cmd_update=$(field "$line" 5)

    is_installed "$name" || return 0

    log "  ↑ Atualizando $name"
    if eval "$cmd_update" >> "$LOG" 2>&1; then
        step_ok "$name atualizado"
    else
        step_warn "$name: falha na atualização"
    fi
}

remove_tool() {
    local name="$1"
    local line
    line=$(read_tools | grep "^${name}:")
    [[ -n "$line" ]] || die "Ferramenta '$name' não encontrada no tool-list.conf"

    log "  ✗ Removendo $name"
    pkg uninstall -y "$name" >> "$LOG" 2>&1 || pip uninstall -y "$name" >> "$LOG" 2>&1 || true
    mark_removed "$name"
    step_ok "$name removido"
}

# ── Comandos públicos ─────────────────────────────────────────────────────────

cmd_install_category() {
    local category="$1"
    log "=== Instalando categoria: $category ==="
    local count=0
    while IFS= read -r line; do
        [[ "$(field "$line" 2)" == "$category" ]] || continue
        install_tool "$line"
        (( count++ )) || true
    done < <(read_tools)
    [[ "$count" -gt 0 ]] || log "⚠ Nenhuma ferramenta encontrada para categoria '$category'"
    log "=== $category: $count ferramenta(s) processada(s) ==="
}

cmd_install_list() {
    # Instala lista de nomes separados por espaço ou vírgula
    local names="${*//,/ }"
    for name in $names; do
        local line
        line=$(read_tools | grep "^${name}:")
        if [[ -n "$line" ]]; then
            install_tool "$line"
        else
            step_warn "Ferramenta '$name' não encontrada no tool-list.conf"
        fi
    done
}

cmd_update_all() {
    log "=== Atualizando ferramentas instaladas ==="
    while IFS= read -r line; do
        update_tool "$line"
    done < <(read_tools)
    log "=== Atualização concluída ==="
}

cmd_list() {
    local filter_cat="${1:-}"
    printf "%-20s %-15s %s\n" "FERRAMENTA" "CATEGORIA" "DESCRIÇÃO"
    printf "%-20s %-15s %s\n" "----------" "---------" "---------"
    while IFS= read -r line; do
        local name category desc installed_mark=""
        name=$(field "$line" 1)
        category=$(field "$line" 2)
        desc=$(field "$line" 3)
        [[ -n "$filter_cat" && "$category" != "$filter_cat" ]] && continue
        is_installed "$name" && installed_mark=" ✓" || installed_mark=""
        printf "%-20s %-15s %s%s\n" "$name" "$category" "$desc" "$installed_mark"
    done < <(read_tools)
}

cmd_categories() {
    read_tools | cut -d: -f2 | sort -u
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Uso: manager.sh <comando> [args]

Comandos:
  install-category <cat>   Instala todas as ferramentas de uma categoria
  install <nome,...>       Instala ferramenta(s) específica(s)
  update                   Atualiza todas as ferramentas instaladas
  remove <nome>            Remove uma ferramenta
  list [categoria]         Lista ferramentas (✓ = instalada)
  categories               Lista categorias disponíveis
EOF
}

case "${1:-}" in
    install-category) cmd_install_category "${2:-}" ;;
    install)          shift; cmd_install_list "$@" ;;
    update)           cmd_update_all ;;
    remove)           remove_tool "${2:-}" ;;
    list)             cmd_list "${2:-}" ;;
    categories)       cmd_categories ;;
    *)                usage ;;
esac
