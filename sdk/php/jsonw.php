<?php
/* jsonW (json Wondrous) para PHP 8+, por cima da ABI C (libjsonw) com a extensao FFI. Sem dependencia.
 *   $a = new JsonW\Leitor("dados.jsw"); foreach ($a as $linha) { ... }   // cada linha como array (JSON)
 *   $w = new JsonW\Escritor("novo.jsw", "id:i64,nome:texto"); $w->gravar(["id" => 1, "nome" => "x"]); $w->fechar(); */
namespace JsonW;

final class Lib {
    private static ?\FFI $ffi = null;
    public static function ffi(): \FFI {
        if (self::$ffi) return self::$ffi;
        $cdef = "const char *jsonw_versao(void);
            void *jsonw_abrir(const char *caminho, char *erro, size_t nerro); void jsonw_fechar(void *a);
            uint64_t jsonw_linhas(const void *a); int jsonw_campos(const void *a); const char *jsonw_esquema(const void *a);
            const char *jsonw_campo_nome(const void *a, int campo);
            int64_t jsonw_linha_json(void *a, uint64_t linha, char *saida, size_t cap); int64_t jsonw_linha_texto(void *a, uint64_t linha, char *saida, size_t cap);
            int64_t jsonw_campo_json(void *a, uint64_t linha, int campo, char *saida, size_t cap); int jsonw_conferir(void *a, char *erro, size_t nerro);
            void *jsonw_criar(const char *caminho, const char *esquema, char *erro, size_t nerro); int jsonw_opcoes(void *w, int nivel, int hash, int bloco_kb);
            int jsonw_gravar_json(void *w, const char *json, size_t n, char *erro, size_t nerro); int jsonw_descarregar(void *w); int jsonw_fechar_escritor(void *w); int jsonw_abandonar(void *w);
            int64_t jsonw_avaliar(void *a, const char *pedido, size_t n, size_t k, char *saida, size_t cap, char *erro, size_t nerro); int64_t jsonw_escolher(const double *notas, size_t n, size_t k, uint64_t *linhas);
            void *jsonw_reconhecedor(const char *termos, char *erro, size_t nerro); void jsonw_reconhecedor_fechar(void *r); int64_t jsonw_reconhecer(void *r, const char *texto, size_t n, char *saida, size_t cap); int jsonw_visao(void *a, const char *escopos, char *erro, size_t nerro);";
        /* a biblioteca: JSONW_LIB (caminho inteiro), ao lado deste arquivo, na pasta sdk ou em bin/<plataforma> do pacote */
        $win = PHP_OS_FAMILY === "Windows"; $maq = strtolower(php_uname("m")); $maq = ["aarch64" => "arm64", "amd64" => "x86_64"][$maq] ?? $maq;
        $plat = ($win ? "windows" : (PHP_OS_FAMILY === "Darwin" ? "macos" : "linux")) . "-" . $maq;
        $nomes = $win ? ["libjsonw.dll"] : ["libjsonw.dylib", "libjsonw.so"]; $cams = [];
        if (getenv("JSONW_LIB")) $cams[] = getenv("JSONW_LIB");
        foreach ([__DIR__, __DIR__ . "/..", __DIR__ . "/../..", __DIR__ . "/../../bin/" . $plat] as $pasta) foreach ($nomes as $n) $cams[] = $pasta . "/" . $n;
        foreach ($nomes as $n) $cams[] = $n;
        $motivo = "";
        foreach ($cams as $cam) {
            if (str_contains($cam, "/") && !file_exists($cam)) continue;
            try { self::$ffi = \FFI::cdef($cdef, $cam); return self::$ffi; } catch (\Throwable $e) { if ($motivo === "") $motivo = " (" . $cam . ": " . $e->getMessage() . ")"; }
        }
        throw new \RuntimeException("libjsonw nao encontrada para $plat$motivo: aponte JSONW_LIB para a biblioteca (bin/<plataforma>/ do pacote) ou copie-a para a pasta sdk");
    }
    public static function texto(callable $fn): string {   /* chama fn(saida, cap) ate caber */
        $cap = 1 << 16;
        for (;;) {
            $b = self::ffi()->new("char[$cap]"); $n = $fn($b, $cap);
            if ($n == -2) { $cap *= 4; continue; }
            if ($n == -3) throw new LinhaOculta("linha oculta pela visao");
            if ($n < 0) throw new \RuntimeException("linha ou campo ilegivel");
            return \FFI::string($b, $n);
        }
    }
}

