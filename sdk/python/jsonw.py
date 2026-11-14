"""jsonW para Python 3.10+, por cima da ABI C (libjsonw). Sem dependência além da biblioteca padrão.

    import jsonw
    with jsonw.Leitor("dados.jsw") as a:
        for linha in a:
            ...
    with jsonw.Escritor("novo.jsw", "id:i64,nome:texto,preco:decimal[2]") as w:
        w.gravar({"id": 1, "nome": "x", "preco": "12.50"})
"""

from __future__ import annotations

import ctypes
import json
import os
import platform
import sys
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path
from types import TracebackType
from typing import TYPE_CHECKING, Any, TypeAlias

if TYPE_CHECKING:
    from typing_extensions import Self

__all__ = ["ErroJsonW", "Escritor", "Leitor", "LinhaOculta", "Reconhecedor", "escolher", "versao"]

Pedido: TypeAlias = "str | dict[str, Any]"

_ERRO = 320


class ErroJsonW(Exception):
    pass


class LinhaOculta(ErroJsonW):
    """Linha de outro tenant depois de visao() (-3 na ABI)."""


def _plataforma() -> str:
    so = {"darwin": "macos", "win32": "windows"}.get(sys.platform, "linux")
    maq = platform.machine().lower()
    return f"{so}-{ {'aarch64': 'arm64', 'amd64': 'x86_64'}.get(maq, maq) }"


def _carregar() -> ctypes.CDLL:
    """JSONW_LIB, ao lado deste arquivo, na pasta sdk, em bin/<plataforma> do pacote ou no caminho do sistema."""
    if dito := os.environ.get("JSONW_LIB"):
        return ctypes.CDLL(dito)
    aqui = Path(__file__).resolve().parent
    nomes = ["libjsonw.dll", "jsonw.dll"] if sys.platform == "win32" else ["libjsonw.dylib", "libjsonw.so"]
    for pasta in (aqui, aqui.parent, aqui.parent.parent, aqui.parent.parent / "bin" / _plataforma()):
        for n in nomes:
            if (cam := pasta / n).exists():
                try:
                    return ctypes.CDLL(str(cam))
                except OSError:
                    continue
    for n in nomes:
        try:
            return ctypes.CDLL(n)
        except OSError:
            continue
    raise OSError(f"libjsonw nao encontrada para {_plataforma()}: aponte JSONW_LIB para a biblioteca")


_l = _carregar()

_P, _S, _I, _U, _L, _C, _D = (
    ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int, ctypes.c_uint64, ctypes.c_int64, ctypes.c_char_p, ctypes.c_double,
)
_U_PTR = ctypes.POINTER(_U)

for _nome, _ret, _args in (
    ("versao", _C, []),
    ("abrir", _P, [_C, _C, _S]),
    ("fechar", None, [_P]),
    ("linhas", _U, [_P]),
    ("campos", _I, [_P]),
    ("esquema", _C, [_P]),
    ("campo_nome", _C, [_P, _I]),
    ("linha_json", _L, [_P, _U, _C, _S]),
    ("linha_texto", _L, [_P, _U, _C, _S]),
    ("campo_json", _L, [_P, _U, _I, _C, _S]),
    ("conferir", _I, [_P, _C, _S]),
    ("visao", _I, [_P, _C, _C, _S]),
    ("indexar", _I, [_P, _I]),
    ("tem_indice", _I, [_P, _I]),
    ("chave", _L, [_P, _I, _C, _S, _U_PTR, _S]),
    ("criar", _P, [_C, _C, _C, _S]),
    ("opcoes", _I, [_P, _I, _I, _I]),
    ("gravar_json", _I, [_P, _C, _S, _C, _S]),
    ("descarregar", _I, [_P]),
    ("fechar_escritor", _I, [_P]),
    ("abandonar", _I, [_P]),
    ("avaliar", _L, [_P, _C, _S, _S, _C, _S, _C, _S]),
    ("escolher", _L, [ctypes.POINTER(_D), _S, _S, _U_PTR]),
    ("reconhecedor", _P, [_C, _C, _S]),
    ("reconhecedor_fechar", None, [_P]),
    ("reconhecer", _L, [_P, _C, _S, _C, _S]),
):
    _f = getattr(_l, f"jsonw_{_nome}")
    _f.restype, _f.argtypes = _ret, _args

versao: str = _l.jsonw_versao().decode()


