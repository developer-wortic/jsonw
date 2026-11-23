<?php
/* jsonW para PHP 8.4+ pela extensão FFI, por cima da ABI C (libjsonw). Sem dependência.
 *   foreach (new JsonW\Leitor("dados.jsw") as $linha) { ... }
 *   $w = new JsonW\Escritor("novo.jsw", "id:i64,nome:texto"); $w->gravar(["id" => 1, "nome" => "x"]); $w->fechar(); */
declare(strict_types=1);

namespace JsonW;

final class Erro extends \RuntimeException {}

/** Linha de outro tenant depois de visao() (-3 na ABI). */
final class LinhaOculta extends \RuntimeException {}

final class Lib
{
    private const int ERRO = 320;

    private const string CDEF = <<<'C'
        const char *jsonw_versao(void);
        void *jsonw_abrir(const char *caminho, char *erro, size_t nerro);
        void jsonw_fechar(void *a);
        uint64_t jsonw_linhas(const void *a);
        int jsonw_campos(const void *a);
        const char *jsonw_esquema(const void *a);
        const char *jsonw_campo_nome(const void *a, int campo);
        int64_t jsonw_linha_json(void *a, uint64_t linha, char *saida, size_t cap);
        int64_t jsonw_linha_texto(void *a, uint64_t linha, char *saida, size_t cap);
        int64_t jsonw_campo_json(void *a, uint64_t linha, int campo, char *saida, size_t cap);
        int jsonw_conferir(void *a, char *erro, size_t nerro);
        int jsonw_visao(void *a, const char *escopos, char *erro, size_t nerro);
        int jsonw_indexar(void *a, int campo);
        int jsonw_tem_indice(const void *a, int campo);
        int64_t jsonw_chave(void *a, int campo, const char *valor, size_t n, uint64_t *linhas, size_t max);
        void *jsonw_criar(const char *caminho, const char *esquema, char *erro, size_t nerro);
        int jsonw_opcoes(void *w, int nivel, int hash, int bloco_kb);
        int jsonw_gravar_json(void *w, const char *json, size_t n, char *erro, size_t nerro);
        int jsonw_descarregar(void *w);
        int jsonw_fechar_escritor(void *w);
        int jsonw_abandonar(void *w);
        int64_t jsonw_avaliar(void *a, const char *pedido, size_t n, size_t k, char *saida, size_t cap, char *erro, size_t nerro);
        int64_t jsonw_escolher(const double *notas, size_t n, size_t k, uint64_t *linhas);
        void *jsonw_reconhecedor(const char *termos, char *erro, size_t nerro);
        void jsonw_reconhecedor_fechar(void *r);
        int64_t jsonw_reconhecer(void *r, const char *texto, size_t n, char *saida, size_t cap);
        C;

    private static ?\FFI $ffi = null;

    public static function ffi(): \FFI
    {
        return self::$ffi ??= self::carregar();
    }

    /** A biblioteca: JSONW_LIB, ao lado deste arquivo, na pasta sdk, em bin/<plataforma> do pacote ou no caminho do sistema. */
    private static function carregar(): \FFI
    {
        $win = PHP_OS_FAMILY === 'Windows';
        $maq = strtolower(php_uname('m'));
        $maq = match ($maq) { 'aarch64' => 'arm64', 'amd64' => 'x86_64', default => $maq };
        $plat = match (PHP_OS_FAMILY) { 'Windows' => 'windows', 'Darwin' => 'macos', default => 'linux' } . "-$maq";
        $nomes = $win ? ['libjsonw.dll'] : ['libjsonw.dylib', 'libjsonw.so'];

        $caminhos = array_filter([getenv('JSONW_LIB') ?: null]);
        foreach ([__DIR__, __DIR__ . '/..', __DIR__ . '/../..', __DIR__ . "/../../bin/$plat"] as $pasta) {
            foreach ($nomes as $n) {
                $caminhos[] = "$pasta/$n";
            }
        }
        array_push($caminhos, ...$nomes);

        $motivo = '';
        foreach ($caminhos as $cam) {
            if (str_contains($cam, '/') && !is_file($cam)) {
                continue;
            }
            try {
                return \FFI::cdef(self::CDEF, $cam);
            } catch (\FFI\Exception $e) {
                $motivo = $motivo ?: " ($cam: {$e->getMessage()})";
            }
        }
        throw new Erro("libjsonw nao encontrada para $plat$motivo: aponte JSONW_LIB para a biblioteca");
    }

    /** Buffer que cresce até caber (-2 = curto). */
    public static function texto(\Closure $chamada): string
    {
        for ($cap = 1 << 16; ; $cap *= 4) {
            $b = self::ffi()->new("char[$cap]");
            $n = $chamada($b, $cap);
            if ($n >= 0) {
                return \FFI::string($b, $n);
            }
            match ($n) {
                -2 => null,
                -3 => throw new LinhaOculta('linha oculta pela visao'),
                default => throw new Erro('linha ou campo ilegivel'),
            };
        }
    }

