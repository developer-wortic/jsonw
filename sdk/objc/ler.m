// ler arq.jsw -> JSONL; --gravar esquema entrada.jsonl saida.jsw; --avaliar arq pedido k; --visao arq escopos pedido k;
// --reconhecer termos.jsw texto. clang -fobjc-arc -I.. ler.m JsonW.m ../libjsonw.a -framework Foundation -o ler
#import "JsonW.h"

static int sair(NSError *erro) {
    fprintf(stderr, "%s\n", erro.localizedDescription.UTF8String);
    return 1;
}

static void escrever(NSString *linha) {
    fputs(linha.UTF8String, stdout);
    fputc('\n', stdout);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *a = [NSMutableArray array];
        for (int i = 1; i < argc; i++) [a addObject:@(argv[i])];
        NSError *erro;

        if (a.count == 4 && [a[0] isEqualToString:@"--gravar"]) {
            JWEscritor *w = [JWEscritor escritorComCaminho:a[3] esquema:a[1] erro:&erro];
            NSString *entrada = [NSString stringWithContentsOfFile:a[2] encoding:NSUTF8StringEncoding error:&erro];
            if (!w || !entrada) return sair(erro);
            for (NSString *l in [entrada componentsSeparatedByString:@"\n"]) {
                if ([l stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length == 0) continue;
                if (![w gravarTexto:l erro:&erro]) return [w abandonar], sair(erro);
            }
            return [w fechar:&erro] ? 0 : sair(erro);
        }
        if (a.count == 4 && [a[0] isEqualToString:@"--avaliar"]) {
            NSString *r = [[JWLeitor leitorComCaminho:a[1] erro:&erro] avaliar:a[2] k:(NSUInteger)a[3].integerValue erro:&erro];
            return r ? (escrever(r), 0) : sair(erro);
        }
        if (a.count == 5 && [a[0] isEqualToString:@"--visao"]) {
            JWLeitor *l = [JWLeitor leitorComCaminho:a[1] erro:&erro];
            if (!l || ![l visao:a[2] erro:&erro]) return sair(erro);
            escrever([l.campos componentsJoinedByString:@","]);
            for (uint64_t i = 0; i < l.linhas; i++) {
                NSString *s = [l jsonDaLinha:i erro:&erro];
                if (s) escrever(s);
                else if (erro.code != JWErroLinhaOculta) return sair(erro);
            }
            NSString *r = [l avaliar:a[3] k:(NSUInteger)a[4].integerValue erro:&erro];
            return r ? (escrever(r), 0) : sair(erro);
        }
        if (a.count == 3 && [a[0] isEqualToString:@"--reconhecer"]) {
            NSString *r = [[JWReconhecedor reconhecedorComCaminho:a[1] erro:&erro] reconhecer:a[2] erro:&erro];
            return r ? (escrever(r), 0) : sair(erro);
        }
        if (a.count == 1) {
            JWLeitor *l = [JWLeitor leitorComCaminho:a[0] erro:&erro];
            if (!l) return sair(erro);
            for (uint64_t i = 0; i < l.linhas; i++) {
                NSString *s = [l jsonDaLinha:i erro:&erro];
                if (!s) return sair(erro);
                escrever(s);
            }
            return 0;
        }
        fputs("uso: ler arquivo.jsw\n", stderr);
        return 2;
    }
}