def _texto(chamada: Callable[[ctypes.Array[ctypes.c_char], int], int]) -> str:
    """Buffer que cresce até caber (-2 = curto)."""
    cap = 1 << 16
    while True:
        b = ctypes.create_string_buffer(cap)
        match chamada(b, cap):
            case -2:
                cap *= 4
            case -3:
                raise LinhaOculta("linha oculta pela visao")
            case n if n < 0:
                raise ErroJsonW("linha ou campo ilegivel")
            case n:
                return b.raw[:n].decode()


def _exigir(chamada: Callable[[ctypes.Array[ctypes.c_char], int], int]) -> None:
    """Chama com um buffer de erro; código diferente de 0 vira ErroJsonW com o texto da biblioteca."""
    e = ctypes.create_string_buffer(_ERRO)
    if chamada(e, _ERRO):
        raise ErroJsonW(e.value.decode())


def _abrir(chamada: Callable[[ctypes.Array[ctypes.c_char], int], int | None]) -> int:
    """Abre um handle; nulo vira ErroJsonW com o texto da biblioteca."""
    e = ctypes.create_string_buffer(_ERRO)
    if not (h := chamada(e, _ERRO)):
        raise ErroJsonW(e.value.decode())
    return h


def _json(valor: Any) -> bytes:
    return json.dumps(valor, ensure_ascii=False, separators=(",", ":")).encode()


class Leitor:
    linhas: int
    esquema: str
    campos: list[str]

    def __init__(self, caminho: str | os.PathLike[str]) -> None:
        c = os.fsencode(caminho)
        self._a: int | None = _abrir(lambda e, n: _l.jsonw_abrir(c, e, n))
        self.linhas = _l.jsonw_linhas(self._a)
        self._ler_esquema()

    def _ler_esquema(self) -> None:
        self.esquema = _l.jsonw_esquema(self._a).decode()
        self.campos = [_l.jsonw_campo_nome(self._a, i).decode() for i in range(_l.jsonw_campos(self._a))]

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        self.fechar()

    def fechar(self) -> None:
        if self._a:
            _l.jsonw_fechar(self._a)
            self._a = None

    def indice(self, campo: int | str) -> int:
        if isinstance(campo, int):
            return campo
        try:
            return self.campos.index(campo)
        except ValueError:
            raise ErroJsonW(f"campo inexistente: {campo}") from None

    def json(self, i: int) -> str:
        return _texto(lambda b, cap: _l.jsonw_linha_json(self._a, i, b, cap))

    def texto(self, i: int) -> str:
        return _texto(lambda b, cap: _l.jsonw_linha_texto(self._a, i, b, cap))

    def linha(self, i: int) -> dict[str, Any]:
        return json.loads(self.json(i))

    def campo(self, i: int, campo: int | str) -> Any:
        k = self.indice(campo)
        return json.loads(_texto(lambda b, cap: _l.jsonw_campo_json(self._a, i, k, b, cap)))

    def conferir(self) -> bool:
        _exigir(lambda e, n: _l.jsonw_conferir(self._a, e, n))
        return True

    def visao(self, escopos: str) -> Self:
        """Trava o que a sessão vê ("pessoal vendas tenant:42"); linha de outro tenant = LinhaOculta."""
        _exigir(lambda e, n: _l.jsonw_visao(self._a, escopos.encode(), e, n))
        self._ler_esquema()
        return self

    def indexar(self, campo: int | str) -> Self:
        if _l.jsonw_indexar(self._a, self.indice(campo)):
            raise ErroJsonW("campo sem indice")
        return self

    def tem_indice(self, campo: int | str) -> bool:
        return _l.jsonw_tem_indice(self._a, self.indice(campo)) == 1

    def chave(self, campo: int | str, valor: Any) -> list[int]:
        """As linhas em que o campo vale `valor` (7, "RJ", None), em ordem crescente."""
        k, v, cap = self.indice(campo), _json(valor), 16
        while True:
            out = (_U * cap)()
            match _l.jsonw_chave(self._a, k, v, len(v), out, cap):
                case -2:
                    raise ErroJsonW("valor nao e do tipo do campo")
                case n if n < 0:
                    raise ErroJsonW("campo invalido")
                case n if n <= cap:
                    return list(out[:n])
                case n:
                    cap = n

    def avaliar_json(self, pedido: Pedido, k: int = 10) -> str:
        """As k melhores linhas pelo pedido, como a ABI devolve: [{"linha", "nota"}], maior nota primeiro."""
        p = pedido.encode() if isinstance(pedido, str) else _json(pedido)
        e = ctypes.create_string_buffer(_ERRO)

        def chamada(b: ctypes.Array[ctypes.c_char], cap: int) -> int:
            n = _l.jsonw_avaliar(self._a, p, len(p), k, b, cap, e, _ERRO)
            if n == -1:
                raise ErroJsonW(e.value.decode())
            return n

        return _texto(chamada)

    def avaliar(self, pedido: Pedido, k: int = 10) -> list[dict[str, float]]:
        return json.loads(self.avaliar_json(pedido, k))

    def __iter__(self) -> Iterator[dict[str, Any]]:
        """Com visão, as linhas de outro tenant ficam de fora."""
        for i in range(self.linhas):
            try:
                yield self.linha(i)
            except LinhaOculta:
                continue

    def __len__(self) -> int:
        return self.linhas


