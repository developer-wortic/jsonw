/* Gravar.java: prova de escrita do SDK Java: java --enable-native-access=ALL-UNNAMED Gravar.java esquema entrada.jsonl saida.jsw */
import java.nio.file.*;
public final class Gravar {
    public static void main(String[] args) throws Exception {
        try (Jsonw.Escritor w = new Jsonw.Escritor(args[2], args[0])) {
            for (String l : Files.readAllLines(Path.of(args[1]))) if (!l.isBlank()) w.gravar(l);
        }
    }
}
