#!/bin/bash
# 03-desktop-env.sh - Instala ambiente gráfico (XFCE4/LXQt/i3)

LOG="${HACKLAB_ROOT:-$(dirname "$0")/..}/logs/install.log"
PREFS="${HACKLAB_ROOT:-$(dirname "$0")/..}/config/user-preferences.conf"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "ERRO: $*"; exit 1; }

# Lê preferência salva ou usa padrão
get_desktop() {
    if [[ -f "$PREFS" ]]; then
        grep "^DESKTOP=" "$PREFS" | cut -d= -f2
    else
        echo "xfce4"
    fi
}

install_xfce4() {
    log "Instalando XFCE4..."
    pkg install -y \
        xfce4 \
        xfce4-terminal \
        xfce4-taskmanager \
        >> "$LOG" 2>&1 || die "Falha ao instalar XFCE4"
    # Configura sessão
    mkdir -p "$HOME/.config/xfce4"
    cat > "$HOME/.xinitrc" <<'EOF'
export DISPLAY=:0
dbus-launch --exit-with-session xfce4-session
EOF
    log "✓ XFCE4 instalado"
}

install_lxqt() {
    log "Instalando LXQt..."
    pkg install -y \
        lxqt-session \
        lxqt-panel \
        openbox \
        >> "$LOG" 2>&1 || die "Falha ao instalar LXQt"
    cat > "$HOME/.xinitrc" <<'EOF'
export DISPLAY=:0
dbus-launch --exit-with-session startlxqt
EOF
    log "✓ LXQt instalado"
}

install_i3() {
    log "Instalando i3..."
    pkg install -y \
        i3 \
        i3status \
        dmenu \
        >> "$LOG" 2>&1 || die "Falha ao instalar i3"
    mkdir -p "$HOME/.config/i3"
    # Config mínima do i3
    cat > "$HOME/.config/i3/config" <<'EOF'
set $mod Mod1
font pango:DejaVu Sans Mono 10
exec --no-startup-id dbus-launch
bindsym $mod+Return exec xterm
bindsym $mod+Shift+q kill
bindsym $mod+d exec dmenu_run
bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Sair?' -B 'Sim' 'i3-msg exit'
bar { status_command i3status }
EOF
    cat > "$HOME/.xinitrc" <<'EOF'
export DISPLAY=:0
exec i3
EOF
    log "✓ i3 instalado"
}

install_file_manager() {
    local desktop="$1"
    case "$desktop" in
        xfce4) pkg install -y thunar >> "$LOG" 2>&1 || true ;;
        lxqt)  pkg install -y pcmanfm-qt >> "$LOG" 2>&1 || true ;;
        i3)    pkg install -y pcmanfm >> "$LOG" 2>&1 || true ;;
    esac
}

configure_theme() {
    # Tema escuro básico para XFCE
    if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" 2>/dev/null || true
    fi
}

main() {
    log "=== Instalação do Ambiente Gráfico ==="
    local desktop
    desktop=$(get_desktop)
    log "Ambiente selecionado: $desktop"

    case "$desktop" in
        xfce4) install_xfce4 ;;
        lxqt)  install_lxqt ;;
        i3)    install_i3 ;;
        *)     log "⚠ Desktop '$desktop' desconhecido, instalando XFCE4..."
               install_xfce4 ;;
    esac

    install_file_manager "$desktop"
    chmod +x "$HOME/.xinitrc" 2>/dev/null || true
    log "=== Ambiente Gráfico OK ==="
}

main "$@"
