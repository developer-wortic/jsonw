// JsonW.h: jsonW para Objective-C (iOS e macOS), por cima da ABI C (jsonw.h). ARC.
//   NSError *erro;
//   JWLeitor *a = [JWLeitor leitorComCaminho:@"dados.jsw" erro:&erro];
//   for (NSDictionary *linha in a.linhasVisiveis) NSLog(@"%@", linha);
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const JWDominioErro;

typedef NS_ERROR_ENUM(JWDominioErro, JWCodigoErro) {
    JWErroBiblioteca = 1,
    /// Linha de outro tenant, escondida por `visao` (-3 na ABI).
    JWErroLinhaOculta = 2,
    JWErroIlegivel = 3,
};

/// A versão da biblioteca.
FOUNDATION_EXPORT NSString *JWVersao(void);

/// As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior).
FOUNDATION_EXPORT NSArray<NSNumber *> *JWEscolher(NSArray<NSNumber *> *notas, NSUInteger k) NS_SWIFT_NAME(escolher(_:k:));

NS_SWIFT_NAME(Leitor)
@interface JWLeitor : NSObject

+ (nullable instancetype)leitorComCaminho:(NSString *)caminho erro:(NSError **)erro NS_SWIFT_NAME(init(caminho:));
/// Abre a partir dos bytes (um download, um asset); o leitor guarda a própria cópia.
+ (nullable instancetype)leitorComDados:(NSData *)dados erro:(NSError **)erro NS_SWIFT_NAME(init(dados:));
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) uint64_t linhas;
@property (nonatomic, readonly, copy) NSString *esquema;
@property (nonatomic, readonly, copy) NSArray<NSString *> *campos;

- (nullable NSString *)jsonDaLinha:(uint64_t)i erro:(NSError **)erro NS_SWIFT_NAME(json(_:));
- (nullable NSString *)textoDaLinha:(uint64_t)i erro:(NSError **)erro NS_SWIFT_NAME(texto(_:));
- (nullable NSDictionary<NSString *, id> *)linha:(uint64_t)i erro:(NSError **)erro NS_SWIFT_NAME(linha(_:));
- (nullable id)campo:(NSString *)campo daLinha:(uint64_t)i erro:(NSError **)erro NS_SWIFT_NAME(campo(_:linha:));

- (BOOL)conferir:(NSError **)erro;
/// Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = `JWErroLinhaOculta`.
- (BOOL)visao:(NSString *)escopos erro:(NSError **)erro NS_SWIFT_NAME(visao(_:));
- (BOOL)indexar:(NSString *)campo erro:(NSError **)erro NS_SWIFT_NAME(indexar(_:));
/// As linhas em que o campo vale `valor` (o JSON do valor: @"7", @"\"RJ\""), em ordem crescente.
- (nullable NSArray<NSNumber *> *)chave:(NSString *)campo valor:(NSString *)valor erro:(NSError **)erro
    NS_SWIFT_NAME(chave(_:valor:));
/// As k melhores linhas pelo pedido em JSON: [{"linha","nota"}].
- (nullable NSString *)avaliar:(NSString *)pedido k:(NSUInteger)k erro:(NSError **)erro NS_SWIFT_NAME(avaliar(_:k:));

/// As linhas como dicionários; com visão, as de outro tenant ficam de fora.
@property (nonatomic, readonly) NSEnumerator<NSDictionary<NSString *, id> *> *linhasVisiveis;

- (void)fechar;

@end

/// O destino só aparece em `fechar`; largado sem fechar, abandona e o destino fica como estava.
NS_SWIFT_NAME(Escritor)
@interface JWEscritor : NSObject

+ (nullable instancetype)escritorComCaminho:(NSString *)caminho esquema:(NSString *)esquema erro:(NSError **)erro
    NS_SWIFT_NAME(init(caminho:esquema:));
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)gravarTexto:(NSString *)texto erro:(NSError **)erro NS_SWIFT_NAME(gravar(texto:));
- (BOOL)gravar:(NSDictionary<NSString *, id> *)linha erro:(NSError **)erro NS_SWIFT_NAME(gravar(_:));
- (BOOL)fechar:(NSError **)erro;
- (void)abandonar;

@end

/// Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais do texto.
NS_SWIFT_NAME(Reconhecedor)
@interface JWReconhecedor : NSObject

+ (nullable instancetype)reconhecedorComCaminho:(NSString *)caminho erro:(NSError **)erro NS_SWIFT_NAME(init(caminho:));
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSString *)reconhecer:(NSString *)texto erro:(NSError **)erro NS_SWIFT_NAME(reconhecer(_:));

@end

NS_ASSUME_NONNULL_END
