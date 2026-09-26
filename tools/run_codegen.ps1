$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $projectRoot 'fpa_recomp_manifest.toml'
$rexglue = $null

if ($env:REXGLUE_SDK_PREFIX) {
    $sdkCli = Join-Path $env:REXGLUE_SDK_PREFIX 'bin/rexglue.exe'
    if (Test-Path -LiteralPath $sdkCli -PathType Leaf) {
        $rexglue = $sdkCli
    }
}
if (-not $rexglue -and (Get-Command 'rexglue' -ErrorAction SilentlyContinue)) {
    $rexglue = 'rexglue'
}
if (-not $rexglue) {
    throw 'ReXGlue CLI not found. Set REXGLUE_SDK_PREFIX or add rexglue.exe to PATH.'
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Local ReXGlue manifest is missing: $manifestPath. Create it from config/rexglue.example.toml first."
}

Push-Location $projectRoot
try {
    & $rexglue codegen $manifestPath
    if ($LASTEXITCODE -ne 0) {
        throw "ReXGlue code generation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
