#!/bin/bash
# 01-gpu-detection.sh - Detecta GPU e instala drivers adequados

LOG="${HACKLAB_ROOT:-$(dirname "$0")/..}/logs/install.log"
HARDWARE_CONF="${HACKLAB_ROOT:-$(dirname "$0")/..}/config/hardware.conf"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

detect_soc() {
    local platform
    platform=$(getprop ro.board.platform 2>/dev/null || grep -m1 "Hardware" /proc/cpuinfo | awk '{print $NF}' || echo "unknown")
    echo "$platform" | tr '[:upper:]' '[:lower:]'
}

detect_gpu_vendor() {
    local soc="$1"
    case "$soc" in
        sm[0-9]*|msm*|qcom*|kona|lahaina|shima|yupik|taro|kalama)
            echo "adreno" ;;
        exynos*|s5e*)
            echo "mali" ;;
        mt[0-9]*|helio*)
            echo "mediatek" ;;
        *)
            # Tenta via /proc/cpuinfo
            if grep -qi "qualcomm\|snapdragon" /proc/cpuinfo 2>/dev/null; then
                echo "adreno"
            elif grep -qi "exynos\|mali" /proc/cpuinfo 2>/dev/null; then
                echo "mali"
            else
                echo "software"
            fi
            ;;
    esac
}

install_adreno_drivers() {
    log "GPU Adreno detectada - instalando Turnip/Zink..."
    pkg install -y mesa-vulkan-icd-freedreno mesa-zink >> "$LOG" 2>&1 || {
        log "⚠ mesa-turnip não disponível, tentando mesa padrão..."
        pkg install -y mesa >> "$LOG" 2>&1
    }
    # Variáveis de ambiente para Adreno
    cat >> "$PREFIX/etc/profile.d/hacklab-gpu.sh" <<'EOF'
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export EGL_PLATFORM=x11
export GALLIUM_DRIVER=zink
EOF
    log "✓ Drivers Adreno (Turnip/Zink) configurados"
}

install_mali_drivers() {
    log "GPU Mali detectada - tentando mesa-mali..."
    pkg install -y mesa >> "$LOG" 2>&1
    cat >> "$PREFIX/etc/profile.d/hacklab-gpu.sh" <<'EOF'
export EGL_PLATFORM=x11
export GALLIUM_DRIVER=softpipe
EOF
    log "⚠ Mali: suporte limitado, usando fallback llvmpipe"
}

install_software_rendering() {
    log "Usando software rendering (llvmpipe)..."
    pkg install -y mesa >> "$LOG" 2>&1
    cat >> "$PREFIX/etc/profile.d/hacklab-gpu.sh" <<'EOF'
export EGL_PLATFORM=x11
export GALLIUM_DRIVER=llvmpipe
export LIBGL_ALWAYS_SOFTWARE=1
EOF
    log "✓ Software rendering configurado"
}

test_gpu() {
    if command -v glxinfo &>/dev/null; then
        local renderer
        renderer=$(DISPLAY=:0 glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
        log "✓ OpenGL renderer: ${renderer:-não testado (X11 não ativo)}"
    fi
}

save_hardware_info() {
    local soc="$1" vendor="$2"
    mkdir -p "$(dirname "$HARDWARE_CONF")"
    cat > "$HARDWARE_CONF" <<EOF
GPU_VENDOR=$vendor
SOC_PLATFORM=$soc
DETECTED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    log "✓ Hardware salvo em $HARDWARE_CONF"
}

main() {
    log "=== Detecção de GPU ==="
    mkdir -p "$PREFIX/etc/profile.d"
    # Limpa configuração anterior
    rm -f "$PREFIX/etc/profile.d/hacklab-gpu.sh"

    local soc vendor
    soc=$(detect_soc)
    vendor=$(detect_gpu_vendor "$soc")
    log "SoC detectado: $soc | GPU: $vendor"

    case "$vendor" in
        adreno)   install_adreno_drivers ;;
        mali)     install_mali_drivers ;;
        *)        install_software_rendering ;;
    esac

    save_hardware_info "$soc" "$vendor"
    test_gpu
    log "=== GPU configurada ==="
}

main "$@"
