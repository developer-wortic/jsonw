// jsonW para Node.js 22+: Leitor e Escritor por cima do addon N-API (jsonw.node).
//   using a = new Leitor("dados.jsw"); for (const linha of a) { ... }
//   using w = new Escritor("novo.jsw", "id:i64,nome:texto"); w.gravar({ id: 1, nome: "x" }); w.fechar();
// `using` é do Node 24+; no Node 22, chame fechar() no fim.
import { createRequire } from "node:module";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const plataforma = `${process.platform}-${process.arch}`;

const nat = (() => {
  const dir = import.meta.dirname;
  for (const c of [join(dir, "prebuilt", plataforma, "jsonw.node"), join(dir, "jsonw.node"), join(dir, "..", "jsonw.node")]) {
    try {
      return require(c);
    } catch (e) {
      if (e.code !== "MODULE_NOT_FOUND") throw e;
    }
  }
  throw new Error(`jsonw: sem addon para ${plataforma}; compile com \`make node\` na pasta sdk`);
})();

export const versao = nat.versao();

/** Linha de outro tenant depois de visao(). */
export const ehOculta = (e) => e?.code === "OCULTA";

export class Leitor {
  #a;
  linhas;
  esquema = "";
  campos = [];

  constructor(caminho) {
    this.#a = nat.abrir(caminho);
    this.linhas = nat.linhas(this.#a);
    this.#lerEsquema();
  }

  #lerEsquema() {
    this.esquema = nat.esquema(this.#a);
    this.campos = nat.campos(this.#a);
  }

  indice(campo) {
    if (typeof campo === "number") return campo;
    const k = this.campos.indexOf(campo);
    if (k < 0) throw new RangeError(`jsonw: campo inexistente: ${campo}`);
    return k;
  }

  json(i) { return nat.linhaJson(this.#a, i); }
  texto(i) { return nat.linhaTexto(this.#a, i); }
  linha(i) { return JSON.parse(this.json(i)); }
  campo(i, campo) { return JSON.parse(nat.campoJson(this.#a, i, this.indice(campo))); }
  conferir() { return nat.conferir(this.#a); }

  indexar(campo) {
    nat.indexar(this.#a, this.indice(campo));
    return this;
  }

  temIndice(campo) { return nat.temIndice(this.#a, this.indice(campo)); }

  /** As linhas em que o campo vale `valor` (7, "RJ", null), em ordem crescente. */
  chave(campo, valor) { return nat.chave(this.#a, this.indice(campo), JSON.stringify(valor)); }

  /** Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant lança erro com code "OCULTA". */
  visao(escopos) {
    nat.visao(this.#a, escopos);
    this.#lerEsquema();
    return this;
  }

  avaliarJson(pedido, k = 10) {
    return nat.avaliar(this.#a, typeof pedido === "string" ? pedido : JSON.stringify(pedido), k);
  }

  /** As k melhores linhas: [{ linha, nota }], da maior nota para a menor. */
  avaliar(pedido, k = 10) { return JSON.parse(this.avaliarJson(pedido, k)); }

  /** Com visão, as linhas de outro tenant ficam de fora. */
  *[Symbol.iterator]() {
    for (let i = 0; i < this.linhas; i++) {
      try {
        yield this.linha(i);
      } catch (e) {
        if (!ehOculta(e)) throw e;
      }
    }
  }

  fechar() {
    if (this.#a) {
      nat.fechar(this.#a);
      this.#a = null;
    }
  }

  [Symbol.dispose]() { this.fechar(); }
}

/** Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais achados no texto. */
export class Reconhecedor {
  #r;

  constructor(caminho) { this.#r = nat.reconhecedor(caminho); }

  reconhecerJson(texto) { return nat.reconhecer(this.#r, texto); }
  reconhecer(texto) { return JSON.parse(this.reconhecerJson(texto)); }

  fechar() {
    if (this.#r) {
      nat.reconhecedorFechar(this.#r);
      this.#r = null;
    }
  }

  [Symbol.dispose]() { this.fechar(); }
}

/** As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior). */
export const escolher = (notas, k) => nat.escolher(notas, k);

/** O destino só aparece no fechar(); saindo do bloco `using` sem fechar, abandona e o destino fica como estava. */
export class Escritor {
  #w;

  constructor(caminho, esquema, { compressao = 1, hash = 0, blocoKb = 0 } = {}) {
    this.#w = nat.criar(caminho, esquema, compressao, hash, blocoKb);
  }

  gravarTexto(texto) { nat.gravar(this.#w, texto); }
  gravar(obj) { this.gravarTexto(JSON.stringify(obj)); }
  descarregar() { nat.descarregar(this.#w); }

  fechar() {
    if (this.#w) {
      const w = this.#w;
      this.#w = null;
      nat.fecharEscritor(w);
    }
  }

  abandonar() {
    if (this.#w) {
      const w = this.#w;
      this.#w = null;
      nat.abandonar(w);
    }
  }

  [Symbol.dispose]() { this.abandonar(); }
}

/** Roda `uso(recurso)` e fecha o recurso no fim, com ou sem erro (o `using` do Node 24, no Node 22). */
const com = (recurso, uso) => {
  try {
    return uso(recurso);
  } finally {
    recurso.fechar();
  }
};

// node index.js arq.jsw -> JSONL; --avaliar arq pedido k; --visao arq escopos pedido k; --reconhecer termos.jsw texto
if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv[2]) {
  const [modo, ...resto] = process.argv.slice(2);
  const saida = (s) => process.stdout.write(`${s}\n`);
  switch (modo) {
    case "--avaliar": {
      const [arq, pedido, k] = resto;
      com(new Leitor(arq), (a) => saida(a.avaliarJson(pedido, Number(k))));
      break;
    }
    case "--visao": {
      const [arq, escopos, pedido, k] = resto;
      com(new Leitor(arq).visao(escopos), (a) => {
        saida(a.campos.join(","));
        for (let i = 0; i < a.linhas; i++) {
          try {
            saida(a.json(i));
          } catch (e) {
            if (!ehOculta(e)) throw e;
          }
        }
        saida(a.avaliarJson(pedido, Number(k)));
      });
      break;
    }
    case "--reconhecer": {
      const [termos, texto] = resto;
      com(new Reconhecedor(termos), (r) => saida(r.reconhecerJson(texto)));
      break;
    }
    default:
      com(new Leitor(modo), (a) => {
        for (let i = 0; i < a.linhas; i++) saida(a.json(i));
      });
  }
}