final class LinhaOculta extends \RuntimeException {}   /* linha de outro tenant depois de visao() (-3 na ABI) */
final class Leitor implements \IteratorAggregate, \Countable {
    private $a; public int $linhas; public string $esquema; public array $campos = [];
    public function __construct(string $caminho) {
        $f = Lib::ffi(); $e = Lib::ffi()->new("char[200]");
        $this->a = $f->jsonw_abrir($caminho, $e, 200);
        if ($this->a === null) throw new \RuntimeException(\FFI::string($e));
        $this->linhas = (int)$f->jsonw_linhas($this->a); $this->esquema = $f->jsonw_esquema($this->a);
        for ($i = 0; $i < $f->jsonw_campos($this->a); $i++) $this->campos[] = $f->jsonw_campo_nome($this->a, $i);
    }
    public function __destruct() { $this->fechar(); }
    public function fechar(): void { if ($this->a !== null) { Lib::ffi()->jsonw_fechar($this->a); $this->a = null; } }
    public function json(int $i): string { $f = Lib::ffi(); $a = $this->a; return Lib::texto(fn($b, $c) => $f->jsonw_linha_json($a, $i, $b, $c)); }
    public function texto(int $i): string { $f = Lib::ffi(); $a = $this->a; return Lib::texto(fn($b, $c) => $f->jsonw_linha_texto($a, $i, $b, $c)); }
    public function linha(int $i): array { return json_decode($this->json($i), true, 512, JSON_THROW_ON_ERROR); }
    public function campo(int $i, int|string $campo): mixed { $k = is_int($campo) ? $campo : array_search($campo, $this->campos, true); $f = Lib::ffi(); $a = $this->a; return json_decode(Lib::texto(fn($b, $c) => $f->jsonw_campo_json($a, $i, $k, $b, $c)), true); }
    public function conferir(): bool { $e = Lib::ffi()->new("char[200]"); if (Lib::ffi()->jsonw_conferir($this->a, $e, 200)) throw new \RuntimeException(\FFI::string($e)); return true; }
    public function visao(string $escopos): static { $f = Lib::ffi(); $e = $f->new("char[300]"); if ($f->jsonw_visao($this->a, $escopos, $e, 300)) throw new \RuntimeException(\FFI::string($e)); $this->esquema = $f->jsonw_esquema($this->a); $this->campos = []; for ($i = 0; $i < $f->jsonw_campos($this->a); $i++) $this->campos[] = $f->jsonw_campo_nome($this->a, $i); return $this; }   /* trava o que a sessao ve */
    public function avaliarJson(string|array $pedido, int $k = 10): string {   /* AVALIAR + ESCOLHER: as k melhores, [{"linha","nota"}] */
        $p = is_string($pedido) ? $pedido : json_encode($pedido, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR); $f = Lib::ffi(); $a = $this->a; $e = $f->new("char[300]");
        return Lib::texto(function ($b, $c) use ($f, $a, $p, $k, $e) { $n = $f->jsonw_avaliar($a, $p, strlen($p), $k, $b, $c, $e, 300); if ($n == -1) throw new \RuntimeException(\FFI::string($e)); return $n; });
    }
    public function avaliar(string|array $pedido, int $k = 10): array { return json_decode($this->avaliarJson($pedido, $k), true, 512, JSON_THROW_ON_ERROR); }
    public function getIterator(): \Generator { for ($i = 0; $i < $this->linhas; $i++) { try { $l = $this->linha($i); } catch (LinhaOculta) { continue; } yield $l; } }
    public function count(): int { return $this->linhas; }
}

