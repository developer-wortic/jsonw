/// jsonW para Dart e Flutter, por cima da ABI C (libjsonw) com dart:ffi.
///
/// ```dart
/// final a = Leitor('dados.jsw');
/// for (final linha in a) print(linha);
/// a.fechar();
/// ```
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class ErroJsonW implements Exception {
  ErroJsonW(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'ErroJsonW: $mensagem';
}

/// Linha de outro tenant, escondida por [Leitor.visao] (-3 na ABI).
final class LinhaOculta extends ErroJsonW {
  LinhaOculta() : super('linha oculta pela visao');
}

const _erro = 320;

DynamicLibrary _carregar() {
  final dito = Platform.environment['JSONW_LIB'];
  if (dito != null && dito.isNotEmpty) return DynamicLibrary.open(dito);
  final nomes = Platform.isWindows
      ? ['libjsonw.dll']
      : Platform.isMacOS || Platform.isIOS
      ? ['libjsonw.dylib']
      : ['libjsonw.so'];
  final aqui = File.fromUri(Platform.script).parent.path;
  for (final pasta in [aqui, '$aqui/..', '$aqui/../..', Directory.current.path, '${Directory.current.path}/..']) {
    for (final n in nomes) {
      if (File('$pasta/$n').existsSync()) return DynamicLibrary.open('$pasta/$n');
    }
  }
  return DynamicLibrary.open(nomes.first);
}

final _lib = _carregar();

typedef _Texto = Int64 Function(Pointer<Void>, Uint64, Pointer<Uint8>, Size);
typedef _TextoD = int Function(Pointer<Void>, int, Pointer<Uint8>, int);

final _versao = _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('jsonw_versao');
final _abrir = _lib
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Size),
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int)
    >('jsonw_abrir');
final _fecharPtr = _lib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('jsonw_fechar');
final _fechar = _fecharPtr.asFunction<void Function(Pointer<Void>)>();
final _linhas = _lib.lookupFunction<Uint64 Function(Pointer<Void>), int Function(Pointer<Void>)>('jsonw_linhas');
final _campos = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('jsonw_campos');
final _esquema = _lib.lookupFunction<Pointer<Utf8> Function(Pointer<Void>), Pointer<Utf8> Function(Pointer<Void>)>(
  'jsonw_esquema',
);
final _campoNome = _lib
    .lookupFunction<Pointer<Utf8> Function(Pointer<Void>, Int32), Pointer<Utf8> Function(Pointer<Void>, int)>(
      'jsonw_campo_nome',
    );
final _linhaJson = _lib.lookupFunction<_Texto, _TextoD>('jsonw_linha_json');
final _linhaTexto = _lib.lookupFunction<_Texto, _TextoD>('jsonw_linha_texto');
final _campoJson = _lib
    .lookupFunction<
      Int64 Function(Pointer<Void>, Uint64, Int32, Pointer<Uint8>, Size),
      int Function(Pointer<Void>, int, int, Pointer<Uint8>, int)
    >('jsonw_campo_json');
final _conferir = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Size),
      int Function(Pointer<Void>, Pointer<Utf8>, int)
    >('jsonw_conferir');
final _visao = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, Size),
      int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>, int)
    >('jsonw_visao');
final _indexar = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>(
  'jsonw_indexar',
);
final _temIndice = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>(
  'jsonw_tem_indice',
);
final _chave = _lib
    .lookupFunction<
      Int64 Function(Pointer<Void>, Int32, Pointer<Uint8>, Size, Pointer<Uint64>, Size),
      int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Uint64>, int)
    >('jsonw_chave');
final _avaliar = _lib
    .lookupFunction<
      Int64 Function(Pointer<Void>, Pointer<Uint8>, Size, Size, Pointer<Uint8>, Size, Pointer<Utf8>, Size),
      int Function(Pointer<Void>, Pointer<Uint8>, int, int, Pointer<Uint8>, int, Pointer<Utf8>, int)
    >('jsonw_avaliar');
final _escolher = _lib
    .lookupFunction<
      Int64 Function(Pointer<Double>, Size, Size, Pointer<Uint64>),
      int Function(Pointer<Double>, int, int, Pointer<Uint64>)
    >('jsonw_escolher');
final _criar = _lib
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Size),
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)
    >('jsonw_criar');
final _opcoes = _lib
    .lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32, Int32), int Function(Pointer<Void>, int, int, int)>(
      'jsonw_opcoes',
    );
final _gravar = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>, Size, Pointer<Utf8>, Size),
      int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Utf8>, int)
    >('jsonw_gravar_json');
final _descarregar = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
  'jsonw_descarregar',
);
final _fecharEscritor = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
  'jsonw_fechar_escritor',
);
final _abandonarPtr = _lib.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('jsonw_abandonar');
final _abandonar = _abandonarPtr.asFunction<int Function(Pointer<Void>)>();
final _reconhecedor = _lib
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Size),
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int)
    >('jsonw_reconhecedor');
