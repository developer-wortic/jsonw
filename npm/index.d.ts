/** Um valor de campo, como sai do JSON. */
export type Valor = string | number | boolean | null | Valor[] | { [campo: string]: Valor };

/** Uma linha do arquivo, como objeto JSON. */
export type Linha = Record<string, Valor>;

/** Resultado de avaliar: as k melhores linhas, da maior nota para a menor. */
export interface Nota {
  readonly linha: number;
  readonly nota: number;
}

/** Pedido de nota em JSON: {"pesos":..}, {"cosseno":..}, {"esparso":..} ou {"grade":..}. */
export type Pedido = string | Readonly<Record<string, unknown>>;

export interface TermoReconhecido {
  readonly termo: string;
  readonly ini: number;
  readonly fim: number;
  readonly texto: string;
  readonly sinal: string;
  readonly peso: number;
}

export interface SinalReconhecido {
  readonly sinal: string;
  readonly soma: number;
  readonly vezes: number;
}

export interface OpcoesEscritor {
  /** 0 nenhuma, 1 rápida (padrão), 2 máxima. */
  readonly compressao?: 0 | 1 | 2;
  /** 0 SHA-256 (padrão), 1 BLAKE3. */
  readonly hash?: 0 | 1;
  /** Tamanho do bloco em KB (0 = padrão). */
  readonly blocoKb?: number;
}

/** Versão da biblioteca. */
export declare const versao: string;

/** true quando o erro é de uma linha de outro tenant, escondida por `visao()`. */
export declare function ehOculta(e: unknown): boolean;

/**
 * Lê um arquivo .jsw (acesso direto por linha e campo, sem decodificar o resto).
 * Com `using`, fecha sozinho no fim do bloco.
 */
export declare class Leitor<L extends Linha = Linha> implements Iterable<L>, Disposable {
  constructor(caminho: string);
  /** Quantidade de linhas. */
  readonly linhas: number;
  /** Esquema em uma linha de texto, por exemplo "id:i64,preco:dinheiro". */
  readonly esquema: string;
  /** Nomes dos campos, na ordem do esquema. */
  readonly campos: readonly string[];
  /** Posição do campo; lança RangeError se o nome não existe. */
  indice(campo: number | (keyof L & string)): number;
  /** A linha i em JSON estrito. */
  json(i: number): string;
  /** A linha i em jsonW-texto. */
  texto(i: number): string;
  /** A linha i como objeto. */
  linha(i: number): L;
  /** Um campo da linha i, por nome ou posição. */
  campo<K extends keyof L & string>(i: number, campo: K): L[K];
  campo(i: number, campo: number): Valor;
  /** Confere a custódia inteira (crc32c e SHA-256 ou BLAKE3 em cadeia). */
  conferir(): true;
  /** Trava o que esta sessão vê: escopos como "pessoal financeiro tenant:42". Linha de outro tenant some na iteração. */
  visao(escopos: string): this;
  /** Pedido de nota; devolve o JSON das k melhores. */
  avaliarJson(pedido: Pedido, k?: number): string;
  /** Pedido de nota; devolve as k melhores. */
  avaliar(pedido: Pedido, k?: number): Nota[];
  /** Monta o índice do campo neste leitor: a busca por chave deixa de varrer o arquivo. */
  indexar(campo: number | (keyof L & string)): this;
  /** true quando o campo tem índice neste leitor. */
  temIndice(campo: number | (keyof L & string)): boolean;
  /** As linhas em que o campo vale o valor, em ordem crescente. */
  chave<K extends keyof L & string>(campo: K, valor: L[K]): number[];
  chave(campo: number, valor: Valor): number[];
  [Symbol.iterator](): Iterator<L>;
  fechar(): void;
  [Symbol.dispose](): void;
}

/**
 * Grava um arquivo .jsw; ele só aparece completo, em troca atômica, no `fechar()`.
 * Saindo de um bloco `using` sem `fechar()`, abandona: o destino fica como estava.
 */
export declare class Escritor<L extends Linha = Linha> implements Disposable {
  constructor(caminho: string, esquema: string, opcoes?: OpcoesEscritor);
  /** Grava um objeto (convertido para JSON). */
  gravar(obj: L): void;
  /** Grava uma linha já em texto JSON ou jsonW-texto. */
  gravarTexto(texto: string): void;
  /** Fecha o bloco atual em disco. */
  descarregar(): void;
  /** Publica o arquivo (troca atômica). Só o fechar() publica. */
  fechar(): void;
  /** Desiste: fecha sem publicar; o destino fica como estava. */
  abandonar(): void;
  [Symbol.dispose](): void;
}

/** Reconhece os termos de uma tabela (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) num texto. */
export declare class Reconhecedor implements Disposable {
  constructor(caminho: string);
  reconhecerJson(texto: string): string;
  reconhecer(texto: string): { termos: TermoReconhecido[]; sinais: SinalReconhecido[] };
  fechar(): void;
  [Symbol.dispose](): void;
}

/** Posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior). */
export declare function escolher(notas: readonly number[] | Float64Array, k: number): number[];
