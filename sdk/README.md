# SDKs do jsonW (json Wondrous)

Uma ABI C estável (`jsonw.h`, `libjsonw.a` / `libjsonw.dylib|.so`) e um SDK por linguagem por cima dela. Cada linha entra e sai
como JSON (ou jsonW-texto); o esquema é o texto canônico (`id:i64,nome:texto,preco:decimal[2]`). Tudo sem dependência além da
própria linguagem.

| Linguagem | Onde | Como |
|---|---|---|
| C | `jsonw.h` + `libjsonw.a` | `jsonw_abrir`, `jsonw_linha_json`, `jsonw_criar`, `jsonw_gravar_json`… |
| C++17 | `cpp/jsonw.hpp` | `jsonw::Leitor`, `jsonw::Escritor` (RAII) |
| Node.js | `node/` (addon N-API, `make node`) | `const {Leitor, Escritor} = require("./node")` |
| Python 3 | `python/jsonw.py` (ctypes) | `jsonw.Leitor`, `jsonw.Escritor`, iteráveis |
| PHP 8 | `php/jsonw.php` (FFI) | `JsonW\Leitor`, `JsonW\Escritor` |
| Go | `go/` (cgo) | `jsonw.Abrir`, `jsonw.Criar` |
| Rust | `rust/` (crate, liga `libjsonw.a`) | `jsonw::Leitor`, `jsonw::Escritor` |
| Java 22+ | `java/Jsonw.java` (FFM, sem JNI) | `Jsonw.Leitor`, `Jsonw.Escritor` |
| Kotlin/JVM 22+ | `kotlin/Jsonw.kt` (FFM) | `Jsonw.Leitor`, `Jsonw.Escritor` (`.use { }`) |
| Swift 5+ | `swift/jsonw.swift` (módulo C `CJsonw`) | `Leitor`, `Escritor` |

Prova: `bash prova.sh` (usa `../bin/<plataforma>/`) grava um arquivo com todos os tipos pelo `wjsw`, lê com cada SDK e compara byte a byte com o
`wjsw para-texto --json`; depois grava por cada SDK e o `wjsw conferir` confere a custódia. SDK sem toolchain na máquina é
pulado e dito.

Leitura: `linhas`, `esquema`, `campos`, `json(i)`, `texto(i)`, `campo(i, k)` (acesso direto a um campo sem decodificar o
resto), `conferir()`. Escrita: `criar(caminho, esquema)`, `opcoes(compressão 0..2, hash 0 sha256 / 1 blake3, bloco em KiB)`,
`gravar(json)`, `descarregar()`, `fechar()` (troca atômica no fechar). Tipos, ferramenta e garantias: `../docs/JSONW.md`.

**Onde fica a biblioteca.** Python, PHP, Java e Kotlin carregam a `libjsonw` dinâmica nesta ordem: a variável `JSONW_LIB`
(caminho inteiro do arquivo), a pasta do SDK, a pasta `sdk` e `bin/<plataforma>/` do pacote (`macos-arm64`, `linux-x86_64`,
`windows-x86_64`). C, C++, Go, Rust e Swift ligam a `libjsonw.a` que estiver na pasta `sdk` (copie de `bin/<plataforma>/`; o
`prova.sh` faz isso). No seu projeto: leve o arquivo do SDK da sua linguagem e a biblioteca da sua plataforma.

**Só `fechar()` publica (1.2.1).** O arquivo aparece inteiro, em troca atômica, no `fechar()`. Quem sai por erro no meio
chama `abandonar()`: nada é publicado e o destino fica como estava. Isso já acontece sozinho no `with` do Python que sai por
exceção, no `Escritor` do C++ destruído por uma exceção e no `Escritor` do Rust e do Swift largado sem `fechar()`. Em Java e
Kotlin o `close()` do try-with-resources publica: chame `abandonar()` no `catch`. Usar um leitor depois de fechado devolve
erro (não derruba o processo). Os tamanhos da ABI são `int64_t`, iguais no Linux, no macOS e no Windows.

**Visão (ABI 1.2).** `visao("pessoal vendas tenant:42")` no leitor trava o que a sessão vê antes de o servidor entregá-lo:
só as colunas liberadas e só as linhas do tenant (coluna inteira `tenant`/`tenant_id` ou marcada `+tenant`).

Operações (ABI 1.1, em cada linguagem no arquivo `*_ops.*` ao lado do SDK, ou no próprio quando cabe):
- `avaliar(pedido, k)` no leitor: AVALIAR + ESCOLHER. Pedido em JSON (`{"pesos":{"preco":-1,"nota":2}}`,
  `{"cosseno":{"campo":"vet","consulta":[..]}}`, `{"esparso":{"campo":"m","consulta":{"12":0.5}}}`,
  `{"grade":{"campos":["x","y"],"arquivo":"g.jsw","linha":0,"saida":0}}`, mais `"threads"`); resposta `[{"linha","nota"}]`
  das k melhores, maior nota primeiro (empate pela linha menor). Lê só as colunas do pedido, em paralelo.
- `escolher(notas, k)`: posições das k maiores notas suas (NaN é a pior).
- `Reconhecedor(termos.jsw)` + `reconhecer(texto)`: a tabela de termos (`termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,
  origem:dic`) vira o autômato ao abrir; resposta `{"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}`.
A prova compara o JSON de `avaliar` e `reconhecer` de cada linguagem com o do `wjsw` (byte a byte).
