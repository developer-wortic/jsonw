// jsonw_ops.go: as operacoes da ABI 1.1 para Go: AVALIAR + ESCOLHER (pedido em JSON -> as k melhores), ESCOLHER das
// suas notas e RECONHECER (tabela de termos -> Reconhecedor; texto -> termos e sinais).
package jsonw

/*
#include <stdlib.h>
#include "jsonw.h"
*/
import "C"

import (
	"encoding/json"
	"errors"
	"unsafe"
)

type Nota struct {
	Linha uint64  `json:"linha"`
	Nota  float64 `json:"nota"`
}
type Reconhecedor struct{ r unsafe.Pointer }

// AvaliarJSON: pedido {"pesos":{..}} | {"cosseno":{..}} | {"esparso":{..}} | {"grade":{..}}; devolve [{"linha","nota"}] das k melhores.
func (l *Leitor) AvaliarJSON(pedido string, k int) (string, error) {
	erro := make([]byte, 300)
	p := C.CString(pedido)
	defer C.free(unsafe.Pointer(p))
	s, err := texto(func(b *C.char, cap C.size_t) C.int64_t {
		return C.jsonw_avaliar(l.a, p, C.size_t(len(pedido)), C.size_t(k), b, cap, (*C.char)(unsafe.Pointer(&erro[0])), 300)
	})
	if err != nil && erro[0] != 0 {
		return "", errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	return s, err
}
func (l *Leitor) Avaliar(pedido any, k int) ([]Nota, error) {
	p, ok := pedido.(string)
	if !ok {
		b, err := json.Marshal(pedido)
		if err != nil {
			return nil, err
		}
		p = string(b)
	}
	s, err := l.AvaliarJSON(p, k)
	if err != nil {
		return nil, err
	}
	var r []Nota
	return r, json.Unmarshal([]byte(s), &r)
}

// Escolher: posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior).
func Escolher(notas []float64, k int) []uint64 {
	if len(notas) == 0 || k <= 0 {
		return nil
	}
	out := make([]uint64, k)
	m := C.jsonw_escolher((*C.double)(unsafe.Pointer(&notas[0])), C.size_t(len(notas)), C.size_t(k), (*C.uint64_t)(unsafe.Pointer(&out[0])))
	if m < 0 {
		return nil
	}
	return out[:m]
}

// NovoReconhecedor: tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) -> reconhecedor.
func NovoReconhecedor(termosJsw string) (*Reconhecedor, error) {
	erro := make([]byte, 300)
	c := C.CString(termosJsw)
	defer C.free(unsafe.Pointer(c))
	r := C.jsonw_reconhecedor(c, (*C.char)(unsafe.Pointer(&erro[0])), 300)
	if r == nil {
		return nil, errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	return &Reconhecedor{r: r}, nil
}
func (r *Reconhecedor) Fechar() {
	if r.r != nil {
		C.jsonw_reconhecedor_fechar(r.r)
		r.r = nil
	}
}

// ReconhecerJSON: {"termos":[{termo,ini,fim,texto,sinal,peso}],"sinais":[{sinal,soma,vezes}]}
func (r *Reconhecedor) ReconhecerJSON(t string) (string, error) {
	c := C.CString(t)
	defer C.free(unsafe.Pointer(c))
	return texto(func(b *C.char, cap C.size_t) C.int64_t { return C.jsonw_reconhecer(r.r, c, C.size_t(len(t)), b, cap) })
}
func (r *Reconhecedor) Reconhecer(t string, destino any) error {
	s, err := r.ReconhecerJSON(t)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(s), destino)
}
