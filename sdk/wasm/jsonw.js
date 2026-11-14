// jsonW em WebAssembly: o mesmo núcleo em C, no navegador, no React Native, no Deno, no Bun e em funções de borda.
//   const jsonw = await carregar();                              // ou carregar(bytesDoWasm) quando não há fetch
//   using a = jsonw.abrir(new Uint8Array(await (await fetch("/dados.jsw")).arrayBuffer()));
//   for (const linha of a) console.log(linha);

const ENOSYS = 52;
const EBADF = 8;

/** Erro de uma linha de outro tenant, escondida por `visao()`. */
export class LinhaOculta extends Error {
  constructor() {
    super("linha oculta pela visao");
    this.name = "LinhaOculta";
    this.code = "OCULTA";
  }
}

export class ErroJsonW extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = "ErroJsonW";
  }
}

export const ehOculta = (e) => e instanceof LinhaOculta;

/** As 14 chamadas de sistema que o módulo importa; o leitor não usa arquivo, rede nem ambiente. */
function sistema(memoria) {
  const visao = () => new DataView(memoria().buffer);
  const semArquivo = () => EBADF;
  return {
    environ_get: () => 0,
    environ_sizes_get: (pn, ptam) => {
      visao().setUint32(pn, 0, true);
      visao().setUint32(ptam, 0, true);
      return 0;
    },
    clock_time_get: (_relogio, _precisao, pt) => {
      visao().setBigUint64(pt, BigInt(Date.now()) * 1_000_000n, true);
      return 0;
    },
    fd_write: (fd, iovs, n, pescrito) => {
      const v = visao();
      let total = 0;
      let texto = "";
      for (let i = 0; i < n; i++) {
        const p = v.getUint32(iovs + i * 8, true);
        const tam = v.getUint32(iovs + i * 8 + 4, true);
        texto += new TextDecoder().decode(new Uint8Array(memoria().buffer, p, tam));
        total += tam;
      }
      if (fd === 2 && texto.trim()) console.error(`jsonw: ${texto.trimEnd()}`);
      v.setUint32(pescrito, total, true);
      return 0;
    },
    fd_close: semArquivo,
    fd_fdstat_get: semArquivo,
    fd_filestat_get: semArquivo,
    fd_pread: semArquivo,
    fd_prestat_get: semArquivo,
    fd_prestat_dir_name: semArquivo,
    fd_seek: semArquivo,
    path_open: () => ENOSYS,
    proc_exit: (codigo) => {
      throw new ErroJsonW(`o modulo terminou com o codigo ${codigo}`);
    },
    sched_yield: () => 0,
  };
}

/**
 * Carrega o módulo. Sem argumento, busca `jsonw.wasm` ao lado deste arquivo (navegador, Deno, Bun, Node 22+).
 * No React Native (Hermes não traz WebAssembly), passe os bytes do .wasm e um WebAssembly em JS:
 *   import { WebAssembly } from "polywasm";
 *   const jsonw = await carregar(bytesDoWasm, { WebAssembly });
 */
export async function carregar(wasm, { WebAssembly: wa = globalThis.WebAssembly } = {}) {
  if (!wa) throw new ErroJsonW("este ambiente nao tem WebAssembly: passe um em carregar(wasm, { WebAssembly })");
  let memoria;
  const importacoes = { wasi_snapshot_preview1: sistema(() => memoria) };
  const fonte = wasm ?? (await buscarAoLado());
  const { instance } = fonte instanceof wa.Module
    ? { instance: await wa.instantiate(fonte, importacoes) }
    : await wa.instantiate(fonte, importacoes);
  const x = instance.exports;
  memoria = x.memory;
  x._initialize();
  return new JsonW(x);
}

async function buscarAoLado() {
  const r = await fetch(new URL("./jsonw.wasm", import.meta.url));
  if (!r.ok) throw new ErroJsonW(`jsonw.wasm nao carregou (${r.status})`);
  return r.arrayBuffer();
}

const codificador = new TextEncoder();
const decodificador = new TextDecoder();

