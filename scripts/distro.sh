#!/bin/bash
# scripts/distro.sh - Gerencia distribuições Linux via proot-distro
# Suporta: kali, ubuntu, debian, parrot, alpine, archlinux, fedora

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG="$HACKLAB_ROOT/logs/distro.log"
PREFS="$HACKLAB_ROOT/config/user-preferences.conf"
DISTRO_CONF="$HACKLAB_ROOT/config/distros.conf"

source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

mkdir -p "$(dirname "$LOG")"
log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die()  { log "ERRO: $*"; exit 1; }

# ── Distros suportadas ────────────────────────────────────────────────────────
# formato: alias|nome_proot|descrição|pacotes_extras
SUPPORTED_DISTROS=(
    "kali|kali-nethunter|Kali Linux NetHunter (arsenal completo)|kali-linux-default"
    "ubuntu|ubuntu|Ubuntu 24.04 LTS|build-essential curl wget git"
    "debian|debian|Debian 12 Bookworm|build-essential curl wget git"
    "parrot|parrot|Parrot OS Security|parrot-core"
    "alpine|alpine|Alpine Linux (leve, ~10MB)|alpine-base"
    "arch|archlinux|Arch Linux (rolling release)|base-devel git"
    "fedora|fedora|Fedora (RPM)|@development-tools git curl"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

require_proot_distro() {
    if ! command -v proot-distro &>/dev/null; then
        log "proot-distro não encontrado. Instalando..."
        pkg install -y proot-distro >> "$LOG" 2>&1 || die "Falha ao instalar proot-distro"
        log "✓ proot-distro instalado"
    fi
}

get_distro_field() {
    local alias="$1" field="$2"
    for entry in "${SUPPORTED_DISTROS[@]}"; do
        local a; a=$(echo "$entry" | cut -d'|' -f1)
        [[ "$a" == "$alias" ]] && echo "$entry" | cut -d'|' -f"$field" && return
    done
}

is_distro_installed() {
    local alias="$1"
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    [[ -z "$proot_name" ]] && return 1
    proot-distro list 2>/dev/null | grep -q "^${proot_name}" || \
        [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/${proot_name}" ]]
}

save_distro_state() {
    local alias="$1" state="$2"
    mkdir -p "$(dirname "$DISTRO_CONF")"
    # Remove entrada anterior e adiciona nova
    grep -vxF "${alias}=${state}" "$DISTRO_CONF" 2>/dev/null | \
        grep -v "^${alias}=" > "${DISTRO_CONF}.tmp" 2>/dev/null || true
    echo "${alias}=${state}" >> "${DISTRO_CONF}.tmp"
    mv "${DISTRO_CONF}.tmp" "$DISTRO_CONF"
}

# ── Instalação ────────────────────────────────────────────────────────────────

cmd_install() {
    local alias="${1:-kali}"
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    local desc;       desc=$(get_distro_field "$alias" 3)
    local extras;     extras=$(get_distro_field "$alias" 4)

    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada. Use: $(cmd_list_supported)"

    require_proot_distro

    if is_distro_installed "$alias"; then
        log "✓ $desc já instalada"
        echo -e " ${GREEN}✓${NC} $desc já está instalada. Use: distro.sh login $alias"
        return 0
    fi

    log "=== Instalando $desc ==="
    echo -e "\n${BOLD}${CYAN}Instalando $desc...${NC}"
    echo -e " ${YELLOW}⚠ Download pode ser grande (500MB–2GB). Aguarde.${NC}\n"

    # Instala a distro base
    proot-distro install "$proot_name" >> "$LOG" 2>&1 || die "Falha ao instalar $desc"

    log "✓ $desc instalada. Configurando ambiente..."

    # Configura ambiente pós-instalação
    _post_install "$alias" "$proot_name" "$extras"

    save_distro_state "$alias" "installed"
    log "=== $desc pronta ==="
    echo -e "\n${GREEN}${BOLD}✓ $desc instalada com sucesso!${NC}"
    echo -e "  Acesse com: ${CYAN}bash $HACKLAB_ROOT/scripts/distro.sh login $alias${NC}"
    echo -e "  Ou pelo menu: ${CYAN}bash $HACKLAB_ROOT/ui/main-menu.sh${NC}\n"
}

_post_install() {
    local alias="$1" proot_name="$2" extras="$3"

    # Comandos de setup dentro da distro
    local setup_cmds=""

    case "$alias" in
        kali)
            setup_cmds='
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    kali-linux-default \
    kali-desktop-xfce \
    xfce4-terminal \
    dbus-x11 \
    sudo \
    locales 2>/dev/null || true
# Cria usuário kali se não existir
id kali &>/dev/null || useradd -m -s /bin/bash -G sudo kali
echo "kali:kali" | chpasswd
echo "kali ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# Configura locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen 2>/dev/null || true
echo "✓ Kali configurado"
'
            ;;
        ubuntu|debian)
            setup_cmds='
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    sudo curl wget git build-essential \
    dbus-x11 xfce4-terminal 2>/dev/null || true
echo "✓ Ambiente configurado"
'
            ;;
        parrot)
            setup_cmds='
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y parrot-core dbus-x11 sudo 2>/dev/null || true
echo "✓ Parrot configurado"
'
            ;;
        alpine)
            setup_cmds='
