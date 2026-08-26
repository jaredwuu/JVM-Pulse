# JVM Pulse

JVM Pulse is a local Windows web application for monitoring JVM CPU, heap, threads, classes, garbage collection, JFR recordings, and retained-memory dominators. It discovers JVMs started from IntelliJ IDEA and other local launchers.

## Start on a fresh Windows computer

The easiest option is to open PowerShell in the downloaded JVM Pulse directory and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

`setup.ps1` checks for a full JDK 21+, installs Temurin 21 through `winget` when needed, downloads a verified project-local copy of Maven, installs Eclipse Memory Analyzer, builds the application, and starts it at [http://localhost:8766](http://localhost:8766). It is safe to run again.

To set up without starting the server, or to use another port:

```powershell
.\setup.ps1 -NoStart
.\setup.ps1 -Port 8767
```

JVM Pulse requires Windows 10 or newer and PowerShell 5.1+. A JRE alone is not sufficient because JVM Pulse uses `jps`, `jcmd`, and JDK attach tools.

### 1. Install the required tools

Open PowerShell and install Git and the Temurin 21 JDK with Windows Package Manager:

```powershell
winget install --exact --id Git.Git
winget install --exact --id EclipseAdoptium.Temurin.21.JDK
```

Install [Apache Maven](https://maven.apache.org/install.html). If Chocolatey is already installed, this command is sufficient:

```powershell
choco install maven -y
```

Close and reopen PowerShell after installation so the updated `PATH` is loaded. Confirm that every command works:

```powershell
git --version
java -version
jps -l
jcmd -l
mvn -version
```

`java -version` and the Java version shown by `mvn -version` should both be 21 or newer. If Maven shows an older Java version, update `JAVA_HOME` to the JDK 21 installation and open a new terminal.

### 2. Download JVM Pulse

```powershell
git clone https://github.com/jaredwuu/JVM-Pulse.git
Set-Location JVM-Pulse
```

If the repository is already open in an IDE, open a PowerShell terminal in the repository root instead.

### 3. Start JVM Pulse

```powershell
.\run.ps1 8766
```

Then open [http://localhost:8766](http://localhost:8766).

If PowerShell says that script execution is disabled, allow scripts only for the current terminal and retry:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\run.ps1 8766
```

Keep that terminal open while using JVM Pulse. Stop the server with `Ctrl+C`.

### What happens on the first start

The first start needs internet access and can take a few minutes. The script:

1. Downloads Eclipse Memory Analyzer into `tools/mat`.
2. Downloads Maven dependencies and builds the Java server into `target`.
3. Starts JVM Pulse on `localhost` using the requested port.

Later starts reuse those downloads. Starting the script again on the same port safely replaces an existing JVM Pulse process, but refuses to stop an unrelated process using that port.

To reinstall Eclipse Memory Analyzer, remove `tools/mat` and run `.\setup-mat.ps1`, or run the setup script after the directory has been removed.

### Startup troubleshooting

- **`java`, `jps`, or `jcmd` is not recognized:** install a full JDK, then open a new PowerShell window.
- **`mvn` is not recognized:** install Maven and ensure its `bin` directory is on `PATH`.
- **Maven uses the wrong Java version:** set `JAVA_HOME` to a JDK 21-or-newer directory and reopen PowerShell.
- **Port 8766 is already in use:** choose another port, for example `.\run.ps1 8767`, and open the matching URL.
- **A download fails:** check proxy/firewall access to Maven Central and `download.eclipse.org`, then rerun the command.
- **A target JVM is missing:** run JVM Pulse and the target application as the same Windows user.

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