    /** Os n primeiros valores de um array C, como lista PHP. */
    public static function lista(\FFI\CData $c, int $n): array
    {
        $r = [];
        for ($i = 0; $i < $n; $i++) {
            $r[] = $c[$i];
        }
        return $r;
    }

    /** Chama com um buffer de erro; código diferente de 0 vira Erro com o texto da biblioteca. */
    public static function exigir(\Closure $chamada): void
    {
        $e = self::ffi()->new('char[' . self::ERRO . ']');
        if ($chamada($e, self::ERRO) !== 0) {
            throw new Erro(\FFI::string($e));
        }
    }

    /** Abre um handle; null vira Erro com o texto da biblioteca. */
    public static function abrir(\Closure $chamada): \FFI\CData
    {
        $e = self::ffi()->new('char[' . self::ERRO . ']');
        return $chamada($e, self::ERRO) ?? throw new Erro(\FFI::string($e));
    }

    public static function json(mixed $valor): string
    {
        return json_encode($valor, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    }

    public static function decodificar(string $json): mixed
    {
        return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    }
}

function versao(): string
{
    return Lib::ffi()->jsonw_versao();
}

/** As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior). */
function escolher(array $notas, int $k): array
{
    $f = Lib::ffi();
    $notas = array_values($notas);
    $n = count($notas);
    $v = $f->new('double[' . max($n, 1) . ']');
    foreach ($notas as $i => $x) {
        $v[$i] = (float) $x;
    }
    $out = $f->new('uint64_t[' . max($k, 1) . ']');
    return Lib::lista($out, max($f->jsonw_escolher($v, $n, $k, $out), 0));
}

/** @implements \IteratorAggregate<int, array> */
final class Leitor implements \IteratorAggregate, \Countable
{
    private ?\FFI\CData $a;
    public readonly int $linhas;
    public private(set) string $esquema = '';
    /** @var list<string> */
    public private(set) array $campos = [];

    public function __construct(string $caminho)
    {
        $f = Lib::ffi();
        $this->a = Lib::abrir(static fn($e, $n) => $f->jsonw_abrir($caminho, $e, $n));
        $this->linhas = $f->jsonw_linhas($this->a);
        $this->lerEsquema();
    }

    public function __destruct()
    {
        $this->fechar();
    }

    public function fechar(): void
    {
        if ($this->a !== null) {
            Lib::ffi()->jsonw_fechar($this->a);
            $this->a = null;
        }
    }

    private function lerEsquema(): void
    {
        $f = Lib::ffi();
        $this->esquema = $f->jsonw_esquema($this->a);
        $campos = [];
        for ($i = 0, $n = $f->jsonw_campos($this->a); $i < $n; $i++) {
            $campos[] = $f->jsonw_campo_nome($this->a, $i);
        }
        $this->campos = $campos;
    }

    public function json(int $i): string
    {
        return Lib::texto(fn($b, $c) => Lib::ffi()->jsonw_linha_json($this->a, $i, $b, $c));
    }

    public function texto(int $i): string
    {
        return Lib::texto(fn($b, $c) => Lib::ffi()->jsonw_linha_texto($this->a, $i, $b, $c));
    }

    public function linha(int $i): array
    {
        return Lib::decodificar($this->json($i));
    }

    public function campo(int $i, int|string $campo): mixed
    {
        $k = $this->indice($campo);
        return Lib::decodificar(Lib::texto(fn($b, $c) => Lib::ffi()->jsonw_campo_json($this->a, $i, $k, $b, $c)));
    }

    public function indice(int|string $campo): int
    {
        if (is_int($campo)) {
            return $campo;
        }
        $k = array_search($campo, $this->campos, true);
        return $k === false ? throw new Erro("campo inexistente: $campo") : $k;
    }

    public function conferir(): true
    {
        Lib::exigir(fn($e, $n) => Lib::ffi()->jsonw_conferir($this->a, $e, $n));
        return true;
    }

    /** Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = LinhaOculta. */
    public function visao(string $escopos): static
    {
        Lib::exigir(fn($e, $n) => Lib::ffi()->jsonw_visao($this->a, $escopos, $e, $n));
        $this->lerEsquema();
        return $this;
    }

    public function indexar(int|string $campo): static
    {
        if (Lib::ffi()->jsonw_indexar($this->a, $this->indice($campo)) !== 0) {
            throw new Erro('campo sem indice');
        }
        return $this;
    }

    public function temIndice(int|string $campo): bool
    {
        return Lib::ffi()->jsonw_tem_indice($this->a, $this->indice($campo)) === 1;
    }

    /** As linhas em que o campo vale $valor (2, "RJ", null), em ordem crescente. */
    public function chave(int|string $campo, mixed $valor): array
    {
        $f = Lib::ffi();
        $k = $this->indice($campo);
        $v = Lib::json($valor);
        for ($cap = 16; ;) {
            $out = $f->new("uint64_t[$cap]");
            $n = $f->jsonw_chave($this->a, $k, $v, strlen($v), $out, $cap);
            if ($n === -2) {
                throw new Erro('valor nao e do tipo do campo');
            }
            if ($n < 0) {
                throw new Erro('campo invalido');
            }
            if ($n <= $cap) {
                return Lib::lista($out, $n);
            }
            $cap = $n;
        }
    }

