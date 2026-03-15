#!/bin/bash
# tools/manager.sh - Gerencia instalação e atualização de ferramentas

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TOOL_LIST="$HACKLAB_ROOT/tools/tool-list.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"
LOG="$HACKLAB_ROOT/logs/install.log"

source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die()  { log "ERRO: $*"; exit 1; }
source "$HACKLAB_ROOT/scripts/audit.sh" 2>/dev/null || true

[[ -f "$TOOL_LIST" ]] || die "tool-list.conf não encontrado: $TOOL_LIST"
mkdir -p "$(dirname "$INSTALLED_DB")" "$(dirname "$LOG")"

PLUGIN_DIR="$HACKLAB_ROOT/tools/plugins"

# ── Helpers ──────────────────────────────────────────────────────────────────

# Lê linhas válidas do conf (ignora comentários e vazias)
read_tools() {
    grep -v '^\s*#' "$TOOL_LIST" | grep -v '^\s*$'
}

# Retorna linha sintética para um plugin: nome:categoria:desc:install:update
plugin_line() {
    local plugin="$1"
    local name category desc
    name=$(basename "$plugin" .sh)
    # Carrega metadados em subshell única para não poluir o ambiente e evitar problema com aspas no path
    local meta
    meta=$(bash --norc --noprofile -c "
        source $(printf '%q' "$plugin") 2>/dev/null
        echo \"\${PLUGIN_CATEGORY:-plugin}\"
        echo \"\${PLUGIN_DESC:-Plugin externo}\"
    " 2>/dev/null)
    category=$(echo "$meta" | head -1)
    desc=$(echo "$meta" | tail -1)
    echo "${name}:${category}:${desc}:__plugin__:__plugin__"
}

# Lê todas as ferramentas: conf + plugins
read_all_tools() {
    read_tools
    [[ -d "$PLUGIN_DIR" ]] || return 0
    local p
    for p in "$PLUGIN_DIR"/*.sh; do
        [[ -f "$p" ]] && plugin_line "$p"
    done
}

is_plugin() { [[ "$(field "$1" 4)" == "__plugin__" ]]; }

# Retorna campo N (1-based) de uma linha do conf
field() { echo "$1" | cut -d: -f"$2"; }

is_installed() {
    local name="$1"
    grep -qxF "$name" "$INSTALLED_DB" 2>/dev/null
}

mark_installed() {
    local name="$1"
    is_installed "$name" || echo "$name" >> "$INSTALLED_DB"
}

mark_removed() {
    local name="$1"
    grep -vxF "$name" "$INSTALLED_DB" > "${INSTALLED_DB}.tmp" 2>/dev/null && \
        mv "${INSTALLED_DB}.tmp" "$INSTALLED_DB" || true
}

# ── Ações ────────────────────────────────────────────────────────────────────

install_tool() {
    local line="$1"
    local name category desc
    name=$(field "$line" 1)
    category=$(field "$line" 2)
    desc=$(field "$line" 3)

    if is_installed "$name"; then
        log "  ↷ $name já instalado, pulando"
        return 0
    fi

    log "  ▶ Instalando $name ($category) — $desc"

    local ok=false
    if is_plugin "$line"; then
        local plugin="$PLUGIN_DIR/${name}.sh"
        if [[ -f "$plugin" ]]; then
            ( source "$plugin"; install ) >> "$LOG" 2>&1 && ok=true
        fi
    else
        local cmd_install
        cmd_install=$(field "$line" 4)
        eval "$cmd_install" >> "$LOG" 2>&1 && ok=true
    fi

    if $ok; then
        mark_installed "$name"
        step_ok "$name instalado"
    else
        step_warn "$name falhou (verifique $LOG)"
    fi
}

update_tool() {
    local line="$1"
    local name
    name=$(field "$line" 1)

    is_installed "$name" || return 0

    log "  ↑ Atualizando $name"
    local ok=false
    if is_plugin "$line"; then
        local plugin="$PLUGIN_DIR/${name}.sh"
        if [[ -f "$plugin" ]]; then
            ( source "$plugin"; update ) >> "$LOG" 2>&1 && ok=true
        fi
    else
        local cmd_update
        cmd_update=$(field "$line" 5)
        eval "$cmd_update" >> "$LOG" 2>&1 && ok=true
    fi

    if $ok; then step_ok "$name atualizado"
    else step_warn "$name: falha na atualização"; fi
}

remove_tool() {
    local name="$1"

    # Tenta via plugin primeiro
    local plugin="$PLUGIN_DIR/${name}.sh"
    if [[ -f "$plugin" ]]; then
        log "  ✗ Removendo $name (plugin)"
        ( source "$plugin"; remove ) >> "$LOG" 2>&1 || true
        mark_removed "$name"
        step_ok "$name removido"
        return 0
    fi

    local line
    line=$(read_tools | grep "^${name}:")
    [[ -n "$line" ]] || die "Ferramenta '$name' não encontrada"

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
    done < <(read_all_tools)
    [[ "$count" -gt 0 ]] || log "⚠ Nenhuma ferramenta encontrada para categoria '$category'"
    log "=== $category: $count ferramenta(s) processada(s) ==="
}

cmd_install_list() {
    local names="${*//,/ }"
    for name in $names; do
        local line
        line=$(read_all_tools | grep "^${name}:")
        if [[ -n "$line" ]]; then
            install_tool "$line"
        else
            step_warn "Ferramenta '$name' não encontrada"
        fi
    done
}

