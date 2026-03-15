# Tutorial — HACKLAB-PRO

## 1. Preparação do dispositivo

### 1.1 Instalar o Termux correto

Baixe o Termux do F-Droid ou GitHub. A versão da Play Store está desatualizada e não funciona.

Após instalar, abra o Termux e execute:

```bash
termux-setup-storage
pkg update && pkg upgrade -y
pkg install -y git
```

### 1.2 Instalar o Termux:X11

Baixe o APK do [Termux:X11](https://github.com/termux/termux-x11/releases) e instale no dispositivo. Ele é o servidor gráfico que exibe o desktop.

### 1.3 Android 12 ou superior

Vá em **Configurações → Opções do Desenvolvedor → Limitar processos em segundo plano** e selecione **Sem limite**. Isso evita que o Android mate o processo do X11.

---

## 2. Instalação

```bash
cd ~
git clone https://github.com/nullwrilte/hacklab-pro
cd hacklab-pro
bash install.sh
```

### O que o instalador pergunta

**Ambiente gráfico:**
- `XFCE4` — recomendado, leve e completo
- `LXQt` — interface mais moderna com Qt
- `i3` — gerenciador tiling, ideal para pouca RAM
- `none` — apenas console, sem interface gráfica

**Wine:** suporte a executar binários `.exe` (requer mais espaço)

**GPU:** aceleração gráfica (detectada automaticamente, pode desabilitar se causar problemas)

### Progresso da instalação

```
[1/5] Verificando ambiente
[2/5] Detectando GPU
[3/5] Instalando base do desktop
[4/5] Instalando ambiente gráfico
[5/5] Limpeza final
```

---

## 3. Iniciando o lab

```bash
bash scripts/start-lab.sh
```

Depois abra o app **Termux:X11** no seu dispositivo. O desktop aparecerá na tela.

---

## 4. Menu principal

```bash
bash ui/main-menu.sh
```

Opções disponíveis:

| Opção | Ação |
|-------|------|
| Iniciar Lab | Sobe X11, PulseAudio, dbus e o desktop |
| Parar Lab | Encerra todos os serviços |
| Instalar ferramentas | Abre seleção por categoria |
| Atualizar tudo | Sistema + ferramentas instaladas |
| Backup | Salva configurações no armazenamento interno |
| Restaurar | Lista backups e restaura o escolhido |
| Listar ferramentas | Mostra todas com status de instalação |
| Status | Mostra se X11, desktop e PulseAudio estão rodando |

---

## 5. Instalando ferramentas

### Via menu interativo

```bash
bash ui/select-tools.sh
```

Navegue pelas categorias, marque as ferramentas desejadas e confirme.

### Via linha de comando

```bash
# Uma categoria inteira
bash tools/manager.sh install-category web

# Ferramentas específicas
bash tools/manager.sh install nmap sqlmap hydra

# Ver o que está disponível
bash tools/manager.sh list
bash tools/manager.sh categories
```

---

## 6. Configurações avançadas

### Trocar o desktop sem reinstalar

Edite `config/user-preferences.conf`:

```bash
DESKTOP=i3   # xfce4 | lxqt | i3 | none
```

Depois reinicie o lab.

### Forçar software rendering (sem GPU)

Edite `config/user-preferences.conf`:

```bash
GPU_ACCEL=false
```

E remova o arquivo de perfil de GPU:

```bash
rm $PREFIX/etc/profile.d/hacklab-gpu.sh
```

### Trocar o mirror de downloads

```bash
bash config/select-mirror.sh
```

Testa a latência de todos os mirrors e aplica o mais rápido.

---

## 7. Backup e restauração

### Fazer backup

```bash
bash scripts/backup-config.sh
```

Salva em `~/storage/shared/hacklab-backups/hacklab-backup_TIMESTAMP.tar.gz`.

O que é incluído: `config/`, `.bashrc`, `.xinitrc`, `.config/xfce4`, `.config/i3`, `.config/pulse`, perfil de GPU.

### Restaurar

```bash
bash scripts/restore-config.sh
# ou direto:
bash scripts/restore-config.sh /caminho/para/backup.tar.gz
```

---

## 8. Atualização

```bash
bash scripts/update-tools.sh
```

Atualiza pacotes do sistema (`pkg upgrade`), pacotes pip desatualizados e todas as ferramentas instaladas.
