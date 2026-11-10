/* jsonW (json Wondrous) para Node.js: Leitor e Escritor por cima do addon N-API (jsonw.node, compilado por `make node`).
 *   const jsonw = require("jsonw"); const a = new jsonw.Leitor("dados.jsw"); for (const linha of a) { ... } a.fechar();
 *   const w = new jsonw.Escritor("novo.jsw", "id:i64,nome:texto"); w.gravar({id: 1, nome: "x"}); w.fechar(); */
"use strict";
const path = require("path");
let nat;
const plataforma = `${process.platform}-${process.arch}`;   /* o pacote do npm traz prebuilt/<plataforma>/jsonw.node */
for (const c of [path.join(__dirname, "prebuilt", plataforma, "jsonw.node"), path.join(__dirname, "jsonw.node"), path.join(__dirname, "..", "jsonw.node")]) { try { nat = require(c); break; } catch (e) { if (e.code !== "MODULE_NOT_FOUND") throw e; } }
if (!nat) throw new Error(`jsonw: sem addon para ${plataforma} (ha para darwin-arm64 e linux-x64; no Windows, use o WSL ou compile com \`make node\` na pasta sdk)`);

class Leitor {
  constructor(caminho) { this._a = nat.abrir(caminho); this.linhas = nat.linhas(this._a); this.esquema = nat.esquema(this._a); this.campos = nat.campos(this._a); }
  json(i) { return nat.linhaJson(this._a, i); }
  texto(i) { return nat.linhaTexto(this._a, i); }
  linha(i) { return JSON.parse(this.json(i)); }
  campo(i, campo) { const k = typeof campo === "number" ? campo : this.campos.indexOf(campo); return JSON.parse(nat.campoJson(this._a, i, k)); }
  conferir() { return nat.conferir(this._a); }
  visao(escopos) { nat.visao(this._a, escopos); this.esquema = nat.esquema(this._a); this.campos = nat.campos(this._a); return this; }   /* trava o que a sessao ve; linha de outro tenant: erro com code OCULTA */
  avaliarJson(pedido, k = 10) { return nat.avaliar(this._a, typeof pedido === "string" ? pedido : JSON.stringify(pedido), k); }
  avaliar(pedido, k = 10) { return JSON.parse(this.avaliarJson(pedido, k)); }   /* as k melhores: [{linha, nota}], da maior nota para a menor */
  *[Symbol.iterator]() { for (let i = 0; i < this.linhas; i++) { let l; try { l = this.linha(i); } catch (e) { if (e.code === "OCULTA") continue; throw e; } yield l; } }
  fechar() { if (this._a) { nat.fechar(this._a); this._a = null; } }
}
class Reconhecedor {   /* tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor */
  constructor(caminho) { this._r = nat.reconhecedor(caminho); }
  reconhecerJson(texto) { return nat.reconhecer(this._r, texto); }
  reconhecer(texto) { return JSON.parse(this.reconhecerJson(texto)); }   /* {termos: [{termo, ini, fim, texto, sinal, peso}], sinais: [{sinal, soma, vezes}]} */
  fechar() { if (this._r) { nat.reconhecedorFechar(this._r); this._r = null; } }
}
const escolher = (notas, k) => nat.escolher(notas, k);   /* posicoes das k maiores notas (maior primeiro; empate pela menor posicao) */
class Escritor {
  constructor(caminho, esquema, opcoes = {}) { this._w = nat.criar(caminho, esquema, opcoes.compressao ?? 1, opcoes.hash ?? 0, opcoes.blocoKb ?? 0); }
  gravarTexto(t) { nat.gravar(this._w, t); }
  gravar(obj) { nat.gravar(this._w, JSON.stringify(obj)); }
  descarregar() { nat.descarregar(this._w); }
  fechar() { if (this._w) { nat.fecharEscritor(this._w); this._w = null; } }
  abandonar() { if (this._w) { nat.abandonar(this._w); this._w = null; } }   /* desiste: fecha sem publicar; o destino fica como estava */
}
module.exports = { Leitor, Escritor, Reconhecedor, escolher, versao: nat.versao() };

if (require.main === module && process.argv[2]) {   /* node index.js arquivo.jsw -> JSONL; --avaliar arq pedido k; --reconhecer termos.jsw texto */
  const [m, x, y, z] = process.argv.slice(2);
  if (m === "--visao") { const a = new Leitor(x).visao(y); const [p, k] = process.argv.slice(5); process.stdout.write(a.campos.join(",") + "\n"); for (let i = 0; i < a.linhas; i++) { try { process.stdout.write(a.json(i) + "\n"); } catch (e) { if (e.code !== "OCULTA") throw e; } } process.stdout.write(a.avaliarJson(p, Number(k)) + "\n"); a.fechar(); }
  else   if (m === "--avaliar") { const a = new Leitor(x); process.stdout.write(a.avaliarJson(y, Number(z)) + "\n"); a.fechar(); }
  else if (m === "--reconhecer") { const r = new Reconhecedor(x); process.stdout.write(r.reconhecerJson(y) + "\n"); r.fechar(); }
  else { const a = new Leitor(m); for (let i = 0; i < a.linhas; i++) process.stdout.write(a.json(i) + "\n"); a.fechar(); }
}
