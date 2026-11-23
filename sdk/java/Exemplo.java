// Exemplo.java: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
// java --enable-native-access=ALL-UNNAMED java/Exemplo.java dados.jsw id 2
import java.nio.charset.StandardCharsets;

public class Exemplo {
    public static void main(String[] args) {
        if (args.length < 3) { System.err.println("uso: Exemplo arquivo.jsw campo valor [--varrer]"); System.exit(2); }
        try (Jsonw.Leitor a = new Jsonw.Leitor(args[0])) {
            int k = a.campos.indexOf(args[1]);
            if (k < 0) { System.err.println("campo " + args[1] + " não existe"); System.exit(1); }
            if (args.length < 4 || !args[3].equals("--varrer")) a.indexar(k);
            StringBuilder sb = new StringBuilder();
            for (long i : a.chave(k, args[2])) sb.append(a.json(i)).append('\n');
            byte[] b = sb.toString().getBytes(StandardCharsets.UTF_8);
            System.out.write(b, 0, b.length); System.out.flush();
        }
    }
}
