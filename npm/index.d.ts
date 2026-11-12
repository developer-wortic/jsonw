// jsonW (json Wondrous) para Node.js: tipos do SDK (index.js).

/** Uma linha do arquivo, como objeto JSON. */
export type Linha = Record<string, unknown>;

/** Resultado de avaliar: as k melhores linhas, da maior nota para a menor. */
export interface Nota { linha: number; nota: number }

/** Lê um arquivo .jsw (acesso direto por linha e campo, sem decodificar o resto). */
export class Leitor implements Iterable<Linha> {
  constructor(caminho: string);
  /** Quantidade de linhas. */
  readonly linhas: number;
  /** Esquema em uma linha de texto, por exemplo "id:i64,preco:dinheiro". */
  readonly esquema: string;
  /** Nomes dos campos, na ordem do esquema. */
  readonly campos: string[];
  /** A linha i em JSON estrito. */
  json(i: number): string;
  /** A linha i em jsonW-texto. */
  texto(i: number): string;
  /** A linha i como objeto. */
  linha(i: number): Linha;
  /** Um campo da linha i, por nome ou posição. */
  campo(i: number, campo: string | number): unknown;
  /** Confere a custódia inteira (crc32c e SHA-256 ou BLAKE3 em cadeia). */
  conferir(): boolean;
  /** Trava o que esta sessão vê: escopos como "pessoal financeiro tenant:42". Linha de outro tenant some na iteração. */
  visao(escopos: string): this;
  /** Pedido de nota (pesos, cosseno, esparso ou grade) em JSON; devolve o JSON das k melhores. */
  avaliarJson(pedido: string | object, k?: number): string;
  /** Pedido de nota; devolve as k melhores. */
  avaliar(pedido: string | object, k?: number): Nota[];
  [Symbol.iterator](): Iterator<Linha>;
  fechar(): void;
}

export interface OpcoesEscritor {
  /** 0 nenhuma, 1 rápida (padrão), 2 máxima. */
  compressao?: 0 | 1 | 2;
  /** 0 SHA-256 (padrão), 1 BLAKE3. */
  hash?: 0 | 1;
  /** Tamanho do bloco em KB (0 = padrão). */
  blocoKb?: number;
}

/** Grava um arquivo .jsw; ele só aparece completo, em troca atômica, no fechar(). */
export class Escritor {
  constructor(caminho: string, esquema: string, opcoes?: OpcoesEscritor);
  /** Grava um objeto (convertido para JSON). */
  gravar(obj: Linha): void;
  /** Grava uma linha já em texto JSON ou jsonW-texto. */
  gravarTexto(texto: string): void;
  /** Fecha o bloco atual em disco. */
  descarregar(): void;
  /** Publica o arquivo (troca atômica). Só o fechar() publica. */
  fechar(): void;
  /** Desiste: fecha sem publicar; o destino fica como estava. */
  abandonar(): void;
}

export interface TermoReconhecido { termo: string; ini: number; fim: number; texto: string; sinal: string; peso: number }
export interface SinalReconhecido { sinal: string; soma: number; vezes: number }

/** Reconhece os termos de uma tabela (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) num texto. */
export class Reconhecedor {
  constructor(caminho: string);
  reconhecerJson(texto: string): string;
  reconhecer(texto: string): { termos: TermoReconhecido[]; sinais: SinalReconhecido[] };
  fechar(): void;
}

/** Posições das k maiores notas (maior primeiro; empate pela menor posição). */
export function escolher(notas: number[] | Float64Array, k: number): number[];

/** Versão da biblioteca. */
export const versao: string;
