$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'

if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
    throw "Visual Studio locator was not found: $vswhere"
}
$vsRoot = (& $vswhere -products * -property installationPath | Select-Object -First 1)
if (-not $vsRoot) {
    throw 'Visual Studio installation was not found.'
}
$cmake = (Get-Command cmake -ErrorAction SilentlyContinue).Source
if (-not $cmake) {
    $cmake = Join-Path $vsRoot 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
}
$clangBin = Join-Path $vsRoot 'VC/Tools/Llvm/x64/bin'
if (-not (Test-Path -LiteralPath $cmake -PathType Leaf)) {
    throw "CMake was not found: $cmake"
}
if (-not (Test-Path -LiteralPath (Join-Path $clangBin 'clang++.exe') -PathType Leaf)) {
    throw "Visual Studio x64 Clang was not found in: $clangBin"
}
$env:PATH = "$clangBin;$env:PATH"
$configureArgs = @('--preset', 'win-amd64-release')
if ($env:REXGLUE_SDK_PREFIX) {
    $configureArgs += "-DCMAKE_PREFIX_PATH=$env:REXGLUE_SDK_PREFIX"
}
Push-Location $projectRoot
try {
    & $cmake @configureArgs
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configuration failed with exit code $LASTEXITCODE."
    }
    & $cmake --build --preset win-amd64-release --parallel 4
    if ($LASTEXITCODE -ne 0) {
        throw "Release build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
