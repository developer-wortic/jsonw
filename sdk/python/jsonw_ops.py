"""jsonW: as operacoes da ABI 1.1 (AVALIAR + ESCOLHER, ESCOLHER, RECONHECER) para Python. Carregado por jsonw.py, que
poe Leitor.avaliar; fica ao lado dele. Uso:
    a.avaliar({"cosseno": {"campo": "vet", "consulta": [0.5, -1, 2, 0.25]}}, k=5)   -> [{"linha": 3, "nota": 0.98}, ...]
    jsonw.escolher([0.2, 0.9, 0.5], 2)                                                -> [1, 2]
    with jsonw.Reconhecedor("termos.jsw") as r: r.reconhecer("texto")                -> {"termos": [...], "sinais": [...]}
"""
import ctypes, json

_l = None; _Erro = Exception

def ligar(l, erro):
    """Chamado por jsonw.py com a biblioteca carregada e a classe de erro (evita importar jsonw de volta)."""
    global _l, _Erro
    _l, _Erro = l, erro
    _l.jsonw_avaliar.restype = ctypes.c_int64; _l.jsonw_avaliar.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t]
    _l.jsonw_escolher.restype = ctypes.c_int64; _l.jsonw_escolher.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_size_t, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint64)]
    _l.jsonw_reconhecedor.restype = ctypes.c_void_p; _l.jsonw_reconhecedor.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t]
    _l.jsonw_reconhecedor_fechar.argtypes = [ctypes.c_void_p]
    _l.jsonw_reconhecer.restype = ctypes.c_int64; _l.jsonw_reconhecer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t]

def avaliar_json(leitor, pedido, k=10):
    """As k melhores linhas pelo pedido (dict ou texto JSON), como a ABI devolve: [{"linha", "nota"}], maior nota primeiro."""
    p = (pedido if isinstance(pedido, str) else json.dumps(pedido, ensure_ascii=False)).encode()
    cap = 1 << 16
    while True:
        b = ctypes.create_string_buffer(cap); e = ctypes.create_string_buffer(300)
        n = _l.jsonw_avaliar(leitor._a, p, len(p), k, b, cap, e, 300)
        if n == -2:
            cap *= 4
            continue
        if n < 0:
            raise _Erro(e.value.decode())
        return b.raw[:n].decode()

def avaliar(leitor, pedido, k=10): return json.loads(avaliar_json(leitor, pedido, k))

def visao(leitor, escopos):
    """Trava o que a sessao ve (servidor multi-tenant: "pessoal vendas tenant:42"): esquema e campos so das colunas visiveis,
    linha de outro tenant = LinhaOculta, avaliar so com campos visiveis e linhas da sessao. Nao destrava."""
    e = ctypes.create_string_buffer(300)
    if _l.jsonw_visao(leitor._a, escopos.encode(), e, 300): raise _Erro(e.value.decode())
    leitor.esquema = _l.jsonw_esquema(leitor._a).decode()
    leitor.campos = [_l.jsonw_campo_nome(leitor._a, i).decode() for i in range(_l.jsonw_campos(leitor._a))]

def escolher(notas, k):
    """Posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior)."""
    n = len(notas); v = (ctypes.c_double * max(n, 1))(*notas); out = (ctypes.c_uint64 * max(k, 1))()
    m = _l.jsonw_escolher(v, n, k, out)
    return [int(out[i]) for i in range(max(m, 0))]

class Reconhecedor:
    """A tabela de termos (esquema termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) vira o reconhecedor."""
    def __init__(self, caminho):
        e = ctypes.create_string_buffer(300)
        self._r = _l.jsonw_reconhecedor(caminho.encode(), e, 300)
        if not self._r:
            raise _Erro(e.value.decode())
    def __enter__(self): return self
    def __exit__(self, *x): self.fechar()
    def fechar(self):
        if self._r: _l.jsonw_reconhecedor_fechar(self._r); self._r = None
    def reconhecer_json(self, texto):
        t = texto.encode(); cap = 1 << 16
        while True:
            b = ctypes.create_string_buffer(cap); n = _l.jsonw_reconhecer(self._r, t, len(t), b, cap)
            if n == -2:
                cap *= 4
                continue
            if n < 0: raise _Erro("reconhecedor fechado ou texto ilegivel")
            return b.raw[:n].decode()
    def reconhecer(self, texto):
        """{"termos": [{"termo", "ini", "fim", "texto", "sinal", "peso"}], "sinais": [{"sinal", "soma", "vezes"}]}"""
        return json.loads(self.reconhecer_json(texto))

def cli(argv, Leitor):   # a linha de comando de jsonw.py (ler em JSONL, --avaliar, --reconhecer)
    import sys
    if argv[1] == "--avaliar":
        with Leitor(argv[2]) as a: print(avaliar_json(a, argv[3], int(argv[4])))
    elif argv[1] == "--visao":   # --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
        with Leitor(argv[2]) as a:
            visao(a, argv[3]); print(",".join(a.campos))
            for i in range(a.linhas):
                try: sys.stdout.write(a.json(i) + "\n")
                except _Erro as x:
                    if type(x).__name__ != "LinhaOculta": raise
            print(avaliar_json(a, argv[4], int(argv[5])))
    elif argv[1] == "--reconhecer":
        with Reconhecedor(argv[2]) as r: print(r.reconhecer_json(argv[3]))
    else:
        with Leitor(argv[1]) as a:
            for i in range(a.linhas): sys.stdout.write(a.json(i) + "\n")