def escolher(notas: Sequence[float], k: int) -> list[int]:
    """As posições das k maiores notas (maior primeiro; empate pela menor posição; NaN é a pior)."""
    v = (_D * max(len(notas), 1))(*notas)
    out = (_U * max(k, 1))()
    m = _l.jsonw_escolher(v, len(notas), k, out)
    return list(out[: max(m, 0)])


class Reconhecedor:
    """Tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> termos e sinais do texto."""

    def __init__(self, caminho: str | os.PathLike[str]) -> None:
        c = os.fsencode(caminho)
        self._r: int | None = _abrir(lambda e, n: _l.jsonw_reconhecedor(c, e, n))

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        self.fechar()

    def fechar(self) -> None:
        if self._r:
            _l.jsonw_reconhecedor_fechar(self._r)
            self._r = None

    def reconhecer_json(self, texto: str) -> str:
        t = texto.encode()
        return _texto(lambda b, cap: _l.jsonw_reconhecer(self._r, t, len(t), b, cap))

    def reconhecer(self, texto: str) -> dict[str, list[dict[str, Any]]]:
        """{"termos": [{"termo", "ini", "fim", "texto", "sinal", "peso"}], "sinais": [{"sinal", "soma", "vezes"}]}"""
        return json.loads(self.reconhecer_json(texto))


class Escritor:
    """O destino só aparece no fechar(); saindo do `with` por erro, abandona e o destino fica como estava."""

    def __init__(
        self, caminho: str | os.PathLike[str], esquema: str, compressao: int = 1, hash_alg: int = 0, bloco_kb: int = 0
    ) -> None:
        c = os.fsencode(caminho)
        self._w: int | None = _abrir(lambda e, n: _l.jsonw_criar(c, esquema.encode(), e, n))
        _l.jsonw_opcoes(self._w, compressao, hash_alg, bloco_kb)

    def __enter__(self) -> Self:
        return self

    def __exit__(self, tipo: type[BaseException] | None, *_: object) -> None:
        if tipo is None:
            self.fechar()
        else:
            self.abandonar()

    def gravar_texto(self, texto: str) -> None:
        b = texto.encode()
        _exigir(lambda e, n: _l.jsonw_gravar_json(self._w, b, len(b), e, n))

    def gravar(self, obj: dict[str, Any]) -> None:
        self.gravar_texto(_json(obj).decode())

    def descarregar(self) -> None:
        _l.jsonw_descarregar(self._w)

    def abandonar(self) -> None:
        if w := self._w:
            self._w = None
            _l.jsonw_abandonar(w)

    def fechar(self) -> None:
        if w := self._w:
            self._w = None
            if _l.jsonw_fechar_escritor(w):
                raise ErroJsonW("nao gravou tudo")


def _cli(argv: list[str]) -> None:
    """jsonw.py arq.jsw -> JSONL; --avaliar arq pedido k; --visao arq escopos pedido k; --reconhecer termos.jsw texto"""
    saida = sys.stdout.write
    match argv[1:]:
        case ["--avaliar", arq, pedido, k]:
            with Leitor(arq) as a:
                print(a.avaliar_json(pedido, int(k)))
        case ["--visao", arq, escopos, pedido, k]:
            with Leitor(arq) as a:
                a.visao(escopos)
                print(",".join(a.campos))
                for i in range(a.linhas):
                    try:
                        saida(a.json(i) + "\n")
                    except LinhaOculta:
                        continue
                print(a.avaliar_json(pedido, int(k)))
        case ["--reconhecer", termos, texto]:
            with Reconhecedor(termos) as r:
                print(r.reconhecer_json(texto))
        case [arq]:
            with Leitor(arq) as a:
                for i in range(a.linhas):
                    saida(a.json(i) + "\n")
        case _:
            raise SystemExit("uso: jsonw.py arquivo.jsw")


if __name__ == "__main__":
    _cli(sys.argv)
