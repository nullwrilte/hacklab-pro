#!/bin/bash
# ui/select-tools.sh - Seleção interativa de ferramentas por categoria

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh"

TOOL_LIST="$HACKLAB_ROOT/tools/tool-list.conf"
INSTALLED_DB="$HACKLAB_ROOT/config/installed-tools.conf"

ENGINE=$(command -v dialog &>/dev/null && echo "dialog" || \
         command -v whiptail &>/dev/null && echo "whiptail" || echo "text")

# ── Helpers ───────────────────────────────────────────────────────────────────

read_tools() { grep -v '^\s*#' "$TOOL_LIST" | grep -v '^\s*$'; }

is_installed() { grep -q "^${1}$" "$INSTALLED_DB" 2>/dev/null; }

get_categories() { read_tools | cut -d: -f2 | sort -u; }

# ── Seleção por categoria (checklist) ─────────────────────────────────────────

select_category_dialog() {
    local category="$1"
    local items=()

    while IFS= read -r line; do
        [[ "$(echo "$line" | cut -d: -f2)" == "$category" ]] || continue
        local name desc state
        name=$(echo "$line" | cut -d: -f1)
        desc=$(echo "$line" | cut -d: -f3)
        is_installed "$name" && state="ON" || state="OFF"
        items+=("$name" "$desc" "$state")
    done < <(read_tools)

    local tmp; tmp=$(mktemp)
    "$ENGINE" --title "Ferramentas: $category" \
              --checklist "Selecione as ferramentas (SPACE = marcar):" \
              20 65 12 "${items[@]}" 2>"$tmp"
    local result; result=$(cat "$tmp"); rm -f "$tmp"
    echo "$result"
}

select_category_text() {
    local category="$1"
    local names=() descs=() states=()

    while IFS= read -r line; do
        [[ "$(echo "$line" | cut -d: -f2)" == "$category" ]] || continue
        names+=("$(echo "$line" | cut -d: -f1)")
        descs+=("$(echo "$line" | cut -d: -f3)")
        is_installed "${names[-1]}" && states+=("✓") || states+=(" ")
    done < <(read_tools)

    echo -e "\n${BOLD}Categoria: $category${NC}"
    for i in "${!names[@]}"; do
        echo "  $((i+1))) [${states[$i]}] ${names[$i]} — ${descs[$i]}"
    done
    echo "  0) Voltar"
    read -rp "Selecione (ex: 1 3 4) ou 0 para voltar: " choices

    local selected=()
    for c in $choices; do
        [[ "$c" == "0" ]] && return
        local idx=$(( c - 1 ))
        [[ -n "${names[$idx]}" ]] && selected+=("${names[$idx]}")
    done
    echo "${selected[@]}"
}

# ── Menu de categorias ────────────────────────────────────────────────────────

select_category_menu() {
    local cat_items=()
    while IFS= read -r cat; do
        local count
        count=$(read_tools | cut -d: -f2 | grep -c "^${cat}$" || true)
        cat_items+=("$cat" "${count} ferramentas")
    done < <(get_categories)
    cat_items+=("all" "Instalar TUDO")
    cat_items+=("back" "← Voltar")

    local tmp; tmp=$(mktemp)
    case "$ENGINE" in
        dialog|whiptail)
            "$ENGINE" --title "Categorias" \
                      --menu "Escolha uma categoria:" \
                      20 55 12 "${cat_items[@]}" 2>"$tmp"
            local result; result=$(cat "$tmp"); rm -f "$tmp"
            echo "$result" ;;
        text)
            echo -e "\n${BOLD}Categorias disponíveis:${NC}"
            local i=1 items=("${cat_items[@]}")
            while [[ $i -le ${#items[@]} ]]; do
                echo "  $(( (i+1)/2 ))) ${items[$i-1]}  —  ${items[$i]}"
                (( i+=2 ))
            done
            read -rp "Escolha: " opt
            local idx=$(( (opt-1)*2 ))
            echo "${items[$idx]}" ;;
    esac
}

# ── Instalação dos selecionados ───────────────────────────────────────────────

install_selected() {
    local selected=("$@")
    [[ ${#selected[@]} -eq 0 ]] && return

    echo -e "\n${BOLD}Instalando ${#selected[@]} ferramenta(s)...${NC}"
    for name in "${selected[@]}"; do
        bash "$HACKLAB_ROOT/tools/manager.sh" install "$name"
    done
}

# ── Loop principal ────────────────────────────────────────────────────────────

main() {
    while true; do
        local category
        category=$(select_category_menu)

        case "$category" in
            back|"") break ;;
            all)
                if [[ "$ENGINE" == "text" ]]; then
                    read -rp "Instalar TODAS as ferramentas? [s/N]: " c
                    [[ "${c,,}" == "s" ]] || continue
                else
                    "$ENGINE" --yesno "Instalar TODAS as ferramentas?" 7 45 || continue
                fi
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category network
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category web
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category exploitation
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category password
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category wireless
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category reverse
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category windows
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category utils
                bash "$HACKLAB_ROOT/tools/manager.sh" install-category desktop
                ;;
            *)
                local selected_str
                if [[ "$ENGINE" == "text" ]]; then
                    selected_str=$(select_category_text "$category")
                else
                    selected_str=$(select_category_dialog "$category")
                fi
                # shellcheck disable=SC2206
                local selected=($selected_str)
                install_selected "${selected[@]}"
                ;;
        esac
    done
}

main "$@"
