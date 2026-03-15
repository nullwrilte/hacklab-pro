#!/bin/bash
# ui/main-menu.sh - Menu principal do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh"

PREFS="$HACKLAB_ROOT/config/user-preferences.conf"

# Detecta engine de menu disponível
menu_engine() {
    command -v dialog   &>/dev/null && echo "dialog"   && return
    command -v whiptail &>/dev/null && echo "whiptail" && return
    echo "text"
}
ENGINE=$(menu_engine)

# ── Wrappers de UI ────────────────────────────────────────────────────────────

ui_menu() {
    # ui_menu "título" "prompt" item1 desc1 item2 desc2 ...
    local title="$1" prompt="$2"; shift 2
    local tmp; tmp=$(mktemp)
    case "$ENGINE" in
        dialog|whiptail)
            "$ENGINE" --clear --title "$title" \
                      --menu "$prompt" 20 60 10 "$@" 2>"$tmp"
            cat "$tmp"; rm -f "$tmp" ;;
        text)
            echo -e "\n${BOLD}$title${NC} — $prompt"
            local i=1 items=("$@")
            while [[ $i -le ${#items[@]} ]]; do
                echo "  $(( (i+1)/2 )) ) ${items[$i-1]}  —  ${items[$i]}"
                (( i+=2 ))
            done
            read -rp "Escolha: " opt
            # Retorna o valor (chave) correspondente ao número
            local idx=$(( (opt-1)*2 ))
            echo "${items[$idx]}" ;;
    esac
}

ui_confirm() {
    local title="$1" msg="$2"
    case "$ENGINE" in
        dialog|whiptail)
            "$ENGINE" --title "$title" --yesno "$msg" 8 50
            return $? ;;
        text)
            read -rp "$msg [s/N]: " r
            [[ "${r,,}" == "s" ]] ;;
    esac
}

ui_msg() {
    local title="$1" msg="$2"
    case "$ENGINE" in
        dialog|whiptail)
            "$ENGINE" --title "$title" --msgbox "$msg" 10 55 ;;
        text)
            echo -e "\n${BOLD}[$title]${NC} $msg\n" ;;
    esac
}

# ── Ações do menu ─────────────────────────────────────────────────────────────

action_start_lab() {
    ui_confirm "Iniciar Lab" "Iniciar desktop e serviços?" && \
        bash "$HACKLAB_ROOT/scripts/start-lab.sh"
}

action_stop_lab() {
    ui_confirm "Parar Lab" "Encerrar desktop e serviços?" && \
        bash "$HACKLAB_ROOT/scripts/stop-lab.sh"
}

action_install_tools() {
    bash "$HACKLAB_ROOT/ui/select-tools.sh"
}

action_update() {
    ui_confirm "Atualizar" "Atualizar sistema e ferramentas?" && \
        bash "$HACKLAB_ROOT/scripts/update-tools.sh"
}

action_backup() {
    bash "$HACKLAB_ROOT/scripts/backup-config.sh" && \
        ui_msg "Backup" "Backup criado com sucesso!"
}

action_restore() {
    bash "$HACKLAB_ROOT/scripts/restore-config.sh"
}

action_list_tools() {
    local output
    output=$(bash "$HACKLAB_ROOT/tools/manager.sh" list 2>/dev/null)
    case "$ENGINE" in
        dialog|whiptail)
            echo "$output" | "$ENGINE" --title "Ferramentas" --programbox 30 70 ;;
        text)
            echo "$output" | less ;;
    esac
}

action_status() {
    local x11_status desktop_status pulse_status
    pgrep -x termux-x11  &>/dev/null && x11_status="✓ rodando" || x11_status="✗ parado"
    pgrep -x pulseaudio  &>/dev/null && pulse_status="✓ rodando" || pulse_status="✗ parado"
    local desktop
    desktop=$(grep "^DESKTOP=" "$PREFS" 2>/dev/null | cut -d= -f2 || echo "xfce4")
    pgrep -x "${desktop}-session" &>/dev/null || pgrep -x "$desktop" &>/dev/null \
        && desktop_status="✓ rodando" || desktop_status="✗ parado"

    ui_msg "Status do Lab" \
"Termux:X11 : $x11_status
Desktop    : $desktop_status ($desktop)
PulseAudio : $pulse_status"
}

# ── Loop principal ────────────────────────────────────────────────────────────

main() {
    while true; do
        clear; banner

        local choice
        choice=$(ui_menu "HACKLAB-PRO" "O que deseja fazer?" \
            "start"   "▶  Iniciar Lab (desktop + serviços)" \
            "stop"    "■  Parar Lab" \
            "tools"   "🔧 Instalar / gerenciar ferramentas" \
            "update"  "↑  Atualizar tudo" \
            "backup"  "💾 Fazer backup das configurações" \
            "restore" "♻  Restaurar backup" \
            "list"    "📋 Listar ferramentas instaladas" \
            "status"  "ℹ  Status dos serviços" \
            "exit"    "✗  Sair")

        case "$choice" in
            start)   action_start_lab ;;
            stop)    action_stop_lab ;;
            tools)   action_install_tools ;;
            update)  action_update ;;
            backup)  action_backup ;;
            restore) action_restore ;;
            list)    action_list_tools ;;
            status)  action_status ;;
            exit|"") break ;;
        esac
    done
}

main "$@"
