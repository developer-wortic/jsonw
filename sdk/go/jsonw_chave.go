// jsonw_chave.go: BUSCAR POR CHAVE (ABI 1.3.13) para Go: as linhas em que um campo vale um valor, em ordem.
// Com l.Indexar(campo), busca binaria no indice, sem varrer; sem indice, varre o arquivo (l.TemIndice diz qual).
//
//	a.Indexar(0); linhas, err := a.Chave(0, 7)        // valor em Go: 7, "RJ", nil
package jsonw

/*
#include <stdlib.h>
#include "jsonw.h"
*/
import "C"

import (
	"encoding/json" // borda-json: o SDK publico recebe o valor do desenvolvedor de fora e o passa a ABI em JSON
	"errors"
	"unsafe"
)

// Indexar monta o indice do campo neste leitor (troca o de outro campo).
func (l *Leitor) Indexar(campo int) error {
	if C.jsonw_indexar(l.a, C.int(campo)) != 0 {
		return errors.New("campo sem indice")
	}
	return nil
}

// TemIndice diz se o campo ja tem indice neste leitor.
func (l *Leitor) TemIndice(campo int) bool { return C.jsonw_tem_indice(l.a, C.int(campo)) == 1 }

// Chave devolve as linhas em que o campo vale o valor (do tipo do campo), em ordem crescente.
func (l *Leitor) Chave(campo int, valor any) ([]uint64, error) {
	v, err := json.Marshal(valor) // borda-json: o valor do desenvolvedor vira o JSON que a ABI le no tipo do campo
	if err != nil {
		return nil, err
	}
	cv := C.CString(string(v))
	defer C.free(unsafe.Pointer(cv))
	out := make([]uint64, 16)
	for {
		n := int64(C.jsonw_chave(l.a, C.int(campo), cv, C.size_t(len(v)), (*C.uint64_t)(unsafe.Pointer(&out[0])), C.size_t(len(out))))
		switch {
		case n == -2:
			return nil, errors.New("valor nao e do tipo do campo")
		case n < 0:
			return nil, errors.New("campo invalido")
		case n <= int64(len(out)):
			return out[:n], nil
		}
		out = make([]uint64, n)
	}
}
