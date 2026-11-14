// exemplo.js: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// node exemplo.js dados.jsw id 2
const { Leitor } = require("./index.js");
const [arquivo, campo, texto, modo] = process.argv.slice(2);
const a = new Leitor(arquivo);
if (!a.campos.includes(campo)) { console.error(`campo ${campo} não existe`); process.exit(1); }
if (modo !== "--varrer") a.indexar(campo);
for (const i of a.chave(campo, JSON.parse(texto))) process.stdout.write(a.json(i) + "\n");
a.fechar();
