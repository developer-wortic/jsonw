# jsonW para Dart e Flutter

`dart:ffi` direto na ABI C, sem código gerado. Os handles fecham sozinhos (`NativeFinalizer`) quando saem de uso.

```dart
import 'package:jsonw/jsonw.dart';

final vendas = Leitor('vendas.jsw')..conferir();
for (final venda in vendas) print(venda);
print(vendas.indexar('cliente').chave('cliente', 42));
print(vendas.avaliar({'pesos': {'valor': 1}}, 10));
vendas.fechar();
```

No Flutter, a `libjsonw` de cada plataforma (`.so` no Android, `.dylib` ou `.framework` no iOS e no macOS) vai junto do app;
`JSONW_LIB` aponta outra.

Dart 3.10+ (provado no 3.13.7). `dart analyze` com `strict-casts`, `strict-inference` e `strict-raw-types`: nenhum aviso.
