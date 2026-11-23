// JsonW.m: a ponte entre o Objective-C e a ABI C. ARC.
#import "JsonW.h"
#include "../jsonw.h"

NSErrorDomain const JWDominioErro = @"org.jsonw";

enum { kErro = 320 };

static BOOL falhar(NSError **erro, JWCodigoErro codigo, NSString *mensagem) {
    if (erro) *erro = [NSError errorWithDomain:JWDominioErro code:codigo userInfo:@{NSLocalizedDescriptionKey : mensagem}];
    return NO;
}

static NSUInteger maior(NSUInteger a, NSUInteger b) { return a > b ? a : b; }

static NSString *textoC(const char *c) { return c ? @(c) : @""; }

/// Buffer que cresce até caber (-2 = curto); -3 = linha oculta.
static NSString *_Nullable lerTexto(NSError **erro, int64_t (^chamada)(char *saida, size_t cap)) {
    for (size_t cap = 1 << 16;; cap *= 4) {
        NSMutableData *b = [NSMutableData dataWithLength:cap];
        int64_t n = chamada(b.mutableBytes, cap);
        if (n == -2) continue;
        if (n == -3) return falhar(erro, JWErroLinhaOculta, @"linha oculta pela visao"), nil;
        if (n < 0) return falhar(erro, JWErroIlegivel, @"linha ou campo ilegivel"), nil;
        return [[NSString alloc] initWithBytes:b.bytes length:(NSUInteger)n encoding:NSUTF8StringEncoding];
    }
}

NSString *JWVersao(void) { return textoC(jsonw_versao()); }

NSArray<NSNumber *> *JWEscolher(NSArray<NSNumber *> *notas, NSUInteger k) {
    NSMutableData *v = [NSMutableData dataWithLength:maior(notas.count, 1) * sizeof(double)];
    NSMutableData *out = [NSMutableData dataWithLength:maior(k, 1) * sizeof(uint64_t)];
    double *pv = v.mutableBytes;
    [notas enumerateObjectsUsingBlock:^(NSNumber *x, NSUInteger i, BOOL *_) { pv[i] = x.doubleValue; }];
    int64_t m = jsonw_escolher(pv, notas.count, k, out.mutableBytes);
    NSMutableArray<NSNumber *> *r = [NSMutableArray arrayWithCapacity:(m > 0 ? (NSUInteger)m : 0)];
    const uint64_t *po = out.bytes;
    for (int64_t i = 0; i < m; i++) [r addObject:@(po[i])];
    return r;
}

@interface JWEnumerador : NSEnumerator
- (instancetype)initComLeitor:(JWLeitor *)leitor;
@end

@implementation JWLeitor {
    void *_a;
}

- (instancetype)initComHandle:(void *)a {
    if ((self = [super init])) {
        _a = a;
        _linhas = jsonw_linhas(a);
        [self lerEsquema];
    }
    return self;
}

+ (instancetype)leitorComCaminho:(NSString *)caminho erro:(NSError **)erro {
    char e[kErro] = "";
    void *a = jsonw_abrir(caminho.fileSystemRepresentation, e, sizeof e);
    if (!a) return falhar(erro, JWErroBiblioteca, textoC(e)), nil;
    return [[self alloc] initComHandle:a];
}

+ (instancetype)leitorComDados:(NSData *)dados erro:(NSError **)erro {
    char e[kErro] = "";
    void *a = jsonw_abrir_memoria(dados.bytes, dados.length, e, sizeof e);
    if (!a) return falhar(erro, JWErroBiblioteca, textoC(e)), nil;
    return [[self alloc] initComHandle:a];
}

- (void)dealloc { [self fechar]; }

- (void)lerEsquema {
    _esquema = textoC(jsonw_esquema(_a));
    int n = jsonw_campos(_a);
    NSMutableArray<NSString *> *c = [NSMutableArray arrayWithCapacity:(n > 0 ? (NSUInteger)n : 0)];
    for (int i = 0; i < n; i++) [c addObject:textoC(jsonw_campo_nome(_a, i))];
    _campos = c;
}

- (int)indice:(NSString *)campo erro:(NSError **)erro {
    NSUInteger k = [_campos indexOfObject:campo];
    if (k == NSNotFound) return falhar(erro, JWErroBiblioteca, [@"campo inexistente: " stringByAppendingString:campo]), -1;
    return (int)k;
}

- (NSString *)jsonDaLinha:(uint64_t)i erro:(NSError **)erro {
    return lerTexto(erro, ^int64_t(char *s, size_t cap) { return jsonw_linha_json(self->_a, i, s, cap); });
}

- (NSString *)textoDaLinha:(uint64_t)i erro:(NSError **)erro {
    return lerTexto(erro, ^int64_t(char *s, size_t cap) { return jsonw_linha_texto(self->_a, i, s, cap); });
}

- (NSDictionary<NSString *, id> *)linha:(uint64_t)i erro:(NSError **)erro {
    NSString *json = [self jsonDaLinha:i erro:erro];
    return json ? [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:erro]
                : nil;
}

- (id)campo:(NSString *)campo daLinha:(uint64_t)i erro:(NSError **)erro {
    int k = [self indice:campo erro:erro];
    if (k < 0) return nil;
    NSString *json = lerTexto(erro, ^int64_t(char *s, size_t cap) { return jsonw_campo_json(self->_a, i, k, s, cap); });
    return json ? [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:NSJSONReadingFragmentsAllowed
                                                    error:erro]
                : nil;
}

- (BOOL)conferir:(NSError **)erro {
    char e[kErro] = "";
    return jsonw_conferir(_a, e, sizeof e) == 0 || falhar(erro, JWErroBiblioteca, textoC(e));
}

