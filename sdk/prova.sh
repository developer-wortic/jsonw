#!/bin/bash
# prova.sh: cada SDK le o mesmo arquivo e produz o mesmo JSONL que o wjsw; depois grava e o wjsw confere. Sem toolchain = pula (e diz).
set -u
cd "$(dirname "$0")"
. "$(dirname "$0")/ambiente-linguagens.sh"   # as versões mais novas do Homebrew na frente do PATH
PLAT=$(uname -sm | sed "s/Darwin arm64/macos-arm64/; s/Linux x86_64/linux-x86_64/; s/MINGW64_NT-[0-9.]* x86_64/windows-x86_64/; s/MSYS_NT-[0-9.]* x86_64/windows-x86_64/; s/ /-/g"); WJSW=../bin/$PLAT/wjsw; [ -x $WJSW ] || WJSW=$WJSW.exe; if [ -x $WJSW ]; then for f in ../bin/$PLAT/libjsonw.*; do cp -f "$f" .; done; cp -f ../bin/$PLAT/jsonw.node node/ 2>/dev/null || true; else WJSW=$(command -v wjsw) || { echo "sem wjsw: nem ../bin/$PLAT nem no PATH"; exit 1; }; [ -f libjsonw.dylib ] || [ -f libjsonw.so ] || { echo "sem libjsonw na pasta sdk"; exit 1; }; fi
T=$(mktemp -d /tmp/jsonw-sdk.XXXXXX); falhas=0; ok=0; pulados=""
export JSONW_LIB="$PWD/$(ls libjsonw.dylib libjsonw.so 2>/dev/null | head -1)"   # o Dart compilado acha a biblioteca por aqui
PYS=""   # o Python mínimo (3.10) e o mais novo instalado; abaixo de 3.10 fica de fora como pulado
PY_NOVO=$(compgen -c python3. | grep -E '^python3\.[0-9]+$' | sort -t. -k2 -n | tail -1)
for p in python3.10 "$PY_NOVO"; do
  [ -n "$p" ] && command -v "$p" >/dev/null || continue
  if "$p" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
    case " $PYS " in *" $p "*) ;; *) PYS="$PYS $p" ;; esac
  else pulados="$pulados $p(abaixo-do-minimo-3.10)"; fi
