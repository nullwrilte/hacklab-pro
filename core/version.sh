#!/bin/bash
# core/version.sh - Sistema de versões do HACKLAB-PRO

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ── Versão atual do projeto ───────────────────────────────────────────────────
VERSION="1.2.0"
VERSION_DATE="2025-01-01"
REPO_URL="https://raw.githubusercontent.com/nullwrilte/hacklab-pro/master"

VERSION_CONF="${VERSION_CONF:-$HACKLAB_ROOT/config/version.conf}"

# ── Helpers ───────────────────────────────────────────────────────────────────

_ver_to_int() {
    # "1.2.3" → 10203  (suporta até 99 por segmento)
    local IFS=.
    local parts=($1)
    echo $(( ${parts[0]:-0} * 10000 + ${parts[1]:-0} * 100 + ${parts[2]:-0} ))
}

get_installed_version() {
    grep "^VERSION=" "$VERSION_CONF" 2>/dev/null | cut -d= -f2
}

save_installed_version() {
    mkdir -p "$(dirname "$VERSION_CONF")"
    # Preserva migrações aplicadas, atualiza só VERSION e VERSION_DATE
    local migrations
    migrations=$(grep "^MIGRATIONS_APPLIED=" "$VERSION_CONF" 2>/dev/null || echo "MIGRATIONS_APPLIED=")
    cat > "$VERSION_CONF" <<EOF
# version.conf — gerado automaticamente por version.sh
VERSION=$VERSION
VERSION_DATE=$VERSION_DATE
INSTALLED_AT=$(date '+%Y-%m-%d %H:%M:%S')
$migrations
EOF
}

# ── Verificação de update remoto ──────────────────────────────────────────────

check_update() {
    local silent="${1:-}"
    local remote_version

    # Tenta buscar versão remota (timeout curto para não travar)
    remote_version=$(curl -sf --max-time 5 \
        "${REPO_URL}/core/version.sh" 2>/dev/null \
        | grep '^VERSION=' | head -1 | cut -d= -f2)

    if [[ -z "$remote_version" ]]; then
        [[ "$silent" != "--silent" ]] && \
            echo -e " ${YELLOW}⚠${NC} Não foi possível verificar updates (sem conexão?)"
        return 1
    fi

    local current; current=$(get_installed_version)
    [[ -z "$current" ]] && current="0.0.0"

    local remote_int; remote_int=$(_ver_to_int "$remote_version")
    local current_int; current_int=$(_ver_to_int "$current")

    if (( remote_int > current_int )); then
        echo -e " ${GREEN}★${NC} Nova versão disponível: ${BOLD}v${remote_version}${NC} (instalada: v${current})"
        echo -e "   Atualize com: ${CYAN}git -C $HACKLAB_ROOT pull${NC}"
        return 0
    else
        [[ "$silent" != "--silent" ]] && \
            echo -e " ${GREEN}✓${NC} HACKLAB-PRO está na versão mais recente (v${current})"
        return 1
    fi
}

# ── Sistema de migrações de configuração ──────────────────────────────────────
# Cada migração é uma função migrate_X_Y_Z() que transforma configs antigas.
# Só é executada uma vez — registrada em MIGRATIONS_APPLIED.

_is_migration_applied() {
    local id="$1"
    grep "^MIGRATIONS_APPLIED=" "$VERSION_CONF" 2>/dev/null \
        | grep -qF "$id"
}

_mark_migration_applied() {
    local id="$1"
    local current
    current=$(grep "^MIGRATIONS_APPLIED=" "$VERSION_CONF" 2>/dev/null \
              | cut -d= -f2-)
    local updated="${current:+$current,}$id"
    sed -i "s|^MIGRATIONS_APPLIED=.*|MIGRATIONS_APPLIED=$updated|" "$VERSION_CONF" 2>/dev/null || \
        echo "MIGRATIONS_APPLIED=$updated" >> "$VERSION_CONF"
}

# Migração 1.0→1.1: user-preferences.conf ganhou campo TOOLS e INSTALL_DATE
migrate_1_1_0() {
    local prefs="$HACKLAB_ROOT/config/user-preferences.conf"
    [[ -f "$prefs" ]] || return 0
    grep -q "^TOOLS=" "$prefs" || echo "TOOLS=essential" >> "$prefs"
    grep -q "^INSTALL_DATE=" "$prefs" || echo "INSTALL_DATE=" >> "$prefs"
}

# Migração 1.1→1.2: installed-tools.conf movido para config/
migrate_1_2_0() {
    local old="$HACKLAB_ROOT/installed-tools.conf"
    local new="$HACKLAB_ROOT/config/installed-tools.conf"
    if [[ -f "$old" && ! -f "$new" ]]; then
        mkdir -p "$(dirname "$new")"
        mv "$old" "$new"
    fi
}

# Tabela de migrações: id → função
declare -A MIGRATIONS=(
    ["1.1.0"]="migrate_1_1_0"
    ["1.2.0"]="migrate_1_2_0"
)
# Ordem de aplicação
MIGRATION_ORDER=("1.1.0" "1.2.0")

migrate_config() {
    [[ -f "$VERSION_CONF" ]] || return 0

    local applied=false
    for id in "${MIGRATION_ORDER[@]}"; do
        _is_migration_applied "$id" && continue
        local fn="${MIGRATIONS[$id]}"
        [[ -z "$fn" ]] && continue
        "$fn" 2>/dev/null && _mark_migration_applied "$id" && applied=true
        echo -e " ${GREEN}✓${NC} Migração aplicada: $id"
    done

    $applied || true
}

# ── Entrypoint standalone ─────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true
    case "${1:-status}" in
        status)
            local_ver=$(get_installed_version)
            echo -e " Versão instalada : ${BOLD}v${local_ver:-desconhecida}${NC}"
            echo -e " Versão do código : ${BOLD}v${VERSION}${NC}"
            ;;
        check)   check_update ;;
        migrate) migrate_config ;;
        save)    save_installed_version; echo "✓ Versão v$VERSION salva" ;;
        *)       echo "Uso: version.sh [status|check|migrate|save]" ;;
    esac
fi
