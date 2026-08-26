# JVM Pulse

Live JVM and host monitoring for CPU, heap, memory, threads, classes, and garbage collection. The application selector discovers local JVMs, including applications launched from IntelliJ IDEA.

## Run

```powershell
.\run.ps1
```

Open `http://localhost:8080`. To use another port, pass it as the first argument: `.\run.ps1 8765`.

The monitor and target JVM must run under the same Windows user. A target using a restricted runtime without the `jdk.management.agent` module may be listed but cannot be attached.

## Diagnostics

The Diagnostics tab provides top CPU threads, observed heap growth, GC pause activity, an on-demand object histogram, timed Java Flight Recorder captures, retained-memory dominators, hot methods, allocation hotspots, call stacks, and source hints. JFR files are streamed from the selected JVM and can be opened in JDK Mission Control or VisualVM.

Retained-memory analysis creates a live HPROF dump and may pause the target. It requires free disk near the target's used heap size and separate analyzer memory. The temporary dump and parser cache are removed after analysis. Apache NetBeans' heap parser is downloaded by Maven during the first build.

The Analysis tab evaluates the active sample window and available diagnostic evidence. It ranks CPU, heap, GC, allocation-pressure, thread-count, and processor-limit findings, then provides evidence-based investigation or optimization actions. Recommendations are advisory and never modify the target application automatically.
