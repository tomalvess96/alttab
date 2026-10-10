#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
pkill -x Alttab || true
rm -rf "$HOME/Applications/Alttab.app"
mkdir -p "$HOME/Applications"
cp -R "$HOME/Library/Caches/alttab-build/Alttab.app" "$HOME/Applications/Alttab.app"
HOSTS_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
mkdir -p "$HOSTS_DIR"
cat > "$HOSTS_DIR/br.inf.brusoft.alttab.json" <<JSON
{
  "name": "br.inf.brusoft.alttab",
  "description": "Ponte do Alttab com o Edge",
  "path": "$HOME/Applications/Alttab.app/Contents/MacOS/alttab-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://npgoecidghckmkdhakalhchnaebjdhlc/"]
}
JSON
open "$HOME/Applications/Alttab.app"
# O alttab-host em execução ficou com o binário antigo: o app recusaria a assinatura dele.
# Encerrado, a extensão do Edge abre um novo (já com o binário novo) em ~5 s.
pkill -f "Alttab.app/Contents/MacOS/alttab-host" || true
echo "instalado em ~/Applications/Alttab.app"
echo "Extensão: edge://extensions → Modo de desenvolvedor → Carregar sem compactação → $(pwd)/extension"
