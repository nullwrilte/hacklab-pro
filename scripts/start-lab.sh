#!/bin/bash
# start-lab.sh - Inicia desktop e serviços do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PREFS="$HACKLAB_ROOT/config/user-preferences.conf"
LOG="$HACKLAB_ROOT/logs/lab.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Lê preferências
desktop=$(grep "^DESKTOP=" "$PREFS" 2>/dev/null | cut -d= -f2 || echo "xfce4")

check_termux_x11() {
    if ! command -v termux-x11 &>/dev/null; then
        log "⚠ Termux:X11 não encontrado."
        log "  Instale via: pkg install termux-x11-nightly"
        log "  E o app Termux:X11 no dispositivo."
        exit 1
    fi
}

start_pulseaudio() {
    if command -v pulseaudio &>/dev/null; then
        pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1" \
                   --exit-idle-time=-1 >> "$LOG" 2>&1 &
        log "✓ PulseAudio iniciado"
    fi
}

start_dbus() {
    if command -v dbus-daemon &>/dev/null && [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
        eval "$(dbus-launch --sh-syntax)" >> "$LOG" 2>&1 || true
        log "✓ dbus iniciado"
    fi
}

start_x11() {
    export DISPLAY=:0
    # Inicia Termux:X11 em background
    termux-x11 :0 -ac >> "$LOG" 2>&1 &
    sleep 2
    log "✓ Termux:X11 iniciado (DISPLAY=:0)"
}

start_desktop() {
    export DISPLAY=:0
    # Carrega variáveis de GPU se existirem
    [[ -f "$PREFIX/etc/profile.d/hacklab-gpu.sh" ]] && \
        source "$PREFIX/etc/profile.d/hacklab-gpu.sh"

    log "Iniciando desktop: $desktop"
    case "$desktop" in
        xfce4) startxfce4 >> "$LOG" 2>&1 & ;;
        lxqt)  startlxqt  >> "$LOG" 2>&1 & ;;
        i3)    i3          >> "$LOG" 2>&1 & ;;
        none)  log "Modo console — sem desktop gráfico"; return ;;
        *)     startxfce4  >> "$LOG" 2>&1 & ;;
    esac
    log "✓ Desktop '$desktop' iniciado (PID $!)"
    echo $! > "$HACKLAB_ROOT/logs/desktop.pid"
}

open_termux_x11_app() {
    # Abre o app Termux:X11 automaticamente se possível
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >> "$LOG" 2>&1 || true
}

main() {
    log "=== Iniciando HACKLAB-PRO ==="
    check_termux_x11
    start_pulseaudio
    start_dbus
    start_x11
    start_desktop
    open_termux_x11_app
    log "=== Lab iniciado. Abra o app Termux:X11 no dispositivo. ==="
    echo -e "\n✓ Lab iniciado! Abra o app \033[1mTermux:X11\033[0m no seu dispositivo."
    echo  "  Para parar: bash $HACKLAB_ROOT/scripts/stop-lab.sh"
}

main "$@"
