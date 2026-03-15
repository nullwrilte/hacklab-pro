#!/bin/bash
# tools/plugins/nuclei.sh - Plugin para o Nuclei (scanner de vulnerabilidades)
# Hooks disponíveis: install, update, remove, check

PLUGIN_NAME="nuclei"
PLUGIN_CATEGORY="web"
PLUGIN_DESC="Scanner de vulnerabilidades baseado em templates"
PLUGIN_VERSION="latest"

install() {
    if command -v go &>/dev/null; then
        go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    else
        # Fallback: baixa binário pré-compilado para ARM64
        local bin_url
        local arch
        arch=$(uname -m)
        case "$arch" in
            aarch64|arm64) bin_url="https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_arm64.zip" ;;
            x86_64)        bin_url="https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_amd64.zip" ;;
            *) echo "Arquitetura não suportada: $arch"; return 1 ;;
        esac
        local tmp; tmp=$(mktemp -d)
        curl -sL "$bin_url" -o "$tmp/nuclei.zip"
        unzip -q "$tmp/nuclei.zip" -d "$tmp"
        install -m 755 "$tmp/nuclei" "$PREFIX/bin/nuclei"
        rm -rf "$tmp"
    fi
    # Atualiza templates após instalar
    nuclei -update-templates -silent 2>/dev/null || true
}

update() {
    if command -v nuclei &>/dev/null; then
        nuclei -update -silent 2>/dev/null || install
        nuclei -update-templates -silent 2>/dev/null || true
    else
        install
    fi
}

remove() {
    rm -f "$PREFIX/bin/nuclei"
    rm -rf "$HOME/.config/nuclei" "$HOME/nuclei-templates"
}

check() {
    command -v nuclei &>/dev/null && nuclei -version &>/dev/null
}
