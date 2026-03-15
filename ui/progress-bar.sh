#!/bin/bash
# progress-bar.sh - Barra de progresso e utilitários de UI

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

TOTAL_STEPS=5
CURRENT_STEP=0

progress_bar() {
    local step="$1" total="$2" label="$3"
    local pct=$(( step * 100 / total ))
    local filled=$(( pct / 5 ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<20; i++)); do bar+="░"; done
    printf "\r${CYAN}[%s]${NC} %3d%% %s" "$bar" "$pct" "$label"
    [[ "$step" -eq "$total" ]] && echo
}

step_start() {
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    echo -e "\n${BOLD}${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC}"
    progress_bar "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

step_ok()   { echo -e " ${GREEN}✓${NC} $1"; }
step_warn() { echo -e " ${YELLOW}⚠${NC} $1"; }
step_err()  { echo -e " ${RED}✗${NC} $1"; }

banner() {
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
 _   _    _    ____ _  ____      _    ____       ____  ____   ___
| | | |  / \  / ___| |/ /\ \    / /  |  _ \     |  _ \|  _ \ / _ \
| |_| | / _ \| |   | ' /  \ \/\/ /   | |_) |____| |_) | |_) | | | |
|  _  |/ ___ \ |___| . \   \  /  |   |  __/_____|  __/|  _ <| |_| |
|_| |_/_/   \_\____|_|\_\   \/   |   |_|        |_|   |_| \_\\___/
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}  Ambiente Linux de Segurança para Android${NC}\n"
}
