# HACKLAB-PRO

Ambiente Linux de segurança ofensiva e defensiva rodando nativamente no Android via Termux, sem root.

## Requisitos

- Android 10 ou superior
- Termux do [F-Droid](https://f-droid.org/packages/com.termux/) ou [GitHub](https://github.com/termux/termux-app/releases) — **não da Play Store**
- App [Termux:X11](https://github.com/termux/termux-x11/releases) instalado no dispositivo
- 2GB de espaço livre mínimo

> Android 12+: desabilite o **Phantom Process Killer** em Opções do Desenvolvedor → Desativar restrições de processos secundário → Ative.

## Instalação

```bash
termux-setup-storage
cd ~
git clone https://github.com/nullwrilte/hacklab-pro
cd hacklab-pro
bash install.sh
```

O instalador vai:
1. Verificar o ambiente e permissões
2. Detectar sua GPU e instalar os drivers corretos
3. Perguntar qual desktop instalar (XFCE4, LXQt ou i3)
4. Instalar a base gráfica (X11, PulseAudio, dbus)
5. Limpar cache e finalizar

## Uso rápido

```bash
# Iniciar o lab (desktop + serviços)
bash scripts/start-lab.sh

# Abrir o menu principal
bash ui/main-menu.sh

# Parar tudo
bash scripts/stop-lab.sh
```

## Gerenciar ferramentas

```bash
# Listar todas as ferramentas (✓ = instalada)
bash tools/manager.sh list

# Instalar uma categoria inteira
bash tools/manager.sh install-category network

# Instalar ferramentas específicas
bash tools/manager.sh install nmap hydra sqlmap

# Atualizar tudo
bash scripts/update-tools.sh
```

## Categorias de ferramentas

| Categoria     | Ferramentas                                      |
|---------------|--------------------------------------------------|
| network       | nmap, tcpdump, netcat, masscan, dnsutils         |
| web           | sqlmap, nikto, gobuster, ffuf, httpx             |
| exploitation  | metasploit, searchsploit, pwncat                 |
| password      | john, hashcat, hydra, crunch                     |
| wireless      | aircrack-ng, reaver, mdk4, hcxtools              |
| reverse       | ngrok, chisel, socat                             |
| windows       | wine, box64                                      |
| utils         | git, vim, tmux, htop, python, jq                 |

## Backup e restauração

```bash
bash scripts/backup-config.sh    # salva em ~/storage/shared/hacklab-backups/
bash scripts/restore-config.sh   # lista backups e restaura o escolhido
```

## Estrutura

```
hacklab-pro/
├── install.sh          # instalador principal
├── config/             # hardware, preferências, mirrors
├── core/               # módulos de instalação (GPU, desktop, X11)
├── tools/              # gerenciador e base de dados de ferramentas
├── ui/                 # menus interativos
├── scripts/            # start, stop, update, backup, restore
├── logs/               # logs de instalação e execução
└── docs/               # documentação
```

## Documentação

- [TUTORIAL.md](TUTORIAL.md) — passo a passo completo
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — problemas comuns e soluções