apk update
apk add --no-cache bash sudo curl wget git build-base
echo "✓ Alpine configurado"
'
            ;;
        arch)
            setup_cmds='
pacman -Syu --noconfirm
pacman -S --noconfirm --needed base-devel git sudo curl wget
echo "✓ Arch configurado"
'
            ;;
        fedora)
            setup_cmds='
dnf update -y -q
dnf install -y @development-tools git curl wget sudo
echo "✓ Fedora configurado"
'
            ;;
    esac

    if [[ -n "$setup_cmds" ]]; then
        log "Configurando $alias pós-instalação..."
        proot-distro login "$proot_name" -- bash -c "$setup_cmds" >> "$LOG" 2>&1 \
            && log "✓ Pós-instalação concluída" \
            || log "⚠ Pós-instalação teve erros (verifique $LOG)"
    fi

    # Cria script de inicialização com X11 para distros com desktop
    _create_launch_script "$alias" "$proot_name"
}

_create_launch_script() {
    local alias="$1" proot_name="$2"
    local launch="$HACKLAB_ROOT/scripts/distro-launch-${alias}.sh"

    cat > "$launch" << LAUNCH
#!/bin/bash
# Auto-gerado por distro.sh — inicia $alias com X11
export DISPLAY=\${DISPLAY:-:0}
export PULSE_SERVER=\${PULSE_SERVER:-127.0.0.1}
export XDG_RUNTIME_DIR="\${TMPDIR:-/tmp}/runtime-\$(id -u)"
mkdir -p "\$XDG_RUNTIME_DIR"

exec proot-distro login ${proot_name} \\
    --shared-tmp \\
    --bind /dev/null:/proc/sys/kernel/cap_last_cap \\
    -- "\${@:-bash}"
LAUNCH
    chmod +x "$launch"
    log "✓ Script de launch criado: $launch"
}

# ── Login / Shell ─────────────────────────────────────────────────────────────

cmd_login() {
    local alias="${1:-kali}"
    shift 2>/dev/null || true
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    local desc;       desc=$(get_distro_field "$alias" 3)

    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada"
    is_distro_installed "$alias" || die "$desc não instalada. Execute: distro.sh install $alias"

    log "Iniciando shell: $desc"
    echo -e "${BOLD}${CYAN}Entrando em $desc...${NC} (digite 'exit' para sair)\n"

    export DISPLAY="${DISPLAY:-:0}"
    export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
    export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"

    proot-distro login "$proot_name" \
        --shared-tmp \
        --bind /dev/null:/proc/sys/kernel/cap_last_cap \
        -- "${@:-bash}"
}

# ── Executa comando dentro da distro ─────────────────────────────────────────

cmd_exec() {
    local alias="$1"; shift
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada"
    is_distro_installed "$alias" || die "Distro '$alias' não instalada"

    export DISPLAY="${DISPLAY:-:0}"
    proot-distro login "$proot_name" \
        --shared-tmp \
        --bind /dev/null:/proc/sys/kernel/cap_last_cap \
        -- "$@"
}

# ── Inicia desktop da distro no X11 ──────────────────────────────────────────

