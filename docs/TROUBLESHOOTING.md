# Troubleshooting — HACKLAB-PRO

## Desktop não abre / tela preta no Termux:X11

**Causa:** X11 não iniciou ou o desktop travou na inicialização.

```bash
# Pare tudo e reinicie
bash scripts/stop-lab.sh
sleep 2
bash scripts/start-lab.sh
```

Se persistir, verifique o log:

```bash
tail -50 logs/lab.log
```

---

## Erro: "termux-x11: command not found"

O pacote não está instalado no Termux (diferente do app).

```bash
pkg install -y termux-x11-nightly
```

Certifique-se também de ter o **app Termux:X11** instalado no dispositivo.

---

## Processo do X11 é morto pelo Android

**Causa:** Phantom Process Killer ativo (Android 12+).

**Solução:** Vá em **Configurações → Opções do Desenvolvedor → Desativar restrições de processos secundário → Ative.


Se não aparecer a opção, execute via ADB:

```bash
adb shell device_config set_sync_disabled_for_tests persistent
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

---

## Sem som / PulseAudio não inicia

```bash
# Mata instâncias travadas e reinicia
pulseaudio --kill 2>/dev/null
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1" --exit-idle-time=-1
```

Verifique se o módulo aaudio está disponível:

```bash
pulseaudio --dump-modules | grep aaudio
```

Se não estiver, o dispositivo pode não suportar áudio via Termux.

---

## GPU / aceleração não funciona

**Verificar o driver ativo:**

```bash
source $PREFIX/etc/profile.d/hacklab-gpu.sh
echo $GALLIUM_DRIVER
DISPLAY=:0 glxinfo 2>/dev/null | grep "OpenGL renderer"
```

**Forçar software rendering:**

```bash
# Em config/user-preferences.conf
GPU_ACCEL=false
```

```bash
rm -f $PREFIX/etc/profile.d/hacklab-gpu.sh
bash scripts/stop-lab.sh && bash scripts/start-lab.sh
```

**Snapdragon e Turnip não carrega:**

```bash
pkg install -y mesa-vulkan-icd-freedreno
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
```

---

## Erro "pkg: command not found" ou repositório inacessível

```bash
# Redefine os repositórios para o oficial
bash config/select-mirror.sh

# Ou manualmente
echo "deb https://packages.termux.dev/apt/termux-main stable main" \
    > $PREFIX/etc/apt/sources.list
pkg update
```

---

## Ferramenta falhou ao instalar

Verifique o log detalhado:

```bash
grep -A5 "nome-da-ferramenta" logs/install.log
```

Tente instalar manualmente:

```bash
bash tools/manager.sh install nome-da-ferramenta
```

Para ferramentas via pip:

```bash
pip install --upgrade nome-da-ferramenta
```

---

## Metasploit não inicia

O Metasploit requer Ruby e dependências pesadas. Em dispositivos com menos de 3GB de RAM pode ser lento.

```bash
pkg install -y ruby
gem install bundler
msfdb init
msfconsole
```

Se travar, aumente o swap:

```bash
# Cria 1GB de swap em arquivo
fallocate -l 1G $PREFIX/var/swap
chmod 600 $PREFIX/var/swap
mkswap $PREFIX/var/swap
swapon $PREFIX/var/swap
```

---

## Sem espaço em disco

```bash
# Limpa cache de pacotes
pkg clean

# Verifica o que ocupa mais espaço
du -sh $PREFIX/var/cache/apt/archives/*
du -sh $HOME/* | sort -rh | head -10
```

---

## Backup não salva em ~/storage/shared

**Causa:** Permissão de armazenamento não concedida.

```bash
termux-setup-storage
```

Aceite a permissão na janela que aparecer. Depois tente o backup novamente.

---

## Restaurar backup corrompido

```bash
# Testa a integridade do arquivo antes de restaurar
tar -tzf /caminho/para/backup.tar.gz > /dev/null && echo "OK" || echo "CORROMPIDO"
```

Se corrompido, use um backup anterior listado em `~/storage/shared/hacklab-backups/`.
