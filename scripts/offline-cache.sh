#!/bin/bash
# scripts/offline-cache.sh - Cache de pacotes para instalação offline

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

CACHE_DIR="${HACKLAB_ROOT}/cache/packages"
CACHE_META="$HACKLAB_ROOT/cache/manifest.conf"
LOG="$HACKLAB_ROOT/logs/offline.log"
TOOL_LIST="$HACKLAB_ROOT/tools/tool-list.conf"

mkdir -p "$CACHE_DIR" "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
die() { echo -e "${RED}ERRO: $*${NC}" >&2; exit 1; }

# ── Detecta pacotes pkg de uma ferramenta ─────────────────────────────────────

_pkg_name_for() {
    local tool="$1"
    # Extrai o nome do pacote do cmd_install (ex: "pkg install -y nmap" → "nmap")
    local line; line=$(grep -v '^\s*#' "$TOOL_LIST" | grep "^${tool}:" | head -1)
    local cmd; cmd=$(echo "$line" | cut -d: -f4)
    # Só processa comandos pkg (não pip, não __plugin__)
    [[ "$cmd" == *"pkg install"* ]] || return 1
    echo "$cmd" | grep -oP '(?<=install -y )\S+' || \
    echo "$cmd" | awk '{print $NF}'
}

# ── Download para cache ───────────────────────────────────────────────────────

cmd_cache() {
    local target="${1:-all}"
    log "=== Iniciando cache offline (target: $target) ==="

    local tools=()
    if [[ "$target" == "all" ]]; then
        mapfile -t tools < <(grep -v '^\s*#' "$TOOL_LIST" | grep -v '^\s*$' | cut -d: -f1)
    else
        tools=("$target")
    fi

    local cached=0 skipped=0 failed=0
    for tool in "${tools[@]}"; do
        local pkg; pkg=$(_pkg_name_for "$tool") || { (( skipped++ )) || true; continue; }

        local dest="$CACHE_DIR/${pkg}.deb"
        if [[ -f "$dest" ]]; then
            log "  ↷ $pkg já em cache"
            (( skipped++ )) || true
            continue
        fi

        log "  ↓ Baixando $pkg..."
        # pkg download salva em $PREFIX/var/cache/apt/archives/
        if pkg download "$pkg" >> "$LOG" 2>&1; then
            # Move o .deb baixado para nosso cache
            local deb
            deb=$(find "$PREFIX/var/cache/apt/archives/" -name "${pkg}*.deb" \
                  -newer "$LOG" 2>/dev/null | head -1)
            if [[ -n "$deb" ]]; then
                cp "$deb" "$dest"
                echo "${tool}=${pkg}:$(date '+%Y-%m-%d')" >> "$CACHE_META"
                step_ok "$pkg cacheado"
                (( cached++ )) || true
            else
                step_warn "$pkg: .deb não encontrado após download"
                (( failed++ )) || true
            fi
        else
            step_warn "$pkg: falha no download"
            (( failed++ )) || true
        fi
    done

    log "=== Cache concluído: $cached baixados, $skipped pulados, $failed falhas ==="
    echo -e "\n${BOLD}Cache:${NC} $cached baixados | $skipped já existiam | $failed falhas"
    echo -e "  Diretório: ${CYAN}$CACHE_DIR${NC}"
}

# ── Instalar a partir do cache ────────────────────────────────────────────────

cmd_install_offline() {
    local tool="$1"
    [[ -n "$tool" ]] || die "Especifique uma ferramenta"

    local pkg; pkg=$(_pkg_name_for "$tool") || die "Ferramenta '$tool' não usa pkg ou não encontrada"
    local deb="$CACHE_DIR/${pkg}.deb"

    [[ -f "$deb" ]] || die "Cache não encontrado para '$pkg'. Execute: offline-cache.sh cache $tool"

    log "Instalando $pkg a partir do cache..."
    dpkg -i "$deb" >> "$LOG" 2>&1 \
        && { step_ok "$tool instalado (offline)"; return 0; } \
        || { step_warn "$tool: falha na instalação offline"; return 1; }
}

# ── Instalar todas as ferramentas do cache ────────────────────────────────────

cmd_install_all_offline() {
    [[ -d "$CACHE_DIR" ]] || die "Cache vazio. Execute: offline-cache.sh cache"

    local debs=("$CACHE_DIR"/*.deb)
    [[ -f "${debs[0]}" ]] || die "Nenhum .deb no cache"

    log "=== Instalação offline de ${#debs[@]} pacote(s) ==="
    local ok=0 fail=0
    for deb in "${debs[@]}"; do
        local pkg; pkg=$(basename "$deb" .deb)
        dpkg -i "$deb" >> "$LOG" 2>&1 \
            && { step_ok "$pkg"; (( ok++ )) || true; } \
            || { step_warn "$pkg falhou"; (( fail++ )) || true; }
    done
    log "=== Offline: $ok instalados, $fail falhas ==="
}

# ── Status do cache ───────────────────────────────────────────────────────────

cmd_status() {
    local count=0 size=0
    if [[ -d "$CACHE_DIR" ]]; then
        count=$(find "$CACHE_DIR" -name "*.deb" | wc -l)
        size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    fi

    echo -e "\n${BOLD}Cache Offline — Status${NC}"
    echo -e "  Pacotes  : $count .deb(s)"
    echo -e "  Tamanho  : ${size:-0}"
    echo -e "  Diretório: $CACHE_DIR"

    if [[ $count -gt 0 ]]; then
        echo -e "\n${BOLD}Pacotes em cache:${NC}"
        for f in "$CACHE_DIR"/*.deb; do
            [[ -f "$f" ]] && echo "  • $(basename "$f" .deb)"
        done
    fi
    echo ""
}

# ── Limpar cache ──────────────────────────────────────────────────────────────

cmd_clear() {
    local count; count=$(find "$CACHE_DIR" -name "*.deb" 2>/dev/null | wc -l)
    [[ $count -eq 0 ]] && { echo "Cache já está vazio."; return 0; }

    read -rp "Remover $count pacote(s) do cache? [s/N]: " r </dev/tty
    [[ "${r,,}" == "s" ]] || { echo "Cancelado."; return 0; }
    rm -f "$CACHE_DIR"/*.deb "$CACHE_META"
    echo -e " ${GREEN}✓${NC} Cache limpo"
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Uso: offline-cache.sh <comando> [ferramenta]

Comandos:
  cache [ferramenta|all]   Baixa pacotes para cache (padrão: all)
  install <ferramenta>     Instala ferramenta a partir do cache
  install-all              Instala todos os pacotes do cache
  status                   Mostra status e conteúdo do cache
  clear                    Remove todos os pacotes do cache
EOF
}

case "${1:-status}" in
    cache)       cmd_cache "${2:-all}" ;;
    install)     [[ -n "${2:-}" ]] || { usage; exit 1; }; cmd_install_offline "$2" ;;
    install-all) cmd_install_all_offline ;;
    status)      cmd_status ;;
    clear)       cmd_clear ;;
    *)           usage; exit 1 ;;
esac
