# Licença de Uso Sustentável do jsonW

Versão 2.0 (23/11/2026). Substitui a versão 1.0 de 06/11/2026 (ver item 15).
Titular: **WORTIC LTDA** (Wortic Tecnologia), CNPJ 37.853.407/0001-71, Brasil ("a Wortic").

O jsonW **não é software livre nem de código aberto** no sentido da Open Source Initiative. É software proprietário da
Wortic, de **uso gratuito** dentro dos limites abaixo (modelo "fair-code"). O código-fonte do núcleo não é público.
O jsonW é obra protegida pela Lei 9.609/1998 (programas de computador) e pela Lei 9.610/1998 (direitos autorais), e faz
parte do programa "Plataforma Wortic", com pedido de registro no INPI (processo BR 51 2026 011190-0).

## 1. Definições
- **Software:** a especificação, as ferramentas (`wjsw`, `wjsw-cgi` e outras), as bibliotecas (inclusive `libjsonw`,
  o módulo de Node.js e a versão WebAssembly), a ABI, os SDKs, os exemplos, os perfis, a documentação e as atualizações
  distribuídas pela Wortic, em qualquer canal (GitHub, npm, jsonw.org ou outro).
- **Núcleo:** o leiaute interno do arquivo coluna, os codecs e a compressão, o protocolo de fio, a custódia, a visão por
  permissão, a cifra e o código em C que implementa tudo isso, publicado ou não.
- **Seus Dados:** os arquivos que você grava com o Software e o conteúdo deles.
- **Serviço Concorrente:** produto ou serviço, pago ou gratuito, cuja função principal seja armazenar, converter,
  consultar, servir ou transportar dados no formato jsonW para terceiros, ou que concorra com o jsonW como formato,
  biblioteca ou banco de dados.

## 2. Aceitação
Ao baixar, instalar, usar, copiar ou distribuir o Software, você aceita estes termos. Se não aceitar, não use o
Software. Quem aceita em nome de uma empresa declara ter poderes para isso.

## 3. O que você pode fazer (licença gratuita)
A Wortic concede a você uma licença **não exclusiva, intransferível, sem direito de sublicenciar, gratuita e revogável
por descumprimento** para:
- usar o Software em qualquer quantidade de computadores, servidores e aplicativos **seus**, inclusive em produtos e
  serviços comerciais seus, desde que o jsonW seja um **componente** e não o próprio serviço oferecido;
- copiar e distribuir o Software **sem modificação**, como parte de um produto seu, com estes termos e os avisos de
  autoria (item 8);
- criar programas, bibliotecas e integrações que usem o Software pelas APIs e SDKs publicados, com a licença que quiser
  para o **seu** código.

## 4. Seus Dados são seus
Os arquivos que você grava com o Software e o conteúdo deles são seus. A Wortic não reivindica direito sobre eles, e
nada nestes termos limita ler, guardar ou entregar os seus arquivos a quem você quiser. Ler arquivos jsonW com o próprio
Software, sem limite de tempo, está sempre permitido.

## 5. O que você não pode fazer
Sem acordo comercial por escrito com a Wortic, você não pode:
1. Vender, alugar, arrendar, sublicenciar, hospedar ou oferecer o Software, ou um Serviço Concorrente, a terceiros, com
   ou sem cobrança, inclusive como serviço gerenciado, nuvem, API ou "plataforma como serviço".
2. Criar, distribuir ou ajudar a criar uma implementação independente, compatível, alternativa ou derivada do Núcleo
   (leitor, gravador, codec, conversor ou protocolo que leia ou grave o leiaute interno sem usar o Software).
3. Fazer engenharia reversa, descompilar, desmontar, rastrear a execução ou de qualquer outra forma tentar extrair o
   código-fonte, os algoritmos, as tabelas ou os parâmetros do Núcleo, salvo o que a lei garantir de forma inafastável,
   e só na medida exata dessa garantia.
4. Usar o Software, a sua documentação, os seus arquivos de teste, as suas saídas ou o seu comportamento observado para
   treinar, ajustar, destilar ou avaliar modelos de inteligência artificial com o fim de reproduzir o formato, o Núcleo
   ou o Software, ou de criar um Serviço Concorrente.