- (BOOL)visao:(NSString *)escopos erro:(NSError **)erro {
    char e[kErro] = "";
    if (jsonw_visao(_a, escopos.UTF8String, e, sizeof e) != 0) return falhar(erro, JWErroBiblioteca, textoC(e));
    [self lerEsquema];
    return YES;
}

- (BOOL)indexar:(NSString *)campo erro:(NSError **)erro {
    int k = [self indice:campo erro:erro];
    if (k < 0) return NO;
    return jsonw_indexar(_a, k) == 0 || falhar(erro, JWErroBiblioteca, @"campo sem indice");
}

- (NSArray<NSNumber *> *)chave:(NSString *)campo valor:(NSString *)valor erro:(NSError **)erro {
    int k = [self indice:campo erro:erro];
    if (k < 0) return nil;
    NSData *v = [valor dataUsingEncoding:NSUTF8StringEncoding];
    for (size_t cap = 16;;) {
        NSMutableData *out = [NSMutableData dataWithLength:cap * sizeof(uint64_t)];
        int64_t n = jsonw_chave(_a, k, v.bytes, v.length, out.mutableBytes, cap);
        if (n == -2) return falhar(erro, JWErroBiblioteca, @"valor nao e do tipo do campo"), nil;
        if (n < 0) return falhar(erro, JWErroBiblioteca, @"campo invalido"), nil;
        if ((size_t)n > cap) {
            cap = (size_t)n;
            continue;
        }
        NSMutableArray<NSNumber *> *r = [NSMutableArray arrayWithCapacity:(NSUInteger)n];
        const uint64_t *p = out.bytes;
        for (int64_t i = 0; i < n; i++) [r addObject:@(p[i])];
        return r;
    }
}

- (NSString *)avaliar:(NSString *)pedido k:(NSUInteger)k erro:(NSError **)erro {
    NSData *p = [pedido dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *e = [NSMutableData dataWithLength:kErro];
    char *pe = e.mutableBytes;
    NSString *r = lerTexto(erro, ^int64_t(char *s, size_t cap) {
        return jsonw_avaliar(self->_a, p.bytes, p.length, k, s, cap, pe, kErro);
    });
    if (!r && pe[0]) falhar(erro, JWErroBiblioteca, textoC(pe));
    return r;
}

- (NSEnumerator<NSDictionary<NSString *, id> *> *)linhasVisiveis {
    return [[JWEnumerador alloc] initComLeitor:self];
}

- (void)fechar {
    if (_a) {
        jsonw_fechar(_a);
        _a = NULL;
    }
}

@end

@implementation JWEnumerador {
    JWLeitor *_leitor;
    uint64_t _i;
}

- (instancetype)initComLeitor:(JWLeitor *)leitor {
    if ((self = [super init])) _leitor = leitor;
    return self;
}

- (id)nextObject {
    while (_i < _leitor.linhas) {
        NSDictionary *l = [_leitor linha:_i++ erro:NULL];
        if (l) return l;
    }
    return nil;
}

@end

@implementation JWEscritor {
    void *_w;
}

+ (instancetype)escritorComCaminho:(NSString *)caminho esquema:(NSString *)esquema erro:(NSError **)erro {
    char e[kErro] = "";
    void *w = jsonw_criar(caminho.fileSystemRepresentation, esquema.UTF8String, e, sizeof e);
    if (!w) return falhar(erro, JWErroBiblioteca, textoC(e)), nil;
    JWEscritor *x = [[self alloc] initComHandle:w];
    return x;
}

- (instancetype)initComHandle:(void *)w {
    if ((self = [super init])) _w = w;
    return self;
}

- (void)dealloc { [self abandonar]; }

- (BOOL)gravarTexto:(NSString *)texto erro:(NSError **)erro {
    NSData *b = [texto dataUsingEncoding:NSUTF8StringEncoding];
    char e[kErro] = "";
    return jsonw_gravar_json(_w, b.bytes, b.length, e, sizeof e) == 0 || falhar(erro, JWErroBiblioteca, textoC(e));
}

- (BOOL)gravar:(NSDictionary<NSString *, id> *)linha erro:(NSError **)erro {
    NSData *b = [NSJSONSerialization dataWithJSONObject:linha options:0 error:erro];
    return b && [self gravarTexto:[[NSString alloc] initWithData:b encoding:NSUTF8StringEncoding] erro:erro];
}

- (BOOL)fechar:(NSError **)erro {
    if (!_w) return YES;
    void *w = _w;
    _w = NULL;
    return jsonw_fechar_escritor(w) == 0 || falhar(erro, JWErroBiblioteca, @"nao gravou tudo");
}

- (void)abandonar {
    if (_w) {
        jsonw_abandonar(_w);
        _w = NULL;
    }
}

@end

@implementation JWReconhecedor {
    void *_r;
}

+ (instancetype)reconhecedorComCaminho:(NSString *)caminho erro:(NSError **)erro {
    char e[kErro] = "";
    void *r = jsonw_reconhecedor(caminho.fileSystemRepresentation, e, sizeof e);
    if (!r) return falhar(erro, JWErroBiblioteca, textoC(e)), nil;
    JWReconhecedor *x = [[self alloc] initComHandle:r];
    return x;
}

- (instancetype)initComHandle:(void *)r {
    if ((self = [super init])) _r = r;
    return self;
}

- (void)dealloc { jsonw_reconhecedor_fechar(_r); }

- (NSString *)reconhecer:(NSString *)texto erro:(NSError **)erro {
    NSData *t = [texto dataUsingEncoding:NSUTF8StringEncoding];
    return lerTexto(erro, ^int64_t(char *s, size_t cap) { return jsonw_reconhecer(self->_r, t.bytes, t.length, s, cap); });
}

@end
