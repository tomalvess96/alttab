#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
pkill -ix alttab || true  # nome antigo (Alttab) e novo (AltTab)
rm -rf "$HOME/Applications/Alttab.app" "$HOME/Applications/AltTab.app"
mkdir -p "$HOME/Applications"
cp -R "$HOME/Library/Caches/alttab-build/AltTab.app" "$HOME/Applications/AltTab.app"
HOSTS_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
mkdir -p "$HOSTS_DIR"
cat > "$HOSTS_DIR/br.inf.brusoft.alttab.json" <<JSON
{
  "name": "br.inf.brusoft.alttab",
  "description": "Ponte do AltTab com o Edge",
  "path": "$HOME/Applications/AltTab.app/Contents/MacOS/alttab-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://npgoecidghckmkdhakalhchnaebjdhlc/"]
}
JSON
open "$HOME/Applications/AltTab.app"
# O alttab-host em execução ficou com o binário antigo: o app recusaria a assinatura dele.
# Encerrado, a extensão do Edge abre um novo (já com o binário novo) em ~5 s.
pkill -if "alttab.app/contents/macos/alttab-host" || true
echo "instalado em ~/Applications/AltTab.app"
echo "Extensão: edge://extensions → Modo de desenvolvedor → Carregar sem compactação → $(pwd)/extension"