class JsonW {
  #x;

  constructor(exportacoes) {
    this.#x = exportacoes;
  }

  get versao() {
    return this.#lerC(this.#x.jsonw_versao());
  }

  /** Abre um .jsw a partir dos bytes (Uint8Array ou ArrayBuffer). O leitor guarda a própria cópia. */
  abrir(bytes) {
    const dados = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    return this.#comBuffer(dados.length, (p) => {
      new Uint8Array(this.#x.memory.buffer, p, dados.length).set(dados);
      return this.#comErro((e, ne) => this.#x.jsonw_abrir_memoria(p, dados.length, e, ne), (h, erro) => {
        if (!h) throw new ErroJsonW(erro());
        return new Leitor(this, h);
      });
    });
  }

  /** As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior). */
  escolher(notas, k) {
    const n = notas.length;
    return this.#comBuffer(Math.max(n, 1) * 8, (pv) => {
      new Float64Array(this.#x.memory.buffer, pv, n).set(notas);
      return this.#comBuffer(Math.max(k, 1) * 8, (po) => {
        const m = Number(this.#x.jsonw_escolher(pv, n, k, po));
        return Array.from(new BigUint64Array(this.#x.memory.buffer, po, Math.max(m, 0)), Number);
      });
    });
  }

  // --- uso interno dos leitores ---

  chamar(nome, ...args) {
    return this.#x[nome](...args);
  }

  get memoria() {
    return this.#x.memory.buffer;
  }

  lerC(p) {
    return this.#lerC(p);
  }

  /** Buffer de saída que cresce até caber (-2 = curto); -3 = linha oculta. */
  texto(chamada) {
    for (let cap = 1 << 16; ; cap *= 4) {
      const r = this.#comBuffer(cap, (p) => {
        const n = Number(chamada(p, cap));
        if (n >= 0) return decodificador.decode(new Uint8Array(this.#x.memory.buffer, p, n));
        if (n === -3) throw new LinhaOculta();
        if (n === -2) return null;
        throw new ErroJsonW("linha ou campo ilegivel");
      });
      if (r !== null) return r;
    }
  }

  /** Texto JS em memória do módulo (sem o zero do fim no tamanho). */
  comTexto(texto, uso) {
    const b = codificador.encode(texto);
    return this.#comBuffer(b.length + 1, (p) => {
      const m = new Uint8Array(this.#x.memory.buffer, p, b.length + 1);
      m.set(b);
      m[b.length] = 0;
      return uso(p, b.length);
    });
  }

  comErro(chamada, uso) {
    return this.#comErro(chamada, uso);
  }

  comBuffer(n, uso) {
    return this.#comBuffer(n, uso);
  }

  #comBuffer(n, uso) {
    const p = this.#x.malloc(n);
    if (!p) throw new ErroJsonW("sem memoria");
    try {
      return uso(p);
    } finally {
      this.#x.free(p);
    }
  }

  #comErro(chamada, uso) {
    return this.#comBuffer(320, (e) => {
      new Uint8Array(this.#x.memory.buffer, e, 1)[0] = 0;
      const r = chamada(e, 320);
      return uso(r, () => this.#lerC(e));
    });
  }

  #lerC(p) {
    if (!p) return "";
    const m = new Uint8Array(this.#x.memory.buffer);
    let fim = p;
    while (m[fim]) fim++;
    return decodificador.decode(m.subarray(p, fim));
  }
}

export class Leitor {
  #j;
  #h;
  linhas = 0;
  esquema = "";
  campos = [];

  constructor(j, h) {
    this.#j = j;
    this.#h = h;
    this.linhas = Number(j.chamar("jsonw_linhas", h));
    this.#lerEsquema();
  }

  #lerEsquema() {
    this.esquema = this.#j.lerC(this.#j.chamar("jsonw_esquema", this.#h));
    const n = this.#j.chamar("jsonw_campos", this.#h);
    this.campos = Array.from({ length: n }, (_, i) => this.#j.lerC(this.#j.chamar("jsonw_campo_nome", this.#h, i)));
  }

