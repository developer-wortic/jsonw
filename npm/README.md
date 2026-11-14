<p align="center">
  <a href="https://jsonw.org"><img alt="jsonW: JSON wasn't made for AI. jsonW was." src="https://raw.githubusercontent.com/developer-wortic/jsonw/main/assets/banner-claro-en.svg" width="100%"></a>
</p>

# jsonW for Node.js and TypeScript

**jsonW is a data format for the AI era: one file that is at once JSON-compatible text, a columnar store like Parquet, a
vector index for semantic search and a permission layer.** Money with its currency, exact decimals, units of measure,
byte-exact codes and embeddings are real types; top-k search, key lookup, row-level multi-tenant permissions and
tamper-evident custody live inside the format. Zero-dependency C core by [Wortic](https://wortic.com.br), prebuilt for
Node.js, TypeScript types included.

```text
6.6×     smaller than uncompressed JSONL
2,310×   faster to read a whole column
0.196 ms key lookup in a 1-million-row file
0        dependencies
```

Measured on 2026-11-13 and 14 with 1.3.11 and 1.3.13 (100k synthetic records, median of 10 runs, vs. JSONL read by our own
JSON reader; key lookup: median of 200 by `id`, macOS arm64). Methodology and limitations, including where jsonW loses, in
the [paper](https://jsonw.org/paper/en).

## Install

```bash
npm install @wortictecnologia/jsonw
```

Prebuilt for **macOS arm64** and **Linux x64** (glibc 2.34+: Ubuntu 22.04+, Debian 12+, RHEL 9+); nothing to compile. The
`jsonw` command also ships for **Windows x64**. Works with `import` and `require`, in Next.js, Remix, Astro, Nuxt, SvelteKit,
NestJS, Express and any Node.js 18+ server.

## Use

```ts
import { Escritor, Leitor } from "@wortictecnologia/jsonw";   // Escritor = writer, Leitor = reader

const w = new Escritor("sales.jsw", "id:i64,product:texto,price:dinheiro,weight:medida[g],sku:codigo");
w.gravar({ id: 1, product: "Coffee", price: "12.50 USD", weight: "250 g", sku: "CAF-0250" });
w.gravar({ id: 2, product: "Cheese bread", price: "8.90 USD", weight: "1 kg", sku: "PDQ-1000" });
w.fechar();                                      // atomic: the file only appears complete

const r = new Leitor("sales.jsw");
r.campo(1, "weight");                            // "1000 g": converted on write, the column is medida[g]
for (const row of r) console.log(row);
r.conferir();                                    // verifies the custody chain (crc32c + SHA-256)
r.avaliar({ pesos: { price: -1 } }, 1);          // top-k by score: [{ linha, nota }]
r.indexar("sku").chave("sku", "PDQ-1000");       // [1]: binary search, no scan
r.fechar();
```

### Semantic search for RAG, without a vector database

```ts
const docs = new Leitor("chunks.jsw");           // schema: id:i64,texto:texto,v:vf16[768]
const top = docs.avaliar({ cosseno: { campo: "v", consulta: queryEmbedding } }, 5);
const context = top.map(({ linha }) => docs.campo(linha, "texto"));
```

### Permissions for multi-tenant apps

Mark columns in the schema (`cpf:codigo?+pessoal`, `margin:decimal[2]+escopo(finance)`) and add an integer `tenant` column.
A reader only sees what its scopes allow, so React, Vue or Svelte components receive only permitted rows from your server
route:

```ts
const view = new Leitor("clinic.jsw").visao("tenant:42");   // other tenants vanish, restricted columns come out null
```

## Command line

```bash
npx -p @wortictecnologia/jsonw jsonw de-json events.jsonl events.jsw     # JSON/JSONL to .jsw, schema inferred
npx -p @wortictecnologia/jsonw jsonw ver events.jsw                      # rows as jsonW-text, with the permission view
npx -p @wortictecnologia/jsonw jsonw filtrar events.jsw "qty > 10"       # zones skip whole blocks
npx -p @wortictecnologia/jsonw jsonw conferir events.jsw                 # custody check
npx -p @wortictecnologia/jsonw jsonw medir                               # write and read speed on your machine
```

On first run the `jsonw` command reports only its version and platform once (`JSONW_SEM_PING=1` turns it off). The Node.js
library itself never touches the network.

## FAQ

**Is jsonW a JSON replacement?** For storage, analytics and AI data, yes; every valid JSON is valid jsonW-text, and
`jsonw para-texto file.jsw --json` gives strict JSON back.

**jsonW or Parquet?** jsonW when you need money, units, exact codes, semantic search, per-customer permissions or custody in
the file. Parquet still reads faster on many cores for some scans; the numbers are in the [paper](https://jsonw.org/paper/en).

**Does it run in the browser or React Native?** The reader runs on the server, next to the data and the credentials, so hidden
columns never reach the client. Send the permitted rows to your components.

## More

- [Full README](https://github.com/developer-wortic/jsonw#readme): the 19 features, types, permissions, database connectors
  (PostgreSQL, MySQL, MariaDB, SQLite, Redis, MongoDB), S3 and R2 remote reads, web servers and SDKs for 11 languages
- [AGENTS.md](https://github.com/developer-wortic/jsonw/blob/main/AGENTS.md): exact rules for AI coding agents
- [jsonw.org](https://jsonw.org) · [Paper](https://jsonw.org/paper/en) · [Português](https://github.com/developer-wortic/jsonw/blob/main/README.pt-BR.md)

License: [Sustainable Use License](https://github.com/developer-wortic/jsonw/blob/main/LICENCA.md). Free to use inside your
products; not for reselling jsonW itself as a service.
