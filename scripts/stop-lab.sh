#!/bin/bash
# stop-lab.sh - Encerra desktop e serviços do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG="$HACKLAB_ROOT/logs/lab.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

stop_desktop() {
    local pid_file="$HACKLAB_ROOT/logs/desktop.pid"
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null && log "✓ Desktop encerrado (PID $pid)"
        rm -f "$pid_file"
    fi
    # Mata processos de desktop conhecidos
    for proc in xfce4-session startlxqt i3 openbox; do
        pkill -x "$proc" 2>/dev/null && log "✓ $proc encerrado" || true
    done
}

stop_x11() {
    pkill -x "termux-x11" 2>/dev/null && log "✓ Termux:X11 encerrado" || true
    pkill -x "Xwayland"   2>/dev/null || true
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true
}

stop_pulseaudio() {
    if command -v pulseaudio &>/dev/null; then
        pulseaudio --kill 2>/dev/null && log "✓ PulseAudio encerrado" || true
    fi
}

stop_dbus() {
    pkill -x "dbus-daemon" 2>/dev/null && log "✓ dbus encerrado" || true
}

main() {
    log "=== Encerrando HACKLAB-PRO ==="
    stop_desktop
    stop_x11
    stop_pulseaudio
    stop_dbus
    log "=== Lab encerrado ==="
    echo "✓ Lab encerrado."
}

main "$@"
