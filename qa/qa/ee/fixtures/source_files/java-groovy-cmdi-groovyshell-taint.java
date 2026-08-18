package testcode.groovy;

import groovy.lang.GroovyClassLoader;
import groovy.lang.GroovyCodeSource;
import groovy.lang.GroovyShell;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.URISyntaxException;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
class GroovyShellUsage {

    private static final Set<String> ALLOWED_EXPRESSIONS = new HashSet<>(Arrays.asList(
            "println 'Hello World!'",
            "println 'Goodbye World!'"));

    @GetMapping("/test1")
    public static void test1(@RequestParam(uri = "uri") String uri, @RequestParam(file = "file") String file,
            @RequestParam(script = "script") String script) throws URISyntaxException, FileNotFoundException {
        GroovyShell shell = new GroovyShell();

        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.evaluate(new File(file));
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.evaluate(new InputStreamReader(new FileInputStream(file)), "script1.groovy");
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.evaluate(script);
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.evaluate(script, "script1.groovy", "test");
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.evaluate(new URI(uri));
        // ok:java-groovy-cmdi-groovyshell-taint
        shell.evaluate("hardcoded script");

        if (ALLOWED_EXPRESSIONS.contains(script)) {
            // ok:java-groovy-cmdi-groovyshell-taint
            shell.evaluate(script);
        }

        if (ALLOWED_EXPRESSIONS.contains(script)) {
            // ruleid:java-groovy-cmdi-groovyshell-taint
            shell.evaluate(new File(file));
        }
    }

    @GetMapping("/test2")
    public static void test2(@RequestParam(uri = "uri") String uri, @RequestParam(file = "file") String file,
            @RequestParam(script = "script") String script) throws URISyntaxException, FileNotFoundException {
        GroovyShell shell = new GroovyShell();

        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(new File(file));
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(new InputStreamReader(new FileInputStream(file)), "test.groovy");
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(new InputStreamReader(new FileInputStream(file)));
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(script);
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(script, "test.groovy");
        // ruleid:java-groovy-cmdi-groovyshell-taint
        shell.parse(new URI(uri));

        String hardcodedScript = "test.groovy";
        // ok:java-groovy-cmdi-groovyshell-taint
        shell.parse(hardcodedScript);

        if (ALLOWED_EXPRESSIONS.contains(script)) {
            // ok:java-groovy-cmdi-groovyshell-taint
            shell.parse(script);
        }
    }

    @GetMapping("/test3")
    public static void test3(@RequestParam(uri = "uri") String uri, @RequestParam(file = "file") String file,
            @RequestParam(script = "script") String script, ClassLoader loader)
            throws URISyntaxException, FileNotFoundException {
        GroovyClassLoader groovyLoader = (GroovyClassLoader) loader;

        // ruleid:java-groovy-cmdi-groovyshell-taint
        groovyLoader.parseClass(new GroovyCodeSource(new File(file)), false);
        // ruleid:java-groovy-cmdi-groovyshell-taint
        groovyLoader.parseClass(new InputStreamReader(new FileInputStream(file)), "test.groovy");
        // ruleid:java-groovy-cmdi-groovyshell-taint
        groovyLoader.parseClass(script);
        // ruleid:java-groovy-cmdi-groovyshell-taint
        groovyLoader.parseClass(script, "test.groovy");

        String hardcodedScript = "test.groovy";
        // ok:java-groovy-cmdi-groovyshell-taint
        shell.parse(hardcodedScript);
    }

}