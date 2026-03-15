#!/bin/bash
# scripts/sandbox.sh - Execução isolada de ferramentas via proot

HACKLAB_ROOT="${HACKLAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$HACKLAB_ROOT/ui/progress-bar.sh" 2>/dev/null || true

SANDBOX_DIR="${TMPDIR:-/tmp}/hacklab-sandbox"
LOG="$HACKLAB_ROOT/logs/sandbox.log"
AUDIT_LOG="$HACKLAB_ROOT/logs/audit.log"

mkdir -p "$(dirname "$LOG")"
log()   { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
audit() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SANDBOX user=$(id -un) cmd=$* " >> "$AUDIT_LOG" 2>/dev/null || true; }
die()   { echo -e "${RED}ERRO: $*${NC}" >&2; exit 1; }

# ── Verifica disponibilidade de isolamento ────────────────────────────────────

_isolation_method() {
    # Preferência: proot (sem root) > unshare (requer kernel support) > chroot básico
    command -v proot   &>/dev/null && echo "proot"   && return
    command -v unshare &>/dev/null && echo "unshare" && return
    echo "basic"
}

# ── Prepara rootfs mínimo para sandbox ───────────────────────────────────────

_setup_sandbox() {
    local sbox="$SANDBOX_DIR/root"
    [[ -d "$sbox/bin" ]] && return 0   # já existe

    mkdir -p "$sbox"/{bin,tmp,proc,dev,etc,home}

    # Copia binários essenciais para o sandbox
    for bin in sh bash ls cat echo grep sed awk; do
        local src; src=$(command -v "$bin" 2>/dev/null) || continue
        cp "$src" "$sbox/bin/" 2>/dev/null || true
    done

    # /etc mínimo
    echo "root:x:0:0:root:/root:/bin/sh" > "$sbox/etc/passwd"
    echo "root:x:0:"                     > "$sbox/etc/group"

    log "Sandbox rootfs criado em $sbox"
}

# ── Executa comando no sandbox ────────────────────────────────────────────────

cmd_run() {
    [[ $# -ge 1 ]] || die "Especifique um comando. Uso: sandbox.sh run <cmd> [args...]"

    local method; method=$(_isolation_method)
    local sbox="$SANDBOX_DIR/root"

    audit "$@"
    log "=== Sandbox ($method): $* ==="

    # Resolve caminho do binário a executar
    local bin; bin=$(command -v "$1" 2>/dev/null) || die "Comando '$1' não encontrado"
    shift
    local args=("$@")

    echo -e "${BOLD}${CYAN}[sandbox:$method]${NC} Executando: $(basename "$bin") ${args[*]}"
    echo -e "${YELLOW}  Isolamento: $method | Diretório: $SANDBOX_DIR${NC}\n"

    case "$method" in
        proot)
            _setup_sandbox
            # Copia o binário para o sandbox
            cp "$bin" "$sbox/bin/" 2>/dev/null || true

            proot \
                --rootfs="$sbox" \
                --bind=/dev \
                --bind=/proc \
                --bind="${TMPDIR:-/tmp}:/tmp" \
                --cwd=/tmp \
                --kill-on-exit \
                "/bin/$(basename "$bin")" "${args[@]}"
            ;;
        unshare)
            # Namespace de rede + PID + mount (sem root via user namespace)
            unshare --net --pid --fork --mount-proc \
                env -i HOME=/tmp PATH=/usr/bin:/bin \
                "$bin" "${args[@]}"
            ;;
        basic)
            # Sem isolamento real — apenas ambiente limpo + diretório temporário
            local tmpwork; tmpwork=$(mktemp -d)
            trap 'rm -rf "$tmpwork"' RETURN
            log "⚠ Isolamento básico (sem proot/unshare)"
            env -i \
                HOME="$tmpwork" \
                PATH="$PREFIX/bin:/usr/bin:/bin" \
                TMPDIR="$tmpwork" \
                TERM="${TERM:-xterm}" \
                "$bin" "${args[@]}"
            ;;
    esac

    local exit_code=$?
    log "=== Sandbox encerrado (exit: $exit_code) ==="
    return $exit_code
}

# ── Shell interativo no sandbox ───────────────────────────────────────────────

cmd_shell() {
    local method; method=$(_isolation_method)
    echo -e "${BOLD}${CYAN}[sandbox:$method]${NC} Shell isolado  (digite 'exit' para sair)\n"
    audit "shell"
    cmd_run "${SHELL:-bash}"
}

# ── Limpa sandbox ─────────────────────────────────────────────────────────────

cmd_clean() {
    rm -rf "$SANDBOX_DIR"
    echo -e " ${GREEN}✓${NC} Sandbox limpo"
    log "Sandbox limpo"
}

# ── Status ────────────────────────────────────────────────────────────────────

cmd_status() {
    local method; method=$(_isolation_method)
    local size="0"
    [[ -d "$SANDBOX_DIR" ]] && size=$(du -sh "$SANDBOX_DIR" 2>/dev/null | cut -f1)

    echo -e "\n${BOLD}Sandbox — Status${NC}"
    echo -e "  Método      : $method"
    echo -e "  Diretório   : $SANDBOX_DIR"
    echo -e "  Tamanho     : $size"
    command -v proot   &>/dev/null && echo -e "  proot       : ${GREEN}disponível${NC}" \
                                   || echo -e "  proot       : ${YELLOW}não instalado (pkg install proot)${NC}"
    command -v unshare &>/dev/null && echo -e "  unshare     : ${GREEN}disponível${NC}" \
                                   || echo -e "  unshare     : não disponível"
    echo ""
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Uso: sandbox.sh <comando> [args]

Comandos:
  run <cmd> [args]   Executa comando em ambiente isolado
  shell              Abre shell interativo no sandbox
  status             Mostra método de isolamento disponível
  clean              Remove diretório do sandbox

Métodos de isolamento (em ordem de preferência):
  proot    — rootfs isolado sem root (recomendado)
  unshare  — namespaces Linux (net/pid/mount)
  basic    — ambiente limpo com diretório temporário

Exemplos:
  sandbox.sh run nmap -sV 192.168.1.1
  sandbox.sh run sqlmap -u http://alvo.com
  sandbox.sh shell
EOF
}

case "${1:-status}" in
    run)    shift; [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_run "$@" ;;
    shell)  cmd_shell ;;
    clean)  cmd_clean ;;
    status) cmd_status ;;
    *)      usage; exit 1 ;;
esac
