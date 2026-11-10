# jsonW nos servidores web

Provado no **Apache 2.4.66** (configuração deste pacote, pedido por pedido). Vale também para nginx com fcgiwrap, LiteSpeed
(mesmo bloco do Apache), Caddy e IIS (CGI).

> **Troque a configuração da 1.2.0 ou anterior por esta.** Na antiga o servidor entregava o `.jsw` por conta própria quando o
> pedido vinha sem parâmetro e sem `Accept: application/json`: o arquivo cru saía inteiro, com as colunas
> `+pessoal`/`+escopo(x)` e as linhas de todos os tenants. Agora **todo** pedido de `.jsw` passa pelo `wjsw-cgi`.

## Como funciona
- **Todo pedido de `.jsw`** vai para o `wjsw-cgi` (em `bin/<plataforma>/`), que só lê dentro de `WJSW_RAIZ`. O servidor nunca
  entrega o arquivo sozinho, porque só o `wjsw-cgi` sabe o que a sessão pode ver.
- **Arquivo sem coluna marcada e sem tenant, pedido sem parâmetro:** sai puro, com `Content-Type: application/jsonw`,
  `Accept-Ranges: bytes` e CORS. Com `Range: bytes=a-b` responde `206` só com a faixa (o leitor remoto baixa cabeçalho,
  rodapé e os blocos da pergunta); faixa fora do arquivo dá `416`; `HEAD` devolve só os cabeçalhos.
- **Arquivo com coluna `+pessoal`/`+escopo(x)` ou com tenant:** nunca sai puro. A resposta vem em JSON só com o que a sessão
  pode ver; arquivo com tenant e sessão sem tenant dá `403`.

| Pedido | Resposta |
|---|---|
| `?formato=json` ou `Accept: application/json` | lista JSON de objetos |
| `?formato=ndjson` ou `Accept: application/x-ndjson` | um objeto por linha |
| `?onde=campo op valor;...` | só as linhas que passam; as zonas pulam blocos inteiros |
| `?campos=a,b` | só esses campos |
| `?limite=N` | no máximo N linhas (teto em `WJSW_MAX_LINHAS`) |

## Segurança
- **Arquivo:** só dentro de `WJSW_RAIZ`, conferido pelo caminho real (`../` e `%2e%2e` barrados).
- **Visão obrigatória:** o que a sessão pode ver vem de um escopo que o **servidor** decide depois de autenticar
  (variável `JSONW_ESCOPO`, por exemplo `pessoal vendas tenant:42` ou `tenant:todos`), nunca de um cabeçalho do cliente.
  Sem o escopo, a coluna `+pessoal`/`+escopo(x)` não sai, nem por `campos=` nem por `onde=` (403); arquivo com `tenant` só
  mostra as linhas do tenant da sessão.
- **O tenant é um número inteiro** (`tenant:i64`, `tenant_id:i64` ou a coluna marcada `+tenant`). Uma coluna `tenant` de texto
  não separa nada: com ela a visão fica fechada e nada sai (só `tenant:todos` abre).

## Arquivos
- `apache-jsonw.conf`: o `[NS]` no RewriteRule é obrigatório (a sub-requisição do `PATH_TRANSLATED` não pode ser reescrita).
- `nginx-jsonw.conf`: a `location` dos `.jsw` reescreve para a `location` interna com fcgiwrap. Preencha `$jsonw_escopo` com
  `auth_request` + `auth_request_set` depois de autenticar.
- **Traefik e outros proxies:** repassam `Range` sem configuração; o jsonW fica no servidor de trás.