5. Modificar e distribuir o Software modificado, ou distribuir partes dele separadas do pacote original.
6. Remover, alterar ou esconder avisos de autoria, de marca, de licença ou de versão, ou contornar qualquer controle
   técnico, de licença ou de custódia do Software.
7. Usar o Software para violar a lei ou direitos de terceiros.

## 6. Licença comercial
Hospedar ou oferecer o jsonW como serviço, distribuir o Software modificado, embutir o Núcleo em produto que concorra com
ele, ou implementar o formato de forma independente exige **licença comercial** da Wortic, com preço e condições em
contrato próprio. Contato: https://wortic.com.br.

## 7. Propriedade, segredos e confidencialidade
O Software, o Núcleo e todas as cópias são e continuam sendo da Wortic; esta licença não transfere propriedade. Tudo o
que não estiver na documentação pública (o leiaute interno, os codecs, os parâmetros e qualquer informação obtida fora
dela) é **segredo de negócio** da Wortic e não pode ser divulgado nem usado fora do que este documento permite.

## 8. Aviso de autoria obrigatório
Todo produto que distribuir o Software deve trazer, na documentação ou na tela de créditos, o aviso:
"Usa o jsonW, da Wortic (jsonw.org), sob a Licença de Uso Sustentável do jsonW."

## 9. Marcas
"jsonW", "json Wondrous", "Wortic", "W-HLM" e os logotipos são marcas da Wortic. Você pode dizer, com verdade, que o
seu produto lê ou grava jsonW. Não pode usar essas marcas no nome do seu produto, empresa ou domínio, nem sugerir
parceria, certificação ou aprovação da Wortic, sem autorização por escrito.

## 10. Patentes
A Wortic reserva todos os direitos de patente e de invenção sobre o Software e o Núcleo. Esta licença só concede o
mínimo necessário para usar o Software como o item 3 permite. Se você (ou empresa do seu grupo) propuser ação alegando
que o Software viola patente ou direito seu, esta licença termina para você na data da propositura.

## 11. Contribuições
Contribuições (código, documentação, relatos, testes) são bem-vindas e passam a integrar o Software sob estes termos.
Quem contribui garante ter direito sobre o que contribui e concede à Wortic licença perpétua, mundial, irrevogável e
gratuita para usar, modificar, distribuir, relicenciar e patentear a contribuição.

## 12. Verificação de conformidade
Com aviso prévio razoável e no máximo uma vez por ano, a Wortic pode pedir que você confirme por escrito que o seu uso
cumpre estes termos e qual o escopo desse uso.

## 13. Sem garantia e limite de responsabilidade
O Software é fornecido "como está", sem garantia de qualquer tipo. Na extensão máxima permitida pela lei, a Wortic não
responde por danos indiretos, lucros cessantes ou perda de dados decorrentes do uso ou da impossibilidade de uso do
Software, e a responsabilidade total dela fica limitada ao que você pagou pelo Software (zero, na licença gratuita).

## 14. Descumprimento
Descumprir estes termos encerra a licença automaticamente. Se for o primeiro descumprimento e você o cessar de boa-fé
em até 30 dias depois de avisado, a licença é restabelecida; a partir do segundo, não. O uso fora destes termos é
violação de direitos de autor de programa de computador (Lei 9.609/1998) e sujeita quem o pratica à abstenção, à
apreensão das cópias e à indenização pelos danos, sem prejuízo das demais medidas legais. As obrigações dos itens 5, 7,
9, 10 e 13 continuam valendo depois do fim da licença.

## 15. Versões destes termos
A Wortic pode publicar versões novas destes termos. Esta versão 2.0 vale para toda cópia do Software obtida a partir de
23/11/2026, de qualquer versão e por qualquer canal. Cópias obtidas antes continuam regidas pelos termos que as
acompanhavam, para aquela cópia.

## 16. Disposições gerais
Se uma cláusula for julgada inválida, as demais continuam valendo, e a inválida é substituída pela válida mais próxima
da intenção original. Não exercer um direito não é renúncia a ele. Estes termos são o acordo inteiro sobre a licença
gratuita; acordo comercial por escrito prevalece sobre eles no que tratar. Em caso de divergência entre esta versão e
uma tradução, vale esta, em português.

## 17. Lei e foro
Lei brasileira. Foro da comarca da sede da Wortic, com renúncia a qualquer outro, por mais privilegiado que seja.