done
ESQ='id:i64,nome:texto,ativo:bool,preco:decimal[2],quando:tempo,peso:medida,valor:dinheiro,tags:lista<texto>,nota:f64?,vet:vf16[4],extra:qualquer'
cat > $T/entrada.jsonl <<'EOF'
{"id": 1, "nome": "Ação com acento, vírgula, \"aspas\" e barra \\", "ativo": true, "preco": "12.50", "quando": "2026-11-06T18:00:00-03:00", "peso": "3,5 km", "valor": "1.234,56 BRL", "tags": ["a", "b"], "nota": 0.5, "vet": [0.5, -1, 2, 0.25], "extra": {"x": [1, 2, null], "y": "z"}}
{"id": 2, "nome": "", "ativo": false, "preco": "-0.05", "quando": "2000-01-01T00:00:00Z", "peso": "25 C", "valor": "US$ 3", "tags": [], "nota": null, "vet": [0, 0, 0, 0], "extra": null}
{"id": 3, "nome": "emoji 👍 e 'apóstrofo'", "ativo": true, "preco": "999999.99", "quando": "1999-12-31T23:59:59.5Z", "peso": "1 kWh", "valor": "0.01 EUR", "tags": ["só", "um"], "nota": -1e-3, "vet": [1, 1, 1, 1], "extra": "texto"}
EOF
$WJSW de-texto "$ESQ" $T/entrada.jsonl $T/base.jsw 2>/dev/null || { echo "FALHOU: wjsw de-texto"; exit 1; }
$WJSW para-texto $T/base.jsw --json > $T/esperado.jsonl
confere() {   # nome, comando que imprime JSONL
  local nome=$1; shift
  if "$@" > $T/$nome.jsonl 2> $T/$nome.err && cmp -s $T/$nome.jsonl $T/esperado.jsonl; then echo "  ok   $nome le igual ao wjsw"; ok=$((ok+1));
  else echo "  FALHOU $nome (ler)"; head -3 $T/$nome.err; diff $T/esperado.jsonl $T/$nome.jsonl | head -4; falhas=$((falhas+1)); fi
}
grava() {   # nome, comando que grava $T/<nome>.jsw a partir de $T/entrada.jsonl
  local nome=$1; shift
  if "$@" 2> $T/$nome.w.err && $WJSW conferir $T/$nome.jsw >/dev/null && $WJSW para-texto $T/$nome.jsw --json | cmp -s - $T/esperado.jsonl; then echo "  ok   $nome grava e o wjsw confere"; ok=$((ok+1));
  else echo "  FALHOU $nome (gravar)"; head -3 $T/$nome.w.err; falhas=$((falhas+1)); fi
}
echo "C (ABI direta)"
cc -std=c11 -O2 -I. prova_c.c libjsonw.a -lm -o $T/prova_c && confere C $T/prova_c $T/base.jsw && grava C $T/prova_c --gravar "$ESQ" $T/entrada.jsonl $T/C.jsw
echo "C++"; if c++ -std=c++23 -O2 -Wall -Wextra -Wpedantic cpp/ler.cpp libjsonw.a -lm -o cpp/ler 2>$T/cpp.err; then confere C++ cpp/ler $T/base.jsw; else echo "  FALHOU C++ (build)"; head -5 $T/cpp.err; falhas=$((falhas+1)); fi
echo "Node"; [ -f node/jsonw.node ] || { NH=$(dirname $(dirname $(command -v node 2>/dev/null || echo /usr/bin/node)))/include/node; [ -d "$NH" ] && cc -std=c11 -O2 -fPIC -shared -undefined dynamic_lookup -I"$NH" node/jsonw_node*.c libjsonw.a -lm -o node/jsonw.node 2>/dev/null || cc -std=c11 -O2 -fPIC -shared -I"$NH" node/jsonw_node*.c libjsonw.a -lm -o node/jsonw.node 2>/dev/null || true; }; if command -v node >/dev/null; then confere Node node node/index.js $T/base.jsw; grava Node node -e 'const j=require("./node"),fs=require("fs");const w=new j.Escritor(process.argv[3],process.argv[1]);for(const l of fs.readFileSync(process.argv[2],"utf8").split("\n"))if(l.trim())w.gravarTexto(l);w.fechar()' "$ESQ" $T/entrada.jsonl $T/Node.jsw; else pulados="$pulados node"; fi
for PY in $PYS; do echo "$PY ($($PY -V 2>&1))"; confere $PY $PY python/jsonw.py $T/base.jsw; grava $PY $PY -c 'import sys; sys.path.insert(0, "python"); import jsonw
w = jsonw.Escritor(sys.argv[3], sys.argv[1])
for l in open(sys.argv[2], encoding="utf-8"):
    if l.strip(): w.gravar_texto(l)
