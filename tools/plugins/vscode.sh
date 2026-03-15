#!/bin/bash
# tools/plugins/vscode.sh - Plugin para VS Code (code-server)
# Roda VS Code no navegador via code-server, sem root, compatível com ARM64

PLUGIN_NAME="vscode"
PLUGIN_CATEGORY="desktop"
PLUGIN_DESC="Editor de código VS Code (code-server)"

CODESERVER_DIR="$HOME/.local/lib/code-server"
CODESERVER_BIN="$HOME/.local/bin/code-server"

install() {
    pkg install -y nodejs-lts 2>/dev/null || pkg install -y nodejs 2>/dev/null || {
        echo "ERRO: nodejs não disponível"; return 1
    }

    mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"

    # Detecta arquitetura
    local arch
    arch=$(uname -m)
    local cs_arch
    case "$arch" in
        aarch64|arm64) cs_arch="arm64" ;;
        x86_64)        cs_arch="amd64" ;;
        armv7*)        cs_arch="armv7l" ;;
        *) echo "Arquitetura não suportada: $arch"; return 1 ;;
    esac

    # Obtém versão mais recente
    local version
    version=$(curl -fsSL "https://api.github.com/repos/coder/code-server/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')

    [[ -z "$version" ]] && { echo "Não foi possível obter versão do code-server"; return 1; }

    local url="https://github.com/coder/code-server/releases/download/v${version}/code-server-${version}-linux-${cs_arch}.tar.gz"
    local tmp; tmp=$(mktemp -d)

    echo "Baixando code-server v${version} (${cs_arch})..."
    curl -fsSL "$url" -o "$tmp/code-server.tar.gz" || { rm -rf "$tmp"; return 1; }

    tar -xzf "$tmp/code-server.tar.gz" -C "$tmp"
    rm -rf "$CODESERVER_DIR"
    mv "$tmp/code-server-${version}-linux-${cs_arch}" "$CODESERVER_DIR"
    rm -rf "$tmp"

    # Cria wrapper no PATH
    cat > "$CODESERVER_BIN" << 'WRAPPER'
#!/bin/bash
# Inicia code-server e abre no Firefox se disponível
PORT="${CODESERVER_PORT:-8080}"
exec "$HOME/.local/lib/code-server/bin/code-server" \
    --bind-addr "127.0.0.1:${PORT}" \
    --auth none \
    "$@"
WRAPPER
    chmod +x "$CODESERVER_BIN"

    # Cria atalho de desktop para XFCE/i3
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/code-server.desktop" << 'DESKTOP'
[Desktop Entry]
Name=VS Code (code-server)
Comment=Editor de código no navegador
Exec=bash -c 'code-server & sleep 2 && xdg-open http://127.0.0.1:8080'
Icon=text-editor
Terminal=false
Type=Application
Categories=Development;TextEditor;
DESKTOP

    echo "✓ code-server instalado em $CODESERVER_DIR"
    echo "  Inicie com: code-server"
    echo "  Acesse em : http://127.0.0.1:8080"
}

update() {
    # Remove instalação atual e reinstala para pegar versão mais recente
    rm -rf "$CODESERVER_DIR" "$CODESERVER_BIN"
    install
}

remove() {
    rm -rf "$CODESERVER_DIR" "$CODESERVER_BIN"
    rm -f "$HOME/.local/share/applications/code-server.desktop"
    echo "✓ code-server removido"
}

check() {
    [[ -x "$CODESERVER_BIN" ]] || command -v code-server &>/dev/null
}
