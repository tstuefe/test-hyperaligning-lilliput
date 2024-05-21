package de.stuefe.repros.metaspace;

import de.stuefe.repros.MiscUtils;
import de.stuefe.repros.TestCaseBase;
import de.stuefe.repros.metaspace.internals.InMemoryClassLoader;
import de.stuefe.repros.metaspace.internals.Utils;
import picocli.CommandLine;

import java.lang.reflect.Constructor;
import java.util.Random;
import java.util.concurrent.Callable;

@CommandLine.Command(name = "ManyClassesManyObjectsFullGC", mixinStandardHelpOptions = true,
        description = "ManyClassesManyObjectsFullGC repro.")
public class InterleaveKlassRefsInHeap extends TestCaseBase implements Callable<Integer> {

    @CommandLine.Option(names = { "--autoyes", "-y" }, defaultValue = "false",
            description = "Autoyes.")
    boolean auto_yes;
    int unattendedModeWaitSecs = 4;

    @CommandLine.Option(names = { "--nowait" }, defaultValue = "false",
            description = "do not wait (only with autoyes).")
    boolean nowait;

    @CommandLine.Option(names = { "--verbose", "-v" }, defaultValue = "false",
            description = "Verbose.")
    boolean verbose;

    public static void main(String... args) {
        int exitCode = new CommandLine(new InterleaveKlassRefsInHeap()).execute(args);
        System.exit(exitCode);
    }


    @CommandLine.Option(names = { "--num-classes", "-C" }, description = "Number of classes (default: ${DEFAULT_VALUE})")
    int numClasses=256;

    @CommandLine.Option(names = { "--objects", "-n" }, description = "Number of objects per class (default: ${DEFAULT_VALUE})")
    int numObjectsPerClass=50000;

    @CommandLine.Option(names = { "--cycles", "-c" }, description = "Number of GC cycles (default: ${DEFAULT_VALUE})")
    int cycles = 10;

    @CommandLine.Option(names = { "--print-hashes" }, description = "Print hashes (default: ${DEFAULT_VALUE})")
    boolean printHashes = false;

    @CommandLine.Option(names = { "--randomize" }, description = "Randomizes object classes (off: strict interleaving) (default: ${DEFAULT_VALUE})")
    boolean randomize = false;

    @CommandLine.Option(names = { "--class-stride" }, description = "If not --randomize: stride by which we alter the class per object (default: ${DEFAULT_VALUE})")
    int classStride = 1;

    static Object[] RETAIN;

    @Override
    public Integer call() throws Exception {
        initialize(verbose, auto_yes, nowait);

        System.out.println("Num Classes: " + numClasses);
        System.out.println("Num Objects per Class: " + numObjectsPerClass);
        System.out.println("Cycles: " + cycles);
        System.out.println("Class association: " + (randomize ? "random" : "striding with " + classStride));

        Random r = new Random(0x12345678);

        final String source = "" +
                "public class CLASSNAME {" +
                "}";

        System.out.print("Generate " + numClasses + " classes...");
        for (int i = 0; i < numClasses; i ++) {
            String classname = "my_generated_class" + i;
            String source0 = source.replace("CLASSNAME", classname);
            Utils.createClassFromSource(classname, source0);
        }
        System.out.println();

        System.out.print("Loading " + numClasses + "...");

        InMemoryClassLoader loader = new InMemoryClassLoader("loader", null);
        Class classes[] = new Class[numClasses];

        try {
            for (int j = 0; j < numClasses; j++) {
                classes[j] = Class.forName("my_generated_class" + j, true, loader);
            }
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }

        System.gc();

        System.out.print("Creating " + numObjectsPerClass + " objects per class...");

        RETAIN = new Object[numObjectsPerClass * numClasses];
        int idx = 0;

        Constructor ctors[] = new Constructor[numClasses];
        for (int i = 0; i < numClasses; i++) {
            Class clazz = classes[i];
            Constructor ctor = clazz.getDeclaredConstructor();
            ctors[i] = ctor;
        }

        // Create objects in heap
        for (int j = 0; j < numObjectsPerClass; j++) {
            for (int i = 0; i < numClasses; i++) {
                int classId = randomize ?
                        r.nextInt(numClasses) :
                        (i * classStride) % numClasses;
                RETAIN[idx] = ctors[classId].newInstance();
                idx++;
           }
        }
        System.out.println();

        if (printHashes) {
            int col = 0;
            for (Object o: RETAIN) {
                int i = System.identityHashCode(o);
                System.out.print(Integer.toHexString(i) + " ");
                if (++col == 16) {
                    col = 0;
                    System.out.println("");
                }
            }
        }

        System.out.println("Done; will start GCs... ");

        if (!nowait) {
            MiscUtils.waitForKeyPress();
        }

        for (int i = 0; i < cycles; i++) {
            System.gc();
        }

        System.out.println("After GCs... ");

        if (!nowait) {
            MiscUtils.waitForKeyPress();
        }

        return 0;


    }

}
