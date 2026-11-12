#!/bin/bash
# npm/montar.sh [saida]: monta o pacote @wortictecnologia/jsonw a partir deste repositorio, igual ao que esta no npm:
# o SDK do Node (sdk/node/index.js), o addon pre-compilado de cada plataforma (prebuilt/<sistema>-<arquitetura>/) e a
# ferramenta wjsw como comando (npx jsonw). Usado pelo .github/workflows/publicar-npm.yml. Nada aqui publica.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"; SAI="${1:-/tmp/jw-npm/jsonw}"
rm -rf "$SAI"; mkdir -p "$SAI/bin" "$SAI/prebuilt/darwin-arm64" "$SAI/prebuilt/linux-x64" "$SAI/prebuilt/win32-x64"
cp "$RAIZ/npm/package.json" "$RAIZ/npm/README.md" "$RAIZ/npm/index.d.ts" "$SAI/"
cp "$RAIZ/npm/bin/jsonw.js" "$SAI/bin/"; chmod +x "$SAI/bin/jsonw.js"
cp "$RAIZ/sdk/node/index.js" "$SAI/index.js"; cp "$RAIZ/LICENCA.md" "$SAI/"
cp "$RAIZ/bin/macos-arm64/jsonw.node" "$RAIZ/bin/macos-arm64/wjsw" "$SAI/prebuilt/darwin-arm64/"
cp "$RAIZ/bin/linux-x86_64/jsonw.node" "$RAIZ/bin/linux-x86_64/wjsw" "$SAI/prebuilt/linux-x64/"
cp "$RAIZ/bin/windows-x86_64/wjsw.exe" "$SAI/prebuilt/win32-x64/"
chmod +x "$SAI/prebuilt/darwin-arm64/wjsw" "$SAI/prebuilt/linux-x64/wjsw"
find "$SAI" -type f | sed "s|$SAI/||" | sort
