# JVM Pulse

JVM Pulse is a local Windows web application for monitoring JVM CPU, heap, threads, classes, garbage collection, JFR recordings, and retained-memory dominators. It discovers JVMs started from IntelliJ IDEA and other local launchers.

## Prerequisites

- Windows 10 or newer with PowerShell 5.1+
- JDK 21 or newer on `PATH` (`java`, `jps`, and `jcmd` must be available)
- Apache Maven 3.8+ on `PATH`
- The monitor and target JVM must run as the same Windows user

Verify the tools:

```powershell
java -version
jps -l
mvn -version
```

## Start

Clone the repository, enter its directory, and run:

```powershell
.\run.ps1 8766
```

Open `http://localhost:8766`.

On the first run, the script:

1. Downloads Eclipse Memory Analyzer 1.17 into the ignored `tools/mat` directory.
2. Builds the Java server and copies Maven runtime dependencies into `target`.
3. Stops an existing JVM Pulse instance on the requested port, but refuses to stop unrelated processes.
4. Starts the monitor on localhost.

Later starts reuse the local MAT installation. Run `.\setup-mat.ps1` directly to reinstall it.

## IntelliJ Targets

If attaching fails because the JMX RMI endpoint advertises a non-loopback address, add this VM option to the target application's IntelliJ run configuration and restart it:

```text
-Djava.rmi.server.hostname=127.0.0.1
```

## Diagnostics

The Diagnostics tab includes top CPU threads, allocation pressure, GC activity, class histograms, JFR hot methods and allocations, and heap dominators. Heap analysis creates a live HPROF dump and can pause the target. Ensure free disk space is at least the target's used heap size.

Eclipse MAT is the primary retained-memory analyzer. Temporary dumps, MAT indexes, recordings, and reports are stored under `captures` and are not committed.

## Repository Contents

Commit these files and directories:

```text
public/
src/
.gitignore
pom.xml
README.md
run.ps1
setup-mat.ps1
```

Do not commit generated or machine-local content:

```text
captures/
target/
out/
tools/mat/
tools/mat.zip
tools/*.json
workspace/
*.log
.edge-profile/
.vscode/
```

Before pushing, check the staged files:

```powershell
git status --short
git diff --cached --stat
```
