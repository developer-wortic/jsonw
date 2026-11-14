# exemplo.py: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
# python3 exemplo.py dados.jsw id 2
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jsonw

arquivo, campo, texto = sys.argv[1:4]
with jsonw.Leitor(arquivo) as a:
    if campo not in a.campos: sys.exit(f"campo {campo} não existe")
    if "--varrer" not in sys.argv[4:]: a.indexar(campo)
    for i in a.chave(campo, json.loads(texto)):
        sys.stdout.buffer.write(a.json(i).encode() + b"\n")
