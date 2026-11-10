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

# Pieces other than zone art (art/prompts.md): war banner pieces, interface chrome and icons.
#   kind      canvas    how                                   output
#   banner    256x512   fit, magenta keyed, DXT5              Media\Banner
#   pole      64x256    fit, keyed, DXT5                      Media\Banner
#   streamer  64x512    fit, keyed, DXT5                      Media\Banner
#   badge     64x64     fit, keyed, DXT5 (no longer used)     Media\Banner
#   frame     256x256 (frame-card) / 512x64 (frame-bar) / 128x64 (frame-step) / 256x128 (frame-plaque): stretched, keyed, DXT5, border measured -> Media\Chrome
#   emblem    128x128   fit, keyed, DXT5                      Media\Chrome (rep-<reaction>: the standing strip)
#   plate     512x128   stretched, keyed, DXT5                Media\Chrome
#   divider   512x64    stretched, keyed, DXT5                Media\Chrome
#   fill      512x64    stretched, opaque DXT1                Media\Chrome
#   icon      128x128   centre-cropped square, opaque DXT1    Media\Icons
#   backdrop  1024x1024 stretched (4:3 source), opaque DXT1  Media\Chrome (atlas-*: the Atlas's sea map)
#   celburst  512x512   stretched, black keyed to alpha (glow), DXT5  Media\Chrome (cel-burst)
#   cel       256x256   fit, keyed, DXT5                      Media\Chrome (cel-laurel, cel-seal-*, cel-claim-*)
#   ribbon    512x128   stretched, keyed, DXT5, not sliced (a centre crest)  Media\Chrome (cel-ribbon)
# Nine-slice borders (frames, plates) are measured from the keyed image, or set in art/slices.json.
$PieceKinds = @{
    banner = @{ size = @(256, 512); fit = 'fit'; key = $true; dir = 'Banner' }
    pole = @{ size = @(64, 256); fit = 'fit'; key = $true; dir = 'Banner' }
    streamer = @{ size = @(64, 512); fit = 'fit'; key = $true; dir = 'Banner' }
    badge = @{ size = @(64, 64); fit = 'fit'; key = $true; dir = 'Banner' }
    'frame-card' = @{ size = @(256, 256); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true }
    'frame-bar' = @{ size = @(512, 64); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true }
    'frame-step' = @{ size = @(128, 64); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true } # reputation ladder step
    'frame-plaque' = @{ size = @(256, 128); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true } # standing strip cell
    emblem = @{ size = @(128, 128); fit = 'fit'; key = $true; dir = 'Chrome' }
    plate = @{ size = @(512, 128); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true }
    divider = @{ size = @(512, 64); fit = 'stretch'; key = $true; dir = 'Chrome' }
    fill = @{ size = @(512, 64); fit = 'stretch'; key = $false; dir = 'Chrome' }
    icon = @{ size = @(128, 128); fit = 'crop'; key = $false; dir = 'Icons' }
    backdrop = @{ size = @(1024, 1024); fit = 'stretch'; key = $false; dir = 'Chrome' }
    celburst = @{ size = @(512, 512); fit = 'stretch'; key = $false; keyBlack = $true; dir = 'Chrome' }
    cel = @{ size = @(256, 256); fit = 'fit'; key = $true; dir = 'Chrome' }
    ribbon = @{ size = @(512, 128); fit = 'stretch'; key = $true; dir = 'Chrome' }
}
$MediaRoot = if ($env:AZF_MEDIA_ROOT) { $env:AZF_MEDIA_ROOT } else { Join-Path $PSScriptRoot '..\Azerfolio\Media' }
$PieceMockRoot = if ($env:AZF_PIECE_MOCK_ROOT) { $env:AZF_PIECE_MOCK_ROOT } else { Join-Path $PSScriptRoot '..\mockups' }
$MockDirs = @{ Banner = 'banner-art'; Chrome = 'chrome-art'; Icons = 'icon-art' }
foreach ($d in 'Banner', 'Chrome', 'Icons') {
    New-Item -ItemType Directory -Force (Join-Path $MediaRoot $d) | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $PieceMockRoot $MockDirs[$d]) | Out-Null
}
$SlicesFile = Join-Path $PSScriptRoot '..\art\slices.json'
$slices = @{}
if (Test-Path $SlicesFile) {
    (Get-Content $SlicesFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $slices[$_.Name] = $_.Value }
}
$measured = @{}