  #vivo() {
    if (!this.#h) throw new ErroJsonW("leitor fechado");
    return this.#h;
  }

  indice(campo) {
    if (typeof campo === "number") return campo;
    const k = this.campos.indexOf(campo);
    if (k < 0) throw new RangeError(`jsonw: campo inexistente: ${campo}`);
    return k;
  }

  json(i) {
    const h = this.#vivo();
    return this.#j.texto((p, cap) => this.#j.chamar("jsonw_linha_json", h, BigInt(i), p, cap));
  }

  texto(i) {
    const h = this.#vivo();
    return this.#j.texto((p, cap) => this.#j.chamar("jsonw_linha_texto", h, BigInt(i), p, cap));
  }

  linha(i) {
    return JSON.parse(this.json(i));
  }

  campo(i, campo) {
    const h = this.#vivo();
    const k = this.indice(campo);
    return JSON.parse(this.#j.texto((p, cap) => this.#j.chamar("jsonw_campo_json", h, BigInt(i), k, p, cap)));
  }

  conferir() {
    const h = this.#vivo();
    return this.#j.comErro((e, ne) => this.#j.chamar("jsonw_conferir", h, e, ne), (r, erro) => {
      if (r !== 0) throw new ErroJsonW(erro());
      return true;
    });
  }

  /** Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant lança LinhaOculta. */
  visao(escopos) {
    const h = this.#vivo();
    this.#j.comTexto(escopos, (pe) =>
      this.#j.comErro((e, ne) => this.#j.chamar("jsonw_visao", h, pe, e, ne), (r, erro) => {
        if (r !== 0) throw new ErroJsonW(erro());
      }),
    );
    this.#lerEsquema();
    return this;
  }

  indexar(campo) {
    if (this.#j.chamar("jsonw_indexar", this.#vivo(), this.indice(campo)) !== 0) throw new ErroJsonW("campo sem indice");
    return this;
  }

  temIndice(campo) {
    return this.#j.chamar("jsonw_tem_indice", this.#vivo(), this.indice(campo)) === 1;
  }

  /** As linhas em que o campo vale `valor` (7, "RJ", null), em ordem crescente. */
  chave(campo, valor) {
    const h = this.#vivo();
    const k = this.indice(campo);
    return this.#j.comTexto(JSON.stringify(valor), (pv, nv) => {
      for (let cap = 16; ; ) {
        const r = this.#j.comBuffer(cap * 8, (po) => {
          const n = Number(this.#j.chamar("jsonw_chave", h, k, pv, nv, po, cap));
          if (n === -2) throw new ErroJsonW("valor nao e do tipo do campo");
          if (n < 0) throw new ErroJsonW("campo invalido");
          if (n > cap) return n;
          return Array.from(new BigUint64Array(this.#j.memoria, po, n), Number);
        });
        if (Array.isArray(r)) return r;
        cap = r;
      }
    });
  }

  avaliarJson(pedido, k = 10) {
    const h = this.#vivo();
    const texto = typeof pedido === "string" ? pedido : JSON.stringify(pedido);
    return this.#j.comTexto(texto, (pp, np) =>
      this.#j.comBuffer(320, (pe) => {
        new Uint8Array(this.#j.memoria, pe, 1)[0] = 0;
        return this.#j.texto((p, cap) => {
          const n = Number(this.#j.chamar("jsonw_avaliar", h, pp, np, k, p, cap, pe, 320));
          if (n === -1) throw new ErroJsonW(this.#j.lerC(pe));
          return n;
        });
      }),
    );
  }

  /** As k melhores linhas: [{ linha, nota }], da maior nota para a menor. */
  avaliar(pedido, k = 10) {
    return JSON.parse(this.avaliarJson(pedido, k));
  }

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
    if (this.#h) {
      this.#j.chamar("jsonw_fechar", this.#h);
      this.#h = 0;
    }
  }

  [Symbol.dispose]() {
    this.fechar();
  }
}
