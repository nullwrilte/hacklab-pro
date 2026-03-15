#!/bin/bash
# tools/plugins/rustscan.sh - Plugin para o RustScan (scanner de portas ultrarrápido)
# Hooks disponíveis: install, update, remove, check

PLUGIN_NAME="rustscan"
PLUGIN_CATEGORY="network"
PLUGIN_DESC="Scanner de portas ultrarrápido (Rust)"
PLUGIN_VERSION="latest"

install() {
    if command -v cargo &>/dev/null; then
        cargo install rustscan
    else
        local arch
        arch=$(uname -m)
        local bin_url
        case "$arch" in
            aarch64|arm64) bin_url="https://github.com/RustScan/RustScan/releases/latest/download/rustscan_aarch64-unknown-linux-musl.tar.gz" ;;
            x86_64)        bin_url="https://github.com/RustScan/RustScan/releases/latest/download/rustscan_x86_64-unknown-linux-musl.tar.gz" ;;
            *) echo "Arquitetura não suportada: $arch"; return 1 ;;
        esac
        local tmp; tmp=$(mktemp -d)
        curl -sL "$bin_url" -o "$tmp/rustscan.tar.gz"
        tar -xzf "$tmp/rustscan.tar.gz" -C "$tmp"
        install -m 755 "$tmp/rustscan" "$PREFIX/bin/rustscan"
        rm -rf "$tmp"
    fi
}

update() {
    if command -v cargo &>/dev/null; then
        cargo install rustscan --force
    else
        install
    fi
}

remove() {
    rm -f "$PREFIX/bin/rustscan"
    command -v cargo &>/dev/null && cargo uninstall rustscan 2>/dev/null || true
}

check() {
    command -v rustscan &>/dev/null && rustscan --version &>/dev/null
}
