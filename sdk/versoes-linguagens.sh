#!/bin/bash
# versoes-linguagens.sh: a versão em uso de cada linguagem (com o ambiente-linguagens.sh carregado) contra a última estável
# do Homebrew (rode `brew update` antes para o índice estar fresco). Sai 1 se alguma estiver atrás.
# Uso: bash sdk/versoes-linguagens.sh
set -u
cd "$(dirname "$0")" || exit 2
# shellcheck source=ambiente-linguagens.sh
source ./ambiente-linguagens.sh >/dev/null
atras=0
ultima() { brew info "$1" 2>/dev/null | head -1 | grep -o 'stable [0-9][0-9.]*' | cut -d' ' -f2; }
linha() {   # nome, versão em uso, fórmula do Homebrew
  local ult ok=ok; ult=$(ultima "$3")
  if [[ -z "$2" || -z "$ult" || "$2" != "$ult"* ]]; then ok="ATRÁS"; atras=$((atras + 1)); fi
  printf '%-8s em uso %-14s última %-12s %s\n' "$1" "${2:-(ausente)}" "${ult:-?}" "$ok"
}
gcc_ultimo=$(find /opt/homebrew/bin -maxdepth 1 -name "gcc-[0-9]*" 2>/dev/null | sort -V | tail -1)
linha C/C++  "$(clang --version | head -1 | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)" llvm
linha GCC    "$([ -n "$gcc_ultimo" ] && "$gcc_ultimo" -dumpfullversion)" gcc
linha Node   "$(node -v | tr -d v)" node
linha Python "$(brew list --versions python@3.15 2>/dev/null | cut -d' ' -f2 | cut -d_ -f1)" python@3.15   # versão pelo Homebrew: a casa não executa o interpretador
linha PHP    "$(php -r 'echo PHP_VERSION;')" php
linha Ruby   "$(ruby -e 'print RUBY_VERSION')" ruby
linha Java   "$(java -version 2>&1 | head -1 | cut -d'"' -f2)" openjdk
linha Kotlin "$(kotlinc -version 2>&1 | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)" kotlin
linha Swift  "$(swift --version 2>&1 | grep -o 'Swift version [0-9.]*' | cut -d' ' -f3)" swift
linha Rust   "$(rustc --version | cut -d' ' -f2)" rust
linha Go     "$(go version | grep -o 'go[0-9][0-9.]*' | cut -c3-)" go
echo "== $atras atrás da última estável"
exit $((atras > 0))
