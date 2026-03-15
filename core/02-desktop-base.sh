#!/bin/bash
# 02-desktop-base.sh - Instala X11, PulseAudio, dbus

LOG="${HACKLAB_ROOT:-$(dirname "$0")/..}/logs/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "ERRO: $*"; exit 1; }

install_x11() {
    log "Instalando X11 e Termux:X11..."
    pkg install -y \
        x11-repo \
        >> "$LOG" 2>&1
    pkg install -y \
        xorg-xauth \
        xorg-xhost \
        xorg-xrandr \
        xorg-xrdb \
        xterm \
        >> "$LOG" 2>&1 || die "Falha ao instalar X11"
    log "✓ X11 instalado"
}

install_pulseaudio() {
    log "Instalando PulseAudio..."
    pkg install -y pulseaudio >> "$LOG" 2>&1 || log "⚠ PulseAudio não disponível"
    # Configura PulseAudio para iniciar sem daemon de sistema
    mkdir -p "$HOME/.config/pulse"
    cat > "$HOME/.config/pulse/default.pa" <<'EOF'
load-module module-native-protocol-unix
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1
load-module module-aaudio-sink
load-module module-aaudio-source
EOF
    log "✓ PulseAudio configurado"
}

install_dbus() {
    log "Instalando dbus..."
    pkg install -y dbus >> "$LOG" 2>&1 || log "⚠ dbus não disponível"
    log "✓ dbus instalado"
}

install_fonts() {
    log "Instalando fontes..."
    pkg install -y \
        fontconfig \
        fonts-dejavu \
        >> "$LOG" 2>&1
    fc-cache -fv >> "$LOG" 2>&1 || true
    log "✓ Fontes configuradas"
}

configure_display() {
    grep -q '^export DISPLAY=' "$HOME/.bashrc" 2>/dev/null || \
        echo 'export DISPLAY=:0' >> "$HOME/.bashrc"
    grep -q '^export PULSE_SERVER=' "$HOME/.bashrc" 2>/dev/null || \
        echo 'export PULSE_SERVER=127.0.0.1' >> "$HOME/.bashrc"
    log "✓ Variáveis de display configuradas"
}

main() {
    log "=== Instalação da Base Desktop ==="
    install_x11
    install_pulseaudio
    install_dbus
    install_fonts
    configure_display
    log "=== Base Desktop OK ==="
}

main "$@"
