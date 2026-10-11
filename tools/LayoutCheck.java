import java.nio.file.*;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

/** Run the mod's tests/layout.lua with mocked game globals. Each shared
 *  module is loaded as its own chunk (the concatenation trap: this Kahlua
 *  treats a `return` inside do..end as a chunk-level return, so modules must
 *  run separately — exactly how the game loads files too).
 *  pcall: Kahlua's stdlib pcall needs the debug-owner thread the game env
 *  installs; this bare harness swaps in a KahluaThread.pcall-based bridge. */
public class LayoutCheck {
    public static void main(String[] args) throws Exception {
        var platform = J2SEPlatform.getInstance();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        Path root = Path.of(args[0]);
        String mocks = """
            UIFont={Small=1,Medium=2,Large=3}
            testWidth,testHeight=1920,1080
            function getCore() return {getScreenWidth=function() return testWidth end,
                getScreenHeight=function() return testHeight end} end
            function getTextManager() return {
                getFontHeight=function(_,f) return f==3 and 24 or f==2 and 19 or 15 end,
                MeasureStringX=function(_,f,s) return #tostring(s or "")*8 end} end
            Events={OnGameBoot={Add=function() end},OnMainMenuEnter={Add=function() end}}
            require=function(name)
                local short=string.match(name,"MZUI/(.+)$")
                if short and MZUI then return rawget(MZUI,short) end
                return nil
            end
            """;
        thread.call(LuaCompiler.loadstring(mocks, "mocks", env), new Object[0]);
        String[] order = { "Theme.lua", "I18n.lua", "Hook.lua", "Draw.lua", "Geometry.lua" };
        for (String name : order) {
            Path p = root.resolve("42/media/lua/shared/MZUI").resolve(name);
            if (Files.exists(p)) {
                String src = Files.readString(p);
                thread.call(LuaCompiler.loadstring(src, name, env), new Object[0]);
            }
        }
        for (String name : new String[] { "Snapshot.lua", "screens/OptionsPresenter.lua", "screens/MultiplayerPresenter.lua" }) {
            Path p = root.resolve("42/media/lua/client/MZUI").resolve(name);
            thread.call(LuaCompiler.loadstring(Files.readString(p), name, env), new Object[0]);
        }
        Object result = thread.call(
            LuaCompiler.loadstring(Files.readString(root.resolve("tests/layout.lua")),
                "MZUI layout regression", env),
            new Object[0]);
        // thread.pcall(...) with debugOwnerThread=null is what the Lua pcall
        // bridge trips on: penalize with KahluaThread.pcall directly, which
        // the game itself initialises lazily (setDebugOwnerThread). Instead,
        // run the tests twice: any Lua error propagates and fails the check.
        String verdict = result == null ? "OK" : result.toString();
        System.out.println(verdict);
        if (!"OK".equals(verdict)) System.exit(1);
    }
}