cmd_desktop() {
    local alias="${1:-kali}"
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    local desc;       desc=$(get_distro_field "$alias" 3)

    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada"
    is_distro_installed "$alias" || die "$desc não instalada"

    if ! xdpyinfo -display "${DISPLAY:-:0}" &>/dev/null; then
        die "X11 não está rodando. Inicie com: bash $HACKLAB_ROOT/scripts/start-lab.sh"
    fi

    log "Iniciando desktop de $desc no X11"
    echo -e "${BOLD}${CYAN}Iniciando desktop de $desc...${NC}"

    export DISPLAY="${DISPLAY:-:0}"
    export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
    export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"

    # Detecta e inicia o desktop disponível na distro
    proot-distro login "$proot_name" \
        --shared-tmp \
        --bind /dev/null:/proc/sys/kernel/cap_last_cap \
        -- bash -c '
            export DISPLAY='"${DISPLAY}"'
            export PULSE_SERVER='"${PULSE_SERVER}"'
            if command -v startxfce4 &>/dev/null; then
                dbus-launch --exit-with-session startxfce4
            elif command -v startlxqt &>/dev/null; then
                dbus-launch --exit-with-session startlxqt
            elif command -v gnome-session &>/dev/null; then
                dbus-launch --exit-with-session gnome-session
            else
                echo "Nenhum desktop encontrado na distro"
                exit 1
            fi
        ' &

    log "✓ Desktop de $desc iniciado (PID $!)"
    echo -e " ${GREEN}✓${NC} Desktop iniciado. Abra o app Termux:X11 no dispositivo."
}

# ── Atualiza distro ───────────────────────────────────────────────────────────

cmd_update() {
    local alias="${1:-kali}"
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    local desc;       desc=$(get_distro_field "$alias" 3)

    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada"
    is_distro_installed "$alias" || die "$desc não instalada"

    log "Atualizando $desc..."
    echo -e "${BOLD}Atualizando $desc...${NC}"

    local update_cmd
    case "$alias" in
        kali|ubuntu|debian|parrot) update_cmd="apt-get update -qq && apt-get upgrade -y" ;;
        alpine)                    update_cmd="apk update && apk upgrade" ;;
        arch)                      update_cmd="pacman -Syu --noconfirm" ;;
        fedora)                    update_cmd="dnf upgrade -y" ;;
        *)                         update_cmd="echo 'Atualização não suportada para $alias'" ;;
    esac

    proot-distro login "$proot_name" \
        --shared-tmp \
        -- bash -c "export DEBIAN_FRONTEND=noninteractive; $update_cmd" >> "$LOG" 2>&1 \
        && { log "✓ $desc atualizada"; step_ok "$desc atualizada"; } \
        || step_warn "$desc: falha na atualização (verifique $LOG)"
}

# ── Remove distro ─────────────────────────────────────────────────────────────

cmd_remove() {
    local alias="$1"
    local proot_name; proot_name=$(get_distro_field "$alias" 2)
    local desc;       desc=$(get_distro_field "$alias" 3)

    [[ -z "$proot_name" ]] && die "Distro '$alias' não suportada"

    echo -e "${YELLOW}⚠ Isso removerá $desc e todos os dados instalados nela.${NC}"
    read -rp "Confirmar remoção? [s/N]: " r
    [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }

    proot-distro remove "$proot_name" >> "$LOG" 2>&1 || true
    rm -f "$HACKLAB_ROOT/scripts/distro-launch-${alias}.sh"
    grep -v "^${alias}=" "$DISTRO_CONF" > "${DISTRO_CONF}.tmp" 2>/dev/null && \
        mv "${DISTRO_CONF}.tmp" "$DISTRO_CONF" || true

    log "✓ $desc removida"
    echo -e " ${GREEN}✓${NC} $desc removida."
}

# ── Lista distros ─────────────────────────────────────────────────────────────

cmd_list() {
    printf "\n${BOLD}%-12s %-10s %s${NC}\n" "ALIAS" "STATUS" "DESCRIÇÃO"
    printf "%-12s %-10s %s\n"  "-----" "------" "---------"
    for entry in "${SUPPORTED_DISTROS[@]}"; do
        local alias proot_name desc status
        alias=$(echo "$entry"     | cut -d'|' -f1)
        proot_name=$(echo "$entry" | cut -d'|' -f2)
        desc=$(echo "$entry"      | cut -d'|' -f3)
        if is_distro_installed "$alias"; then
            status="${GREEN}instalada${NC}"
        else
            status="disponível"
        fi
        printf "%-12s %-18b %s\n" "$alias" "$status" "$desc"
    done
    echo ""
}

cmd_list_supported() {
    for entry in "${SUPPORTED_DISTROS[@]}"; do
        echo "$entry" | cut -d'|' -f1
    done | tr '\n' ' '
}

# ── Menu interativo ───────────────────────────────────────────────────────────

