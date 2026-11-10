# jsonW (json Wondrous): o que você precisa para usar

jsonW é um modelo de dados com três formas que se convertem sem perda: **linha** (mensagem, evento, tempo real), **coluna**
(arquivo `.jsw`: lote, treino, busca, leitura por `mmap` sem cópia) e **texto** (`jsonW-texto`, para gente escrever; todo JSON
válido é jsonW-texto válido). O núcleo é em C, sem dependência, mantido pela Wortic; este pacote traz a ferramenta `wjsw`, a
biblioteca `libjsonw` e um SDK por linguagem. Termos de uso em `../LICENCA.md`. Site: jsonw.org.

## Tipos
| Tipo | No esquema | Observação |
|---|---|---|
| nulo, bool | `bool` | |
| inteiro | `i64` | guardado na largura mínima |
| decimal exato | `decimal[2]` (escala) | nunca passa por ponto flutuante |
| real | `f64` `f32` `f16` `bf16` | |
| tempo | `tempo` | microssegundos UTC |
| uuid | `uuid` | |
| texto, bytes | `texto` `bytes` | Unicode inteiro (acento, emoji, `\0`); `+nfc` normaliza |
| url | `url` | validada ao gravar (`esquema://…`, `mailto:`, `tel:`, `urn:`; ≤ 8 KiB) |
| código | `codigo` | bytes exatos: nunca normaliza nem apara (CNPJ, chave, placa, SKU) |
| medida | `medida` ou `medida[kg]` | unidade por valor, ou coluna numa unidade (g, t, lb… são convertidos; outra grandeza é recusada) |
| dinheiro | `dinheiro` ou `dinheiro[4]` | moeda ISO 4217 por valor; soma só na mesma moeda |
| texto repetido | `dic` | dicionário por arquivo |
| vetor | `vf32[n]` `vf16[n]` `bits[n]` `vq8[n]` `vq4[n]` | `n` omitido = variável; matriz contínua no arquivo |
| tensor | `tensor<f16>[768,768]` | elemento f32, f16, bf16, u8, i8, i16, i32 |
| mídia | `midia` | {sha, mime, tamanho, duracao?, largura?, altura?, dados?, url?, extra?}; o codec continua o aberto |
| referência | `ref` | {arquivo?, linha} |
| lista, objeto, mapa | `lista<t>` `obj{...}` `mapa<k,v>` | aninhamento até 1000 níveis |
| qualquer | `qualquer` | JSON aberto |

`?` depois do tipo aceita nulo. Aspas, vírgulas, pontos, barras e qualquer byte dentro de um texto são dados: nunca quebram
o arquivo nem a leitura (o leitor confere todo índice e limite antes de usar).

**Números com vírgula ou ponto.** Quem lê aceita os dois: `12,50d`, `12.50d`, `1.234,56 BRL`, `1,234.56 USD`, `3,5 km`. Com os
dois separadores, o último é o decimal; com um só, é decimal (`12,5`), exceto vírgula + 3 dígitos numa moeda de ponto
(`USD 1,234` = mil) ou ponto + 3 dígitos numa moeda de vírgula (`R$ 1.234` = mil). O canônico sai sempre com ponto. Em
`qualquer`, a vírgula decimal só vale com o sufixo `d` colado (`12,50d`).

**Medidas universais** (89 unidades em 14 grandezas, código estável): comprimento mm cm m km µm nm mi in ft yd nmi · massa mg g kg t lb oz ct ·
volume mL L m3 cm3 hL gal · energia J kJ MJ GJ TJ Wh kWh MWh GWh cal kcal BTU · tempo s ms us min h d sem · área m2 cm2 km2
ha ft2 alq · dados B KB MB GB TB KiB MiB GiB TiB bit · velocidade m/s km/h mph kn ft/s · temperatura C F K · adimensional un %
permil ppm pc · potência W kW MW cv hp · pressão Pa kPa bar atm psi mmHg · carbono gCO2e kgCO2e tCO2e · densidade kg/m3 g/cm3
g/L. Conversão exata entre múltiplos decimais (12,5 mm = 0,0125 m) e arredondada na escala pedida nas demais (1 mi =
1609,344 m; 25 °C = 77 °F). **Dinheiro:** `12,50 BRL`, `$"R$ 1.234,56"`, `US$`, `€`, `£`, `¥`, `₿`; canônico `1234.56 BRL`.

