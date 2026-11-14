#!/bin/bash
# exemplos.sh: roda o exemplo "abrir um .jsw e buscar por chave" de cada SDK (jsonw_chave, ABI 1.3.13) no mesmo arquivo e
# confere com o wjsw, COM indice e SEM indice (--varrer): chave unica, valor vazio, chave repetida (2 linhas, em ordem) e chave
# ausente (nada). Sem toolchain = pula (e diz). Usa as bibliotecas de ../bin/<plataforma>.
set -u
cd "$(dirname "$0")"
. ./ambiente-linguagens.sh
PLAT=$(uname -sm | sed "s/Darwin arm64/macos-arm64/; s/Linux x86_64/linux-x86_64/; s/Linux aarch64/linux-arm64/; s/ /-/g"); WJSW=../bin/$PLAT/wjsw
for f in ../bin/$PLAT/libjsonw.*; do cp -f "$f" .; done
T=$(mktemp -d /tmp/jsonw-ex.XXXXXX); ok=0; falhas=0; pulados=""
printf '%s\n' '{id:1,nome:"Ação"}' '{id:2,nome:""}' '{id:3,nome:"emoji 👍"}' '{id:4,nome:"Ação"}' > $T/e.jsw.txt
$WJSW de-texto 'id:i64,nome:texto' $T/e.jsw.txt $T/e.jsw >/dev/null || { echo "FALHOU: wjsw de-texto"; exit 1; }
$WJSW para-texto $T/e.jsw --json > $T/todas.txt   # borda-json: o SDK público entrega cada linha em JSON ao desenvolvedor de fora
sed -n 2p $T/todas.txt > $T/esp-id2; sed -n 2p $T/todas.txt > $T/esp-vazio; sed -n '1p;4p' $T/todas.txt > $T/esp-rep; : > $T/esp-ausente
roda() {   # nome, comando (recebe arquivo campo valor [--varrer] no fim)
  local nome=$1; shift; local ruim=""
  local CAMPOS=(id nome nome id) VALORES=('2' '""' '"Ação"' '999') ESPERADOS=(esp-id2 esp-vazio esp-rep esp-ausente)
  for modo in "" --varrer; do
    for j in 0 1 2 3; do   # o valor vai em JSON, com as aspas, como a pessoa digita
      local c=${CAMPOS[$j]} v=${VALORES[$j]} esp=${ESPERADOS[$j]}
      local saida; saida=$("${CMD[@]}" $T/e.jsw "$c" "$v" $modo 2>>$T/$nome.err)
      [ "$saida" = "$(cat $T/$esp)" ] || ruim="$ruim [$c=$v ${modo:-indice}]"
    done
  done
  if [ -z "$ruim" ]; then echo "  ok   $nome (indice e varredura: unica, vazio, repetida, ausente)"; ok=$((ok+1));
  else echo "  FALHOU $nome:$ruim"; head -3 $T/$nome.err; falhas=$((falhas+1)); fi
}
c() { local n=$1; shift; CMD=("$@"); roda "$n"; }
cc -std=c11 -O2 -I. c/exemplo.c libjsonw.a -lm -o $T/c && c C $T/c
if c++ -std=c++23 -O2 -Wall -Wextra -I. -Icpp cpp/exemplo.cpp libjsonw.a -lm -o $T/cpp 2>$T/cpp.err; then c C++ $T/cpp; else echo "  FALHOU C++ (build)"; head -3 $T/cpp.err; falhas=$((falhas+1)); fi
if command -v node >/dev/null; then NH=$(dirname $(dirname $(command -v node)))/include/node; cc -std=c11 -O2 -fPIC -shared -undefined dynamic_lookup -I"$NH" node/jsonw_node*.c libjsonw.a -lm -o node/jsonw.node 2>/dev/null || cc -std=c11 -O2 -fPIC -shared -I"$NH" node/jsonw_node*.c libjsonw.a -lm -o node/jsonw.node; c Node node node/exemplo.js; else pulados="$pulados node"; fi
if command -v php >/dev/null && php -r 'exit(extension_loaded("FFI")?0:1);'; then c PHP php php/exemplo.php; else pulados="$pulados php"; fi
PYS=""   # o Python mínimo (3.10) e o mais novo instalado
PY_NOVO=$(compgen -c python3. | grep -E '^python3\.[0-9]+$' | sort -t. -k2 -n | tail -1)
for p in python3.10 "$PY_NOVO"; do
  [ -n "$p" ] && command -v "$p" >/dev/null && "$p" -c 'import sys; sys.exit(sys.version_info < (3, 10))' || continue
  case " $PYS " in *" $p "*) ;; *) PYS="$PYS $p" ;; esac
done
for p in $PYS; do c "$p" "$p" -I python/exemplo.py; done
[ -n "$PYS" ] || pulados="$pulados python(3.10+)"
if command -v ruby >/dev/null; then c Ruby ruby ruby/exemplo.rb; else pulados="$pulados ruby"; fi
if command -v go >/dev/null; then (cd go && go build -o $T/go ./cmd/exemplo 2>$T/go.b.err) && c Go $T/go || { echo "  FALHOU Go (build)"; head -3 $T/go.b.err; falhas=$((falhas+1)); }; else pulados="$pulados go"; fi
if command -v cargo >/dev/null; then (cd rust && cargo build --release --example exemplo -q 2>$T/rs.b.err) && c Rust rust/target/release/examples/exemplo || { echo "  FALHOU Rust (build)"; head -3 $T/rs.b.err; falhas=$((falhas+1)); }; else pulados="$pulados rust"; fi
if command -v java >/dev/null; then c Java java --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 java/Exemplo.java; else pulados="$pulados java"; fi
if command -v kotlinc >/dev/null; then kotlinc kotlin/Jsonw.kt kotlin/JsonwOps.kt kotlin/Exemplo.kt -include-runtime -d $T/k.jar 2>$T/kt.b.err && c Kotlin java --enable-native-access=ALL-UNNAMED -cp $T/k.jar ExemploKt || { echo "  FALHOU Kotlin (build)"; head -3 $T/kt.b.err; falhas=$((falhas+1)); }; else pulados="$pulados kotlin"; fi
if command -v swiftc >/dev/null; then swiftc -I swift swift/jsonw.swift swift/jsonw_ops.swift swift/exemplo/main.swift libjsonw.a -o $T/sw 2>$T/sw.b.err && c Swift $T/sw || { echo "  FALHOU Swift (build)"; head -3 $T/sw.b.err; falhas=$((falhas+1)); }; else pulados="$pulados swift"; fi
echo "exemplos: $ok ok, $falhas falhas; pulados:${pulados:- nenhum}"
rm -rf $T; [ $falhas -eq 0 ]
