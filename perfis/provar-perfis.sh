#!/bin/bash
# provar-perfis.sh [wjsw]: para cada objeto de cada perfil (perfis/*.jsw.txt), grava as amostras (amostras/<proto>.<objeto>.jsonl)
# em jsonW com o esquema do perfil, confere a custódia (wjsw conferir) e devolve em JSON: tem de sair byte a byte igual à entrada.
set -u
W=${1:-wjsw}; case "$W" in */*) W="$(cd "$(dirname "$W")" && pwd)/$(basename "$W")";; esac
cd "$(dirname "$0")"; T=$(mktemp -d); ok=0; falhas=0
for perfil in *.jsw.txt; do
  p=${perfil%.jsw.txt}
  grep -v '^//' "$perfil" | while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    obj=$(sed -E 's/.*objeto:"([^"]+)".*/\1/' <<<"$linha"); esq=$(sed -E 's/.*esquema:"([^"]+)".*/\1/' <<<"$linha")
    a="amostras/$p.$obj.jsw.txt"; d="$T/dados.txt"; grep -v "^//" "$a" > "$d" 2>/dev/null
    if [ ! -s "$a" ]; then echo "FALHA sem amostra $p.$obj"; echo x >> "$T/falhas"; continue; fi
    if ! "$W" de-texto "$esq" "$a" "$T/x.jsw" 2> "$T/err" >/dev/null; then echo "FALHA grava  $p.$obj: $(head -c 200 "$T/err")"; echo x >> "$T/falhas"; continue; fi
    "$W" conferir "$T/x.jsw" >/dev/null 2>&1 || { echo "FALHA custódia $p.$obj"; echo x >> "$T/falhas"; continue; }
    if "$W" para-texto "$T/x.jsw" --json | cmp -s - "$d"; then echo "ok    $p.$obj ($(wc -l < "$d" | tr -d ' ') linhas, ida e volta igual, custódia ok)"; echo x >> "$T/oks"
    else echo "FALHA volta  $p.$obj"; diff <("$W" para-texto "$T/x.jsw" --json) "$d" | head -4; echo x >> "$T/falhas"; fi
  done
done
ok=$(cat "$T/oks" 2>/dev/null | wc -l | tr -d ' '); falhas=$(cat "$T/falhas" 2>/dev/null | wc -l | tr -d ' ')
echo "perfis: $ok ok, $falhas falhas"; rm -rf "$T"; [ "$falhas" = 0 ]