# The kind of a source file by its name, or $null.
function Get-PieceKind([string]$name) {
    if ($name -match '^(banner|pole|streamer|badge)-(alliance|horde)$') { return $Matches[1] }
    if ($name -eq 'frame-card' -or $name -eq 'frame-bar' -or $name -eq 'frame-step' -or $name -eq 'frame-plaque') { return $name }
    if ($name -match '^rep-(hated|hostile|unfriendly|neutral|friendly|honored|revered|exalted)$') { return 'emblem' }
    if ($name -match '^plate-[a-z0-9-]+$') { return 'plate' }
    if ($name -match '^divider(-[a-z0-9-]+)?$') { return 'divider' }
    if ($name -match '^bar-fill(-[a-z0-9-]+)?$') { return 'fill' }
    if ($name -match '^icon-[a-z0-9-]+$') { return 'icon' }
    if ($name -match '^atlas-[a-z0-9-]+$') { return 'backdrop' }
    if ($name -eq 'cel-burst') { return 'celburst' }
    if ($name -eq 'cel-ribbon') { return 'ribbon' }
    if ($name -match '^cel-(laurel|seal-[a-z0-9-]+|claim-(alliance|horde))$') { return 'cel' }
    return $null
}

function Convert-Piece([string]$inPath, [string]$name, [string]$kind) {
    $k = $PieceKinds[$kind]
    $cw, $ch = $k.size
    $src = [System.Drawing.Image]::FromFile($inPath)
    try {
        $dst = New-Object System.Drawing.Bitmap $cw, $ch, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($dst)
        # The canvas behind the piece: black for a glow keyed from black, else magenta.
        if ($k.keyBlack) { $g.Clear([System.Drawing.Color]::Black) }
        else { $g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255)) }
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        # Mirror at the edges while resampling, so pixels past the image's edge (the canvas
        # colour) don't bleed into its border (a faint magenta rim around the burst, owner).
        $attrs = New-Object System.Drawing.Imaging.ImageAttributes
        $attrs.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        if ($k.fit -eq 'fit') {
            $scale = [Math]::Min($cw / $src.Width, $ch / $src.Height)
            $dw = [int][Math]::Round($src.Width * $scale); $dh = [int][Math]::Round($src.Height * $scale)
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle ([int](($cw - $dw) / 2)), ([int](($ch - $dh) / 2)), $dw, $dh),
                0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
        } elseif ($k.fit -eq 'crop') {
            $side = [Math]::Min($src.Width, $src.Height)
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch),
                [int](($src.Width - $side) / 2), [int](($src.Height - $side) / 2), $side, $side, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
        } else {
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch),
                0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
        }
        $attrs.Dispose()
        $g.Dispose()
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "azf-$name.png"
        $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $dst.Dispose()
    } finally { $src.Dispose() }
    $png = Join-Path (Resolve-Path (Join-Path $PieceMockRoot $MockDirs[$k.dir])).Path "$name.png"
    $blp = Join-Path (Resolve-Path (Join-Path $MediaRoot $k.dir)).Path "$name.blp"
    $note = ''
    if ($k.keyBlack) {
        $note = [AzfBlp]::KeyBlack($tmp, $png)
        $null = [AzfBlp]::ConvertAlpha($png, $blp)
    } elseif ($k.key) {
        $note = [AzfBlp]::KeyMagenta($tmp, $png)
        $null = [AzfBlp]::ConvertAlpha($png, $blp)
    } else {
        Copy-Item $tmp $png -Force
        $null = [AzfBlp]::Convert($png, $blp)
        $note = "${cw}x${ch}, opaque"
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if ($k.slice) {
        if ($slices.ContainsKey($name)) {
            $measured[$name] = @([double]$slices[$name].x, [double]$slices[$name].y); $note += ", border from slices.json"
        } else {
            $m = [AzfBlp]::MeasureFrame($png)
            if ($m) { $xy = $m.Split(','); $measured[$name] = @([double]$xy[0], [double]$xy[1]); $note += ", border $m" }
            else { $note += ", BORDER NOT MEASURED: no empty centre; set it in art/slices.json" }
        }
    }
    return "$([IO.Path]::GetFileName($inPath)) -> $($k.dir)\$name.blp [$note]"
}

