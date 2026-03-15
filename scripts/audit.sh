#!/bin/bash
# scripts/audit.sh - Log estruturado de auditoria do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

AUDIT_LOG="$HACKLAB_ROOT/logs/audit.log"
AUDIT_MAX_LINES=10000   # rotaciona após este limite

mkdir -p "$(dirname "$AUDIT_LOG")"

# ── Registro de evento ────────────────────────────────────────────────────────
# Formato: ISO8601 | LEVEL | USER | ACTION | DETAIL
# Chamado por outros scripts via: source audit.sh && audit_log ACTION "detalhe"

audit_log() {
    local action="${1:-UNKNOWN}"
    local detail="${2:-}"
    local level="${3:-INFO}"

    printf '%s | %-8s | %-12s | %-20s | %s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" \
        "$level" \
        "$(id -un 2>/dev/null || echo unknown)" \
        "$action" \
        "$detail" \
        >> "$AUDIT_LOG" 2>/dev/null || true

    # Rotação simples: mantém últimas AUDIT_MAX_LINES linhas
    local lines; lines=$(wc -l < "$AUDIT_LOG" 2>/dev/null || echo 0)
    if (( lines > AUDIT_MAX_LINES )); then
        local tmp; tmp=$(mktemp)
        tail -n "$AUDIT_MAX_LINES" "$AUDIT_LOG" > "$tmp" && mv "$tmp" "$AUDIT_LOG"
    fi
}

# Atalhos por nível
audit_info()  { audit_log "$1" "${2:-}" "INFO";    }
audit_warn()  { audit_log "$1" "${2:-}" "WARN";    }
audit_error() { audit_log "$1" "${2:-}" "ERROR";   }
audit_sec()   { audit_log "$1" "${2:-}" "SECURITY";}

# ── Hook automático: injeta audit_log em scripts do projeto ──────────────────
# Uso: source audit.sh  (no topo de qualquer script)
# Depois basta chamar audit_log "AÇÃO" "detalhe"

# ── Comandos de consulta ──────────────────────────────────────────────────────

cmd_show() {
    local n="${1:-50}"
    [[ -f "$AUDIT_LOG" ]] || { echo "Nenhum evento registrado."; return; }
    echo -e "\n${BOLD}Últimos $n eventos de auditoria:${NC}\n"
    tail -n "$n" "$AUDIT_LOG" | \
        awk -F' | ' '{
            level=$2
            gsub(/ /,"",level)
            color="\033[0m"
            if (level=="WARN")     color="\033[1;33m"
            if (level=="ERROR")    color="\033[0;31m"
            if (level=="SECURITY") color="\033[1;31m"
            printf "  %s%s\033[0m\n", color, $0
        }'
    echo ""
}

cmd_filter() {
    local field="$1" value="$2"
    [[ -f "$AUDIT_LOG" ]] || { echo "Nenhum evento registrado."; return; }

    case "$field" in
        level)  grep -i "| ${value} " "$AUDIT_LOG" ;;
        action) grep -i "| ${value} " "$AUDIT_LOG" ;;
        user)   grep    "| ${value} " "$AUDIT_LOG" ;;
        date)   grep    "^${value}"   "$AUDIT_LOG" ;;
        *)      grep -i "$value"      "$AUDIT_LOG" ;;
    esac | head -100
}

cmd_stats() {
    [[ -f "$AUDIT_LOG" ]] || { echo "Nenhum evento registrado."; return; }

    local total; total=$(wc -l < "$AUDIT_LOG")
    local errors; errors=$(grep -c '| ERROR' "$AUDIT_LOG" 2>/dev/null || echo 0)
    local warns;  warns=$(grep  -c '| WARN'  "$AUDIT_LOG" 2>/dev/null || echo 0)
    local secs;   secs=$(grep   -c '| SECURITY' "$AUDIT_LOG" 2>/dev/null || echo 0)

    echo -e "\n${BOLD}Estatísticas de Auditoria${NC}"
    echo -e "  Total de eventos : $total"
    echo -e "  Erros            : ${RED}$errors${NC}"
    echo -e "  Avisos           : ${YELLOW}$warns${NC}"
    echo -e "  Segurança        : ${RED}$secs${NC}"
    echo -e "  Log              : $AUDIT_LOG"
    echo -e "  Tamanho          : $(du -sh "$AUDIT_LOG" 2>/dev/null | cut -f1)"

    echo -e "\n${BOLD}Top 5 ações:${NC}"
    awk -F'|' '{gsub(/ /,"",$4); print $4}' "$AUDIT_LOG" 2>/dev/null | \
        sort | uniq -c | sort -rn | head -5 | \
        awk '{printf "  %4d  %s\n", $1, $2}'
    echo ""
}

cmd_clear() {
    read -rp "Limpar todo o log de auditoria? [s/N]: " r </dev/tty
    [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    > "$AUDIT_LOG"
    echo -e " ${GREEN}✓${NC} Log de auditoria limpo"
}

cmd_export() {
    local dest="${1:-$HACKLAB_ROOT/logs/audit-export-$(date '+%Y%m%d_%H%M%S').log}"
    cp "$AUDIT_LOG" "$dest" 2>/dev/null || die "Falha ao exportar"
    echo -e " ${GREEN}✓${NC} Exportado para: $dest"
}

# ── Integração automática com outros scripts ──────────────────────────────────
# Quando sourced, registra o script que fez o source

_audit_source_hook() {
    local caller="${BASH_SOURCE[1]:-unknown}"
    [[ "$caller" == "$HACKLAB_ROOT/scripts/audit.sh" ]] && return
    audit_log "SOURCE" "$(basename "$caller")"
}

# Só executa o hook se estiver sendo sourced (não executado diretamente)
[[ "${BASH_SOURCE[0]}" != "$0" ]] && _audit_source_hook

# ── Entrypoint standalone ─────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    usage() {
        cat <<EOF
Uso: audit.sh <comando> [args]

Comandos:
  show [n]              Mostra últimos N eventos (padrão: 50)
  filter <campo> <val>  Filtra por: level, action, user, date
  stats                 Estatísticas do log
  export [arquivo]      Exporta log para arquivo
  clear                 Limpa o log de auditoria
  log <ação> [detalhe]  Registra evento manualmente
EOF
    }

    case "${1:-show}" in
        show)   cmd_show   "${2:-50}" ;;
        filter) [[ -n "${2:-}" && -n "${3:-}" ]] || { usage; exit 1; }
                cmd_filter "$2" "$3" ;;
        stats)  cmd_stats ;;
        export) cmd_export "${2:-}" ;;
        clear)  cmd_clear ;;
        log)    shift; audit_log "$@" ;;
        *)      usage; exit 1 ;;
    esac
fi