cmd_update_all() {
    log "=== Atualizando ferramentas instaladas ==="
    while IFS= read -r line; do
        update_tool "$line"
    done < <(read_all_tools)
    log "=== Atualização concluída ==="
}

cmd_list() {
    local filter_cat="${1:-}"
    printf "%-20s %-15s %-8s %s\n" "FERRAMENTA" "CATEGORIA" "ORIGEM" "DESCRIÇÃO"
    printf "%-20s %-15s %-8s %s\n" "----------" "---------" "------" "---------"
    while IFS= read -r line; do
        local name category desc origin installed_mark
        name=$(field "$line" 1)
        category=$(field "$line" 2)
        desc=$(field "$line" 3)
        is_plugin "$line" && origin="plugin" || origin="conf"
        [[ -n "$filter_cat" && "$category" != "$filter_cat" ]] && continue
        is_installed "$name" && installed_mark=" ✓" || installed_mark=""
        printf "%-20s %-15s %-8s %s%s\n" "$name" "$category" "$origin" "$desc" "$installed_mark"
    done < <(read_all_tools)
}

cmd_categories() {
    read_all_tools | cut -d: -f2 | sort -u
}

cmd_plugins() {
    [[ -d "$PLUGIN_DIR" ]] || { echo "Nenhum plugin instalado."; return; }
    printf "%-20s %-15s %s\n" "PLUGIN" "CATEGORIA" "DESCRIÇÃO"
    printf "%-20s %-15s %s\n" "------" "---------" "---------"
    local p
    for p in "$PLUGIN_DIR"/*.sh; do
        [[ -f "$p" ]] || continue
        local line; line=$(plugin_line "$p")
        local name category desc
        name=$(field "$line" 1); category=$(field "$line" 2); desc=$(field "$line" 3)
        is_installed "$name" && local mark=" ✓" || local mark=""
        printf "%-20s %-15s %s%s\n" "$name" "$category" "$desc" "$mark"
    done
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Uso: manager.sh <comando> [args]

Comandos:
  install-category <cat>   Instala todas as ferramentas de uma categoria
  install <nome,...>       Instala ferramenta(s) específica(s) (conf ou plugin)
  update                   Atualiza todas as ferramentas instaladas
  remove <nome>            Remove uma ferramenta
  list [categoria]         Lista ferramentas (✓ = instalada, origem: conf/plugin)
  categories               Lista categorias disponíveis
  plugins                  Lista plugins disponíveis em tools/plugins/
EOF
}

case "${1:-}" in
    install-category) [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_install_category "${2}" ;;
    install)          shift; cmd_install_list "$@" ;;
    update)           cmd_update_all ;;
    remove)           [[ -n "${2:-}" ]] || { usage; exit 1; }; remove_tool "${2}" ;;
    list)             cmd_list "${2:-}" ;;
    categories)       cmd_categories ;;
    plugins)          cmd_plugins ;;
    *)                usage ;;
esac
