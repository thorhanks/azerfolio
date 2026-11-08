# Processes zone illustrations for the addon and the mockup (see art/style-guide.md §6).
#   art/source/<mapID>-<slug>.(png|jpg|jpeg)  ->  mockups/zone-art/<mapID>.png        (1024x512 PNG, 2:1 crop)
#                                              ->  Azerfolio/Media/Zones/<mapID>.blp   (BLP2 DXT1 + mipmaps, for the game)
#   art/source/fallback*.(png|jpg|jpeg)       ->  fallback.png / fallback.blp
# Regenerates Azerfolio/Data/Art.lua and mockups/zone-art/index.js from what exists.
# Optional focal points: art/focal.json  { "1429": { "x": 0.45, "y": 0.55 } }  (0..1; default 0.5, 0.5)
param(
    [string]$Source = (Join-Path $PSScriptRoot '..\art\source'),
    [string]$Out = (Join-Path $PSScriptRoot '..\mockups\zone-art'),            # PNG (mockup)
    [string]$BlpOut = (Join-Path $PSScriptRoot '..\Azerfolio\Media\Zones'),   # BLP (game)
    [string]$MockOut = (Join-Path $PSScriptRoot '..\mockups\zone-art'),
    [string]$ArtLua = (Join-Path $PSScriptRoot '..\Azerfolio\Data\Art.lua'),
    [string]$FocalFile = (Join-Path $PSScriptRoot '..\art\focal.json'),
    [int]$Width = 1024,
    [int]$Height = 512
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

foreach ($dir in $Source, $Out, $BlpOut, $MockOut, (Split-Path $ArtLua)) { New-Item -ItemType Directory -Force $dir | Out-Null }
if (-not ('AzfBlp' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Blp.cs') -ReferencedAssemblies System.Drawing }

$focal = @{}
if (Test-Path $FocalFile) {
    (Get-Content $FocalFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $focal[$_.Name] = $_.Value }
}

function Convert-Image([string]$inPath, [string]$outPath, [double]$fx, [double]$fy) {
    $src = [System.Drawing.Image]::FromFile($inPath)
    try {
        $ratio = $Width / $Height
        if ($src.Width / $src.Height -ge $ratio) { $ch = $src.Height; $cw = [int][Math]::Round($ch * $ratio) }
        else { $cw = $src.Width; $ch = [int][Math]::Round($cw / $ratio) }
        $cx = [int][Math]::Round($fx * $src.Width - $cw / 2); $cy = [int][Math]::Round($fy * $src.Height - $ch / 2)
        $cx = [Math]::Max(0, [Math]::Min($src.Width - $cw, $cx)); $cy = [Math]::Max(0, [Math]::Min($src.Height - $ch, $cy))

        $dst = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($dst)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $attr = New-Object System.Drawing.Imaging.ImageAttributes
        $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)   # no dark edge artifacts
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $Width, $Height), $cx, $cy, $cw, $ch, [System.Drawing.GraphicsUnit]::Pixel, $attr)
        $g.Dispose()
        $dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $dst.Dispose()
        $warn = if ($cw -lt $Width) { "  (upscaled from ${cw}px wide; generate larger for best quality)" } else { '' }
        return "$([IO.Path]::GetFileName($inPath)) -> $([IO.Path]::GetFileName($outPath)) [crop ${cw}x${ch} at $cx,$cy]$warn"
    } finally { $src.Dispose() }
}

# War banner pieces (art/prompts.md § War banner pieces): painted on flat magenta, fitted into a
# power-of-two canvas (padding is magenta too, so it keys out), keyed to alpha, then BLP2 DXT5.
$PieceSizes = @{ banner = @(256, 512); pole = @(64, 256); badge = @(64, 64) }
$PieceBlpOut = Join-Path $PSScriptRoot '..\Azerfolio\Media\Banner'
$PieceMockOut = Join-Path $PSScriptRoot '..\mockups\banner-art'
foreach ($dir in $PieceBlpOut, $PieceMockOut) { New-Item -ItemType Directory -Force $dir | Out-Null }

