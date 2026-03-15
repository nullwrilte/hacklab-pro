#!/bin/bash
# install.sh - Instalador principal do HACKLAB-PRO

set -euo pipefail

export HACKLAB_ROOT="$(cd "$(dirname "$0")" && pwd)"
export LOG="$HACKLAB_ROOT/logs/install.log"
export PREFS="$HACKLAB_ROOT/config/user-preferences.conf"

source "$HACKLAB_ROOT/ui/progress-bar.sh"

mkdir -p "$HACKLAB_ROOT/logs"
exec > >(tee -a "$LOG") 2>&1

die() { step_err "$*"; exit 1; }

# ── Menu interativo ──────────────────────────────────────────────────────────

select_desktop() {
    if command -v dialog &>/dev/null; then
        dialog --title "HACKLAB-PRO" \
               --menu "Escolha o ambiente gráfico:" 12 50 4 \
               "xfce4" "XFCE4 (recomendado, leve)" \
               "lxqt"  "LXQt (moderno, Qt)" \
               "i3"    "i3 (tiling, pouca RAM)" \
               "none"  "Apenas console" \
               2>/tmp/hacklab_desktop && cat /tmp/hacklab_desktop || echo "xfce4"
    else
        echo -e "\nAmbiente gráfico:"
        echo "  1) XFCE4 (padrão)"
        echo "  2) LXQt"
        echo "  3) i3"
        echo "  4) Apenas console"
        read -rp "Escolha [1]: " opt
        case "${opt:-1}" in
            2) echo "lxqt" ;; 3) echo "i3" ;; 4) echo "none" ;; *) echo "xfce4" ;;
        esac
    fi
}

select_options() {
    local wine="false" gpu="true"
    read -rp "Ativar suporte a Wine (.exe)? [s/N]: " w
    [[ "${w,,}" == "s" ]] && wine="true"
    read -rp "Ativar aceleração de GPU? [S/n]: " g
    [[ "${g,,}" == "n" ]] && gpu="false"
    echo "WINE=$wine"
    echo "GPU_ACCEL=$gpu"
}

save_preferences() {
    local desktop="$1"
    mkdir -p "$(dirname "$PREFS")"
    {
        echo "DESKTOP=$desktop"
        select_options
        echo "INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$PREFS"
}

# ── Orquestrador ─────────────────────────────────────────────────────────────

run_module() {
    local script="$HACKLAB_ROOT/core/$1"
    [[ -f "$script" ]] || die "Módulo não encontrado: $script"
    chmod +x "$script"
    bash "$script" || die "Falha no módulo: $1"
}

main() {
    clear
    banner

    echo -e "${BOLD}Iniciando instalação...${NC}"
    echo -e "Log: $LOG\n"

    # Coleta preferências antes de instalar
    local desktop
    desktop=$(select_desktop)
    save_preferences "$desktop"

    # Lê se GPU está habilitada
    local gpu_accel
    gpu_accel=$(grep "^GPU_ACCEL=" "$PREFS" | cut -d= -f2)

    TOTAL_STEPS=5

    step_start "Verificando ambiente"
    run_module "00-environment-check.sh"
    step_ok "Ambiente verificado"

    if [[ "$gpu_accel" != "false" ]]; then
        step_start "Detectando GPU"
        run_module "01-gpu-detection.sh"
        step_ok "GPU configurada"
    else
        step_start "GPU desabilitada pelo usuário"
        CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    fi

    if [[ "$desktop" != "none" ]]; then
        step_start "Instalando base do desktop"
        run_module "02-desktop-base.sh"
        step_ok "Base instalada"

        step_start "Instalando ambiente gráfico ($desktop)"
        run_module "03-desktop-env.sh"
        step_ok "Desktop instalado"
    else
        CURRENT_STEP=$(( CURRENT_STEP + 2 ))
        step_start "Modo console selecionado"
        step_ok "Pulando instalação gráfica"
    fi

    step_start "Limpeza final"
    run_module "99-cleanup.sh"
    step_ok "Concluído"

    echo -e "\n${GREEN}${BOLD}✓ HACKLAB-PRO instalado com sucesso!${NC}"
    echo -e "  Inicie com: ${CYAN}bash $HACKLAB_ROOT/scripts/start-lab.sh${NC}\n"
}

main "$@"
