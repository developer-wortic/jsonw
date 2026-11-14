// O mesmo jsonw.js para Node, Deno e Bun no servidor: o .wasm vem do disco, ao lado deste arquivo.
import { readFile } from "node:fs/promises";
import { carregar as carregarDe } from "./jsonw.js";

export * from "./jsonw.js";

export const carregar = async (wasm, opcoes) =>
  carregarDe(wasm ?? (await readFile(new URL("./jsonw.wasm", import.meta.url))), opcoes);