w.fechar()' "$ESQ" $T/entrada.jsonl $T/$PY.jsw; done; [ -n "$PYS" ] || pulados="$pulados python"
echo "PHP"; if command -v php >/dev/null && php -r 'exit(extension_loaded("FFI")?0:1);'; then confere PHP php php/jsonw.php $T/base.jsw; grava PHP php -r 'require "php/jsonw.php"; $w = new JsonW\Escritor($argv[3], $argv[1]); foreach (file($argv[2]) as $l) if (trim($l) !== "") $w->gravarTexto($l); $w->fechar();' "$ESQ" $T/entrada.jsonl $T/PHP.jsw; else pulados="$pulados php"; fi
echo "Go"; if command -v go >/dev/null; then (cd go && go build -o ler ./cmd/ler >/dev/null 2>$T/go.err) && confere Go go/ler $T/base.jsw && grava Go go/ler --gravar "$ESQ" $T/entrada.jsonl $T/Go.jsw || { echo "  FALHOU Go (build)"; head -5 $T/go.err; falhas=$((falhas+1)); }; else pulados="$pulados go"; fi
echo "Rust"; if command -v cargo >/dev/null; then (cd rust && cargo build --release --example ler -q 2>$T/rust.err) && confere Rust rust/target/release/examples/ler $T/base.jsw || { echo "  FALHOU Rust (build)"; head -5 $T/rust.err; falhas=$((falhas+1)); }; else pulados="$pulados rust"; fi
echo "Java"; if command -v java >/dev/null && java -version 2>&1 | grep -qE 'version "(2[2-9]|[3-9][0-9])'; then confere Java java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 java/Jsonw.java $T/base.jsw; grava Java java --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 java/Gravar.java "$ESQ" $T/entrada.jsonl $T/Java.jsw; else pulados="$pulados java(22+)"; fi
echo "Swift"; if command -v swiftc >/dev/null; then swiftc -I swift swift/jsonw.swift swift/jsonw_ops.swift swift/main.swift libjsonw.a -o $T/swift_ler 2>$T/swift.err && confere Swift $T/swift_ler $T/base.jsw && grava Swift $T/swift_ler --gravar "$ESQ" $T/entrada.jsonl $T/Swift.jsw || { echo "  FALHOU Swift (build)"; head -5 $T/swift.err; falhas=$((falhas+1)); }; else pulados="$pulados swift"; fi
echo "Dart"; if command -v dart >/dev/null; then (cd dart && dart pub get --enforce-lockfile >/dev/null 2>&1 && dart compile exe bin/ler.dart -o $T/dart_ler >$T/dart.err 2>&1) && confere Dart $T/dart_ler $T/base.jsw && grava Dart $T/dart_ler --gravar "$ESQ" $T/entrada.jsonl $T/Dart.jsw || { echo "  FALHOU Dart (build)"; head -5 $T/dart.err; falhas=$((falhas+1)); }; else pulados="$pulados dart"; fi
echo "Objective-C"; if [ "$(uname)" = Darwin ]; then /usr/bin/clang -fobjc-arc -fmodules -Wall -Wextra -Wpedantic -Werror -I. objc/ler.m objc/JsonW.m libjsonw.a -framework Foundation -o $T/objc_ler 2>$T/objc.err && confere Objective-C $T/objc_ler $T/base.jsw && grava Objective-C $T/objc_ler --gravar "$ESQ" $T/entrada.jsonl $T/Objective-C.jsw || { echo "  FALHOU Objective-C (build)"; head -5 $T/objc.err; falhas=$((falhas+1)); }; else pulados="$pulados objective-c(macos)"; fi
echo "COBOL"; if command -v cobc >/dev/null; then cobc -x -free -Wall cobol/ler.cob libjsonw.a -o $T/cobol_ler 2>$T/cobol.err && confere COBOL $T/cobol_ler $T/base.jsw || { echo "  FALHOU COBOL (build)"; head -5 $T/cobol.err; falhas=$((falhas+1)); }; else pulados="$pulados cobol"; fi
echo "Kotlin"; if command -v kotlinc >/dev/null && command -v java >/dev/null; then (kotlinc kotlin/Jsonw.kt kotlin/JsonwOps.kt -include-runtime -d $T/jsonw.jar 2>$T/kt.err) && confere Kotlin java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 -jar $T/jsonw.jar $T/base.jsw && grava Kotlin java --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -jar $T/jsonw.jar --gravar "$ESQ" $T/entrada.jsonl $T/Kotlin.jsw || { echo "  FALHOU Kotlin (build)"; head -5 $T/kt.err; falhas=$((falhas+1)); }; else pulados="$pulados kotlin"; fi
echo "Ruby"; if command -v ruby >/dev/null; then confere Ruby ruby ruby/jsonw.rb $T/base.jsw; grava Ruby ruby ruby/jsonw.rb --gravar "$ESQ" $T/entrada.jsonl $T/Ruby.jsw; else pulados="$pulados ruby"; fi