final _reconhecedorFecharPtr = _lib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('jsonw_reconhecedor_fechar');
final _reconhecer = _lib
    .lookupFunction<
      Int64 Function(Pointer<Void>, Pointer<Uint8>, Size, Pointer<Uint8>, Size),
      int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int)
    >('jsonw_reconhecer');

String get versao => _versao().toDartString();

/// Buffer que cresce até caber (-2 = curto); -3 = linha oculta.
String _texto(int Function(Pointer<Uint8>, int) chamada) {
  for (var cap = 1 << 16; ; cap *= 4) {
    final b = malloc<Uint8>(cap);
    try {
      switch (chamada(b, cap)) {
        case -2:
          continue;
        case -3:
          throw LinhaOculta();
        case < 0:
          throw ErroJsonW('linha ou campo ilegivel');
        case final n:
          return utf8.decode(b.asTypedList(n));
      }
    } finally {
      malloc.free(b);
    }
  }
}

/// Chama com um buffer de erro; devolve o retorno e o texto do erro.
(T, String) _comErro<T>(T Function(Pointer<Utf8>, int) chamada) {
  final e = malloc<Uint8>(_erro)..value = 0;
  try {
    final r = chamada(e.cast(), _erro);
    return (r, e.cast<Utf8>().toDartString());
  } finally {
    malloc.free(e);
  }
}

/// Bytes UTF-8 de um texto, numa memória que vive só durante [uso].
R _comBytes<R>(String texto, R Function(Pointer<Uint8>, int) uso) {
  final b = utf8.encode(texto);
  final p = malloc<Uint8>(b.length + 1);
  try {
    p.asTypedList(b.length + 1)
      ..setAll(0, b)
      ..[b.length] = 0;
    return uso(p, b.length);
  } finally {
    malloc.free(p);
  }
}

final _finalizadorLeitor = NativeFinalizer(_fecharPtr.cast());

/// Lê um .jsw pelo mmap. Fecha sozinho quando sai de uso, ou antes, por [fechar].
final class Leitor with Iterable<Map<String, Object?>> implements Finalizable {
  Leitor(String caminho) : _h = _abrirArquivo(caminho) {
    _finalizadorLeitor.attach(this, _h, detach: this);
    linhas = _linhas(_h);
    _lerEsquema();
  }

  static Pointer<Void> _abrirArquivo(String caminho) => using((arena) {
    final (h, erro) = _comErro((e, n) => _abrir(caminho.toNativeUtf8(allocator: arena), e, n));
    if (h == nullptr) throw ErroJsonW(erro);
    return h;
  });

  Pointer<Void> _h;
  late final int linhas;
  late String esquema;
  late List<String> campos;

  Pointer<Void> get _vivo => _h == nullptr ? throw ErroJsonW('leitor fechado') : _h;

  void _lerEsquema() {
    esquema = _esquema(_h).toDartString();
    campos = List.generate(_campos(_h), (i) => _campoNome(_h, i).toDartString(), growable: false);
  }

  int indice(Object campo) => switch (campo) {
    final int k => k,
    final String nome when campos.contains(nome) => campos.indexOf(nome),
    _ => throw ErroJsonW('campo inexistente: $campo'),
  };

  String json(int i) => _texto((b, cap) => _linhaJson(_vivo, i, b, cap));
  String texto(int i) => _texto((b, cap) => _linhaTexto(_vivo, i, b, cap));
  Map<String, Object?> linha(int i) => (jsonDecode(json(i)) as Map).cast();

  Object? campo(int i, Object campo) {
    final k = indice(campo);
    return jsonDecode(_texto((b, cap) => _campoJson(_vivo, i, k, b, cap)));
  }

  bool conferir() {
    final (r, erro) = _comErro((e, n) => _conferir(_vivo, e, n));
    if (r != 0) throw ErroJsonW(erro);
    return true;
  }

  /// Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant lança [LinhaOculta].
  Leitor visao(String escopos) {
    final r = using((arena) {
      final (r, erro) = _comErro((e, n) => _visao(_vivo, escopos.toNativeUtf8(allocator: arena), e, n));
      return r == 0 ? null : erro;
    });
    if (r != null) throw ErroJsonW(r);
    _lerEsquema();
    return this;
  }

  Leitor indexar(Object campo) {
    if (_indexar(_vivo, indice(campo)) != 0) throw ErroJsonW('campo sem indice');
    return this;
  }

  bool temIndice(Object campo) => _temIndice(_vivo, indice(campo)) == 1;

  /// As linhas em que o campo vale [valor] (7, 'RJ', null), em ordem crescente.
  List<int> chave(Object campo, Object? valor) {
    final k = indice(campo);
    return _comBytes(jsonEncode(valor), (v, nv) {
      for (var cap = 16; ;) {
        final out = malloc<Uint64>(cap);
        try {
          switch (_chave(_vivo, k, v, nv, out, cap)) {
            case -2:
              throw ErroJsonW('valor nao e do tipo do campo');
            case < 0:
              throw ErroJsonW('campo invalido');
            case final n when n <= cap:
              return List.of(out.asTypedList(n));
            case final n:
              cap = n;
          }
        } finally {
          malloc.free(out);
        }
      }
    });
  }

