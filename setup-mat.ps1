$ErrorActionPreference = 'Stop'

$version = '1.17.0.20260601'
$archiveName = "MemoryAnalyzer-$version-win32.win32.x86_64.zip"
$downloadUrl = "https://download.eclipse.org/mat/1.17.0/rcp/$archiveName"
$toolsDirectory = Join-Path $PSScriptRoot 'tools'
$matDirectory = Join-Path $toolsDirectory 'mat'
$launcher = Join-Path $matDirectory 'mat\ParseHeapDump.bat'
$matIni = Join-Path $matDirectory 'mat\MemoryAnalyzer.ini'
$archive = Join-Path $toolsDirectory 'mat.zip'
$partialArchive = "$archive.part"
$toolsRoot = [IO.Path]::GetFullPath($toolsDirectory).TrimEnd('\') + '\'
$matRoot = [IO.Path]::GetFullPath($matDirectory)
if (-not $matRoot.StartsWith($toolsRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to manage MAT outside $toolsRoot"
}

if (Test-Path -LiteralPath $launcher) {
    Write-Host "Eclipse MAT is already installed at $matDirectory"
    exit 0
}

New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
Write-Host "Downloading Eclipse Memory Analyzer $version..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $partialArchive -UseBasicParsing
    Move-Item -LiteralPath $partialArchive -Destination $archive -Force
    if (Test-Path -LiteralPath $matDirectory) {
        Remove-Item -LiteralPath $matDirectory -Recurse -Force
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $matDirectory -Force
    if (-not (Test-Path -LiteralPath $launcher)) {
        throw "The MAT archive did not contain mat\ParseHeapDump.bat."
    }
    $ini = Get-Content -LiteralPath $matIni
    $ini = $ini -replace '^-Xmx\d+[mMgG]$', '-Xmx8g'
    Set-Content -LiteralPath $matIni -Value $ini -Encoding ASCII
    Write-Host "Eclipse MAT installed at $matDirectory"
} finally {
    Remove-Item -LiteralPath $partialArchive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
}
