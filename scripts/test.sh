#!/bin/bash
# Compila fora do OneDrive: o File Provider põe atributos estendidos nos binários e o codesign recusa.
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift test --scratch-path "$HOME/Library/Caches/alttab-build" "$@"