# operacoes: o mesmo pedido de AVALIAR (cosseno no vf16, top-2) e o mesmo RECONHECER em cada SDK tem de dar o JSON
# identico ao do wjsw (que usa o nucleo direto). Linguagem sem toolchain ja foi pulada acima.
echo "operações: avaliar + escolher, reconhecer"
PED='{"cosseno":{"campo":"vet","consulta":[0.5,-1,2,0.25]}}'
LEX='termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic'
printf '%s\n' '{"termo":"ação com acento","forma":"acao com acento","sinal":"teste","peso":1.5,"idioma":"pt","origem":"prova"}' '{"termo":"emoji","forma":"emoji","sinal":"outro","peso":1,"idioma":"pt","origem":"prova"}' > $T/termos.jsonl
$WJSW de-texto "$LEX" $T/termos.jsonl $T/termos.jsw 2>/dev/null || { echo "FALHOU: wjsw de-texto (termos)"; exit 1; }
TXT='AÇÃO com acento, emoji 👍 e "ação com acento" de novo.'
$WJSW avaliar $T/base.jsw "$PED" 2 --json | sed 's/,"valor":.*}$/}/' | paste -sd, - | sed 's/^/[/; s/$/]/' > $T/esperado-avaliar.json
$WJSW reconhecer $T/termos.jsw "$TXT" --json > $T/esperado-reconhecer.json
igual() {   # nome, arquivo esperado, comando que imprime o JSON
  local nome=$1 esp=$2; shift 2; local err=$T/${nome// /_}.op.err
  if "$@" 2> $err | tr -d '\n' | cmp -s - <(tr -d '\n' < $esp); then echo "  ok   $nome"; ok=$((ok+1)); else echo "  FALHOU $nome"; head -3 $err; "$@" 2>/dev/null | head -c 300; echo; falhas=$((falhas+1)); fi
}
igual "C avaliar" $T/esperado-avaliar.json $T/prova_c --avaliar $T/base.jsw "$PED" 2; igual "C reconhecer" $T/esperado-reconhecer.json $T/prova_c --reconhecer $T/termos.jsw "$TXT"
[ -x $T/cpp_ler ] && CPP=$T/cpp_ler || CPP=cpp/ler; [ -x $CPP ] && { igual "C++ avaliar" $T/esperado-avaliar.json $CPP --avaliar $T/base.jsw "$PED" 2; igual "C++ reconhecer" $T/esperado-reconhecer.json $CPP --reconhecer $T/termos.jsw "$TXT"; }
command -v node >/dev/null && { igual "Node avaliar" $T/esperado-avaliar.json node node/index.js --avaliar $T/base.jsw "$PED" 2; igual "Node reconhecer" $T/esperado-reconhecer.json node node/index.js --reconhecer $T/termos.jsw "$TXT"; }
for PY in $PYS; do igual "$PY avaliar" $T/esperado-avaliar.json $PY python/jsonw.py --avaliar $T/base.jsw "$PED" 2; igual "$PY reconhecer" $T/esperado-reconhecer.json $PY python/jsonw.py --reconhecer $T/termos.jsw "$TXT"; done
command -v php >/dev/null && php -r 'exit(extension_loaded("FFI")?0:1);' && { igual "PHP avaliar" $T/esperado-avaliar.json php php/jsonw.php --avaliar $T/base.jsw "$PED" 2; igual "PHP reconhecer" $T/esperado-reconhecer.json php php/jsonw.php --reconhecer $T/termos.jsw "$TXT"; }
command -v ruby >/dev/null && { igual "Ruby avaliar" $T/esperado-avaliar.json ruby ruby/jsonw.rb --avaliar $T/base.jsw "$PED" 2; igual "Ruby reconhecer" $T/esperado-reconhecer.json ruby ruby/jsonw.rb --reconhecer $T/termos.jsw "$TXT"; }
[ -x go/ler ] && { igual "Go avaliar" $T/esperado-avaliar.json go/ler --avaliar $T/base.jsw "$PED" 2; igual "Go reconhecer" $T/esperado-reconhecer.json go/ler --reconhecer $T/termos.jsw "$TXT"; }
[ -x rust/target/release/examples/ler ] && { igual "Rust avaliar" $T/esperado-avaliar.json rust/target/release/examples/ler --avaliar $T/base.jsw "$PED" 2; igual "Rust reconhecer" $T/esperado-reconhecer.json rust/target/release/examples/ler --reconhecer $T/termos.jsw "$TXT"; }
command -v java >/dev/null && java -version 2>&1 | grep -qE 'version "(2[2-9]|[3-9][0-9])' && { igual "Java avaliar" $T/esperado-avaliar.json java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 java/Jsonw.java --avaliar $T/base.jsw "$PED" 2; igual "Java reconhecer" $T/esperado-reconhecer.json java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 java/Jsonw.java --reconhecer $T/termos.jsw "$TXT"; }
[ -x $T/swift_ler ] && { igual "Swift avaliar" $T/esperado-avaliar.json $T/swift_ler --avaliar $T/base.jsw "$PED" 2; igual "Swift reconhecer" $T/esperado-reconhecer.json $T/swift_ler --reconhecer $T/termos.jsw "$TXT"; }
[ -x $T/dart_ler ] && { igual "Dart avaliar" $T/esperado-avaliar.json $T/dart_ler --avaliar $T/base.jsw "$PED" 2; igual "Dart reconhecer" $T/esperado-reconhecer.json $T/dart_ler --reconhecer $T/termos.jsw "$TXT"; }
[ -x $T/objc_ler ] && { igual "Objective-C avaliar" $T/esperado-avaliar.json $T/objc_ler --avaliar $T/base.jsw "$PED" 2; igual "Objective-C reconhecer" $T/esperado-reconhecer.json $T/objc_ler --reconhecer $T/termos.jsw "$TXT"; }
[ -f $T/jsonw.jar ] && { igual "Kotlin avaliar" $T/esperado-avaliar.json java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 -jar $T/jsonw.jar --avaliar $T/base.jsw "$PED" 2; igual "Kotlin reconhecer" $T/esperado-reconhecer.json java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 -jar $T/jsonw.jar --reconhecer $T/termos.jsw "$TXT"; }
# visao: depois de jsonw_visao("tenant:1") cada SDK imprime as colunas visiveis, so as linhas do tenant 1 e o avaliar
# so com elas, identico ao C; a coluna +pessoal (renda) nao pode aparecer
echo "visão: colunas visíveis, linhas do tenant, avaliar da sessão"
VESQ='id:i64,nota:f64,renda:f64+pessoal,tenant:i64+tenant'; VP='{"pesos":{"nota":1}}'; VA="$T/visao.jsw tenant:1"
for i in $(seq 0 19); do echo "{\"id\":$i,\"nota\":$((i % 7)),\"renda\":$((1000*i)).5,\"tenant\":$((1 + (i & 1)))}"; done > $T/visao.jsonl
$T/prova_c --gravar "$VESQ" $T/visao.jsonl $T/visao.jsw && $T/prova_c --visao $VA "$VP" 3 > $T/esperado-visao.txt && ! grep -q renda $T/esperado-visao.txt && [ "$(wc -l < $T/esperado-visao.txt)" -eq 12 ] && { echo "  ok   C visao"; ok=$((ok+1)); } || { echo "  FALHOU C visao"; falhas=$((falhas+1)); }
[ -x $CPP ] && igual "C++ visao" $T/esperado-visao.txt $CPP --visao $VA "$VP" 3
command -v node >/dev/null && igual "Node visao" $T/esperado-visao.txt node node/index.js --visao $VA "$VP" 3
for PY in $PYS; do igual "$PY visao" $T/esperado-visao.txt $PY python/jsonw.py --visao $VA "$VP" 3; done
command -v php >/dev/null && php -r 'exit(extension_loaded("FFI")?0:1);' && igual "PHP visao" $T/esperado-visao.txt php php/jsonw.php --visao $VA "$VP" 3
command -v ruby >/dev/null && igual "Ruby visao" $T/esperado-visao.txt ruby ruby/jsonw.rb --visao $VA "$VP" 3
[ -x go/ler ] && igual "Go visao" $T/esperado-visao.txt go/ler --visao $VA "$VP" 3
[ -x rust/target/release/examples/ler ] && igual "Rust visao" $T/esperado-visao.txt rust/target/release/examples/ler --visao $VA "$VP" 3
command -v java >/dev/null && java -version 2>&1 | grep -qE 'version "(2[2-9]|[3-9][0-9])' && igual "Java visao" $T/esperado-visao.txt java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 java/Jsonw.java --visao $VA "$VP" 3
[ -x $T/swift_ler ] && igual "Swift visao" $T/esperado-visao.txt $T/swift_ler --visao $VA "$VP" 3
[ -x $T/dart_ler ] && igual "Dart visao" $T/esperado-visao.txt $T/dart_ler --visao $VA "$VP" 3
[ -x $T/objc_ler ] && igual "Objective-C visao" $T/esperado-visao.txt $T/objc_ler --visao $VA "$VP" 3
[ -f $T/jsonw.jar ] && igual "Kotlin visao" $T/esperado-visao.txt java --enable-native-access=ALL-UNNAMED -Dstdout.encoding=UTF-8 -Dfile.encoding=UTF-8 -jar $T/jsonw.jar --visao $VA "$VP" 3
# ABI: handle nulo ou fechado nao derruba o processo, abandonar nao publica, k maior que n (prova_abi.c); e nas linguagens
# que tem saida automatica do escritor (with do Python) ou fechar/abandonar explicitos (Node): o arquivo pela metade nao aparece
echo "ABI: handle fechado, abandonar, cap curto"
cc -std=c11 -O2 -I. prova_abi.c libjsonw.a -lm -o $T/prova_abi 2>$T/abi.err && $T/prova_abi $T > $T/abi.out 2>&1 && { echo "  ok   C handle nulo, abandonar, cap curto, escolher"; ok=$((ok+1)); } || { echo "  FALHOU C (ABI)"; head -5 $T/abi.err $T/abi.out; falhas=$((falhas+1)); }
for PY in $PYS; do $PY -c 'import sys, os; sys.path.insert(0, "python"); import jsonw
d = sys.argv[1] + "/py-abandono-%d.%d.jsw" % sys.version_info[:2]
try:
    with jsonw.Escritor(d, "id:i64") as w:
        w.gravar({"id": 1}); raise RuntimeError("erro de quem grava")
except RuntimeError: pass
assert not os.path.exists(d), "o with que saiu por erro publicou o arquivo"
with jsonw.Escritor(d, "id:i64") as w: w.gravar({"id": 1})
a = jsonw.Leitor(d); a.fechar()
try: a.json(0); raise SystemExit("leitor fechado respondeu")
except jsonw.ErroJsonW: pass
w = jsonw.Escritor(d, "id:i64"); w.gravar({"id": 2}); w.gravar({"id": 3}); w.abandonar()
assert jsonw.Leitor(d).linhas == 1, "abandonar publicou"' $T 2>$T/pyab.err && { echo "  ok   $PY with por erro nao publica, abandonar, leitor fechado"; ok=$((ok+1)); } || { echo "  FALHOU $PY (abandonar)"; head -5 $T/pyab.err; falhas=$((falhas+1)); }; done
if command -v node >/dev/null; then node -e 'const j=require("./node"),fs=require("fs");const d=process.argv[1]+"/node-abandono.jsw";
let w=new j.Escritor(d,"id:i64");w.gravar({id:1});w.fechar();
w=new j.Escritor(d,"id:i64");w.gravar({id:2});w.gravar({id:3});w.abandonar();
const a=new j.Leitor(d);if(a.linhas!==1)throw new Error("abandonar publicou: "+a.linhas);a.fechar();
let caiu=false;try{a.json(0)}catch(e){caiu=true}if(!caiu)throw new Error("leitor fechado respondeu");
if(j.escolher([0.2,0.9,0.5],1e12).join()!=="1,2,0")throw new Error("escolher com k gigante");if(j.escolher([1,2],-5).length!==0)throw new Error("escolher com k negativo")' $T 2>$T/nodeab.err && { echo "  ok   Node abandonar, leitor fechado, escolher com k fora da faixa"; ok=$((ok+1)); } || { echo "  FALHOU Node (abandonar)"; head -5 $T/nodeab.err; falhas=$((falhas+1)); }; fi
echo "busca por chave: com e sem indice, chave ausente, repetida, valor vazio, tipo errado, visao"
cc -std=c11 -O2 -I. prova_chave.c libjsonw.a -lm -o $T/prova_chave 2>$T/chave.err && $T/prova_chave > $T/chave.out 2>&1 && grep -q "TUDO CERTO" $T/chave.out && { echo "  ok   C jsonw_chave ($(grep -c '^  ok' $T/chave.out) casos)"; ok=$((ok+1)); } || { echo "  FALHOU C jsonw_chave"; grep -v '^  ok' $T/chave.out $T/chave.err | head -5; falhas=$((falhas+1)); }
bash exemplos.sh > $T/ex.out 2>&1; grep '^  ok\|^  FALHOU' $T/ex.out; ok=$((ok + $(grep -c '^  ok' $T/ex.out))); falhas=$((falhas + $(grep -c '^  FALHOU' $T/ex.out)))
echo; echo "SDKs: $ok provas ok, $falhas falhas; pulados (sem toolchain aqui):${pulados:- nenhum}"
[ -n "${JSONW_PROVA_MANTER:-}" ] && echo "arquivos em $T" || rm -rf $T
exit $falhas