## Esquema
Texto canônico: `id:i64,nome:texto?,preco:decimal[2],v:vf16[1024]`. Campo novo entra com nulo; um nome nunca muda de tipo; o
leitor resolve pelo nome, então arquivo velho é lido por código novo e vice-versa. Marcas de permissão: `+escopo(x)` (coluna
visível só para quem tem o escopo `x`) e `+pessoal` (dado pessoal, escondido sem o escopo `pessoal`).

## Ferramenta `wjsw` (`bin/<plataforma>/wjsw`)
```
wjsw de-texto "id:i64,nome:texto,preco:decimal[2]" dados.jsonl dados.jsw [--max]   # JSON/JSONL → .jsw (--max: compressão máxima)
wjsw ver dados.jsw        # linhas em jsonW-texto      wjsw info dados.jsw        # esquema, blocos, tamanho, hash
wjsw conferir dados.jsw   # custódia inteira           wjsw reparar dados.jsw     # arquivo cortado: refaz o fim
wjsw para-texto --json dados.jsw > dados.jsonl        # volta para JSON, sem perda
wjsw filtrar dados.jsw "preco > 10; ativo = true" [saida.jsw]    # linhas que passam (zonas pulam blocos inteiros)
wjsw calcular dados.jsw [--onde "..."] [--por campo] [--valor campo]   # contagem, soma exata, mínimo, máximo, média
wjsw comparar a.jsw b.jsw chave                       # só em a, só em b, mudou, iguais
wjsw avaliar dados.jsw pesos "preco=-1,nota=2" [k]    # AVALIAR + ESCOLHER: nota por linha, as k melhores (padrão 10)
wjsw avaliar dados.jsw cosseno vet "0.5,-1,2,0.25" 5  # cosseno com a coluna de vetores; esparso m "12=0.5,40=1"; grade "x,y" grade.jsw
wjsw avaliar dados.jsw '{"pesos":{"preco":-1}}' 3 --json   # o pedido em JSON (o mesmo da ABI); --json = um JSON por linha
wjsw escolher dados.jsw preco 10                      # as 10 linhas de maior valor na coluna
wjsw reconhecer termos.jsw "texto a classificar"      # RECONHECER: termos do léxico no texto e a soma por sinal (--json)
wjsw medir                # mede gravar/ler nesta máquina
```
Saída de `avaliar`/`escolher`: `nota`, `linha` e a linha em jsonW-texto, da melhor para a pior. A tabela de termos do
`reconhecer` tem o esquema `termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic` (um termo por linha; o
autômato é montado ao abrir); casa palavra inteira, sem acento e sem caixa, e devolve o trecho original do texto.

## Arquivo `.jsw`: garantias
- Só anexa: cada bloco se sustenta (marcador, crc32c, hash); arquivo cortado perde só o último bloco e `wjsw reparar` refaz
  o fim; dá para ler em fluxo enquanto outro processo grava (`tail -f` que nunca vê bloco pela metade).
- Acesso direto a (linha, campo) sem decodificar o resto; leitura paralela por bloco; `mmap` compartilhado entre processos.
- Zonas (mínimo e máximo por bloco) fazem a busca pular blocos inteiros.
- Compressão em três níveis (0 nenhuma, 1 rápida, 2 máxima) e custódia por SHA-256 (padrão) ou BLAKE3, com cadeia do
  arquivo inteiro: qualquer dado, zona ou dicionário trocado falha no `conferir`.
- Edição e exclusão num arquivo que só anexa: gravar de novo com a mesma chave edita; gravar a chave com `_apagado:bool =
  true` exclui; compactar regrava só o que vale e o histórico fica no arquivo original.
- Abertura parcial: com cabeçalho e rodapé (HTTP Range) o leitor tem esquema, índice e zonas, e busca cada bloco só quando uma
  linha dele é lida.
