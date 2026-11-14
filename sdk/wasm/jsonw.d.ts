export type Valor = string | number | boolean | null | Valor[] | { [campo: string]: Valor };
export type Linha = Record<string, Valor>;
export interface Nota {
  readonly linha: number;
  readonly nota: number;
}
/** Pedido de nota em JSON: {"pesos":..}, {"cosseno":..}, {"esparso":..} ou {"grade":..}. */
export type Pedido = string | Readonly<Record<string, unknown>>;

export declare class ErroJsonW extends Error {}

/** Linha de outro tenant, escondida por `visao()`. */
export declare class LinhaOculta extends Error {
  readonly code: "OCULTA";
}

export declare function ehOculta(e: unknown): e is LinhaOculta;

/** Bytes de um .jsw: o corpo de um `fetch`, um asset do React Native, um arquivo lido em memória. */
export type Bytes = Uint8Array | ArrayBuffer;

export interface OpcoesCarregar {
  /** A implementação de WebAssembly; no React Native (Hermes), a do `polywasm`. Padrão: a do ambiente. */
  readonly WebAssembly?: Pick<typeof WebAssembly, "Module" | "instantiate">;
}

/**
 * Carrega o núcleo em WebAssembly. Sem argumento, busca `jsonw.wasm` ao lado deste arquivo.
 * No React Native, passe os bytes do `.wasm` e o WebAssembly do `polywasm`.
 */
export declare function carregar(wasm?: Bytes | WebAssembly.Module, opcoes?: OpcoesCarregar): Promise<JsonW>;

export interface JsonW {
  readonly versao: string;
  /** Abre um .jsw a partir dos bytes; o leitor guarda a própria cópia. */
  abrir<L extends Linha = Linha>(bytes: Bytes): Leitor<L>;
  /** Posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior). */
  escolher(notas: ArrayLike<number>, k: number): number[];
}

export declare class Leitor<L extends Linha = Linha> implements Iterable<L>, Disposable {
  readonly linhas: number;
  readonly esquema: string;
  readonly campos: readonly string[];
  indice(campo: number | (keyof L & string)): number;
  json(i: number): string;
  texto(i: number): string;
  linha(i: number): L;
  campo<K extends keyof L & string>(i: number, campo: K): L[K];
  campo(i: number, campo: number): Valor;
  conferir(): true;
  visao(escopos: string): this;
  indexar(campo: number | (keyof L & string)): this;
  temIndice(campo: number | (keyof L & string)): boolean;
  chave<K extends keyof L & string>(campo: K, valor: L[K]): number[];
  chave(campo: number, valor: Valor): number[];
  avaliarJson(pedido: Pedido, k?: number): string;
  avaliar(pedido: Pedido, k?: number): Nota[];
  [Symbol.iterator](): Iterator<L>;
  fechar(): void;
  [Symbol.dispose](): void;
}
