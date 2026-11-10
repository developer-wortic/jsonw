# AGENTS.md: como uma IA usa o jsonW sem errar

Instruções para agentes de código (Claude Code, Codex, Cursor, Copilot e outros) e para qualquer modelo que vá ler, gravar ou
consultar dados em jsonW. Leia inteiro antes de escrever código. (English summary at the end.)

## O que é, em uma frase
jsonW é um modelo de dados com três formas sem perda entre elas: **linha** (binária, tempo real), **coluna** (arquivo `.jsw`)
e **texto** (jsonW-texto; todo JSON válido é jsonW-texto válido). Ferramenta `wjsw`, biblioteca `libjsonw` (ABI em
`sdk/jsonw.h`) e SDKs em 10 linguagens. O núcleo em C é fechado; use só a ferramenta, a ABI e os SDKs.

## Onde está cada coisa
- `bin/<plataforma>/`: `wjsw` (ferramenta), `wjsw-cgi` (servidores web), `wcon` (bancos de dados) e `wremoto` (leitura
  remota), `libjsonw.a` e a biblioteca dinâmica. Plataformas: `macos-arm64`, `linux-x86_64`, `windows-x86_64` (`.exe`,
  `.dll`; sem `wcon` e `wremoto`, que rodam pelo WSL).
- `sdk/`: um SDK por linguagem; `sdk/README.md` diz como compilar cada um; `bash sdk/prova.sh` prova todos.
- `docs/JSONW.md`: referência completa de tipos, esquema, ferramenta, garantias e segurança.
- `servidores-web/`: Apache e nginx prontos para o `wjsw-cgi`.

## Regras que evitam 90% dos erros
1. **Comece pelo esquema.** Uma linha, `nome:tipo` separados por vírgula: `id:i64,nome:texto?,preco:dinheiro`.
   `?` aceita nulo. Um nome nunca muda de tipo; campo novo entra com nulo.
2. **Use o tipo de negócio certo, não `texto` nem `f64` para tudo:**
   - dinheiro → `dinheiro` (valor com moeda ISO 4217: `"12,50 BRL"`, `"8.90 USD"`); nunca `f64`;
   - valor exato sem moeda → `decimal[2]` (a escala entre colchetes);
   - peso, volume, energia, distância, carbono → `medida[unidade]` (`medida[kg]`, `medida[kWh]`, `medida[tCO2e]`);
     a entrada pode vir em outra unidade da mesma grandeza e é convertida ao gravar; outra grandeza é recusada;
   - CNPJ, CPF, chave, placa, SKU, CEP → `codigo` (bytes exatos; o zero da frente nunca some); nunca `i64`;
   - data e hora → `tempo` (microssegundos UTC);
   - texto que se repete muito (cidade, status, categoria) → `dic`;
   - embedding → `vf16[n]` ou `vq8[n]` (n = dimensão; o cosseno do `avaliar` aceita `vf32`, `vf16`, `vq8` e `vq4`); vetor esparso → `mapa<i64,f32>`.
3. **Marque as permissões no esquema, não no código:** `cpf:codigo?+pessoal`, `margem:decimal[2]+escopo(financeiro)`, e uma
   coluna `tenant:i64` (ou `tenant_id:i64`) em dados de vários clientes. Sem o escopo, a coluna sai nula; sem o tenant, a linha
   some. O tenant é sempre um número inteiro: uma coluna `tenant` de texto não separa nada e fecha a visão (nada sai).
4. **Números:** a entrada aceita vírgula ou ponto (`1.234,56` e `1,234.56`). A saída canônica usa ponto. Em `qualquer`, a
   vírgula decimal só vale com o sufixo `d` colado (`12,50d`).
5. **O arquivo só anexa.** Para editar, grave de novo a mesma chave; para excluir, grave a chave com `_apagado: true`;
   para enxugar, compacte. Nunca reescreva o `.jsw` por fora.
6. **Confira depois de gravar:** `wjsw conferir arq.jsw` deve responder `ok: N linhas, B blocos, sha256 e crc32c conferidos`.
7. **Nunca leia o binário do `.jsw` à mão** nem tente decodificar o leiaute: use `wjsw` ou um SDK. O leiaute é interno e
   muda entre versões; a ABI e os SDKs são estáveis.

