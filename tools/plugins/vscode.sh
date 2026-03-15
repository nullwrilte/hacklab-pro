#!/bin/bash
# tools/plugins/vscode.sh - Plugin para VS Code open source nativo (code-oss)
# Instala o code-oss do repositório x11 do Termux — binário nativo, sem navegador

PLUGIN_NAME="vscode"
PLUGIN_CATEGORY="desktop"
PLUGIN_DESC="VS Code open source nativo (code-oss)"

install() {
    # Habilita repositório x11 (necessário para code-oss e electron)
    pkg install -y x11-repo 2>/dev/null || true

    # code-oss depende do electron compilado para Termux
    pkg install -y code-oss || {
        echo "ERRO: falha ao instalar code-oss"
        return 1
    }

    # Cria symlink 'code' para compatibilidade com extensões e scripts
    if ! command -v code &>/dev/null && command -v code-oss &>/dev/null; then
        ln -sf "$(command -v code-oss)" "$PREFIX/bin/code" 2>/dev/null || true
    fi

    _create_desktop_entry
    echo "✓ code-oss instalado"
    echo "  Inicie com: code-oss  (ou: code)"
}

_create_desktop_entry() {
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/code-oss.desktop" << 'DESKTOP'
[Desktop Entry]
Name=VS Code (code-oss)
Comment=Editor de código open source
Exec=code-oss %F
Icon=code-oss
Terminal=false
Type=Application
Categories=Development;TextEditor;IDE;
MimeType=text/plain;inode/directory;
StartupNotify=true
DESKTOP
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

update() {
    pkg upgrade -y code-oss
}

remove() {
    pkg uninstall -y code-oss || true
    rm -f "$PREFIX/bin/code" 2>/dev/null || true
    rm -f "$HOME/.local/share/applications/code-oss.desktop"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo "✓ code-oss removido"
}

check() {
    command -v code-oss &>/dev/null || command -v code &>/dev/null
}
