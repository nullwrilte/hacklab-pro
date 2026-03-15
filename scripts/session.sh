#!/bin/bash
# scripts/session.sh - Salva e restaura sessões do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

SESSIONS_DIR="$HACKLAB_ROOT/config/sessions"
PREFS="$HACKLAB_ROOT/config/user-preferences.conf"
LOG="$HACKLAB_ROOT/logs/session.log"

mkdir -p "$SESSIONS_DIR" "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { echo -e "${RED}ERRO: $*${NC}" >&2; exit 1; }

# ── Coleta estado atual do lab ────────────────────────────────────────────────

_collect_state() {
    local desktop; desktop=$(grep "^DESKTOP=" "$PREFS" 2>/dev/null | cut -d= -f2 || echo "xfce4")

    # PIDs dos processos principais
    local pid_x11;     pid_x11=$(pgrep -x termux-x11    | head -1 || echo "")
    local pid_pulse;   pid_pulse=$(pgrep -x pulseaudio  | head -1 || echo "")
    local pid_dbus;    pid_dbus=$(pgrep -x dbus-daemon  | head -1 || echo "")
    local pid_desktop; pid_desktop=$(cat "$HACKLAB_ROOT/logs/desktop.pid" 2>/dev/null || echo "")

    # Variáveis de ambiente relevantes
    local display="${DISPLAY:-:0}"
    local pulse_server="${PULSE_SERVER:-127.0.0.1}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-}"

    # Ferramentas instaladas (snapshot)
    local tools_snapshot=""
    [[ -f "$HACKLAB_ROOT/config/installed-tools.conf" ]] && \
        tools_snapshot=$(paste -sd',' "$HACKLAB_ROOT/config/installed-tools.conf" 2>/dev/null || true)

    cat <<EOF
SAVED_AT=$(date '+%Y-%m-%d %H:%M:%S')
DESKTOP=$desktop
DISPLAY=$display
PULSE_SERVER=$pulse_server
DBUS_SESSION_BUS_ADDRESS=$dbus_addr
PID_X11=$pid_x11
PID_PULSE=$pid_pulse
PID_DBUS=$pid_dbus
PID_DESKTOP=$pid_desktop
TOOLS_SNAPSHOT=$tools_snapshot
EOF
}

# ── Salvar sessão ─────────────────────────────────────────────────────────────

cmd_save() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        # Nome automático baseado em timestamp
        name="session-$(date '+%Y%m%d-%H%M%S')"
    fi

    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "Nome inválido: use apenas letras, números, - e _"

    local path="$SESSIONS_DIR/${name}.conf"

    if [[ -f "$path" ]]; then
        read -rp "Sessão '$name' já existe. Sobrescrever? [s/N]: " r </dev/tty
        [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    fi

    _collect_state > "$path"
    log "Sessão '$name' salva"
    echo -e " ${GREEN}✓${NC} Sessão '${BOLD}$name${NC}' salva"
    echo -e "   Restaure com: ${CYAN}bash $HACKLAB_ROOT/scripts/session.sh restore $name${NC}"
}

# ── Listar sessões ────────────────────────────────────────────────────────────

cmd_list() {
    echo -e "\n${BOLD}Sessões salvas:${NC}"
    local found=false
    for f in "$SESSIONS_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        local name; name=$(basename "$f" .conf)
        local saved; saved=$(grep "^SAVED_AT=" "$f" | cut -d= -f2-)
        local desktop; desktop=$(grep "^DESKTOP=" "$f" | cut -d= -f2)
        local display; display=$(grep "^DISPLAY=" "$f" | cut -d= -f2)
        printf "  %-30s  %-8s  %-5s  %s\n" "$name" "$desktop" "$display" "$saved"
        found=true
    done
    $found || echo "  Nenhuma sessão salva."
    echo ""
}

# ── Restaurar sessão ──────────────────────────────────────────────────────────

