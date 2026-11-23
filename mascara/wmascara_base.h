/* wmascara_base.h: o que os arquivos de cada tipo usam por dentro (limpar, completar com zero, módulos 10 e 11). */
#ifndef WMASCARA_BASE_H
#define WMASCARA_BASE_H
#include "wmascara.h"

/* Copia para `s` só letras e dígitos, letra em maiúscula; devolve quantos (ou -1 se passar de `max`). */
int wmb_limpar(const char *e, char *s, int max);
int wmb_so_digitos(const char *s, int n);
/* Repõe zeros à esquerda até `alvo` caracteres. */
void wmb_completar(char *s, int n, int alvo);
/* Soma ponderada de dígitos: s[i] * peso[i]; valor do caractere = c - '0' (vale para letra no CNPJ alfanumérico). */
int wmb_soma(const char *s, const int *peso, int n);
int wmb_mod11_dv(int soma);           /* resto < 2 -> 0, senão 11 - resto (CNPJ, CPF, NF-e) */
int wmb_mod10_dv(const char *s, int n); /* pesos 2,1,2,1... da direita, soma dos algarismos (boleto) */

typedef WmErro (*WmbNorm)(const char *limpo, int n, char saida[WM_MAX]);
typedef void (*WmbFmt)(const char *canon, char saida[WM_MAX]);

/* Cada tipo (wmascara_doc.c, _lugar.c, _fiscal.c) */
WmErro wmb_cnpj(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cpf(const char *c, int n, char s[WM_MAX]);
WmErro wmb_pis(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cns(const char *c, int n, char s[WM_MAX]);
WmErro wmb_titulo(const char *c, int n, char s[WM_MAX]);
WmErro wmb_renavam(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cep(const char *c, int n, char s[WM_MAX]);
WmErro wmb_telefone(const char *c, int n, char s[WM_MAX]);
WmErro wmb_placa(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cnae(const char *c, int n, char s[WM_MAX]);
WmErro wmb_ncm(const char *c, int n, char s[WM_MAX]);
WmErro wmb_chave_nfe(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cnj(const char *c, int n, char s[WM_MAX]);
WmErro wmb_boleto(const char *c, int n, char s[WM_MAX]);
/* outros países (wmascara_mundo.c) */
WmErro wmb_iban(const char *c, int n, char s[WM_MAX]);
WmErro wmb_pt_nif(const char *c, int n, char s[WM_MAX]);
WmErro wmb_fr_siren(const char *c, int n, char s[WM_MAX]);
WmErro wmb_fr_siret(const char *c, int n, char s[WM_MAX]);
WmErro wmb_it_iva(const char *c, int n, char s[WM_MAX]);
WmErro wmb_it_cf(const char *c, int n, char s[WM_MAX]);
WmErro wmb_es_nif(const char *c, int n, char s[WM_MAX]);
WmErro wmb_de_steuer(const char *c, int n, char s[WM_MAX]);
WmErro wmb_de_ust(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cn_uscc(const char *c, int n, char s[WM_MAX]);
WmErro wmb_jp_empresa(const char *c, int n, char s[WM_MAX]);
WmErro wmb_jp_mynumber(const char *c, int n, char s[WM_MAX]);
WmErro wmb_mx_curp(const char *c, int n, char s[WM_MAX]);
WmErro wmb_mx_rfc(const char *c, int n, char s[WM_MAX]);
WmErro wmb_ar_cuit(const char *c, int n, char s[WM_MAX]);
WmErro wmb_pe_ruc(const char *c, int n, char s[WM_MAX]);
WmErro wmb_cl_rut(const char *c, int n, char s[WM_MAX]);
WmErro wmb_co_nit(const char *c, int n, char s[WM_MAX]);
WmErro wmb_us_ein(const char *c, int n, char s[WM_MAX]);
WmErro wmb_us_ssn(const char *c, int n, char s[WM_MAX]);
WmErro wmb_us_zip(const char *c, int n, char s[WM_MAX]);
WmErro wmb_uk_crn(const char *c, int n, char s[WM_MAX]);
WmErro wmb_uk_postcode(const char *c, int n, char s[WM_MAX]);
WmErro wmb_vat(const char *c, int n, char s[WM_MAX]);   /* wmascara_vat.c */
WmErro wmb_fone_intl(const char *c, int n, char s[WM_MAX]);   /* wmascara_fone.c */
void wmb_fmt(WmTipo t, const char *canon, char s[WM_MAX]);
#endif