## Ferramenta `wjsw` (comandos e saídas reais)
```bash
wjsw de-texto "id:i64,produto:texto,preco:dinheiro,peso:medida[g],sku:codigo" vendas.jsonl vendas.jsw   # JSONL -> .jsw (--max: compressão máxima)
wjsw ver vendas.jsw                 # {id:1,produto:"Café especial",preco:12.50 BRL,peso:250 g,sku:"CAF-0250"}  (as 20 primeiras linhas; `ver arq 100 50` = 50 a partir da 100)
wjsw ver vendas.jsw --json          # o mesmo em JSON estrito
wjsw info vendas.jsw                # esquema, blocos, tamanho, hash, zonas
wjsw conferir vendas.jsw            # ok: 2 linhas, 1 blocos, sha256 e crc32c conferidos
wjsw para-texto vendas.jsw --json   # exporta tudo para JSON, sem perda (o arquivo vem antes da opção)
wjsw filtrar vendas.jsw "peso > 500; preco < 10 BRL" [saida.jsw]   # medida compara pela grandeza (500 = 500 g; vale "0,5 kg"); dinheiro pede a moeda
wjsw calcular vendas.jsw [--onde "..."] [--por campo] [--valor campo]   # contagem, soma exata, mín, máx, média
wjsw comparar ontem.jsw hoje.jsw sku                 # só em a, só em b, mudou, iguais
wjsw avaliar docs.jsw pesos "preco=-1,nota=2" 10     # as 10 melhores por nota
wjsw avaliar docs.jsw cosseno vet "0.5,-1,2,0.25" 5  # busca por significado na coluna vet
wjsw avaliar docs.jsw '{"pesos":{"preco":-1}}' 3 --json
wjsw escolher vendas.jsw preco 10                    # as 10 maiores de uma coluna
wjsw reconhecer termos.jsw "texto a classificar" --json
wjsw reparar vendas.jsw                              # gravação cortada: refaz o fim
WJSW_ESCOPOS="pessoal financeiro tenant:42" wjsw ver clinica.jsw   # ver com permissões
```
A tabela de termos do `reconhecer` tem o esquema `termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic`.

## SDKs (nomes em português, iguais em todas as linguagens)
- `Leitor(caminho)`: `linhas`, `esquema`, `campos`, `json(i)`, `texto(i)`, `campo(i, nome_ou_indice)`, `conferir()`,
  `avaliar(pedido_json, k)`, `fechar()`.
- `Escritor(caminho, esquema[, compressao 0..2, hash 0=sha256/1=blake3, bloco_kb])`: `gravar(obj)`, `gravarTexto(texto)`,
  `descarregar()`, `fechar()` (troca atômica: o arquivo só aparece completo) e `abandonar()` (desiste: nada é publicado e o
  destino fica como estava). Só o `fechar()` publica; saiu por erro no meio, chame `abandonar()`.
- A biblioteca é achada por `JSONW_LIB` (caminho do arquivo), na pasta `sdk` ou em `bin/<plataforma>/`. Usar um leitor
  depois de fechado devolve erro.
- `Reconhecedor(termos.jsw).reconhecer(texto)`; `escolher(notas, k)`.
- Python, Node e PHP aceitam objeto/dicionário em `gravar`; Rust e C recebem a linha como texto JSON.
- Node pelo npm: `npm install @wortictecnologia/jsonw` (addon pré-compilado para macOS arm64 e Linux x64, e o comando
  `jsonw`, que é o `wjsw`). Use `require("@wortictecnologia/jsonw")`.