  /// As k melhores linhas pelo pedido, como a ABI devolve: [{"linha","nota"}].
  String avaliarJson(Object pedido, [int k = 10]) {
    final texto = pedido is String ? pedido : jsonEncode(pedido);
    return _comBytes(texto, (p, np) {
      final e = malloc<Uint8>(_erro)..value = 0;
      try {
        return _texto((b, cap) {
          final n = _avaliar(_vivo, p, np, k, b, cap, e.cast(), _erro);
          if (n == -1) throw ErroJsonW(e.cast<Utf8>().toDartString());
          return n;
        });
      } finally {
        malloc.free(e);
      }
    });
  }

  List<({int linha, double nota})> avaliar(Object pedido, [int k = 10]) => [
    for (final m in (jsonDecode(avaliarJson(pedido, k)) as List).cast<Map<String, Object?>>())
      (linha: m['linha']! as int, nota: (m['nota']! as num).toDouble()),
  ];

  /// Com visão, as linhas de outro tenant ficam de fora.
  @override
  Iterator<Map<String, Object?>> get iterator => _linhasVisiveis().iterator;

  Iterable<Map<String, Object?>> _linhasVisiveis() sync* {
    for (var i = 0; i < linhas; i++) {
      try {
        yield linha(i);
      } on LinhaOculta {
        continue;
      }
    }
  }

  @override
  int get length => linhas;

  void fechar() {
    if (_h == nullptr) return;
    _finalizadorLeitor.detach(this);
    _fechar(_h);
    _h = nullptr;
  }
}

/// As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior).
List<int> escolher(List<double> notas, int k) {
  final v = malloc<Double>(notas.isEmpty ? 1 : notas.length);
  final out = malloc<Uint64>(k < 1 ? 1 : k);
  try {
    v.asTypedList(notas.length).setAll(0, notas);
    final m = _escolher(v, notas.length, k, out);
    return m > 0 ? List.of(out.asTypedList(m)) : const [];
  } finally {
    malloc
      ..free(v)
      ..free(out);
  }
}

final _finalizadorEscritor = NativeFinalizer(_abandonarPtr.cast());

/// O destino só aparece em [fechar]; largado sem fechar, abandona e o destino fica como estava.
final class Escritor implements Finalizable {
  Escritor(String caminho, String esquema, {int compressao = 1, int hash = 0, int blocoKb = 0})
    : _w = using((arena) {
        final (w, erro) = _comErro(
          (e, n) => _criar(caminho.toNativeUtf8(allocator: arena), esquema.toNativeUtf8(allocator: arena), e, n),
        );
        if (w == nullptr) throw ErroJsonW(erro);
        return w;
      }) {
    _finalizadorEscritor.attach(this, _w, detach: this);
    _opcoes(_w, compressao, hash, blocoKb);
  }

  Pointer<Void> _w;

  void gravarTexto(String texto) {
    final erro = _comBytes(texto, (b, n) {
      final (r, erro) = _comErro((e, ne) => _gravar(_w, b, n, e, ne));
      return r == 0 ? null : erro;
    });
    if (erro != null) throw ErroJsonW(erro);
  }

  void gravar(Map<String, Object?> linha) => gravarTexto(jsonEncode(linha));

  void descarregar() => _descarregar(_w);

  void fechar() {
    if (_w == nullptr) return;
    _finalizadorEscritor.detach(this);
    final r = _fecharEscritor(_w);
    _w = nullptr;
    if (r != 0) throw ErroJsonW('nao gravou tudo');
  }

  void abandonar() {
    if (_w == nullptr) return;
    _finalizadorEscritor.detach(this);
    _abandonar(_w);
    _w = nullptr;
  }
}

final _finalizadorReconhecedor = NativeFinalizer(_reconhecedorFecharPtr.cast());

/// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais do texto.
final class Reconhecedor implements Finalizable {
  Reconhecedor(String termos)
    : _r = using((arena) {
        final (r, erro) = _comErro((e, n) => _reconhecedor(termos.toNativeUtf8(allocator: arena), e, n));
        if (r == nullptr) throw ErroJsonW(erro);
        return r;
      }) {
    _finalizadorReconhecedor.attach(this, _r, detach: this);
  }

  Pointer<Void> _r;

  String reconhecerJson(String texto) => _comBytes(texto, (t, n) => _texto((b, cap) => _reconhecer(_r, t, n, b, cap)));

  Map<String, Object?> reconhecer(String texto) => (jsonDecode(reconhecerJson(texto)) as Map).cast();

  void fechar() {
    if (_r == nullptr) return;
    _finalizadorReconhecedor.detach(this);
    _reconhecedorFecharPtr.asFunction<void Function(Pointer<Void>)>()(_r);
    _r = nullptr;
  }
}
