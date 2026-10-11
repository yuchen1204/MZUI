import java.nio.file.*;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

/** Syntax-check every .lua under a root: compile it with the game's Kahlua. */
public class SyntaxCheck {
    public static void main(String[] args) throws Exception {
        var platform = J2SEPlatform.getInstance();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        int ok = 0, bad = 0;
        try (var walk = Files.walk(Path.of(args[0]))) {
            for (var p : (Iterable<Path>) walk.filter(x -> x.toString().endsWith(".lua"))::iterator) {
                String src = Files.readString(p);
                try {
                    var fn = LuaCompiler.loadstring(src, p.toString(), env);
                    if (fn == null) throw new IllegalStateException("compiled to null");
                    ok++;
                } catch (Exception e) {
                    System.out.println("SYNTAX FAIL " + p + ": " + e.getMessage());
                    bad++;
                }
            }
        }
        System.out.println("syntax check: " + ok + " ok, " + bad + " failed");
        if (bad > 0) System.exit(1);
    }
}
