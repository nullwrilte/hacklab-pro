#!/bin/bash
# install.sh - Instalador principal do HACKLAB-PRO

# ── Inicialização segura ──────────────────────────────────────────────────────
# Não usa set -e globalmente pois dialog retorna exit 1 ao cancelar.
# Erros fatais são tratados explicitamente via die().
set -uo pipefail

export HACKLAB_ROOT="$(cd "$(dirname "$0")" && pwd)"
export LOG="$HACKLAB_ROOT/logs/install.log"
export PREFS="$HACKLAB_ROOT/config/user-preferences.conf"

# Garante diretório de log antes de qualquer outra coisa
mkdir -p "$HACKLAB_ROOT/logs" "$HACKLAB_ROOT/config"

# Carrega UI (após mkdir para garantir que o log pode ser criado)
source "$HACKLAB_ROOT/ui/progress-bar.sh" || {
    echo "ERRO: não foi possível carregar ui/progress-bar.sh" >&2
    exit 1
}

# Redireciona saída para log (após source para não logar o próprio source)
exec > >(tee -a "$LOG") 2>&1

# ── Tratamento de erros e sinais ─────────────────────────────────────────────

die() {
    step_err "$*"
    echo -e "\n${RED}Instalação abortada. Veja o log: $LOG${NC}" >&2
    exit 1
}

cleanup_on_exit() {
    local code=$?
    tput cnorm 2>/dev/null || true
    [[ $code -ne 0 ]] && echo -e "\n${YELLOW}⚠ Instalação interrompida (código $code).${NC}" >&2
}

trap cleanup_on_exit EXIT
trap 'die "Interrompido pelo usuário (SIGINT)"' INT
trap 'die "Interrompido (SIGTERM)"' TERM

# ── Verificação de re-instalação ─────────────────────────────────────────────

check_reinstall() {
    [[ -f "$PREFS" ]] || return 0
    local prev_date
    prev_date=$(grep "^INSTALL_DATE=" "$PREFS" 2>/dev/null | cut -d= -f2-)
    [[ -z "$prev_date" ]] && return 0

    echo -e "${YELLOW}⚠ HACKLAB-PRO já foi instalado em: $prev_date${NC}"
    echo -e "  Re-instalar irá sobrescrever as preferências atuais.\n"

    local engine="text"
    command -v dialog &>/dev/null && engine="dialog"

    case "$engine" in
        dialog)
            dialog --title "Re-instalação" \
                   --yesno "HACKLAB-PRO já instalado ($prev_date).\nDeseja re-instalar?" \
                   8 55 || { echo "Instalação cancelada."; exit 0; } ;;
        text)
            read -rp "Continuar com a re-instalação? [s/N]: " r </dev/tty
            [[ "${r,,}" == "s" ]] || { echo "Instalação cancelada."; exit 0; } ;;
    esac
}

# ── Coleta de preferências ────────────────────────────────────────────────────
# Todas as perguntas interativas leem de /dev/tty explicitamente para não
# serem afetadas pelo redirecionamento exec > >(tee).

select_desktop() {
    local engine="text"
    command -v dialog &>/dev/null && engine="dialog"

    if [[ "$engine" == "dialog" ]]; then
        local tmp result
        tmp=$(mktemp)
        dialog --title "HACKLAB-PRO — Desktop" \
               --menu "Escolha o ambiente gráfico:" 12 55 4 \
               "xfce4" "XFCE4 (recomendado, leve)" \
               "lxqt"  "LXQt (moderno, Qt)" \
               "i3"    "i3 (tiling, pouca RAM)" \
               "none"  "Apenas console" \
               2>"$tmp" >/dev/tty
        result=$(cat "$tmp"); rm -f "$tmp"
        echo "${result:-xfce4}"
    else
        echo -e "\n${BOLD}Ambiente gráfico:${NC}" >/dev/tty
        echo "  1) XFCE4 (padrão)"  >/dev/tty
        echo "  2) LXQt"            >/dev/tty
        echo "  3) i3"              >/dev/tty
        echo "  4) Apenas console"  >/dev/tty
        local opt
        read -rp "Escolha [1]: " opt </dev/tty
        case "${opt:-1}" in
            2) echo "lxqt" ;; 3) echo "i3" ;; 4) echo "none" ;; *) echo "xfce4" ;;
        esac
    fi
}

