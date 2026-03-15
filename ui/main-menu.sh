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
    local title="$1" prompt="$2"; shift 2
    local tmp; tmp=$(mktemp)
    case "$ENGINE" in
        dialog|whiptail)
            "$ENGINE" --clear --title "$title" \
                      --menu "$prompt" 22 65 14 "$@" 2>"$tmp"
            local result; result=$(cat "$tmp"); rm -f "$tmp"
            echo "${result}" ;;
        text)
            echo -e "\n${BOLD}$title${NC} — $prompt"
            local i=1 items=("$@")
            while [[ $i -le ${#items[@]} ]]; do
                echo "  $(( (i+1)/2 )) ) ${items[$i-1]}  —  ${items[$i]}"
                (( i+=2 ))
            done
            read -rp "Escolha: " opt
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
    if command -v fzf &>/dev/null; then
        bash "$HACKLAB_ROOT/ui/fzf-tools.sh"
    else
        bash "$HACKLAB_ROOT/ui/select-tools.sh"
    fi
}

action_update() {
    ui_confirm "Atualizar" "Atualizar sistema e ferramentas?" && \
        bash "$HACKLAB_ROOT/scripts/update-tools.sh"
}

action_check_update() {
    local result
    result=$(HACKLAB_ROOT="$HACKLAB_ROOT" VERSION_CONF="$HACKLAB_ROOT/config/version.conf" \
        bash "$HACKLAB_ROOT/core/version.sh" check 2>&1)
    ui_msg "Versão" "$result"
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
    pgrep -x termux-x11 &>/dev/null && x11_status="✓ rodando" || x11_status="✗ parado"
    pgrep -x pulseaudio &>/dev/null && pulse_status="✓ rodando" || pulse_status="✗ parado"
    local desktop
    desktop=$(grep "^DESKTOP=" "$PREFS" 2>/dev/null | head -1 | cut -d= -f2 || echo "xfce4")
    if pgrep -x "${desktop}-session" &>/dev/null || pgrep -x "$desktop" &>/dev/null; then
        desktop_status="✓ rodando"
    else
        desktop_status="✗ parado"
    fi
    ui_msg "Status do Lab" \
"Termux:X11 : $x11_status
Desktop    : $desktop_status ($desktop)
PulseAudio : $pulse_status"
}

action_health_check() {
    bash "$HACKLAB_ROOT/tools/health-check.sh"
}

action_plugins() {
    local output
    output=$(bash "$HACKLAB_ROOT/tools/manager.sh" plugins 2>/dev/null)
    case "$ENGINE" in
        dialog|whiptail)
            echo "$output" | "$ENGINE" --title "Plugins" --programbox 20 70 ;;
        text)
            echo "$output" | less ;;
    esac
}

action_distro()    { bash "$HACKLAB_ROOT/scripts/distro.sh"   menu; }
action_profiles()  { bash "$HACKLAB_ROOT/scripts/profiles.sh" menu; }
action_sessions()  { bash "$HACKLAB_ROOT/scripts/session.sh"  menu; }

action_offline() {
    bash "$HACKLAB_ROOT/scripts/offline-cache.sh" status
    local choice
    choice=$(ui_menu "Cache Offline" "O que deseja fazer?" \
        "cache"   "Baixar pacotes para cache" \
        "install" "Instalar tudo do cache" \
        "clear"   "Limpar cache" \
        "back"    "← Voltar")
    case "$choice" in
        cache)   bash "$HACKLAB_ROOT/scripts/offline-cache.sh" cache ;;
        install) bash "$HACKLAB_ROOT/scripts/offline-cache.sh" install-all ;;
        clear)   bash "$HACKLAB_ROOT/scripts/offline-cache.sh" clear ;;
    esac
}

action_dashboard() { bash "$HACKLAB_ROOT/ui/dashboard.sh"; }

