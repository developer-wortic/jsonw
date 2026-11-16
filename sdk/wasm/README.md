# jsonW em WebAssembly

O mesmo núcleo em C, compilado para WebAssembly (221 KB): lê `.jsw` no navegador, no React Native, no Deno, no Bun e em
funções de borda, sem servidor. A API é a do SDK de Node, com uma diferença: `abrir()` recebe os bytes do arquivo, não
um caminho.

```ts
import { carregar } from "@wortictecnologia/jsonw/wasm";

const jsonw = await carregar();
using vendas = jsonw.abrir(await (await fetch("/vendas.jsw")).arrayBuffer());

vendas.conferir();
for (const venda of vendas) console.log(venda);
vendas.indexar("cliente").chave("cliente", 42);
vendas.avaliar({ pesos: { valor: 1 } }, 10);
```

## React Native

O Hermes não traz WebAssembly. Passe os bytes do `.wasm` e o WebAssembly do `polywasm`:

```ts
import { WebAssembly } from "polywasm";
import { carregar } from "@wortictecnologia/jsonw/wasm";

const jsonw = await carregar(bytesDoWasm, { WebAssembly });
```

`bytesDoWasm` é o `jsonw.wasm` do pacote, carregado como asset (`@wortictecnologia/jsonw/wasm/jsonw.wasm`).

## Onde foi provado

| Ambiente | Prova |
|---|---|
| Node 22 e 26 | `node prova.mjs dados.jsw visao.jsw`: mesmas linhas, esquema, custódia, avaliar, chave, escolher e visão que o addon nativo |
| Chrome 157 | `prova-navegador.html` servido por HTTP |
| Hermes do React Native 0.88 (`hermes-v260318099.0.5`) | o mesmo pacote, empacotado como o Metro faz |

## Limites

- Só leitura: gravar `.jsw` continua no servidor (SDKs nativos).
- No React Native, o `polywasm` interpreta o WebAssembly em JavaScript: serve para arquivos de até alguns MB no aparelho.
