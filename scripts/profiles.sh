#!/bin/bash
# scripts/profiles.sh - Perfis de instalação nomeados

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

PROFILES_DIR="$HACKLAB_ROOT/config/profiles"
PREFS="$HACKLAB_ROOT/config/user-preferences.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"

mkdir -p "$PROFILES_DIR"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo -e "${RED}ERRO: $*${NC}" >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────

_profile_path() { echo "$PROFILES_DIR/${1}.conf"; }

_list_profiles() {
    local found=false
    for f in "$PROFILES_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        local name; name=$(basename "$f" .conf)
        local date; date=$(grep "^SAVED_AT=" "$f" 2>/dev/null | cut -d= -f2-)
        local desktop; desktop=$(grep "^DESKTOP=" "$f" 2>/dev/null | cut -d= -f2)
        local tools_count; tools_count=$(grep "^TOOLS_LIST=" "$f" 2>/dev/null | cut -d= -f2- | tr ',' '\n' | grep -c '.' || echo 0)
        printf "  %-20s  %-8s  %3s ferramentas  %s\n" "$name" "$desktop" "$tools_count" "$date"
        found=true
    done
    $found || echo "  Nenhum perfil salvo."
}

# ── Salvar perfil ─────────────────────────────────────────────────────────────

cmd_save() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        read -rp "Nome do perfil: " name </dev/tty
        [[ -z "$name" ]] && die "Nome não pode ser vazio"
    fi

    # Valida nome (apenas alfanumérico + hífen/underscore)
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "Nome inválido: use apenas letras, números, - e _"

    local path; path=$(_profile_path "$name")

    if [[ -f "$path" ]]; then
        read -rp "Perfil '$name' já existe. Sobrescrever? [s/N]: " r </dev/tty
        [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    fi

    # Captura preferências atuais
    local desktop wine gpu tools
    desktop=$(grep "^DESKTOP="   "$PREFS" 2>/dev/null | cut -d= -f2 || echo "xfce4")
    wine=$(grep    "^WINE="      "$PREFS" 2>/dev/null | cut -d= -f2 || echo "false")
    gpu=$(grep     "^GPU_ACCEL=" "$PREFS" 2>/dev/null | cut -d= -f2 || echo "true")
    tools=$(grep   "^TOOLS="     "$PREFS" 2>/dev/null | cut -d= -f2 || echo "essential")

    # Lista de ferramentas instaladas (CSV)
    local tools_list=""
    [[ -f "$INSTALLED_DB" ]] && tools_list=$(paste -sd',' "$INSTALLED_DB" 2>/dev/null || true)

    cat > "$path" <<EOF
# Perfil HACKLAB-PRO: $name
PROFILE_NAME=$name
SAVED_AT=$(date '+%Y-%m-%d %H:%M:%S')
DESKTOP=$desktop
WINE=$wine
GPU_ACCEL=$gpu
TOOLS=$tools
TOOLS_LIST=$tools_list
EOF

    echo -e " ${GREEN}✓${NC} Perfil '${BOLD}$name${NC}' salvo em: $path"
}

# ── Carregar perfil ───────────────────────────────────────────────────────────

cmd_load() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "\n${BOLD}Perfis disponíveis:${NC}"
        _list_profiles
        read -rp "Nome do perfil a carregar: " name </dev/tty
        [[ -z "$name" ]] && return 0
    fi

    local path; path=$(_profile_path "$name")
    [[ -f "$path" ]] || die "Perfil '$name' não encontrado"

    local desktop wine gpu tools tools_list
    desktop=$(grep    "^DESKTOP="    "$path" | cut -d= -f2)
    wine=$(grep       "^WINE="       "$path" | cut -d= -f2)
    gpu=$(grep        "^GPU_ACCEL="  "$path" | cut -d= -f2)
    tools=$(grep      "^TOOLS="      "$path" | cut -d= -f2)
    tools_list=$(grep "^TOOLS_LIST=" "$path" | cut -d= -f2-)

    echo -e "\n${BOLD}Carregando perfil '$name':${NC}"
    echo -e "  Desktop: $desktop | Wine: $wine | GPU: $gpu | Ferramentas: $tools"

    read -rp "Aplicar preferências? [S/n]: " r </dev/tty
    if [[ "${r,,}" != "n" ]]; then
        cat > "$PREFS" <<EOF
