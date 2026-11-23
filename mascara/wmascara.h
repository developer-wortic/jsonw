/* wmascara.h: os formatos de dados brasileiros sem medo de máscara. Cada tipo tem três passos com a mesma regra em todo lugar:
 * normalizar (tira ponto, traço, barra, espaço e caixa; repõe o zero da frente que planilha come, só quando o dígito confere),
 * validar (dígito verificador oficial) e formatar (a máscara de exibição). Sem alocação, sem locale, sem estado: seguro em thread.
 * Código aberto (licença do jsonW). */
#ifndef WMASCARA_H
#define WMASCARA_H
#include <stddef.h>

typedef enum {
    WM_CNPJ, WM_CPF, WM_CEP, WM_TELEFONE, WM_PIS, WM_CNS, WM_TITULO, WM_RENAVAM, WM_PLACA,
    WM_CNAE, WM_NCM, WM_CHAVE_NFE, WM_CNJ, WM_BOLETO,
    WM_IBAN, WM_PT_NIF, WM_FR_SIREN, WM_FR_SIRET, WM_IT_IVA, WM_IT_CF, WM_ES_NIF, WM_DE_STEUER, WM_DE_UST, WM_CN_USCC,
    WM_JP_EMPRESA, WM_JP_MYNUMBER, WM_MX_CURP, WM_MX_RFC, WM_AR_CUIT, WM_PE_RUC, WM_CL_RUT, WM_CO_NIT,
    WM_US_EIN, WM_US_SSN, WM_US_ZIP, WM_UK_CRN, WM_UK_POSTCODE, WM_VAT, WM_FONE_INTL,
    WM_DESCONHECIDO
} WmTipo;

typedef enum {
    WM_OK = 0,
    WM_VAZIO = -1,     /* nada que se aproveite */
    WM_TAMANHO = -2,   /* não tem o tamanho do tipo, nem com o zero da frente */
    WM_DIGITO = -3,    /* tamanho certo, dígito verificador errado */
    WM_FORMA = -4      /* tem caractere que o tipo não aceita (letra em CPF, DDD inexistente...) */
} WmErro;

/* Normaliza `entrada` para a forma canônica do tipo em `saida` (só os caracteres que contam; telefone sai em E.164).
 * `saida` precisa de WM_MAX bytes. Devolve WM_OK ou o erro; em erro, `saida` fica vazia. */
#define WM_MAX 64
WmErro wm_normalizar(WmTipo t, const char *entrada, char saida[WM_MAX]);

/* Formata a forma canônica (ou qualquer entrada, que é normalizada antes) com a máscara de exibição. */
WmErro wm_formatar(WmTipo t, const char *entrada, char saida[WM_MAX]);

/* Diz o tipo mais provável de um texto solto (CNPJ, CPF, CEP, telefone...), validando o dígito quando há. */
WmTipo wm_detectar(const char *entrada);

const char *wm_tipo_nome(WmTipo t);   /* "cnpj", "cpf", "cep"...: o nome usado no jsonW e nas APIs */
WmTipo wm_tipo_de_nome(const char *nome);
const char *wm_erro_texto(WmErro e);  /* frase curta em português para devolver a quem chamou */

#endif
