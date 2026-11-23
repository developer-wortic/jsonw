# jsonW em COBOL

GnuCOBOL 3.2+ chama a ABI C direto, com `CALL STATIC ... RETURNING`: sem ponte, sem código em C de cola.
`ler.cob` abre o `.jsw`, confere a custódia e imprime cada linha em JSON, que o programa de lote lê como registro.

```bash
cobc -x -free -Wall ler.cob ../libjsonw.a -o ler
./ler vendas.jsw
```

As outras funções da ABI (`jsonw_chave`, `jsonw_avaliar`, `jsonw_visao`, `jsonw_criar` e `jsonw_gravar_json`) seguem o mesmo
molde: texto com `X"00"` no fim, `BY REFERENCE` para buffers, `BY VALUE` para handles e tamanhos (`BINARY-DOUBLE UNSIGNED`).