action_checksum() {
    local choice
    choice=$(ui_menu "Checksums" "O que deseja fazer?" \
        "verify-all" "Verificar todos os binários" \
        "register"   "Registrar binários instalados" \
        "list"       "Listar checksums" \
        "back"       "← Voltar")
    case "$choice" in
        verify-all) bash "$HACKLAB_ROOT/scripts/checksum.sh" verify ;;
        register)   bash "$HACKLAB_ROOT/scripts/checksum.sh" register-all ;;
        list)       bash "$HACKLAB_ROOT/scripts/checksum.sh" list | less ;;
    esac
}

action_sandbox() {
    bash "$HACKLAB_ROOT/scripts/sandbox.sh" status
    local choice
    choice=$(ui_menu "Sandbox" "O que deseja fazer?" \
        "shell" "Abrir shell isolado" \
        "clean" "Limpar sandbox" \
        "back"  "← Voltar")
    case "$choice" in
        shell) bash "$HACKLAB_ROOT/scripts/sandbox.sh" shell ;;
        clean) bash "$HACKLAB_ROOT/scripts/sandbox.sh" clean ;;
    esac
}

action_audit() {
    local choice
    choice=$(ui_menu "Auditoria" "O que deseja fazer?" \
        "show"   "Ver últimos 50 eventos" \
        "stats"  "Estatísticas" \
        "export" "Exportar log" \
        "clear"  "Limpar log" \
        "back"   "← Voltar")
    case "$choice" in
        show)   bash "$HACKLAB_ROOT/scripts/audit.sh" show   | less -R ;;
        stats)  bash "$HACKLAB_ROOT/scripts/audit.sh" stats ;;
        export) bash "$HACKLAB_ROOT/scripts/audit.sh" export ;;
        clear)  bash "$HACKLAB_ROOT/scripts/audit.sh" clear ;;
    esac
}

# ── Loop principal ────────────────────────────────────────────────────────────

main() {
    while true; do
        clear; banner

        local choice
        choice=$(ui_menu "HACKLAB-PRO" "O que deseja fazer?" \
            "start"     "▶  Iniciar Lab (desktop + serviços)" \
            "stop"      "■  Parar Lab" \
            "dashboard" "📊 Dashboard em tempo real" \
            "tools"     "🔧 Instalar / gerenciar ferramentas" \
            "distro"    "🐉 Distros Linux (proot-distro)" \
            "update"    "↑  Atualizar tudo" \
            "version"   "🟢 Verificar atualizações do projeto" \
            "health"    "🩺 Health Check (verificar + reparar)" \
            "checksum"  "🔒 Verificar integridade (checksums)" \
            "sandbox"   "📦 Sandbox (execução isolada)" \
            "audit"     "📋 Auditoria de ações" \
            "plugins"   "🧩 Listar plugins disponíveis" \
            "profiles"  "📍 Perfis de instalação" \
            "sessions"  "💾 Sessões do lab" \
            "offline"   "📦 Cache offline" \
            "backup"    "💾 Fazer backup das configurações" \
            "restore"   "♻  Restaurar backup" \
            "list"      "📋 Listar ferramentas instaladas" \
            "status"    "ℹ  Status dos serviços" \
            "exit"      "✗  Sair")

        case "$choice" in
            start)     action_start_lab ;;
            stop)      action_stop_lab ;;
            dashboard) action_dashboard ;;
            tools)     action_install_tools ;;
            distro)    action_distro ;;
            update)    action_update ;;
            version)   action_check_update ;;
            health)    action_health_check ;;
            checksum)  action_checksum ;;
            sandbox)   action_sandbox ;;
            audit)     action_audit ;;
            plugins)   action_plugins ;;
            profiles)  action_profiles ;;
            sessions)  action_sessions ;;
            offline)   action_offline ;;
            backup)    action_backup ;;
            restore)   action_restore ;;
            list)      action_list_tools ;;
            status)    action_status ;;
            exit|"")   break ;;
        esac
    done
}

main "$@"
