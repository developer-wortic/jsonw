#!/bin/bash
# ambiente-linguagens.sh: no macOS, põe na frente do PATH a última versão de cada linguagem dos SDKs que o Homebrew deixa
# fora do caminho padrão (Ruby, Java, Swift, LLVM, Python). Em outro sistema não faz nada.
#   source sdk/ambiente-linguagens.sh      (versão em uso x última estável: bash sdk/versoes-linguagens.sh)
[ "$(uname)" = Darwin ] || return 0 2>/dev/null || exit 0

B=$(brew --prefix 2>/dev/null || echo /opt/homebrew)/opt
for d in "$B/ruby/bin" "$B/openjdk/bin" "$B/swift/bin" "$B/llvm/bin" "$B/python@3.15/libexec/bin"; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
GEMBIN=$(find "$B/../lib/ruby/gems" -maxdepth 2 -type d -name bin 2>/dev/null | sort -V | tail -1)
[ -n "$GEMBIN" ] && PATH="$GEMBIN:$PATH"
export PATH

[ -d "$B/openjdk/libexec/openjdk.jdk" ] && export JAVA_HOME="$B/openjdk/libexec/openjdk.jdk/Contents/Home"
[ -z "${SDKROOT:-}" ] && SDKROOT=$(xcrun --show-sdk-path 2>/dev/null) && export SDKROOT