function escolher(array $notas, int $k): array {   /* posicoes das k maiores notas (maior primeiro; empate pela menor posicao) */
    $f = Lib::ffi(); $n = count($notas); $v = $f->new("double[" . max($n, 1) . "]"); foreach (array_values($notas) as $i => $x) $v[$i] = (float)$x;
    $out = $f->new("uint64_t[" . max($k, 1) . "]"); $m = $f->jsonw_escolher($v, $n, $k, $out); $r = []; for ($i = 0; $i < $m; $i++) $r[] = (int)$out[$i]; return $r;
}

final class Reconhecedor {   /* tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor */
    private $r;
    public function __construct(string $termosJsw) { $f = Lib::ffi(); $e = $f->new("char[300]"); $this->r = $f->jsonw_reconhecedor($termosJsw, $e, 300); if ($this->r === null) throw new \RuntimeException(\FFI::string($e)); }
    public function __destruct() { $this->fechar(); }
    public function fechar(): void { if ($this->r !== null) { Lib::ffi()->jsonw_reconhecedor_fechar($this->r); $this->r = null; } }
    public function reconhecerJson(string $texto): string { $f = Lib::ffi(); $r = $this->r; return Lib::texto(fn($b, $c) => $f->jsonw_reconhecer($r, $texto, strlen($texto), $b, $c)); }
    public function reconhecer(string $texto): array { return json_decode($this->reconhecerJson($texto), true, 512, JSON_THROW_ON_ERROR); }   /* {termos: [...], sinais: [...]} */
}

final class Escritor {
    private $w;
    public function __construct(string $caminho, string $esquema, int $compressao = 1, int $hash = 0, int $blocoKb = 0) {
        $f = Lib::ffi(); $e = Lib::ffi()->new("char[200]");
        $this->w = $f->jsonw_criar($caminho, $esquema, $e, 200);
        if ($this->w === null) throw new \RuntimeException(\FFI::string($e));
        $f->jsonw_opcoes($this->w, $compressao, $hash, $blocoKb);
    }
    public function gravarTexto(string $texto): void { $e = Lib::ffi()->new("char[200]"); if (Lib::ffi()->jsonw_gravar_json($this->w, $texto, strlen($texto), $e, 200)) throw new \RuntimeException(\FFI::string($e)); }
    public function gravar(array $obj): void { $this->gravarTexto(json_encode($obj, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)); }
    public function descarregar(): void { Lib::ffi()->jsonw_descarregar($this->w); }
    public function fechar(): void { if ($this->w !== null) { $r = Lib::ffi()->jsonw_fechar_escritor($this->w); $this->w = null; if ($r) throw new \RuntimeException("nao gravou tudo"); } }
    public function abandonar(): void { if ($this->w !== null) { Lib::ffi()->jsonw_abandonar($this->w); $this->w = null; } }   /* desiste: fecha sem publicar; o destino fica como estava */
    public function __destruct() { $this->fechar(); }
}

if (PHP_SAPI === "cli" && isset($argv) && realpath($argv[0]) === __FILE__ && isset($argv[1])) {   /* php jsonw.php arquivo.jsw -> JSONL; --avaliar arq pedido k; --reconhecer termos.jsw texto */
    if ($argv[1] === "--avaliar") { $a = new Leitor($argv[2]); echo $a->avaliarJson($argv[3], (int)$argv[4]), "\n"; }
    elseif ($argv[1] === "--visao") { $a = (new Leitor($argv[2]))->visao($argv[3]); echo implode(",", $a->campos), "\n"; for ($i = 0; $i < $a->linhas; $i++) { try { echo $a->json($i), "\n"; } catch (LinhaOculta) {} } echo $a->avaliarJson($argv[4], (int)$argv[5]), "\n"; }
    elseif ($argv[1] === "--reconhecer") { $r = new Reconhecedor($argv[2]); echo $r->reconhecerJson($argv[3]), "\n"; }
    else { $a = new Leitor($argv[1]); for ($i = 0; $i < $a->linhas; $i++) echo $a->json($i), "\n"; }
}