function Convert-Piece([string]$inPath, [string]$name, [string]$kind) {
    $cw, $ch = $PieceSizes[$kind]
    $src = [System.Drawing.Image]::FromFile($inPath)
    try {
        $scale = [Math]::Min($cw / $src.Width, $ch / $src.Height)
        $dw = [int][Math]::Round($src.Width * $scale); $dh = [int][Math]::Round($src.Height * $scale)
        $dst = New-Object System.Drawing.Bitmap $cw, $ch, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($dst)
        $g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($src, [int](($cw - $dw) / 2), [int](($ch - $dh) / 2), $dw, $dh)
        $g.Dispose()
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "azf-$name.png"
        $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $dst.Dispose()
    } finally { $src.Dispose() }
    $png = Join-Path (Resolve-Path $PieceMockOut).Path "$name.png"
    $keyed = [AzfBlp]::KeyMagenta($tmp, $png)
    Remove-Item $tmp -ErrorAction SilentlyContinue
    $blp = Join-Path (Resolve-Path $PieceBlpOut).Path "$name.blp"
    $null = [AzfBlp]::ConvertAlpha($png, $blp)
    return "$([IO.Path]::GetFileName($inPath)) -> $name.blp [$keyed]"
}

$processed = 0
$files = Get-ChildItem $Source -File | Where-Object { $_.Extension -match '^\.(png|jpe?g)$' } | Sort-Object Name
foreach ($f in $files) {
    if ($f.BaseName -match '^(banner|pole|badge)-(alliance|horde)$') {
        Write-Output (Convert-Piece $f.FullName $f.BaseName $Matches[1])
        $processed++
        continue
    }
    if ($f.BaseName -match '^(\d+)(?:[-_ ].*)?$') { $key = $Matches[1] }
    elseif ($f.BaseName -match '^fallback') { $key = 'fallback' }
    else { Write-Output "Skip $($f.Name): name must start with a map ID (e.g. 1429-elwynn-forest.png) or 'fallback'"; continue }
    $fx = 0.5; $fy = 0.5
    if ($focal.ContainsKey($key)) { if ($null -ne $focal[$key].x) { $fx = [double]$focal[$key].x }; if ($null -ne $focal[$key].y) { $fy = [double]$focal[$key].y } }
    $target = Join-Path (Resolve-Path $Out).Path "$key.png"
    $line = Convert-Image $f.FullName $target $fx $fy
    if ((Resolve-Path $MockOut).Path -ne (Resolve-Path $Out).Path) { Copy-Item $target (Join-Path $MockOut "$key.png") -Force }
    $blp = Join-Path (Resolve-Path $BlpOut).Path "$key.blp"
    $null = [AzfBlp]::Convert($target, $blp)
    Write-Output "$line + $key.blp"
    $processed++
}

# Index of available art, rebuilt from the game's BLP folder.
$ids = @(Get-ChildItem $BlpOut -Filter *.blp | Where-Object { $_.BaseName -match '^\d+$' } | ForEach-Object { [int]$_.BaseName } | Sort-Object)
$hasFallback = Test-Path (Join-Path $BlpOut 'fallback.blp')

$lua = @('-- Generated by tools/process-art.ps1. Do not edit.',
         '-- Zones with a finished illustration in Media\Zones (the client cannot test whether a file exists).',
         'local _, ns = ...',
         'ns.Art = {',
         "    hasFallback = $($hasFallback.ToString().ToLower()),",
         '    zones = {')
foreach ($id in $ids) { $lua += "        [$id] = true," }
$lua += '    },'
# War banner pieces in Media\Banner (UI/ZoneBanner.lua uses them instead of its stand-in).
$pieces = @(Get-ChildItem $PieceBlpOut -Filter *.blp | ForEach-Object { $_.BaseName } | Sort-Object)
$lua += '    banner = {'
foreach ($p in $pieces) { $lua += "        [""$p""] = true," }
$lua += @('    },', '}')
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $ArtLua)).Path + '\' + (Split-Path $ArtLua -Leaf), $lua, (New-Object System.Text.UTF8Encoding $false))

$js = "// Generated by tools/process-art.ps1. Do not edit.`nwindow.AZF_ART = { fallback: $($hasFallback.ToString().ToLower()), ids: [$($ids -join ',')] };`n"
[IO.File]::WriteAllText((Join-Path (Resolve-Path $MockOut).Path 'index.js'), $js, (New-Object System.Text.UTF8Encoding $false))

Write-Output "Processed $processed image(s). Art available for $($ids.Count) zone(s); fallback: $hasFallback; banner pieces: $($pieces.Count)."