select_options() {
    # Retorna variáveis via stdout no formato KEY=VALUE, uma por linha.
    # Lê do /dev/tty para não ser afetado pelo exec > >(tee).
    local wine="false" gpu="true" tools="essential"
    local wine_input gpu_input tools_input

    echo -e "\n${BOLD}Opções adicionais:${NC}" >/dev/tty
    read -rp "  Ativar suporte a Wine (.exe)? [s/N]: " wine_input </dev/tty
    [[ "${wine_input,,}" == "s" ]] && wine="true"

    read -rp "  Ativar aceleração de GPU? [S/n]: " gpu_input </dev/tty
    [[ "${gpu_input,,}" == "n" ]] && gpu="false"

    echo -e "\n${BOLD}Instalar ferramentas de segurança?${NC}" >/dev/tty
    echo "  1) Todas  — network, web, exploitation, password, wireless, reverse, utils, desktop" >/dev/tty
    echo "  2) Essenciais — network, web, utils, desktop (VS Code + Firefox)  [padrão]" >/dev/tty
    echo "  3) Interativo — escolher por categoria após a instalação" >/dev/tty
    echo "  4) Pular  — instalar depois com: bash tools/manager.sh" >/dev/tty
    read -rp "  Escolha [2]: " tools_input </dev/tty
    case "${tools_input:-2}" in
        1) tools="all" ;;
        2) tools="essential" ;;
        3) tools="interactive" ;;
        *) tools="skip" ;;
    esac

    echo "WINE=$wine"
    echo "GPU_ACCEL=$gpu"
    echo "TOOLS=$tools"
}

save_preferences() {
    local desktop="$1" wine="$2" gpu="$3" tools="$4"
    mkdir -p "$(dirname "$PREFS")"
    cat > "$PREFS" <<EOF
# user-preferences.conf — gerado por install.sh em $(date '+%Y-%m-%d %H:%M:%S')
DESKTOP=$desktop
WINE=$wine
GPU_ACCEL=$gpu
TOOLS=$tools
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    log "Preferências salvas: DESKTOP=$desktop WINE=$wine GPU_ACCEL=$gpu TOOLS=$tools"
}

# ── Instalação de ferramentas ─────────────────────────────────────────────────

ALL_CATEGORIES=(network web exploitation password wireless reverse utils desktop)
ESSENTIAL_CATEGORIES=(network web utils desktop)

install_tools_auto() {
    local mode="$1"
    local categories=()

    case "$mode" in
        all)       categories=("${ALL_CATEGORIES[@]}") ;;
        essential) categories=("${ESSENTIAL_CATEGORIES[@]}") ;;
        *)         return 0 ;;
    esac

    local total=${#categories[@]}
    local i=0
    for cat in "${categories[@]}"; do
        (( i++ )) || true
        log "[$i/$total] Instalando categoria: $cat"
        HACKLAB_ROOT="$HACKLAB_ROOT" bash "$HACKLAB_ROOT/tools/manager.sh" install-category "$cat" \
            || step_warn "Categoria '$cat' teve falhas (verifique $LOG)"
    done
}

# ── Orquestrador de módulos ───────────────────────────────────────────────────