cmd_menu() {
    local engine="text"
    command -v dialog   &>/dev/null && engine="dialog"
    command -v whiptail &>/dev/null && [[ "$engine" == "text" ]] && engine="whiptail"

    while true; do
        # Monta lista de distros com status
        local items=()
        for entry in "${SUPPORTED_DISTROS[@]}"; do
            local alias desc status_label
            alias=$(echo "$entry" | cut -d'|' -f1)
            desc=$(echo "$entry"  | cut -d'|' -f3)
            is_distro_installed "$alias" \
                && status_label="[✓] $desc" \
                || status_label="[ ] $desc"
            items+=("$alias" "$status_label")
        done
        items+=("back" "← Voltar ao menu principal")

        local choice
        case "$engine" in
            dialog|whiptail)
                local tmp; tmp=$(mktemp)
                "$engine" --title "HACKLAB-PRO — Distros Linux" \
                          --menu "Selecione uma distribuição:" \
                          20 65 10 "${items[@]}" 2>"$tmp"
                choice=$(cat "$tmp"); rm -f "$tmp" ;;
            text)
                echo -e "\n${BOLD}Distribuições Linux disponíveis:${NC}"
                local i=1 arr=("${items[@]}")
                while [[ $i -le ${#arr[@]} ]]; do
                    echo "  $(( (i+1)/2 ))) ${arr[$i-1]}  —  ${arr[$i]}"
                    (( i+=2 ))
                done
                read -rp "Escolha: " opt
                local idx=$(( (opt-1)*2 ))
                choice="${arr[$idx]}" ;;
        esac

        [[ -z "$choice" || "$choice" == "back" ]] && break

        # Submenu da distro selecionada
        local desc; desc=$(get_distro_field "$choice" 3)
        local installed_label="Instalar $desc"
        is_distro_installed "$choice" && installed_label="✓ Já instalada"

        local action
        case "$engine" in
            dialog|whiptail)
                local tmp; tmp=$(mktemp)
                "$engine" --title "$desc" \
                          --menu "O que deseja fazer?" \
                          16 60 6 \
                          "install" "$installed_label" \
                          "login"   "Abrir shell interativo" \
                          "desktop" "Iniciar desktop no X11" \
                          "update"  "Atualizar pacotes" \
                          "remove"  "Remover distro" \
                          "back"    "← Voltar" \
                          2>"$tmp"
                action=$(cat "$tmp"); rm -f "$tmp" ;;
            text)
                echo -e "\n${BOLD}$desc${NC}"
                echo "  1) $installed_label"
                echo "  2) Abrir shell interativo"
                echo "  3) Iniciar desktop no X11"
                echo "  4) Atualizar pacotes"
                echo "  5) Remover distro"
                echo "  6) Voltar"
                read -rp "Escolha: " opt
                case "${opt:-6}" in
                    1) action="install" ;; 2) action="login" ;;
                    3) action="desktop" ;; 4) action="update" ;;
                    5) action="remove"  ;; *) action="back" ;;
                esac ;;
        esac

        case "$action" in
            install) cmd_install "$choice" ;;
            login)   cmd_login   "$choice" ;;
            desktop) cmd_desktop "$choice" ;;
            update)  cmd_update  "$choice" ;;
            remove)  cmd_remove  "$choice" ;;
        esac
    done
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF

${BOLD}Uso:${NC} distro.sh <comando> [distro] [args]

${BOLD}Comandos:${NC}
  install [distro]       Instala uma distribuição Linux
  login   [distro]       Abre shell interativo na distro
  exec    <distro> <cmd> Executa comando dentro da distro
  desktop [distro]       Inicia desktop da distro no X11
  update  [distro]       Atualiza pacotes da distro
  remove  <distro>       Remove a distro e seus dados
  list                   Lista distros disponíveis e instaladas
  menu                   Abre menu interativo

${BOLD}Distros suportadas:${NC}
  kali, ubuntu, debian, parrot, alpine, arch, fedora

${BOLD}Exemplos:${NC}
  distro.sh install kali
  distro.sh login kali
  distro.sh exec kali nmap -sV 192.168.1.1
  distro.sh desktop kali
  distro.sh update ubuntu
  distro.sh remove debian

EOF
}

case "${1:-menu}" in
    install) cmd_install "${2:-kali}" ;;
    login)   cmd_login   "${2:-kali}" "${@:3}" ;;
    exec)    [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_exec "$2" "${@:3}" ;;
    desktop) cmd_desktop "${2:-kali}" ;;
    update)  cmd_update  "${2:-kali}" ;;
    remove)  [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_remove "$2" ;;
    list)    cmd_list ;;
    menu)    cmd_menu ;;
    -h|--help) usage ;;
    *) usage; exit 1 ;;
esac
