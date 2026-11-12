#!/usr/bin/env node
/* jsonw / wjsw no npm: roda a ferramenta wjsw pre-compilada desta plataforma, com os mesmos argumentos e o mesmo codigo
 * de saida (npx jsonw ver dados.jsw). */
"use strict";
const path = require("path");
const fs = require("fs");
const { spawnSync } = require("child_process");

const plataforma = `${process.platform}-${process.arch}`;
const exe = path.join(__dirname, "..", "prebuilt", plataforma, process.platform === "win32" ? "wjsw.exe" : "wjsw");
if (!fs.existsSync(exe)) {
  console.error(`jsonw: sem a ferramenta wjsw para ${plataforma} (há para darwin-arm64, linux-x64 e win32-x64).`);
  process.exit(2);
}
const r = spawnSync(exe, process.argv.slice(2), { stdio: "inherit" });
if (r.error) { console.error(`jsonw: ${r.error.message}`); process.exit(2); }
process.exit(r.status === null ? 1 : r.status);
