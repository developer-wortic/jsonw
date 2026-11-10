// jsonw_visao.go: a visao (ABI 1.2) para Go. O servidor multi-tenant trava no Leitor o que a sessao ve ("pessoal vendas
// tenant:42") antes de entrega-lo: Esquema e Campos passam a ser so das colunas visiveis; linha de outro tenant = ErrOculta;
// AvaliarJSON recusa campo escondido e so devolve linhas da sessao. Nao destrava.
package jsonw

/*
#include <stdlib.h>
#include "jsonw.h"
*/
import "C"

import (
	"errors"
	"unsafe"
)

// ErrOculta: a linha e de outro tenant (depois de Visao); quem itera pula.
var ErrOculta = errors.New("linha oculta pela visao")

func (l *Leitor) Visao(escopos string) error {
	erro := make([]byte, 300)
	e := C.CString(escopos)
	defer C.free(unsafe.Pointer(e))
	if C.jsonw_visao(l.a, e, (*C.char)(unsafe.Pointer(&erro[0])), 300) != 0 {
		return errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	l.Esquema = C.GoString(C.jsonw_esquema(l.a))
	l.Campos = l.Campos[:0]
	for i := 0; i < int(C.jsonw_campos(l.a)); i++ {
		l.Campos = append(l.Campos, C.GoString(C.jsonw_campo_nome(l.a, C.int(i))))
	}
	return nil
}
