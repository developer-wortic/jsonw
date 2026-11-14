// node wasm/prova.mjs dados.jsw visao.jsw: o leitor em WebAssembly (sem o WASI do Node, como no navegador) contra o addon
// nativo, no mesmo arquivo. Sai 1 na primeira diferença.
import { readFileSync } from "node:fs";
import { Leitor as Nativo } from "../node/index.js";
import { carregar } from "./jsonw-node.js";

const [arquivo, comVisao] = process.argv.slice(2);
const falhar = (o) => {
  console.error(`  FALHOU wasm: ${o}`);
  process.exit(1);
};

const j = await carregar();
const a = j.abrir(readFileSync(arquivo));
const n = new Nativo(arquivo);

if (a.esquema !== n.esquema) falhar("esquema");
for (let i = 0; i < a.linhas; i++) {
  if (a.json(i) !== n.json(i) || a.texto(i) !== n.texto(i)) falhar(`linha ${i}`);
}
a.conferir();
const pedido = { pesos: { id: 1 } };
if (a.avaliarJson(pedido, 2) !== n.avaliarJson(pedido, 2)) falhar("avaliar");
a.indexar("id");
n.indexar("id");
if (JSON.stringify(a.chave("id", 1)) !== JSON.stringify(n.chave("id", 1))) falhar("chave");
if (JSON.stringify(j.escolher([0.2, 0.9, 0.5], 2)) !== "[1,2]") falhar("escolher");

let recusou = false;
try {
  j.abrir(new Uint8Array([1, 2, 3]));
} catch {
  recusou = true;
}
if (!recusou) falhar("abriu bytes que não são jsonW");

const v = j.abrir(readFileSync(comVisao)).visao("tenant:1");
const nv = new Nativo(comVisao).visao("tenant:1");
if (JSON.stringify([...v]) !== JSON.stringify([...nv]) || v.campos.join() !== nv.campos.join()) falhar("visão");

a.fechar();
let fechado = false;
try {
  a.json(0);
} catch {
  fechado = true;
}
if (!fechado) falhar("leitor fechado respondeu");

console.log(
  `  ok   wasm ${j.versao}: ${a.linhas} linhas, esquema, custódia, avaliar, chave, escolher e visão iguais ao nativo; ` +
    "bytes inválidos e leitor fechado recusados",
);
