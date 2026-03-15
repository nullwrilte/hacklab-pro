#!/bin/bash
# tools/health-check.sh - Verifica integridade das ferramentas instaladas e oferece auto-repair

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"
LOG="$HACKLAB_ROOT/logs/health.log"

source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

HEALTHY=() BROKEN=()

# ── Verifica uma ferramenta ───────────────────────────────────────────────────

check_tool() {
    local name="$1"

    # 1. Tenta plugin hook check() primeiro (em subshell para não poluir o ambiente)
    local plugin="$HACKLAB_ROOT/tools/plugins/${name}.sh"
    if [[ -f "$plugin" ]]; then
        if ( source "$plugin"; declare -f check &>/dev/null && check ) >> "$LOG" 2>&1; then
            HEALTHY+=("$name"); return
        else
            BROKEN+=("$name"); return
        fi
    fi

    # 2. Verifica se o binário existe no PATH
    if command -v "$name" &>/dev/null; then
        HEALTHY+=("$name"); return
    fi

    # 3. Tenta variações comuns do nome do binário
    local alt
    for alt in "${name}-ng" "${name}cat" "py${name}" "${name}3"; do
        command -v "$alt" &>/dev/null && { HEALTHY+=("$name"); return; }
    done

    BROKEN+=("$name")
}

# ── Repair ────────────────────────────────────────────────────────────────────

repair_tool() {
    local name="$1"
    log "  ↺ Reparando: $name"

    # Tenta via plugin (em subshell para não poluir o ambiente)
    local plugin="$HACKLAB_ROOT/tools/plugins/${name}.sh"
    if [[ -f "$plugin" ]]; then
        if ( source "$plugin"; declare -f install &>/dev/null && install ) >> "$LOG" 2>&1; then
            step_ok "$name reparado (plugin)"; return 0
        fi
    fi

    # Tenta via tool-list.conf
    local line
    line=$(grep -v '^\s*#' "$HACKLAB_ROOT/tools/tool-list.conf" | grep -F ":" | grep "^${name}:" | head -1)
    if [[ -n "$line" ]]; then
        local cmd_install
        cmd_install=$(echo "$line" | cut -d: -f4)
        if eval "$cmd_install" >> "$LOG" 2>&1; then
            step_ok "$name reparado"
            return 0
        fi
    fi

    step_warn "$name: falha no repair (verifique $LOG)"
    return 1
}

# ── Relatório ─────────────────────────────────────────────────────────────────

print_report() {
    echo
    echo -e "${BOLD}══════════════════════════════${NC}"
    echo -e "${BOLD}  Health Check — HACKLAB-PRO  ${NC}"
    echo -e "${BOLD}══════════════════════════════${NC}"
    echo -e " ${GREEN}✓ Saudáveis : ${#HEALTHY[@]}${NC}"
    echo -e " ${RED}✗ Quebradas : ${#BROKEN[@]}${NC}"
    echo

    if [[ ${#BROKEN[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Ferramentas com problema:${NC}"
        for t in "${BROKEN[@]}"; do echo "  • $t"; done
        echo
    fi
}

# ── Auto-repair interativo ────────────────────────────────────────────────────

prompt_repair() {
    [[ ${#BROKEN[@]} -eq 0 ]] && return

    local engine="text"
    command -v dialog   &>/dev/null && engine="dialog"
    command -v whiptail &>/dev/null && [[ "$engine" == "text" ]] && engine="whiptail"

    local do_repair=false
    case "$engine" in
        dialog|whiptail)
            "$engine" --title "Auto-Repair" \
                      --yesno "Encontradas ${#BROKEN[@]} ferramenta(s) quebrada(s).\nDeseja tentar reparar automaticamente?" \
                      8 55 && do_repair=true ;;
        text)
            read -rp "Reparar ${#BROKEN[@]} ferramenta(s) quebrada(s)? [s/N]: " r
            [[ "${r,,}" == "s" ]] && do_repair=true ;;
    esac

    if $do_repair; then
        log "=== Auto-Repair iniciado ==="
        for name in "${BROKEN[@]}"; do
            repair_tool "$name"
        done
        log "=== Auto-Repair concluído ==="
    fi
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

main() {
    mkdir -p "$(dirname "$LOG")"
    log "=== Health Check iniciado ==="

    [[ -f "$INSTALLED_DB" ]] || { log "Nenhuma ferramenta instalada ainda."; exit 0; }

    local tools=()
    mapfile -t tools < <(grep -v '^\s*$' "$INSTALLED_DB" 2>/dev/null)

    [[ ${#tools[@]} -eq 0 ]] && { log "Nenhuma ferramenta registrada."; exit 0; }

    TOTAL_STEPS=${#tools[@]}
    CURRENT_STEP=0

    for name in "${tools[@]}"; do
        CURRENT_STEP=$(( CURRENT_STEP + 1 ))
        progress_bar "$CURRENT_STEP" "$TOTAL_STEPS" "Verificando $name..."
        check_tool "$name"
    done
    echo

    print_report
    log "Saudáveis: ${#HEALTHY[@]} | Quebradas: ${#BROKEN[@]}"

    # Auto-repair apenas se chamado interativamente (não com --silent)
    [[ "${1:-}" != "--silent" ]] && prompt_repair

    log "=== Health Check concluído ==="

    # Retorna código de saída não-zero se houver ferramentas quebradas
    [[ ${#BROKEN[@]} -eq 0 ]]
}

main "$@"
