#!/bin/bash
# ui/fzf-tools.sh - TUI com fzf para busca e gerenciamento de ferramentas

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

TOOL_LIST="$HACKLAB_ROOT/tools/tool-list.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"
PLUGIN_DIR="$HACKLAB_ROOT/tools/plugins"
MANAGER="$HACKLAB_ROOT/tools/manager.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

is_installed() { grep -qxF "$1" "$INSTALLED_DB" 2>/dev/null; }

read_all_tools() {
    grep -v '^\s*#' "$TOOL_LIST" | grep -v '^\s*$'
    [[ -d "$PLUGIN_DIR" ]] || return 0
    for p in "$PLUGIN_DIR"/*.sh; do
        [[ -f "$p" ]] || continue
        local name meta category desc
        name=$(basename "$p" .sh)
        meta=$(bash --norc --noprofile -c "
            source $(printf '%q' "$p") 2>/dev/null
            echo \"\${PLUGIN_CATEGORY:-plugin}\"
            echo \"\${PLUGIN_DESC:-Plugin externo}\"
        " 2>/dev/null)
        category=$(echo "$meta" | head -1)
        desc=$(echo "$meta" | tail -1)
        echo "${name}:${category}:${desc}:__plugin__:__plugin__"
    done
}

# Formata linha para exibição no fzf: STATUS  NOME  CATEGORIA  DESCRIÇÃO
format_line() {
    local line="$1"
    local name category desc status
    name=$(echo "$line"     | cut -d: -f1)
    category=$(echo "$line" | cut -d: -f2)
    desc=$(echo "$line"     | cut -d: -f3)
    is_installed "$name" && status="${GREEN}✓${NC}" || status=" "
    printf "%-2b %-22s %-14s %s\n" "$status" "$name" "[$category]" "$desc"
}

# Gera preview de uma ferramenta (exibido no painel direito do fzf)
preview_tool() {
    local name="$1"
    local line
    line=$(bash "$HACKLAB_ROOT/tools/manager.sh" list 2>/dev/null | grep "^${name} " | head -1)

    echo ""
    echo "  Ferramenta : $name"

    local raw
    raw=$(grep -v '^\s*#' "$TOOL_LIST" | grep "^${name}:" | head -1)
    [[ -z "$raw" ]] && raw=$(bash --norc --noprofile -c "
        p=\"$PLUGIN_DIR/${name}.sh\"
        [[ -f \"\$p\" ]] && source \"\$p\" 2>/dev/null
        echo \"\${PLUGIN_CATEGORY:-plugin}:\${PLUGIN_DESC:-Plugin externo}\"
    " 2>/dev/null)

    local category desc
    category=$(echo "$raw" | cut -d: -f2)
    desc=$(echo "$raw"     | cut -d: -f3)

    echo "  Categoria  : $category"
    echo "  Descrição  : $desc"
    echo ""
    if grep -qxF "$name" "$INSTALLED_DB" 2>/dev/null; then
        echo "  Status     : ✓ INSTALADA"
    else
        echo "  Status     : ✗ não instalada"
    fi
    echo ""

    # Mostra hook check do plugin se existir
    local plugin="$PLUGIN_DIR/${name}.sh"
    if [[ -f "$plugin" ]]; then
        echo "  Origem     : plugin"
        local check_result
        check_result=$(bash --norc --noprofile -c "
            source $(printf '%q' "$plugin") 2>/dev/null
            declare -f check &>/dev/null && check && echo 'ok' || echo 'fail'
        " 2>/dev/null)
        [[ "$check_result" == "ok" ]] \
            && echo "  Check      : ✓ binário encontrado" \
            || echo "  Check      : ✗ binário não encontrado"
    else
        echo "  Origem     : tool-list.conf"
        local bin
        bin=$(command -v "$name" 2>/dev/null || true)
        [[ -n "$bin" ]] \
            && echo "  Binário    : $bin" \
            || echo "  Binário    : não encontrado no PATH"
    fi
    echo ""
}
export -f preview_tool is_installed
export HACKLAB_ROOT TOOL_LIST INSTALLED_DB PLUGIN_DIR

# ── Ação sobre ferramenta selecionada ─────────────────────────────────────────

action_on_tool() {
    local name="$1"
    [[ -z "$name" ]] && return

    # Extrai nome limpo (remove status prefix)
    name=$(echo "$name" | awk '{print $2}')
    [[ -z "$name" ]] && return

    local actions=("instalar" "remover" "info" "cancelar")
    is_installed "$name" && actions=("remover" "reinstalar" "info" "cancelar")

    local action
    action=$(printf '%s\n' "${actions[@]}" | fzf \
        --prompt "  $name → " \
        --height=8 \
        --border=rounded \
        --no-info \
        --header "  Escolha uma ação:")

    case "$action" in
        instalar|reinstalar)
            echo -e "\n${BOLD}Instalando $name...${NC}"
            bash "$MANAGER" install "$name"
            read -rp "  Pressione Enter para continuar..." </dev/tty
            ;;
        remover)
            read -rp "  Remover $name? [s/N]: " r </dev/tty
            [[ "${r,,}" == "s" ]] && bash "$MANAGER" remove "$name"
            read -rp "  Pressione Enter para continuar..." </dev/tty
            ;;
        info)
            preview_tool "$name" | less -R
            ;;
    esac
}

# ── Modo busca livre ──────────────────────────────────────────────────────────

mode_search() {
    local header="  HACKLAB-PRO — Busca de Ferramentas"
    header+="  │  Enter=ação  │  Ctrl-I=instalar  │  Ctrl-R=remover  │  Ctrl-C=sair"

    local selected
    selected=$(read_all_tools | while IFS= read -r line; do
        format_line "$line"
    done | fzf \
        --ansi \
        --prompt "  🔍 Buscar: " \
        --header "$header" \
        --preview "preview_tool \$(echo {} | awk '{print \$2}')" \
        --preview-window=right:40%:wrap \
        --height=90% \
        --border=rounded \
        --bind "ctrl-i:execute(bash $MANAGER install \$(echo {} | awk '{print \$2}') </dev/tty >/dev/tty 2>&1)+reload($(declare -f read_all_tools format_line is_installed | cat); read_all_tools | while IFS= read -r line; do format_line \"\$line\"; done)" \
        --bind "ctrl-r:execute(bash $MANAGER remove \$(echo {} | awk '{print \$2}') </dev/tty >/dev/tty 2>&1)+reload($(declare -f read_all_tools format_line is_installed | cat); read_all_tools | while IFS= read -r line; do format_line \"\$line\"; done)" \
        --info=inline \
        --no-sort \
        2>/dev/tty)

    [[ -n "$selected" ]] && action_on_tool "$selected"
}

# ── Modo filtro por categoria ─────────────────────────────────────────────────

mode_by_category() {
    local category
    category=$(read_all_tools | cut -d: -f2 | sort -u | fzf \
        --prompt "  📂 Categoria: " \
        --height=40% \
        --border=rounded \
        --header "  Selecione uma categoria (Enter=confirmar  Esc=voltar)" \
        --no-info \
        2>/dev/tty)

    [[ -z "$category" ]] && return

    local selected
    selected=$(read_all_tools | grep ":${category}:" | while IFS= read -r line; do
        format_line "$line"
    done | fzf \
        --ansi \
        --prompt "  [$category] 🔍 " \
        --header "  Categoria: $category  │  Enter=ação  │  Ctrl-I=instalar  │  Ctrl-C=voltar" \
        --preview "preview_tool \$(echo {} | awk '{print \$2}')" \
        --preview-window=right:40%:wrap \
        --height=90% \
        --border=rounded \
        --multi \
        --bind "ctrl-i:execute(bash $MANAGER install \$(echo {} | awk '{print \$2}') </dev/tty >/dev/tty 2>&1)" \
        --info=inline \
        2>/dev/tty)

    if [[ -n "$selected" ]]; then
        # Suporte a multi-seleção
        while IFS= read -r line; do
            action_on_tool "$line"
        done <<< "$selected"
    fi
}

# ── Modo instalados ───────────────────────────────────────────────────────────

mode_installed() {
    [[ -s "$INSTALLED_DB" ]] || { echo "Nenhuma ferramenta instalada."; return; }

    local selected
    selected=$(while IFS= read -r name; do
        local raw
        raw=$(grep -v '^\s*#' "$TOOL_LIST" | grep "^${name}:" | head -1)
        [[ -z "$raw" ]] && raw="${name}:plugin:Plugin externo:__plugin__:__plugin__"
        format_line "$raw"
    done < "$INSTALLED_DB" | fzf \
        --ansi \
        --prompt "  ✓ Instaladas: " \
        --header "  Ferramentas instaladas  │  Enter=ação  │  Ctrl-R=remover" \
        --preview "preview_tool \$(echo {} | awk '{print \$2}')" \
        --preview-window=right:40%:wrap \
        --height=90% \
        --border=rounded \
        --bind "ctrl-r:execute(bash $MANAGER remove \$(echo {} | awk '{print \$2}') </dev/tty >/dev/tty 2>&1)" \
        --info=inline \
        2>/dev/tty)

    [[ -n "$selected" ]] && action_on_tool "$selected"
}

# ── Menu principal do fzf-tools ───────────────────────────────────────────────

main() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${YELLOW}⚠ fzf não encontrado. Instalando...${NC}"
        pkg install -y fzf 2>/dev/null || {
            echo -e "${RED}✗ Falha ao instalar fzf. Use o menu padrão.${NC}"
            exec bash "$HACKLAB_ROOT/ui/select-tools.sh"
        }
    fi

    while true; do
        local mode
        mode=$(printf '%s\n' \
            "🔍  Buscar todas as ferramentas" \
            "📂  Filtrar por categoria" \
            "✓   Ver ferramentas instaladas" \
            "←   Voltar ao menu principal" \
            | fzf \
                --prompt "  HACKLAB-PRO fzf › " \
                --height=12 \
                --border=rounded \
                --no-info \
                --header "  Gerenciador de Ferramentas" \
                2>/dev/tty)

        case "$mode" in
            "🔍"*)  mode_search ;;
            "📂"*)  mode_by_category ;;
            "✓"*)   mode_installed ;;
            *) break ;;
        esac
    done
}

main "$@"