## Bancos de dados (`wcon` e `wremoto`, macOS e Linux)
Para levar dados de um banco ao jsonW e de volta, use o `wcon`; **não escreva o esquema à mão**: ele sai do tipo de cada
coluna. Não exporte para CSV ou JSON no meio do caminho (perde tipo, zero à esquerda e precisão).
```bash
WSQL_URL=postgresql://papel@host:5432/banco wcon pg "select * from vendas where data > now() - interval '30 days'" vendas.jsw
wcon pg-gravar vendas.jsw public.vendas                       # volta: colunas pelo nome, uma transação
wcon sqlite app.db "select * from clientes" clientes.jsw      # e: wcon sqlite-gravar clientes.jsw app.db clientes
WMYSQL_CRED=~/.cred/mysql wcon mysql 127.0.0.1:3306/loja "select * from pedidos" pedidos.jsw
WREDIS_CRED=~/.cred/redis wcon redis 127.0.0.1:6379 "sessao:*" sessoes.jsw
WMONGO_CRED=~/.cred/mongo wcon mongo 127.0.0.1:27017/loja produtos '{"ativo":true}' produtos.jsw
wjsw de-json eventos.jsonl eventos.jsw                         # JSON/JSONL com o esquema inferido
wremoto filtrar https://exemplo.com/dados/vendas.jsw "preco > 100"   # só os blocos que passam são baixados
```
- Credencial sempre em **arquivo** (`usuario:senha`; no Redis só a senha; no R2/S3 `chave:segredo`); a senha do Postgres
  vai em `PGPASSWORD` ou `~/.pgpass`. Nunca ponha senha na linha de comando nem na URL.
- No Postgres, `timestamptz`, `timestamp` e `date` viram `tempo` e voltam iguais; no MySQL e no SQLite, data e datetime
  sem fuso ficam texto de propósito. `numeric` vira `decimal` exato.
- MySQL 8: por enquanto só com `mysql_native_password`. No Windows, rode o `wcon` pelo WSL.

## Servidores web
Todo pedido de `.jsw` passa pelo `bin/<plataforma>/wjsw-cgi` (o servidor nunca entrega o arquivo sozinho): arquivo sem coluna
marcada e sem tenant sai puro (Range 206 + CORS); o resto sai só com o que a sessão pode ver. Configure
com `servidores-web/apache-jsonw.conf` ou `nginx-jsonw.conf`. Parâmetros: `?formato=json|ndjson`, `?onde=`, `?campos=`,
`?limite=`. O escopo vem do servidor depois de autenticar (`JSONW_ESCOPO`), **nunca de um cabeçalho do cliente**.

## Armadilhas conhecidas
- `para-texto` exporta tudo (é a cópia de quem já tem o arquivo); `ver` aplica a visão. Para mostrar dados a um usuário,
  use `ver`, o `wjsw-cgi` ou o SDK com a visão, nunca o `para-texto`.
- Um real inteiro sai no JSON como `12.0` (nunca `12`), para quem lê com tipo receber real.
- `comparar` compara pelo valor: `-0 == 0`, `3 == 3.0`, `1.50 == 1.500`.
- Na primeira execução, o `wjsw` avisa versão e plataforma uma vez (`JSONW_SEM_PING=1` desliga). Biblioteca e SDKs nunca
  acessam a rede.
- Licença: uso livre dentro de produtos; não ofereça o jsonW em si como serviço e não faça engenharia reversa do núcleo.

---

## English summary for agents
jsonW = one data model, three lossless forms (row, column `.jsw`, text; every JSON is valid jsonW-text). Use `wjsw` or a
SDK, never parse `.jsw` bytes. Schema: `name:type` comma-separated; Portuguese keywords: `texto` (text), `dinheiro` (money
with ISO currency), `decimal[2]`, `medida[kg]` (unit-aware measure), `codigo` (exact code: IDs, SKUs), `tempo` (time),
`dic` (dictionary text), `vf16[n]`/`vq8[n]` (vectors), `qualquer` (open JSON); `?` nullable. Permissions in schema:
`+pessoal`, `+escopo(x)`, `tenant` column. Commands: `de-texto` (import), `ver` (view), `conferir` (verify),
`para-texto --json` (export), `filtrar` (filter), `calcular` (aggregate), `comparar` (diff), `avaliar`/`escolher`/
`reconhecer` (score, top-k, classify). SDK classes: `Leitor` (reader), `Escritor` (writer), `Reconhecedor` (classifier).
Append-only: rewrite a key to edit, `_apagado: true` to delete.
