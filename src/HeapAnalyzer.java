import org.netbeans.lib.profiler.heap.Heap;
import org.netbeans.lib.profiler.heap.HeapFactory;
import org.netbeans.lib.profiler.heap.Instance;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

public final class HeapAnalyzer {
    public static void main(String[] args) throws Exception {
        Path dump = Path.of(args[0]);
        String classPath = args.length > 1 ? Files.readString(Path.of(args[1])) : "";
        Heap heap = HeapFactory.createHeap(dump.toFile());
        List<Instance> biggest;
        boolean retainedSizesAvailable = true;
        String analysisWarning = null;
        try {
            biggest = instances(heap.getBiggestObjectsByRetainedSize(20));
        } catch (RuntimeException parserFailure) {
            retainedSizesAvailable = false;
            analysisWarning = "Retained-size calculation is unavailable for this heap format; showing the largest objects by shallow size.";
            biggest = biggestByShallowSize(heap, 20);
        }
        String prefix = "{\"dumpSize\":" + Files.size(dump)
                + ",\"retainedSizesAvailable\":" + retainedSizesAvailable
                + ",\"warning\":" + nullable(analysisWarning) + ",\"dominators\":[";
        StringJoiner json = new StringJoiner(",", prefix, "]}");
        for (Object value : biggest) {
            Instance instance = (Instance) value;
            String className = instance.getJavaClass().getName();
            long retainedSize = retainedSizesAvailable ? instance.getRetainedSize() : instance.getSize();
            json.add("{\"className\":\"" + esc(className) + "\",\"instanceId\":" + instance.getInstanceId()
                    + ",\"shallowSize\":" + instance.getSize() + ",\"retainedSize\":" + retainedSize
                    + ",\"gcRootPath\":" + rootPath(instance, retainedSizesAvailable) + ",\"source\":" + nullable(findSource(classPath, className))
                    + ",\"hint\":\"" + esc(memoryHint(className)) + "\"}");
        }
        System.out.print(json);
    }

    private static List<Instance> instances(List values) {
        List<Instance> result = new ArrayList<>(values.size());
        for (Object value : values) result.add((Instance) value);
        return result;
    }

    private static List<Instance> biggestByShallowSize(Heap heap, int limit) {
        PriorityQueue<Instance> biggest = new PriorityQueue<>(Comparator.comparingLong(Instance::getSize));
        Iterator iterator = heap.getAllInstancesIterator();
        while (iterator.hasNext()) {
            Instance instance = (Instance) iterator.next();
            if (instance == null) continue;
            if (biggest.size() < limit) biggest.add(instance);
            else if (instance.getSize() > biggest.peek().getSize()) {
                biggest.poll();
                biggest.add(instance);
            }
        }
        List<Instance> result = new ArrayList<>(biggest);
        result.sort(Comparator.comparingLong(Instance::getSize).reversed());
        return result;
    }

    private static String rootPath(Instance start, boolean available) {
        if (!available) return "[\"Unavailable for this heap format\"]";
        StringJoiner path = new StringJoiner(",", "[", "]");
        Set<Long> seen = new HashSet<>();
        Instance current = start;
        try {
            for (int depth = 0; current != null && depth < 12 && seen.add(current.getInstanceId()); depth++) {
                path.add("\"" + esc(current.getJavaClass().getName() + (current.isGCRoot() ? " [GC root]" : "")) + "\"");
                if (current.isGCRoot()) break;
                current = current.getNearestGCRootPointer();
            }
        } catch (RuntimeException parserFailure) {
            path.add("\"GC-root path unavailable for this object\"");
        }
        return path.toString();
    }

    private static String findSource(String classPath, String className) {
        String relative = className.split("\\$", 2)[0].replace('.', '/') + ".java";
        for (String entry : classPath.split(File.pathSeparator)) {
            try {
                Path classes = Path.of(entry);
                if (classes.endsWith(Path.of("target", "classes"))) {
                    Path source = classes.getParent().getParent().resolve("src/main/java").resolve(relative);
                    if (Files.isRegularFile(source)) return source.toString();
                }
            } catch (Exception ignored) {}
        }
        return null;
    }

    private static String memoryHint(String name) {
        if (name.equals("java.lang.String") || name.equals("byte[]") || name.equals("char[]")) return "Inspect payload duplication, cache keys, buffers, and string construction.";
        if (name.contains("HashMap") || name.contains("ConcurrentHashMap")) return "Review cache bounds, key lifecycle, and map ownership.";
        if (name.contains("ThreadLocal")) return "Ensure ThreadLocal values are removed when pooled-thread work completes.";
        return "Use retained size and the GC-root path to identify the owning component before changing allocation code.";
    }

    private static String nullable(String value) { return value == null ? "null" : "\"" + esc(value) + "\""; }
    private static String esc(String value) { return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"); }
}
