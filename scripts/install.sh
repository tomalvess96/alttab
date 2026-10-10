#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
pkill -x Alttab || true
rm -rf "$HOME/Applications/Alttab.app"
mkdir -p "$HOME/Applications"
cp -R "$HOME/Library/Caches/alttab-build/Alttab.app" "$HOME/Applications/Alttab.app"
open "$HOME/Applications/Alttab.app"
echo "instalado em ~/Applications/Alttab.app"