run_module() {
    local name="$1"
    local script="$HACKLAB_ROOT/core/$name"
    [[ -f "$script" ]] || die "Módulo não encontrado: $script"
    chmod +x "$script"
    HACKLAB_ROOT="$HACKLAB_ROOT" bash "$script" || die "Falha no módulo: $name"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    clear
    banner

    echo -e "${BOLD}Iniciando instalação...${NC}"
    echo -e "Log: ${CYAN}$LOG${NC}\n"

    # Verifica re-instalação antes de qualquer coisa
    check_reinstall

    # Coleta todas as preferências antes de iniciar (leitura de /dev/tty)
    local desktop
    desktop=$(select_desktop)

    # select_options retorna KEY=VALUE; extrai cada valor
    local opts
    opts=$(select_options)
    local wine gpu tools
    wine=$(echo  "$opts" | grep "^WINE="      | cut -d= -f2)
    gpu=$(echo   "$opts" | grep "^GPU_ACCEL=" | cut -d= -f2)
    tools=$(echo "$opts" | grep "^TOOLS="     | cut -d= -f2)

    # Salva preferências no disco
    save_preferences "$desktop" "$wine" "$gpu" "$tools"

    echo ""

    # Calcula número real de steps conforme opções
    local steps=3  # ambiente + cleanup + ferramentas
    [[ "$gpu"     != "false" ]] && (( steps++ ))
    [[ "$desktop" != "none"  ]] && (( steps += 2 ))
    [[ "$tools"   != "skip" && "$tools" != "interactive" ]] && (( steps++ ))
    TOTAL_STEPS=$steps
    CURRENT_STEP=0

    # ── Step 1: Verificação de ambiente
    step_start "Verificando ambiente"
    run_module "00-environment-check.sh"
    step_ok "Ambiente verificado"

    # ── Step 2: GPU (opcional)
    if [[ "$gpu" != "false" ]]; then
        step_start "Detectando e configurando GPU"
        run_module "01-gpu-detection.sh"
        step_ok "GPU configurada"
    else
        step_warn "Aceleração de GPU desabilitada pelo usuário"
    fi

    # ── Steps 3-4: Desktop (opcional)
    if [[ "$desktop" != "none" ]]; then
        step_start "Instalando base gráfica (X11, PulseAudio, dbus)"
        run_module "02-desktop-base.sh"
        step_ok "Base gráfica instalada"

        step_start "Instalando ambiente gráfico: $desktop"
        run_module "03-desktop-env.sh"
        step_ok "Desktop '$desktop' instalado"
    else
        step_warn "Modo console — instalação gráfica ignorada"
    fi

    # ── Step: Wine (se habilitado)
    if [[ "$wine" == "true" ]]; then
        log "Instalando Wine..."
        pkg install -y wine >> "$LOG" 2>&1 && step_ok "Wine instalado" || step_warn "Wine: falha na instalação"
    fi

    # ── Step: Ferramentas automáticas
    if [[ "$tools" == "all" || "$tools" == "essential" ]]; then
        step_start "Instalando ferramentas ($tools)"
        install_tools_auto "$tools"
        step_ok "Ferramentas instaladas"
    fi

    # ── Step: Limpeza final
    step_start "Limpeza e finalização"
    run_module "99-cleanup.sh"
    step_ok "Concluído"

    # ── Instalação interativa (fora dos steps, após tudo)
    if [[ "$tools" == "interactive" ]]; then
        echo -e "\n${BOLD}Abrindo seleção interativa de ferramentas...${NC}"
        bash "$HACKLAB_ROOT/ui/select-tools.sh"
    fi

    # ── Resumo final
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║  ✓ HACKLAB-PRO instalado com sucesso ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}\n"
    echo -e "  Desktop    : ${CYAN}$desktop${NC}"
    echo -e "  GPU accel  : ${CYAN}$gpu${NC}"
    echo -e "  Wine       : ${CYAN}$wine${NC}"
    echo -e "  Ferramentas: ${CYAN}$tools${NC}"
    echo -e "  Log        : ${CYAN}$LOG${NC}\n"
    echo -e "  Para iniciar : ${BOLD}bash $HACKLAB_ROOT/scripts/start-lab.sh${NC}"
    echo -e "  Menu         : ${BOLD}bash $HACKLAB_ROOT/ui/main-menu.sh${NC}\n"
}

main "$@"
