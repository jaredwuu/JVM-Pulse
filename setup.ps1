[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8766,
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$mavenVersion = '3.9.16'
$toolsDirectory = Join-Path $PSScriptRoot 'tools'
$mavenDirectory = Join-Path $toolsDirectory "maven\apache-maven-$mavenVersion"
$mavenLauncher = Join-Path $mavenDirectory 'bin\mvn.cmd'

function Get-JavaMajorVersion {
    $versionOutput = (& java -version 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'version "(?<major>\d+)') {
        return 0
    }
    return [int]$Matches.major
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

Write-Host 'Checking Java...'
$javaCommand = Get-Command java -ErrorAction SilentlyContinue
$javaMajor = if ($javaCommand) { Get-JavaMajorVersion } else { 0 }
if ($javaMajor -lt 21) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'JDK 21+ is required and winget is unavailable. Install a full JDK 21 or newer, then rerun setup.ps1.'
    }

    Write-Host 'Installing Eclipse Temurin JDK 21 (Windows may request approval)...'
    & winget install --exact --id EclipseAdoptium.Temurin.21.JDK --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "JDK installation failed with exit code $LASTEXITCODE."
    }
    Refresh-Path

    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    $javaMajor = if ($javaCommand) { Get-JavaMajorVersion } else { 0 }
    if ($javaMajor -lt 21) {
        $adoptiumRoot = Join-Path $env:ProgramFiles 'Eclipse Adoptium'
        $installedJdk = Get-ChildItem -LiteralPath $adoptiumRoot -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($installedJdk) {
            $env:JAVA_HOME = $installedJdk.FullName
            $env:Path = "$(Join-Path $installedJdk.FullName 'bin');$env:Path"
            $javaMajor = Get-JavaMajorVersion
        }
    }
    if ($javaMajor -lt 21) {
        throw 'JDK 21 was installed but is not available in this terminal. Open a new PowerShell window and rerun setup.ps1.'
    }
}
Write-Host "Java $javaMajor is ready."

if (-not (Test-Path -LiteralPath $mavenLauncher)) {
    $archiveName = "apache-maven-$mavenVersion-bin.zip"
    $downloadBase = "https://dlcdn.apache.org/maven/maven-3/$mavenVersion/binaries"
    $archive = Join-Path $toolsDirectory $archiveName
    $checksumFile = "$archive.sha512"
    $mavenRoot = Join-Path $toolsDirectory 'maven'

    New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
    Write-Host "Downloading Apache Maven $mavenVersion..."
    try {
        Invoke-WebRequest -Uri "$downloadBase/$archiveName" -OutFile $archive -UseBasicParsing
        Invoke-WebRequest -Uri "$downloadBase/$archiveName.sha512" -OutFile $checksumFile -UseBasicParsing
        $expectedHash = ((Get-Content -LiteralPath $checksumFile -Raw) -split '\s+')[0].Trim()
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash
        if ($actualHash -ne $expectedHash) {
            throw 'The downloaded Maven archive failed SHA-512 verification.'
        }
        New-Item -ItemType Directory -Force -Path $mavenRoot | Out-Null
        Expand-Archive -LiteralPath $archive -DestinationPath $mavenRoot -Force
        if (-not (Test-Path -LiteralPath $mavenLauncher)) {
            throw 'The Maven archive did not contain the expected launcher.'
        }
    } finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $checksumFile -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "Maven $mavenVersion is ready."

if ($NoStart) {
    Write-Host 'Setup complete. Start later with: .\run.ps1 8766'
    exit 0
}

Write-Host "Starting JVM Pulse on http://localhost:$Port ..."
& (Join-Path $PSScriptRoot 'run.ps1') $Port
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
