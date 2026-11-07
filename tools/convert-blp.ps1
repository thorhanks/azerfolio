# Converts processed zone art (1024x512 PNG) to BLP2 DXT1 with mipmaps, using tools/Blp.cs (no external tools).
#   powershell -File tools/convert-blp.ps1 -In <png or folder> -Out <folder> [-Verify]
# -Verify decodes each result back to PNG and prints the PSNR against the input (higher is better; >30 dB is good).
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
if (-not ('AzfBlp' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'Blp.cs') -ReferencedAssemblies System.Drawing
}
New-Item -ItemType Directory -Force $Out | Out-Null
$files = if (Test-Path $In -PathType Container) { Get-ChildItem $In -Filter *.png } else { Get-Item $In }
$tmp = Join-Path ([IO.Path]::GetTempPath()) 'azf-blp-verify.png'
foreach ($f in $files) {
    $target = Join-Path (Resolve-Path $Out).Path ($f.BaseName + '.blp')
    $info = [AzfBlp]::Convert($f.FullName, $target)
    $line = "$($f.Name) -> $([IO.Path]::GetFileName($target)) ($info)"
    if ($Verify) {
        [AzfBlp]::Decode($target, $tmp)
        $line += ('  PSNR {0:N1} dB' -f [AzfBlp]::Psnr($f.FullName, $tmp))
    }
    Write-Output $line
}
if (Test-Path $tmp) { Remove-Item $tmp -Force }
