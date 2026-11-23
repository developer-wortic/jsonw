<?php
// exemplo.php: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// php exemplo.php dados.jsw id 2
require __DIR__ . '/jsonw.php';
[$arquivo, $campo, $texto] = array_slice($argv, 1, 3); $modo = $argv[4] ?? '';
$a = new JsonW\Leitor($arquivo);
if (!in_array($campo, $a->campos, true)) { fwrite(STDERR, "campo $campo não existe\n"); exit(1); }
if ($modo !== '--varrer') $a->indexar($campo);
foreach ($a->chave($campo, json_decode($texto, true)) as $i) echo $a->json($i), "\n";