cmd_restore() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        cmd_list
        read -rp "Nome da sessão a restaurar: " name </dev/tty
        [[ -z "$name" ]] && return 0
    fi

    local path="$SESSIONS_DIR/${name}.conf"
    [[ -f "$path" ]] || die "Sessão '$name' não encontrada"

    local desktop display pulse dbus saved
    desktop=$(grep "^DESKTOP="              "$path" | cut -d= -f2)
    display=$(grep "^DISPLAY="              "$path" | cut -d= -f2)
    pulse=$(grep   "^PULSE_SERVER="         "$path" | cut -d= -f2)
    dbus=$(grep    "^DBUS_SESSION_BUS_ADDRESS=" "$path" | cut -d= -f2-)
    saved=$(grep   "^SAVED_AT="             "$path" | cut -d= -f2-)

    echo -e "\n${BOLD}Restaurando sessão '$name'${NC} (salva em $saved)"
    echo -e "  Desktop: $desktop | DISPLAY: $display"

    # Exporta variáveis de ambiente da sessão
    export DISPLAY="$display"
    export PULSE_SERVER="$pulse"
    [[ -n "$dbus" ]] && export DBUS_SESSION_BUS_ADDRESS="$dbus"

    # Atualiza preferências com o desktop da sessão
    if [[ -f "$PREFS" ]]; then
        sed -i "s|^DESKTOP=.*|DESKTOP=$desktop|" "$PREFS" 2>/dev/null || true
    fi

    log "Sessão '$name' restaurada (DISPLAY=$display, DESKTOP=$desktop)"
    echo -e " ${GREEN}✓${NC} Variáveis de ambiente restauradas"

    # Pergunta se quer iniciar o lab com as configurações da sessão
    read -rp "Iniciar lab com as configurações desta sessão? [S/n]: " r </dev/tty
    if [[ "${r,,}" != "n" ]]; then
        bash "$HACKLAB_ROOT/scripts/start-lab.sh"
    fi
}

# ── Remover sessão ────────────────────────────────────────────────────────────

cmd_delete() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        cmd_list
        read -rp "Nome da sessão a remover: " name </dev/tty
        [[ -z "$name" ]] && return 0
    fi

    local path="$SESSIONS_DIR/${name}.conf"
    [[ -f "$path" ]] || die "Sessão '$name' não encontrada"

    read -rp "Remover sessão '$name'? [s/N]: " r </dev/tty
    [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    rm -f "$path"
    echo -e " ${GREEN}✓${NC} Sessão '$name' removida"
}

# ── Auto-save ao parar o lab ──────────────────────────────────────────────────

cmd_autosave() {
    local name="auto-$(date '+%Y%m%d-%H%M%S')"
    _collect_state > "$SESSIONS_DIR/${name}.conf"
    # Mantém apenas as 5 sessões auto mais recentes
    local autos=()
    mapfile -t autos < <(ls -t "$SESSIONS_DIR"/auto-*.conf 2>/dev/null)
    local i
    for (( i=5; i<${#autos[@]}; i++ )); do
        rm -f "${autos[$i]}"
    done
    log "Auto-save: $name"
}

# ── Menu interativo ───────────────────────────────────────────────────────────

cmd_menu() {
    local engine="text"
    command -v dialog   &>/dev/null && engine="dialog"
    command -v whiptail &>/dev/null && [[ "$engine" == "text" ]] && engine="whiptail"

    while true; do
        local choice
        case "$engine" in
            dialog|whiptail)
                local tmp; tmp=$(mktemp)
                "$engine" --title "Sessões do Lab" \
                          --menu "Gerenciar sessões:" 14 55 5 \
                          "save"    "Salvar sessão atual" \
                          "restore" "Restaurar sessão" \
                          "list"    "Listar sessões" \
                          "delete"  "Remover sessão" \
                          "back"    "← Voltar" \
                          2>"$tmp"
                choice=$(cat "$tmp"); rm -f "$tmp" ;;
            text)
                echo -e "\n${BOLD}Sessões do Lab:${NC}"
                echo "  1) Salvar sessão atual"
                echo "  2) Restaurar sessão"
                echo "  3) Listar sessões"
                echo "  4) Remover sessão"
                echo "  5) Voltar"
                read -rp "Escolha: " opt
                case "${opt:-5}" in
                    1) choice="save"    ;; 2) choice="restore" ;;
                    3) choice="list"    ;; 4) choice="delete"  ;;
                    *) choice="back"    ;;
                esac ;;
        esac

        case "$choice" in
            save)    cmd_save    ;;
            restore) cmd_restore ;;
            list)    cmd_list    ;;
            delete)  cmd_delete  ;;
            back|"") break ;;
        esac
    done
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    echo "Uso: session.sh <save|restore|list|delete|autosave|menu> [nome]"
}

case "${1:-menu}" in
    save)     cmd_save     "${2:-}" ;;
    restore)  cmd_restore  "${2:-}" ;;
    list)     cmd_list ;;
    delete)   cmd_delete   "${2:-}" ;;
    autosave) cmd_autosave ;;
    menu)     cmd_menu ;;
    *)        usage; exit 1 ;;
esac
