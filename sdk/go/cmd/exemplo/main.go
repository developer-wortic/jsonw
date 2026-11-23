// exemplo: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// go run ./cmd/exemplo dados.jsw id 2
package main

import (
	"encoding/json" // borda-json: o valor que a pessoa digita na linha de comando
	"fmt"
	"os"
	"slices"

	"jsonw"
)

func main() {
	a, err := jsonw.Abrir(os.Args[1])
	if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	defer a.Fechar()
	k := slices.Index(a.Campos, os.Args[2])
	if k < 0 { fmt.Fprintln(os.Stderr, "campo", os.Args[2], "não existe"); os.Exit(1) }
	if len(os.Args) < 5 || os.Args[4] != "--varrer" { a.Indexar(k) }
	var valor any
	json.Unmarshal([]byte(os.Args[3]), &valor) // borda-json: o valor que a pessoa digita na linha de comando
	linhas, err := a.Chave(k, valor)
	if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	for _, i := range linhas { s, _ := a.JSON(i); fmt.Println(s) }
}
