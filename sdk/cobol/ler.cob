      >>SOURCE FORMAT FREE
*> ler.cob: jsonW em COBOL (GnuCOBOL 3.2+), chamando a ABI C direto. Imprime cada linha do .jsw em JSON.
*>   cobc -x -free ler.cob -L.. -ljsonw -o ler && ./ler dados.jsw
IDENTIFICATION DIVISION.
PROGRAM-ID. JSONW-LER.

DATA DIVISION.
WORKING-STORAGE SECTION.
01 caminho          PIC X(4096).
01 caminho-c        PIC X(4097).
01 erro             PIC X(320) VALUE LOW-VALUES.
01 erro-tam         USAGE BINARY-DOUBLE UNSIGNED VALUE 320.
01 leitor           USAGE POINTER.
01 linhas           USAGE BINARY-DOUBLE UNSIGNED.
01 i                USAGE BINARY-DOUBLE UNSIGNED.
01 saida            PIC X(65536).
01 saida-tam        USAGE BINARY-DOUBLE UNSIGNED VALUE 65536.
01 n                USAGE BINARY-DOUBLE.
01 r                USAGE BINARY-LONG.

PROCEDURE DIVISION.
    ACCEPT caminho FROM ARGUMENT-VALUE
    IF caminho = SPACES
        DISPLAY "uso: ler arquivo.jsw" UPON SYSERR
        MOVE 2 TO RETURN-CODE
        STOP RUN
    END-IF
    STRING FUNCTION TRIM(caminho) DELIMITED BY SIZE, X"00" DELIMITED BY SIZE INTO caminho-c

    CALL STATIC "jsonw_abrir" USING BY REFERENCE caminho-c BY REFERENCE erro BY VALUE erro-tam
        RETURNING leitor
    IF leitor = NULL
        DISPLAY FUNCTION TRIM(erro) UPON SYSERR
        MOVE 1 TO RETURN-CODE
        STOP RUN
    END-IF

    CALL STATIC "jsonw_conferir" USING BY VALUE leitor BY REFERENCE erro BY VALUE erro-tam RETURNING r
    IF r NOT = 0
        DISPLAY "custodia: " FUNCTION TRIM(erro) UPON SYSERR
        MOVE 1 TO RETURN-CODE
        STOP RUN
    END-IF

    CALL STATIC "jsonw_linhas" USING BY VALUE leitor RETURNING linhas
    PERFORM VARYING i FROM 0 BY 1 UNTIL i >= linhas
        CALL STATIC "jsonw_linha_json" USING BY VALUE leitor BY VALUE i BY REFERENCE saida BY VALUE saida-tam
            RETURNING n
        IF n < 0
            DISPLAY "linha " i " ilegivel" UPON SYSERR
            MOVE 1 TO RETURN-CODE
            STOP RUN
        END-IF
        DISPLAY saida(1:n)
    END-PERFORM

    CALL STATIC "jsonw_fechar" USING BY VALUE leitor
    STOP RUN.
