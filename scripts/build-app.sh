#!/bin/bash
# Compila e monta o .app FORA do OneDrive: o File Provider põe atributos estendidos e o codesign recusa.
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_ID="${ALTTAB_SIGN_ID:-C081393AF63E6A78FE2343B68E2DAE3855D328A1}"
SCRATCH="$HOME/Library/Caches/alttab-build"
APP="$SCRATCH/Alttab.app"

swift build -c release --product AlttabApp --scratch-path "$SCRATCH"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$SCRATCH/release/AlttabApp" "$APP/Contents/MacOS/Alttab"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"
echo "ok: $APP"
