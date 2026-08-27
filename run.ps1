$ErrorActionPreference = 'Stop'
$port = if ($args.Count -gt 0) { [int]$args[0] } else { 8080 }
$matLauncher = Join-Path $PSScriptRoot 'tools\mat\mat\ParseHeapDump.bat'
if (-not (Test-Path -LiteralPath $matLauncher)) {
    & (Join-Path $PSScriptRoot 'setup-mat.ps1')
}
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
$compatibilityOptions = '--enable-native-access=ALL-UNNAMED'
$env:MAVEN_OPTS = if ($previousMavenOpts) { "$previousMavenOpts $compatibilityOptions" } else { $compatibilityOptions }
$localMaven = Join-Path $PSScriptRoot 'tools\maven\apache-maven-3.9.16\bin\mvn.cmd'
$maven = if (Test-Path -LiteralPath $localMaven) { $localMaven } else { 'mvn' }
try {
    & $maven -q -DskipTests package
    if ($LASTEXITCODE -ne 0) {
        throw "Maven build failed with exit code $LASTEXITCODE."
    }
} finally {
    $env:MAVEN_OPTS = $previousMavenOpts
}
$dependencies = (Get-ChildItem target\dependency\*.jar | ForEach-Object FullName) -join ';'
java --add-modules jdk.httpserver,jdk.attach,jdk.management.jfr -cp "target\classes;$dependencies" JvmPulseServer $port
if ($LASTEXITCODE -ne 0) {
    throw "JVM Pulse exited with code $LASTEXITCODE."
}
