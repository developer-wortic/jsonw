// Package jsonw: jsonW (json Wondrous) para Go, por cima da ABI C (libjsonw.a via cgo). Cada linha vai e volta como JSON.
//
//	a, err := jsonw.Abrir("dados.jsw"); defer a.Fechar()
//	for i := uint64(0); i < a.Linhas(); i++ { var m map[string]any; a.Linha(i, &m) }
//	w, _ := jsonw.Criar("novo.jsw", "id:i64,nome:texto"); w.Gravar(map[string]any{"id": 1, "nome": "x"}); w.Fechar()
package jsonw

/*
#cgo CFLAGS: -I${SRCDIR}/..
#cgo LDFLAGS: ${SRCDIR}/../libjsonw.a -lm
#include <stdlib.h>
#include "jsonw.h"
*/
import "C"

import (
	"encoding/json"
	"errors"
	"unsafe"
)

type Leitor struct {
	a      unsafe.Pointer
	Linhas uint64
	Esquema string
	Campos []string
}
type Escritor struct{ w unsafe.Pointer }

func Versao() string { return C.GoString(C.jsonw_versao()) }

func Abrir(caminho string) (*Leitor, error) {
	erro := make([]byte, 200)
	c := C.CString(caminho)
	defer C.free(unsafe.Pointer(c))
	a := C.jsonw_abrir(c, (*C.char)(unsafe.Pointer(&erro[0])), 200)
	if a == nil {
		return nil, errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	l := &Leitor{a: a, Linhas: uint64(C.jsonw_linhas(a)), Esquema: C.GoString(C.jsonw_esquema(a))}
	for i := 0; i < int(C.jsonw_campos(a)); i++ {
		l.Campos = append(l.Campos, C.GoString(C.jsonw_campo_nome(a, C.int(i))))
	}
	return l, nil
}
func (l *Leitor) Fechar() {
	if l.a != nil {
		C.jsonw_fechar(l.a)
		l.a = nil
	}
}
func texto(fn func(b *C.char, cap C.size_t) C.int64_t) (string, error) {
	cap := 1 << 16
	for {
		b := make([]byte, cap)
		n := fn((*C.char)(unsafe.Pointer(&b[0])), C.size_t(cap))
		if n == -2 {
			cap *= 4
			continue
		}
		if n == -3 {
			return "", ErrOculta
		}
		if n < 0 {
			return "", errors.New("linha ou campo ilegivel")
		}
		return string(b[:n]), nil
	}
}
func (l *Leitor) JSON(i uint64) (string, error) {
	return texto(func(b *C.char, cap C.size_t) C.int64_t { return C.jsonw_linha_json(l.a, C.uint64_t(i), b, cap) })
}
func (l *Leitor) Texto(i uint64) (string, error) {
	return texto(func(b *C.char, cap C.size_t) C.int64_t { return C.jsonw_linha_texto(l.a, C.uint64_t(i), b, cap) })
}
func (l *Leitor) Linha(i uint64, destino any) error {
	s, err := l.JSON(i)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(s), destino)
}
func (l *Leitor) Campo(i uint64, campo int, destino any) error {
	s, err := texto(func(b *C.char, cap C.size_t) C.int64_t { return C.jsonw_campo_json(l.a, C.uint64_t(i), C.int(campo), b, cap) })
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(s), destino)
}
func (l *Leitor) Conferir() error {
	erro := make([]byte, 200)
	if C.jsonw_conferir(l.a, (*C.char)(unsafe.Pointer(&erro[0])), 200) != 0 {
		return errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	return nil
}

func Criar(caminho, esquema string) (*Escritor, error) {
	erro := make([]byte, 200)
	c, e := C.CString(caminho), C.CString(esquema)
	defer C.free(unsafe.Pointer(c))
	defer C.free(unsafe.Pointer(e))
	w := C.jsonw_criar(c, e, (*C.char)(unsafe.Pointer(&erro[0])), 200)
	if w == nil {
		return nil, errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	return &Escritor{w: w}, nil
}
func (w *Escritor) Opcoes(compressao, hash, blocoKb int) { C.jsonw_opcoes(w.w, C.int(compressao), C.int(hash), C.int(blocoKb)) }
func (w *Escritor) GravarTexto(t string) error {
	erro := make([]byte, 200)
	c := C.CString(t)
	defer C.free(unsafe.Pointer(c))
	if C.jsonw_gravar_json(w.w, c, C.size_t(len(t)), (*C.char)(unsafe.Pointer(&erro[0])), 200) != 0 {
		return errors.New(C.GoString((*C.char)(unsafe.Pointer(&erro[0]))))
	}
	return nil
}
func (w *Escritor) Gravar(obj any) error {
	b, err := json.Marshal(obj)
	if err != nil {
		return err
	}
	return w.GravarTexto(string(b))
}
func (w *Escritor) Descarregar() { C.jsonw_descarregar(w.w) }
func (w *Escritor) Fechar() error {
	if w.w == nil {
		return nil
	}
	r := C.jsonw_fechar_escritor(w.w)
	w.w = nil
	if r != 0 {
		return errors.New("nao gravou tudo")
	}
	return nil
}

// Abandonar: desiste da gravacao; fecha sem publicar e o destino fica como estava (para quem sai por erro no meio).
func (w *Escritor) Abandonar() {
	if w.w != nil {
		C.jsonw_abandonar(w.w)
		w.w = nil
	}
}
