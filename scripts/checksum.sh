#!/bin/bash
# scripts/checksum.sh - Verificação de integridade de arquivos e binários

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

CHECKSUM_DB="$HACKLAB_ROOT/config/checksums.db"
LOG="$HACKLAB_ROOT/logs/checksum.log"

mkdir -p "$(dirname "$CHECKSUM_DB")" "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { echo -e "${RED}ERRO: $*${NC}" >&2; exit 1; }

# Algoritmo preferido disponível
_hash_cmd() {
    command -v sha256sum &>/dev/null && echo "sha256sum" && return
    command -v sha1sum   &>/dev/null && echo "sha1sum"   && return
    command -v md5sum    &>/dev/null && echo "md5sum"    && return
    die "Nenhum comando de hash encontrado (sha256sum/sha1sum/md5sum)"
}

_hash_file() {
    local file="$1" cmd
    cmd=$(_hash_cmd)
    "$cmd" "$file" 2>/dev/null | awk '{print $1}'
}

# ── Registrar checksum ────────────────────────────────────────────────────────

cmd_register() {
    local target="$1"
    [[ -n "$target" ]] || die "Especifique um arquivo ou binário"

    # Resolve caminho completo se for binário no PATH
    local path="$target"
    [[ -f "$path" ]] || path=$(command -v "$target" 2>/dev/null) || \
        die "'$target' não encontrado"

    local hash algo
    algo=$(_hash_cmd)
    hash=$(_hash_file "$path")
    [[ -z "$hash" ]] && die "Falha ao calcular hash de '$path'"

    # Remove entrada anterior e adiciona nova
    grep -v "^${path}:" "$CHECKSUM_DB" 2>/dev/null > "${CHECKSUM_DB}.tmp" || true
    echo "${path}:${algo##*/}:${hash}:$(date '+%Y-%m-%d %H:%M:%S')" >> "${CHECKSUM_DB}.tmp"
    mv "${CHECKSUM_DB}.tmp" "$CHECKSUM_DB"

    log "Registrado: $path ($algo: $hash)"
    echo -e " ${GREEN}✓${NC} Registrado: $(basename "$path")  [$hash]"
}

# ── Verificar checksum ────────────────────────────────────────────────────────

cmd_verify() {
    local target="${1:-}"
    local ok=0 fail=0 missing=0

    # Filtra linhas do DB
    local -a entries=()
    if [[ -n "$target" ]]; then
        local path="$target"
        [[ -f "$path" ]] || path=$(command -v "$target" 2>/dev/null) || \
            die "'$target' não encontrado"
        mapfile -t entries < <(grep "^${path}:" "$CHECKSUM_DB" 2>/dev/null)
        [[ ${#entries[@]} -eq 0 ]] && die "'$path' não está registrado. Use: checksum.sh register $target"
    else
        [[ -f "$CHECKSUM_DB" ]] || die "Nenhum checksum registrado ainda"
        mapfile -t entries < <(cat "$CHECKSUM_DB")
    fi

    [[ ${#entries[@]} -eq 0 ]] && { echo "Nenhum checksum registrado."; return 0; }

    echo -e "\n${BOLD}Verificando integridade...${NC}"
    for entry in "${entries[@]}"; do
        local path algo expected
        path=$(echo "$entry"     | cut -d: -f1)
        algo=$(echo "$entry"     | cut -d: -f2)
        expected=$(echo "$entry" | cut -d: -f3)

        if [[ ! -f "$path" ]]; then
            step_warn "$(basename "$path"): arquivo não encontrado"
            (( missing++ )) || true
            continue
        fi

        local actual
        actual=$(_hash_file "$path")
        if [[ "$actual" == "$expected" ]]; then
            step_ok "$(basename "$path")  ✓"
            (( ok++ )) || true
        else
            step_err "$(basename "$path")  FALHOU (esperado: ${expected:0:16}… atual: ${actual:0:16}…)"
            log "FALHA: $path esperado=$expected atual=$actual"
            (( fail++ )) || true
        fi
    done

    echo ""
    echo -e "  ${GREEN}✓ OK: $ok${NC}  ${RED}✗ Falhas: $fail${NC}  ${YELLOW}? Ausentes: $missing${NC}"
    [[ $fail -eq 0 && $missing -eq 0 ]]
}

# ── Registrar todos os binários instalados ────────────────────────────────────

cmd_register_all() {
    [[ -f "$HACKLAB_ROOT/config/installed-tools.conf" ]] || \
        die "Nenhuma ferramenta instalada"

    local count=0
    while IFS= read -r tool; do
        local path; path=$(command -v "$tool" 2>/dev/null) || continue
        cmd_register "$path" 2>/dev/null && (( count++ )) || true
    done < "$HACKLAB_ROOT/config/installed-tools.conf"

    echo -e "\n${GREEN}✓${NC} $count binário(s) registrado(s)"
}

# ── Listar checksums registrados ──────────────────────────────────────────────

cmd_list() {
    [[ -f "$CHECKSUM_DB" ]] || { echo "Nenhum checksum registrado."; return; }
    echo -e "\n${BOLD}Checksums registrados:${NC}"
    printf "  %-35s %-8s %s\n" "ARQUIVO" "ALGO" "HASH (primeiros 16)"
    printf "  %-35s %-8s %s\n" "-------" "----" "-------------------"
    while IFS=: read -r path algo hash date _; do
        printf "  %-35s %-8s %s  (%s)\n" \
            "$(basename "$path")" "$algo" "${hash:0:16}…" "$date"
    done < "$CHECKSUM_DB"
    echo ""
}

# ── Remover entrada ───────────────────────────────────────────────────────────

cmd_remove() {
    local target="$1"
    [[ -n "$target" ]] || die "Especifique um arquivo"
    local path="$target"
    [[ -f "$path" ]] || path=$(command -v "$target" 2>/dev/null) || true

    grep -v "^${path}:" "$CHECKSUM_DB" 2>/dev/null > "${CHECKSUM_DB}.tmp" && \
        mv "${CHECKSUM_DB}.tmp" "$CHECKSUM_DB" || true
    echo -e " ${GREEN}✓${NC} Entrada removida: $target"
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Uso: checksum.sh <comando> [arquivo|ferramenta]

Comandos:
  register <arquivo>   Registra checksum de um arquivo ou binário
  register-all         Registra todos os binários instalados
  verify [arquivo]     Verifica integridade (todos ou um específico)
  list                 Lista checksums registrados
  remove <arquivo>     Remove entrada do banco
EOF
}

case "${1:-list}" in
    register)     [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_register "$2" ;;
    register-all) cmd_register_all ;;
    verify)       cmd_verify "${2:-}" ;;
    list)         cmd_list ;;
    remove)       [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_remove "$2" ;;
    *)            usage; exit 1 ;;
esac
