#!/bin/bash
# tools/plugins/firefox.sh - Plugin para Firefox
# Instala Firefox via repositório x11 do Termux

PLUGIN_NAME="firefox"
PLUGIN_CATEGORY="desktop"
PLUGIN_DESC="Navegador Firefox"

install() {
    # Garante que o repositório x11 está habilitado
    pkg install -y x11-repo 2>/dev/null || true

    if pkg install -y firefox 2>/dev/null; then
        _create_desktop_entry
        echo "✓ Firefox instalado via pkg"
        return 0
    fi

    # Fallback: Firefox ESR via repositório alternativo
    echo "pkg falhou, tentando firefox-esr..."
    if pkg install -y firefox-esr 2>/dev/null; then
        # Cria alias para nome canônico
        ln -sf "$(command -v firefox-esr)" "$PREFIX/bin/firefox" 2>/dev/null || true
        _create_desktop_entry
        echo "✓ Firefox ESR instalado"
        return 0
    fi

    echo "ERRO: Firefox não disponível nos repositórios atuais"
    return 1
}

_create_desktop_entry() {
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/firefox.desktop" << 'DESKTOP'
[Desktop Entry]
Name=Firefox
Comment=Navegador Web
Exec=firefox %u
Icon=firefox
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
DESKTOP
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

update() {
    pkg upgrade -y firefox 2>/dev/null || pkg upgrade -y firefox-esr 2>/dev/null || true
}

remove() {
    pkg uninstall -y firefox 2>/dev/null || pkg uninstall -y firefox-esr 2>/dev/null || true
    rm -f "$HOME/.local/share/applications/firefox.desktop"
    rm -f "$PREFIX/bin/firefox" 2>/dev/null || true
    echo "✓ Firefox removido"
}

check() {
    command -v firefox &>/dev/null || command -v firefox-esr &>/dev/null
}
