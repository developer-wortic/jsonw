// ler arquivo.jsw -> JSONL; ler --gravar esquema entrada.jsonl saida.jsw; ler --avaliar arq pedido k; ler --reconhecer termos.jsw texto (prova do SDK Go)
package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"jsonw"
)

func falha(err error) { fmt.Fprintln(os.Stderr, err); os.Exit(1) }

func main() {
	if len(os.Args) == 5 && os.Args[1] == "--gravar" {
		w, err := jsonw.Criar(os.Args[4], os.Args[2])
		if err != nil { falha(err) }
		f, _ := os.Open(os.Args[3]); sc := bufio.NewScanner(f); sc.Buffer(make([]byte, 1<<20), 1<<24)
		for sc.Scan() { if strings.TrimSpace(sc.Text()) != "" { if err := w.GravarTexto(sc.Text()); err != nil { falha(err) } } }
		if err := w.Fechar(); err != nil { falha(err) }
		return
	}
	if len(os.Args) == 5 && os.Args[1] == "--avaliar" {
		a, err := jsonw.Abrir(os.Args[2]); if err != nil { falha(err) }; defer a.Fechar()
		k, _ := strconv.Atoi(os.Args[4]); s, err := a.AvaliarJSON(os.Args[3], k); if err != nil { falha(err) }
		fmt.Println(s); return
	}
	if len(os.Args) == 6 && os.Args[1] == "--visao" { // --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
		a, err := jsonw.Abrir(os.Args[2]); if err != nil { falha(err) }; defer a.Fechar()
		if err := a.Visao(os.Args[3]); err != nil { falha(err) }
		fmt.Println(strings.Join(a.Campos, ","))
		for i := uint64(0); i < a.Linhas; i++ { s, err := a.JSON(i); if errors.Is(err, jsonw.ErrOculta) { continue }; if err != nil { falha(err) }; fmt.Println(s) }
		k, _ := strconv.Atoi(os.Args[5]); s, err := a.AvaliarJSON(os.Args[4], k); if err != nil { falha(err) }
		fmt.Println(s); return
	}
	if len(os.Args) == 4 && os.Args[1] == "--reconhecer" {
		r, err := jsonw.NovoReconhecedor(os.Args[2]); if err != nil { falha(err) }; defer r.Fechar()
		s, err := r.ReconhecerJSON(os.Args[3]); if err != nil { falha(err) }
		fmt.Println(s); return
	}
	a, err := jsonw.Abrir(os.Args[1])
	if err != nil { falha(err) }
	defer a.Fechar()
	out := bufio.NewWriter(os.Stdout); defer out.Flush()
	for i := uint64(0); i < a.Linhas; i++ { s, err := a.JSON(i); if err != nil { falha(err) }; out.WriteString(s); out.WriteString("\n") }
}