- Leitor à prova de arquivo forjado: limites em todo índice, aninhamento máximo 1000, fuzz na prova.
- Números reais nunca dependem do locale do processo: um JVM ou PHP em pt-BR não troca o ponto por vírgula. Um real inteiro
  sai no JSON como `12.0` (nunca `12`): quem lê com tipo recebe real, igual ao original.
- `comparar` compara pelo valor, não pelo texto: `-0 == 0`, `3 == 3.0`, `1.50 == 1.500`; bytes só são iguais a bytes.

## Segurança
- **Credencial** assinada (HMAC-SHA256, verificação em tempo constante, nonce + sequência contra replay) carregando emissor,
  sujeito, tenant, escopos e validade, dentro do próprio jsonW, por cima do TLS.
- **Visão por permissão**: `+escopo(x)` e `+pessoal` escondem a coluna; se há uma coluna inteira `tenant`/`tenant_id` (ou marcada `+tenant`), só as linhas do tenant da
  credencial aparecem (`tenant:todos` libera), pulando blocos inteiros; célula = os dois. O que a sessão não pode ver não
  sai do servidor.

## SDKs (`sdk/`)
Uma ABI C estável (`sdk/jsonw.h` + `libjsonw`) e, por cima dela, C, C++17, Node.js (N-API), Python 3 (ctypes), PHP 8 (FFI),
Go (cgo), Rust, Java 22+ (FFM), Kotlin/JVM e Swift. Leitura: `linhas`, `esquema`, `campos`, `json(i)`, `texto(i)`,
`campo(i, k)`, `conferir()`. Escrita: `criar(caminho, esquema)`, `opcoes(compressão 0..2, hash 0/1, bloco em KiB)`,
`gravar(json)`, `descarregar()`, `fechar()` (troca atômica; só ele publica) e `abandonar()` (desiste: o destino fica como
estava). Operações (ABI 1.1): `avaliar(pedido, k)` devolve as k melhores
linhas `[{"linha", "nota"}]` para um pedido em JSON (`{"pesos": {"preco": -1, "nota": 2}}`, `{"cosseno": {"campo": "vet",
"consulta": [...]}}`, `{"esparso": {"campo": "m", "consulta": {"12": 0.5}}}`, `{"grade": {"campos": ["x", "y"], "arquivo":
"g.jsw"}}`), lendo só as colunas do pedido, em paralelo; `escolher(notas, k)` dá as posições das k maiores notas suas;
`Reconhecedor(termos.jsw).reconhecer(texto)` devolve `{"termos": [{termo, ini, fim, texto, sinal, peso}], "sinais": [{sinal,
soma, vezes}]}`. Como instalar e provar: `sdk/README.md` e `sdk/prova.sh`.

## Apoio à IA
Léxico (tabela de termos + autômato compilado, casamento de palavra inteira sem acento e sem caixa), grade de interpolação
N-linear (bilinear, trilinear…) e vetor esparso (`mapa<i64,f32>` com produto, norma e cosseno) vêm no núcleo. As operações
AVALIAR (pesos, cosseno, esparso, grade), ESCOLHER (top-k determinístico: nota maior primeiro, empate pela linha menor) e
RECONHECER (classificação de texto pelo léxico) estão na ferramenta e em todos os SDKs: são as peças de um roteador de
especialistas e de qualquer ranking sobre um `.jsw`.

## Contagem de instalações (transparência)
Para saber quantas instalações o jsonW tem, a ferramenta `wjsw` deste pacote, **na primeira vez** que roda em cada máquina,
manda para `wortic.com.br/jsonw/instalou/` só a versão e a plataforma (por exemplo `v=1.2.1&so=linux-x86_64`), grava
`~/.jsonw/instalou` e nunca mais repete. Nada de nome, caminho, dado ou IP é guardado (o servidor anota dia, plataforma e
versão). Para desligar antes da primeira execução: `JSONW_SEM_PING=1` no ambiente ou um arquivo `~/.jsonw/sem-ping`. A
biblioteca `libjsonw` e os SDKs nunca acessam a rede.
