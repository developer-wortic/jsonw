# jsonW para Objective-C (iOS e macOS)

ARC, nulidade anotada, erros por `NSError **`. Os nomes viram Swift natural (`Leitor(caminho:)`, `chave(_:valor:)`).

```objc
#import "JsonW.h"

NSError *erro;
JWLeitor *vendas = [JWLeitor leitorComCaminho:@"vendas.jsw" erro:&erro];
if (![vendas conferir:&erro]) return NO;
for (NSDictionary *venda in vendas.linhasVisiveis) NSLog(@"%@", venda);
NSArray<NSNumber *> *linhas = [vendas chave:@"cliente" valor:@"42" erro:&erro];
```

`leitorComDados:` abre um `.jsw` que veio pela rede ou de um asset, sem gravar em disco.

Compilar: `clang -fobjc-arc -I.. JsonW.m seu.m ../libjsonw.a -framework Foundation` (provado com `-Wall -Wextra -Wpedantic
-Werror`, nenhum aviso).
