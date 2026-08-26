$ErrorActionPreference = 'Stop'
$port = if ($args.Count -gt 0) { [int]$args[0] } else { 8080 }
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $ownerPid = $listener.OwningProcess
    $isJvmPulse = jps -l | Select-String -Pattern "^$ownerPid\s+JvmPulseServer$"
    if (-not $isJvmPulse) {
        throw "Port $port is used by PID $ownerPid, which is not JVM Pulse. Refusing to stop it."
    }
    Write-Host "Stopping existing JVM Pulse PID $ownerPid on port $port..."
    Stop-Process -Id $ownerPid
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 250
        $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    } while ($listener -and (Get-Date) -lt $deadline)
    if ($listener) {
        throw "JVM Pulse PID $ownerPid stopped, but port $port was not released within 10 seconds."
    }
}

$previousMavenOpts = $env:MAVEN_OPTS
$compatibilityOptions = '--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow'
$env:MAVEN_OPTS = if ($previousMavenOpts) { "$previousMavenOpts $compatibilityOptions" } else { $compatibilityOptions }
try {
    mvn -q -DskipTests package
} finally {
    $env:MAVEN_OPTS = $previousMavenOpts
}
$dependencies = (Get-ChildItem target\dependency\*.jar | ForEach-Object FullName) -join ';'
java --add-modules jdk.httpserver,jdk.attach,jdk.management.jfr -cp "target\classes;$dependencies" JvmPulseServer $port
