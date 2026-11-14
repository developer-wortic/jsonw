#!/usr/bin/env node
// npx jsonw ver dados.jsw: roda a ferramenta wjsw pré-compilada desta plataforma, com os mesmos argumentos e código de saída.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const plataforma = `${process.platform}-${process.arch}`;
const exe = join(import.meta.dirname, "..", "prebuilt", plataforma, process.platform === "win32" ? "wjsw.exe" : "wjsw");
if (!existsSync(exe)) {
  console.error(`jsonw: sem a ferramenta wjsw para ${plataforma} (há para darwin-arm64, linux-x64 e win32-x64).`);
  process.exit(2);
}
const r = spawnSync(exe, process.argv.slice(2), { stdio: "inherit" });
if (r.error) {
  console.error(`jsonw: ${r.error.message}`);
  process.exit(2);
}
process.exit(r.status ?? 1);
