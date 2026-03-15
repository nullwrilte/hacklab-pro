#!/bin/bash
# ui/dashboard.sh - Dashboard em tempo real do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

PREFS="$HACKLAB_ROOT/config/user-preferences.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"
VERSION_CONF="$HACKLAB_ROOT/config/version.conf"
LOG="$HACKLAB_ROOT/logs/install.log"
AUDIT_LOG="$HACKLAB_ROOT/logs/audit.log"

# ── Coleta de métricas ────────────────────────────────────────────────────────

_status_icon() { $1 && echo "${GREEN}●${NC}" || echo "${RED}●${NC}"; }

_svc_status() {
    local proc="$1"
    pgrep -x "$proc" &>/dev/null && echo "${GREEN}rodando${NC}" || echo "${RED}parado${NC}"
}

_mem_bar() {
    local used total pct filled bar=""
    read -r total used <<< "$(free -m 2>/dev/null | awk '/^Mem:/{print $2, $3}')"
    [[ -z "$total" || "$total" -eq 0 ]] && { echo "N/A"; return; }
    pct=$(( used * 100 / total ))
    filled=$(( pct / 10 ))
    local i
    for (( i=0; i<filled; i++ ));  do bar+="█"; done
    for (( i=filled; i<10; i++ )); do bar+="░"; done
    printf "%s %d%% (%dMB/%dMB)" "$bar" "$pct" "$used" "$total"
}

_disk_bar() {
    local line pct used avail bar=""
    line=$(df -h "$HACKLAB_ROOT" 2>/dev/null | tail -1)
    [[ -z "$line" ]] && { echo "N/A"; return; }
    pct=$(echo "$line" | awk '{gsub(/%/,"",$5); print $5}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    local filled=$(( pct / 10 ))
    local i
    for (( i=0; i<filled; i++ ));  do bar+="█"; done
    for (( i=filled; i<10; i++ )); do bar+="░"; done
    printf "%s %d%% (usado: %s | livre: %s)" "$bar" "$pct" "$used" "$avail"
}

_cpu_load() {
    local load
    load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || uptime | grep -oP 'load average: \K[\d.]+')
    echo "${load:-N/A}"
}

_tools_count() {
    local total installed
    total=$(grep -vc '^\s*[#$]' "$HACKLAB_ROOT/tools/tool-list.conf" 2>/dev/null || echo 0)
    installed=$(grep -c '.' "$INSTALLED_DB" 2>/dev/null || echo 0)
    echo "$installed/$total"
}

_last_log_lines() {
    local n="${1:-5}"
    tail -n "$n" "$LOG" 2>/dev/null | sed 's/^/  /' || echo "  (sem logs)"
}

_last_audit_lines() {
    local n="${1:-4}"
    tail -n "$n" "$AUDIT_LOG" 2>/dev/null | sed 's/^/  /' || echo "  (sem auditoria)"
}

# ── Renderiza dashboard ───────────────────────────────────────────────────────

render() {
    local version desktop
    version=$(grep "^VERSION=" "$VERSION_CONF" 2>/dev/null | cut -d= -f2 || echo "dev")
    desktop=$(grep "^DESKTOP="  "$PREFS"        2>/dev/null | cut -d= -f2 || echo "xfce4")

    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    printf  "${BOLD}${CYAN}║${NC}  ${BOLD}HACKLAB-PRO Dashboard${NC}  %-28s${BOLD}${CYAN}║${NC}\n" \
            "$(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ── Serviços
    echo -e "${BOLD}  Serviços${NC}"
    printf  "  %-14s %b\n" "Termux:X11"  "$(_svc_status termux-x11)"
    printf  "  %-14s %b\n" "PulseAudio"  "$(_svc_status pulseaudio)"
    printf  "  %-14s %b\n" "dbus"        "$(_svc_status dbus-daemon)"
    printf  "  %-14s %b  (DISPLAY=${DISPLAY:-:0})\n" "Desktop ($desktop)" \
            "$(pgrep -x "${desktop}-session" &>/dev/null || pgrep -x "$desktop" &>/dev/null \
               && echo "${GREEN}rodando${NC}" || echo "${RED}parado${NC}")"
    echo ""

    # ── Sistema
    echo -e "${BOLD}  Sistema${NC}"
    printf  "  %-14s %b\n" "CPU load"    "$(_cpu_load)"
    printf  "  %-14s %b\n" "Memória"     "$(_mem_bar)"
    printf  "  %-14s %b\n" "Disco"       "$(_disk_bar)"
    echo ""

    # ── Projeto
    echo -e "${BOLD}  Projeto${NC}"
    printf  "  %-14s %s\n" "Versão"      "v$version"
    printf  "  %-14s %s\n" "Ferramentas" "$(_tools_count) instaladas"
    printf  "  %-14s %s\n" "Desktop"     "$desktop"
    echo ""

    # ── Últimas ações
    echo -e "${BOLD}  Últimas ações (log)${NC}"
    _last_log_lines 4
    echo ""

    echo -e "  ${YELLOW}[q] sair  [r] atualizar  [s] start  [x] stop  [h] health${NC}"
}

# ── Loop interativo ───────────────────────────────────────────────────────────

main() {
    local interval="${1:-5}"   # segundos entre atualizações automáticas
    local interactive=true
    [[ "${1:-}" == "--once" ]] && { render; return; }

    # Desativa echo e modo canônico para capturar tecla sem Enter
    tput civis 2>/dev/null || true
    trap 'tput cnorm 2>/dev/null; echo ""; exit 0' INT TERM EXIT

    while true; do
        render

        # Aguarda input com timeout
        local key=""
        read -r -s -n1 -t "$interval" key || true

        case "$key" in
            q|Q) break ;;
            s)   bash "$HACKLAB_ROOT/scripts/start-lab.sh" ;;
            x)   bash "$HACKLAB_ROOT/scripts/stop-lab.sh"  ;;
            h)   bash "$HACKLAB_ROOT/tools/health-check.sh"; read -rn1 -s ;;
            # r ou timeout: apenas re-renderiza
        esac
    done

    tput cnorm 2>/dev/null || true
}

main "$@"
