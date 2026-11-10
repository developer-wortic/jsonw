"""jsonW (json Wondrous) para Python, por cima da ABI C (libjsonw). Sem dependencia alem da biblioteca padrao.

    import jsonw
    with jsonw.Leitor("dados.jsw") as a:
        print(a.esquema, a.linhas)
        for linha in a:            # cada linha como dict (JSON)
            ...
    with jsonw.Escritor("novo.jsw", "id:i64,nome:texto,preco:decimal[2]") as w:
        w.gravar({"id": 1, "nome": "x", "preco": "12.50"})   # ou w.gravar_texto("{id: 1, nome: 'x', preco: 12,50d}")
"""
import ctypes, json, os, sys

def _plataforma():   # o nome da pasta de bin/ no pacote publico (bin/macos-arm64, bin/linux-x86_64, bin/windows-x86_64)
    import platform
    so = {"darwin": "macos", "win32": "windows"}.get(sys.platform, "linux")
    maq = platform.machine().lower()
    return so + "-" + {"aarch64": "arm64", "amd64": "x86_64"}.get(maq, maq)

def _carregar():
    """A biblioteca: JSONW_LIB (caminho inteiro), ao lado deste arquivo, na pasta sdk ou em bin/<plataforma> do pacote."""
    aqui = os.path.dirname(os.path.abspath(__file__))
    nomes = ["libjsonw.dylib", "libjsonw.so"] if sys.platform != "win32" else ["libjsonw.dll", "jsonw.dll"]
    dito = os.environ.get("JSONW_LIB")
    if dito:
        return ctypes.CDLL(dito)
    pastas = (aqui, os.path.join(aqui, ".."), os.path.join(aqui, "..", ".."), os.path.join(aqui, "..", "..", "bin", _plataforma()), "")
    for pasta in pastas:
        for n in nomes:
            cam = os.path.join(pasta, n) if pasta else n
            if pasta and not os.path.exists(cam):
                continue
            try:
                return ctypes.CDLL(cam)
            except OSError:
                pass
    raise OSError("libjsonw nao encontrada para " + _plataforma() + ": aponte JSONW_LIB para a biblioteca (bin/<plataforma>/libjsonw.dylib|.so|.dll do pacote) ou copie-a para a pasta sdk")

_l = _carregar()
_P, _S, _I, _U, _L, _C = ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int, ctypes.c_uint64, ctypes.c_int64, ctypes.c_char_p   # _L: int64_t na ABI (o mesmo tamanho em todo sistema)
for _n, _r, _a in [("versao", _C, []), ("abrir", _P, [_C, _C, _S]), ("fechar", None, [_P]), ("linhas", _U, [_P]), ("campos", _I, [_P]), ("esquema", _C, [_P]), ("campo_nome", _C, [_P, _I]),
                   ("linha_json", _L, [_P, _U, _C, _S]), ("linha_texto", _L, [_P, _U, _C, _S]), ("campo_json", _L, [_P, _U, _I, _C, _S]), ("conferir", _I, [_P, _C, _S]), ("criar", _P, [_C, _C, _C, _S]),
                   ("opcoes", _I, [_P, _I, _I, _I]), ("gravar_json", _I, [_P, _C, _S, _C, _S]), ("descarregar", _I, [_P]), ("fechar_escritor", _I, [_P]), ("abandonar", _I, [_P]), ("visao", _I, [_P, _C, _C, _S])]:
    _f = getattr(_l, "jsonw_" + _n); _f.restype = _r; _f.argtypes = _a
versao = _l.jsonw_versao().decode()

class ErroJsonW(Exception):
    pass
class LinhaOculta(ErroJsonW): pass   # linha de outro tenant depois de visao() (-3 na ABI)

def _texto(fn, *args):
    cap = 1 << 16
    while True:
        b = ctypes.create_string_buffer(cap)
        n = fn(*args, b, cap)
        if n == -2: cap *= 4; continue
        if n == -3: raise LinhaOculta("linha oculta pela visao")
        if n < 0: raise ErroJsonW("linha ou campo ilegivel")
        return b.raw[:n].decode()

class Leitor:
    def __init__(self, caminho):
        e = ctypes.create_string_buffer(200)
        self._a = _l.jsonw_abrir(caminho.encode(), e, 200)
        if not self._a:
            raise ErroJsonW(e.value.decode())
        self.linhas = _l.jsonw_linhas(self._a); self.esquema = _l.jsonw_esquema(self._a).decode()
        self.campos = [_l.jsonw_campo_nome(self._a, i).decode() for i in range(_l.jsonw_campos(self._a))]
    def __enter__(self): return self
    def __exit__(self, *x): self.fechar()
    def fechar(self):
        if self._a: _l.jsonw_fechar(self._a); self._a = None
    def json(self, i): return _texto(_l.jsonw_linha_json, self._a, i)
    def texto(self, i): return _texto(_l.jsonw_linha_texto, self._a, i)
    def linha(self, i): return json.loads(self.json(i))
    def campo(self, i, campo):
        k = campo if isinstance(campo, int) else self.campos.index(campo)
        return json.loads(_texto(_l.jsonw_campo_json, self._a, i, k))
    def conferir(self):
        e = ctypes.create_string_buffer(200)
        if _l.jsonw_conferir(self._a, e, 200): raise ErroJsonW(e.value.decode())
        return True
    def __iter__(self):   # com visao, as linhas de outro tenant ficam de fora
        for i in range(self.linhas):
            try: yield self.linha(i)
            except LinhaOculta: pass
    def __len__(self): return self.linhas

class Escritor:
    def __init__(self, caminho, esquema, compressao=1, hash_alg=0, bloco_kb=0):
        e = ctypes.create_string_buffer(200); self._w = _l.jsonw_criar(caminho.encode(), esquema.encode(), e, 200)
        if not self._w: raise ErroJsonW(e.value.decode())
        _l.jsonw_opcoes(self._w, compressao, hash_alg, bloco_kb)
    def __enter__(self): return self
    def __exit__(self, tipo, *x):   # saiu do with por erro: nada e publicado (o arquivo pela metade nao toma o lugar do destino)
        if tipo is None: self.fechar()
        else: self.abandonar()
    def abandonar(self):
        """Desiste: fecha sem publicar; o destino fica como estava."""
        if self._w: _l.jsonw_abandonar(self._w); self._w = None
    def gravar_texto(self, texto):
        e = ctypes.create_string_buffer(200); b = texto.encode()
        if _l.jsonw_gravar_json(self._w, b, len(b), e, 200): raise ErroJsonW(e.value.decode())
    def gravar(self, obj): self.gravar_texto(json.dumps(obj, ensure_ascii=False))
    def descarregar(self): _l.jsonw_descarregar(self._w)
    def fechar(self):
        if self._w:
            r = _l.jsonw_fechar_escritor(self._w); self._w = None
            if r: raise ErroJsonW("nao gravou tudo")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jsonw_ops; jsonw_ops.ligar(_l, ErroJsonW)   # operacoes (jsonw_ops.py, ao lado): avaliar + escolher, reconhecer
from jsonw_ops import avaliar, avaliar_json, escolher, Reconhecedor, visao
Leitor.avaliar = avaliar; Leitor.avaliar_json = avaliar_json; Leitor.visao = visao

if __name__ == "__main__":   # python3 jsonw.py arquivo.jsw -> JSONL; --avaliar arq pedido k; --reconhecer termos.jsw texto
    jsonw_ops.cli(sys.argv, Leitor)
