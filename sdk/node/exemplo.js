// node exemplo.js dados.jsw id 2 (Node 24+, pelo `using`): as linhas em que o campo vale o valor (JSON), pelo índice; --varrer para sem índice.
import { Leitor } from "./index.js";

const [arquivo, campo, texto, modo] = process.argv.slice(2);
using a = new Leitor(arquivo);
if (!a.campos.includes(campo)) {
  console.error(`campo ${campo} não existe`);
  process.exit(1);
}
if (modo !== "--varrer") a.indexar(campo);
for (const i of a.chave(campo, JSON.parse(texto))) process.stdout.write(`${a.json(i)}\n`);
