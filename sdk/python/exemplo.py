# python3 exemplo.py dados.jsw id 2: as linhas em que o campo vale o valor (JSON), pelo índice; --varrer para sem índice.
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jsonw  # noqa: E402

arquivo, campo, texto, *resto = sys.argv[1:]
try:
    with jsonw.Leitor(arquivo) as a:
        k = a.indice(campo)
        if "--varrer" not in resto:
            a.indexar(k)
        for i in a.chave(k, json.loads(texto)):
            sys.stdout.write(a.json(i) + "\n")
except jsonw.ErroJsonW as e:
    sys.exit(str(e))