# user-preferences.conf — restaurado do perfil '$name' em $(date '+%Y-%m-%d %H:%M:%S')
DESKTOP=$desktop
WINE=$wine
GPU_ACCEL=$gpu
TOOLS=$tools
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
        echo -e " ${GREEN}✓${NC} Preferências aplicadas"
    fi

    if [[ -n "$tools_list" ]]; then
        read -rp "Restaurar lista de ferramentas instaladas? [S/n]: " r </dev/tty
        if [[ "${r,,}" != "n" ]]; then
            mkdir -p "$(dirname "$INSTALLED_DB")"
            echo "$tools_list" | tr ',' '\n' | grep -v '^$' > "$INSTALLED_DB"
            local count; count=$(wc -l < "$INSTALLED_DB")
            echo -e " ${GREEN}✓${NC} $count ferramenta(s) restauradas no registro"

            read -rp "Re-instalar ferramentas ausentes agora? [s/N]: " r </dev/tty
            if [[ "${r,,}" == "s" ]]; then
                while IFS= read -r tool; do
                    command -v "$tool" &>/dev/null || \
                        bash "$HACKLAB_ROOT/tools/manager.sh" install "$tool"
                done < "$INSTALLED_DB"
            fi
        fi
    fi

    echo -e " ${GREEN}✓${NC} Perfil '$name' carregado"
}

# ── Remover perfil ────────────────────────────────────────────────────────────

cmd_delete() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo -e "\n${BOLD}Perfis disponíveis:${NC}"
        _list_profiles
        read -rp "Nome do perfil a remover: " name </dev/tty
        [[ -z "$name" ]] && return 0
    fi

    local path; path=$(_profile_path "$name")
    [[ -f "$path" ]] || die "Perfil '$name' não encontrado"

    read -rp "Remover perfil '$name'? [s/N]: " r </dev/tty
    [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    rm -f "$path"
    echo -e " ${GREEN}✓${NC} Perfil '$name' removido"
}

# ── Menu interativo ───────────────────────────────────────────────────────────

cmd_menu() {
    local engine="text"
    command -v dialog   &>/dev/null && engine="dialog"
    command -v whiptail &>/dev/null && [[ "$engine" == "text" ]] && engine="whiptail"

    while true; do
        local choice
        case "$engine" in
            dialog|whiptail)
                local tmp; tmp=$(mktemp)
                "$engine" --title "Perfis de Instalação" \
                          --menu "Gerenciar perfis:" 14 55 5 \
                          "save"   "Salvar perfil atual" \
                          "load"   "Carregar perfil" \
                          "list"   "Listar perfis" \
                          "delete" "Remover perfil" \
                          "back"   "← Voltar" \
                          2>"$tmp"
                choice=$(cat "$tmp"); rm -f "$tmp" ;;
            text)
                echo -e "\n${BOLD}Perfis de Instalação:${NC}"
                echo "  1) Salvar perfil atual"
                echo "  2) Carregar perfil"
                echo "  3) Listar perfis"
                echo "  4) Remover perfil"
                echo "  5) Voltar"
                read -rp "Escolha: " opt
                case "${opt:-5}" in
                    1) choice="save"   ;; 2) choice="load"   ;;
                    3) choice="list"   ;; 4) choice="delete" ;;
                    *) choice="back"   ;;
                esac ;;
        esac

        case "$choice" in
            save)   cmd_save   ;;
            load)   cmd_load   ;;
            list)   echo -e "\n${BOLD}Perfis salvos:${NC}"; _list_profiles; echo ;;
            delete) cmd_delete ;;
            back|"") break ;;
        esac
    done
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    echo "Uso: profiles.sh <save|load|list|delete|menu> [nome]"
}

case "${1:-menu}" in
    save)   cmd_save   "${2:-}" ;;
    load)   cmd_load   "${2:-}" ;;
    list)   echo -e "\n${BOLD}Perfis salvos:${NC}"; _list_profiles; echo ;;
    delete) cmd_delete "${2:-}" ;;
    menu)   cmd_menu ;;
    *)      usage; exit 1 ;;
esac