$processed = 0
$files = Get-ChildItem $Source -File | Where-Object { $_.Extension -match '^\.(png|jpe?g)$' } | Sort-Object Name
foreach ($f in $files) {
    $kind = Get-PieceKind $f.BaseName
    if ($kind) {
        Write-Output (Convert-Piece $f.FullName $f.BaseName $kind)
        $processed++
        continue
    }
    if ($f.BaseName -match '^(\d+)(?:[-_ ].*)?$') { $key = $Matches[1] }
    elseif ($f.BaseName -match '^fallback') { $key = 'fallback' }
    else { Write-Output "Skip $($f.Name): not a zone (map ID first), fallback, banner, chrome or icon name (art/prompts.md)"; continue }
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
function Get-Names([string]$dir) {
    @(Get-ChildItem (Join-Path $MediaRoot $dir) -Filter *.blp | ForEach-Object { $_.BaseName } | Sort-Object)
}
$inv = [System.Globalization.CultureInfo]::InvariantCulture
# War banner pieces in Media\Banner (UI/ZoneBanner.lua uses them instead of its stand-in).
$pieces = Get-Names 'Banner'
$lua += '    banner = {'
foreach ($p in $pieces) { $lua += "        [""$p""] = true," }
$lua += '    },'
# Interface chrome in Media\Chrome: true, or { x, y } nine-slice borders (fractions of the image).
$chrome = Get-Names 'Chrome'
$lua += '    chrome = {'
foreach ($p in $chrome) {
    if ($measured.ContainsKey($p)) { $lua += "        [""$p""] = { x = $($measured[$p][0].ToString($inv)), y = $($measured[$p][1].ToString($inv)) }," }
    elseif ($slices.ContainsKey($p)) { $lua += "        [""$p""] = { x = $(([double]$slices[$p].x).ToString($inv)), y = $(([double]$slices[$p].y).ToString($inv)) }," }
    else { $lua += "        [""$p""] = true," }
}
$lua += '    },'
# Icons in Media\Icons, by name without the "icon-" prefix.
$icons = Get-Names 'Icons'
$lua += '    icons = {'
foreach ($p in $icons) { $lua += "        [""$($p -replace '^icon-', '')""] = true," }
$lua += @('    },', '}')
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $ArtLua)).Path + '\' + (Split-Path $ArtLua -Leaf), $lua, (New-Object System.Text.UTF8Encoding $false))

# The mockup's index: zone art, banner pieces, chrome (with borders) and icons.
$q = '"'
$chromeJs = ($chrome | ForEach-Object {
    if ($measured.ContainsKey($_)) { $q + $_ + $q + ': { x: ' + $measured[$_][0].ToString($inv) + ', y: ' + $measured[$_][1].ToString($inv) + ' }' }
    else { $q + $_ + $q + ': true' } }) -join ', '
$bannerJs = ($pieces | ForEach-Object { $q + $_ + $q }) -join ','
$iconsJs = ($icons | ForEach-Object { $q + ($_ -replace '^icon-', '') + $q }) -join ','
$js = '// Generated by tools/process-art.ps1. Do not edit.' + "`n" + 'window.AZF_ART = { fallback: ' + $hasFallback.ToString().ToLower() +
    ', ids: [' + ($ids -join ',') + '], banner: [' + $bannerJs + '], chrome: { ' + $chromeJs + ' }, icons: [' + $iconsJs + '] };' + "`n"
[IO.File]::WriteAllText((Join-Path (Resolve-Path $MockOut).Path 'index.js'), $js, (New-Object System.Text.UTF8Encoding $false))

Write-Output "Processed $processed image(s). Art available for $($ids.Count) zone(s); fallback: $hasFallback; banner pieces: $($pieces.Count); chrome: $($chrome.Count); icons: $($icons.Count)."
