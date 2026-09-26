$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'fpa_recomp_launcher.cs'
$output = Join-Path $PSScriptRoot 'fpa_recomp_launcher.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
}
if (-not (Test-Path -LiteralPath $compiler)) {
    throw 'The .NET Framework C# compiler was not found. Install the .NET Framework developer tools or Visual Studio build tools.'
}

& $compiler /nologo /target:winexe /platform:anycpu /optimize+ `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
    "/out:$output" $source
if ($LASTEXITCODE -ne 0) {
    throw "Launcher compilation failed with exit code $LASTEXITCODE."
}
Write-Output "Built launcher: $output"
