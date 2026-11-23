// dart run bin/ler.dart arq.jsw -> JSONL; --gravar esquema entrada.jsonl saida.jsw; --avaliar arq pedido k;
// --visao arq escopos pedido k; --reconhecer termos.jsw texto
import 'dart:io';

import 'package:jsonw/jsonw.dart';

void main(List<String> args) {
  final saida = StringBuffer();
  switch (args) {
    case ['--gravar', final esquema, final entrada, final destino]:
      final w = Escritor(destino, esquema);
      try {
        for (final l in File(entrada).readAsLinesSync()) {
          if (l.trim().isNotEmpty) w.gravarTexto(l);
        }
        w.fechar();
      } catch (_) {
        w.abandonar();
        rethrow;
      }
    case ['--avaliar', final arq, final pedido, final k]:
      final a = Leitor(arq);
      saida.writeln(a.avaliarJson(pedido, int.parse(k)));
      a.fechar();
    case ['--visao', final arq, final escopos, final pedido, final k]:
      final a = Leitor(arq).visao(escopos);
      saida.writeln(a.campos.join(','));
      for (var i = 0; i < a.linhas; i++) {
        try {
          saida.writeln(a.json(i));
        } on LinhaOculta {
          continue;
        }
      }
      saida.writeln(a.avaliarJson(pedido, int.parse(k)));
      a.fechar();
    case ['--reconhecer', final termos, final texto]:
      final r = Reconhecedor(termos);
      saida.writeln(r.reconhecerJson(texto));
      r.fechar();
    case [final arq]:
      final a = Leitor(arq);
      for (var i = 0; i < a.linhas; i++) {
        saida.writeln(a.json(i));
      }
      a.fechar();
    default:
      stderr.writeln('uso: ler arquivo.jsw');
      exitCode = 2;
  }
  stdout.write(saida);
}