    /** As k melhores linhas pelo pedido, como a ABI devolve: [{"linha","nota"}]. */
    public function avaliarJson(string|array $pedido, int $k = 10): string
    {
        $p = is_string($pedido) ? $pedido : Lib::json($pedido);
        $f = Lib::ffi();
        $e = $f->new('char[320]');
        return Lib::texto(function ($b, $c) use ($f, $p, $k, $e): int {
            $n = $f->jsonw_avaliar($this->a, $p, strlen($p), $k, $b, $c, $e, 320);
            return $n === -1 ? throw new Erro(\FFI::string($e)) : $n;
        });
    }

    public function avaliar(string|array $pedido, int $k = 10): array
    {
        return Lib::decodificar($this->avaliarJson($pedido, $k));
    }

    /** Com visão, as linhas de outro tenant ficam de fora. */
    public function getIterator(): \Generator
    {
        for ($i = 0; $i < $this->linhas; $i++) {
            try {
                $linha = $this->linha($i);
            } catch (LinhaOculta) {
                continue;
            }
            yield $i => $linha;
        }
    }

    public function count(): int
    {
        return $this->linhas;
    }
}

/** Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais achados no texto. */
final class Reconhecedor
{
    private ?\FFI\CData $r;

    public function __construct(string $termosJsw)
    {
        $f = Lib::ffi();
        $this->r = Lib::abrir(static fn($e, $n) => $f->jsonw_reconhecedor($termosJsw, $e, $n));
    }

    public function __destruct()
    {
        $this->fechar();
    }

    public function fechar(): void
    {
        if ($this->r !== null) {
            Lib::ffi()->jsonw_reconhecedor_fechar($this->r);
            $this->r = null;
        }
    }

    public function reconhecerJson(string $texto): string
    {
        return Lib::texto(fn($b, $c) => Lib::ffi()->jsonw_reconhecer($this->r, $texto, strlen($texto), $b, $c));
    }

    public function reconhecer(string $texto): array
    {
        return Lib::decodificar($this->reconhecerJson($texto));
    }
}

/** O destino só aparece no fechar(); abandonar() desiste e deixa o destino como estava. */
final class Escritor
{
    private ?\FFI\CData $w;

    public function __construct(string $caminho, string $esquema, int $compressao = 1, int $hash = 0, int $blocoKb = 0)
    {
        $f = Lib::ffi();
        $this->w = Lib::abrir(static fn($e, $n) => $f->jsonw_criar($caminho, $esquema, $e, $n));
        $f->jsonw_opcoes($this->w, $compressao, $hash, $blocoKb);
    }

    public function __destruct()
    {
        $this->fechar();
    }

    public function gravarTexto(string $texto): void
    {
        Lib::exigir(fn($e, $n) => Lib::ffi()->jsonw_gravar_json($this->w, $texto, strlen($texto), $e, $n));
    }

    public function gravar(array $obj): void
    {
        $this->gravarTexto(Lib::json($obj));
    }

    public function descarregar(): void
    {
        Lib::ffi()->jsonw_descarregar($this->w);
    }

    public function fechar(): void
    {
        if ($this->w === null) {
            return;
        }
        [$w, $this->w] = [$this->w, null];
        if (Lib::ffi()->jsonw_fechar_escritor($w) !== 0) {
            throw new Erro('nao gravou tudo');
        }
    }

    public function abandonar(): void
    {
        if ($this->w !== null) {
            [$w, $this->w] = [$this->w, null];
            Lib::ffi()->jsonw_abandonar($w);
        }
    }
}

/* php jsonw.php arq.jsw -> JSONL; --avaliar arq pedido k; --visao arq escopos pedido k; --reconhecer termos.jsw texto */
if (PHP_SAPI === 'cli' && realpath($argv[0] ?? '') === __FILE__ && isset($argv[1])) {
    match ($argv[1]) {
        '--avaliar' => print (new Leitor($argv[2]))->avaliarJson($argv[3], (int) $argv[4]) . "\n",
        '--reconhecer' => print (new Reconhecedor($argv[2]))->reconhecerJson($argv[3]) . "\n",
        '--visao' => (static function (array $argv): void {
            $a = (new Leitor($argv[2]))->visao($argv[3]);
            echo implode(',', $a->campos), "\n";
            for ($i = 0; $i < $a->linhas; $i++) {
                try {
                    echo $a->json($i), "\n";
                } catch (LinhaOculta) {
                }
            }
            echo $a->avaliarJson($argv[4], (int) $argv[5]), "\n";
        })($argv),
        default => (static function (string $arq): void {
            $a = new Leitor($arq);
            for ($i = 0; $i < $a->linhas; $i++) {
                echo $a->json($i), "\n";
            }
        })($argv[1]),
    };
}
