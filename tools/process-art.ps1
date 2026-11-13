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
# Strip seams (2026-11-12): a generated panel's lane can start a little sideways of where the panel
# above ends (Warrior Alliance panel 3 began ~50 px right of panel 2's lane, so the cross-fade
# showed two half lanes). Offset finds the sideways shift that best matches the two panels' rows
# at the join (the bright lane dominates: column brightness, high-passed, correlated); Shift bends
# a panel's rows sideways by a per-row amount (fading out at the edges), so both panels meet halfway.
if (-not ('AzfSeam' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class AzfSeam {
    static byte[] Read(Bitmap b, out int stride) {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        stride = d.Stride; var buf = new byte[stride * b.Height];
        Marshal.Copy(d.Scan0, buf, 0, buf.Length); b.UnlockBits(d); return buf;
    }
    static double[] Profile(Bitmap b, int y0, int y1) {
        int st; var buf = Read(b, out st); int w = b.Width;
        var p = new double[w];
        for (int y = y0; y < y1; y++) for (int x = 0; x < w; x++) {
            int i = y * st + x * 4; p[x] += 0.11 * buf[i] + 0.59 * buf[i + 1] + 0.30 * buf[i + 2];
        }
        // High-pass: minus a 61-px moving average, so broad light and shade don't count.
        var q = new double[w];
        for (int x = 0; x < w; x++) {
            double s = 0; int n = 0;
            for (int k = Math.Max(0, x - 30); k <= Math.Min(w - 1, x + 30); k++) { s += p[k]; n++; }
            q[x] = p[x] - s / n;
        }
        return q;
    }
    // The shift d (px) such that the lower panel's top rows look like the upper panel's bottom
    // rows moved d to the right; band = rows compared on each side.
    public static int Offset(Bitmap upper, Bitmap lower, int band, int maxShift) {
        var a = Profile(upper, upper.Height - band, upper.Height);
        var b = Profile(lower, 0, band);
        int w = a.Length, best = 0; double bestScore = double.MinValue;
        for (int d = -maxShift; d <= maxShift; d++) {
            double s = 0, na = 0, nb = 0;
            for (int x = 0; x < w; x++) {
                int xb = x + d; if (xb < 0 || xb >= w) continue;
                s += a[x] * b[xb]; na += a[x] * a[x]; nb += b[xb] * b[xb];
            }
            double score = (na > 0 && nb > 0) ? s / Math.Sqrt(na * nb) : 0;
            if (score > bestScore) { bestScore = score; best = d; }
        }
        return best;
    }
    // Moves row y right by shift[y] px (fractional, linear), sampling clamped at the edges.
    public static void Shift(Bitmap b, double[] shift, int edge) {
        int st; var src = Read(b, out st); int w = b.Width, h = b.Height;
        var dst = (byte[])src.Clone();
        for (int y = 0; y < h; y++) {
            double s = shift[y]; if (Math.Abs(s) < 0.01) continue;
            for (int x = 0; x < w; x++) {
                // The bend fades out toward the left and right edges (over `edge` px), so the
                // edges stay put and nothing outside the image is sampled (clamping smeared the
                // edge column into streaks; mirroring showed mirrored trees, owner 2026-11-12).
                double e = Math.Min(x, w - 1 - x) / (double)edge;
                e = e >= 1 ? 1 : e * e * (3 - 2 * e);
                double sx = Math.Max(0, Math.Min(w - 1, x - s * e));
                int x0 = (int)Math.Floor(sx), x1 = Math.Min(w - 1, x0 + 1); double f = sx - x0;
                for (int c = 0; c < 4; c++)
                    dst[y * st + x * 4 + c] = (byte)Math.Round(src[y * st + x0 * 4 + c] * (1 - f) + src[y * st + x1 * 4 + c] * f);
            }
        }
        var d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(dst, 0, d.Scan0, dst.Length); b.UnlockBits(d);
    }
}
'@
}
$SeamTaper = 150   # rows over which a panel's bend at a seam fades out
$SeamMax = 90      # largest sideways shift looked for at a seam (px of 512)
$SeamEdge = 80     # px from the left and right edges over which the bend fades out

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
#   emblem    128x128   fit, keyed + despilled, DXT5          Media\Chrome (rep-<reaction>: the standing strip)
#   texture   256x128   stretched, opaque DXT1                Media\Chrome (plaque-fill-*: tinted by the UI)
# despill (emblems, frame-plaque): solid pixels lose the magenta they reflect (silver, gold).
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
    'frame-plaque' = @{ size = @(256, 128); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true; despill = $true } # standing strip cell
    emblem = @{ size = @(128, 128); fit = 'fit'; key = $true; dir = 'Chrome'; despill = $true }
    texture = @{ size = @(256, 128); fit = 'stretch'; key = $false; dir = 'Chrome'; levels = 165 } # plaque-fill-*: colourless, tinted in the UI
    plate = @{ size = @(512, 128); fit = 'stretch'; key = $true; dir = 'Chrome'; slice = $true }
    divider = @{ size = @(512, 64); fit = 'stretch'; key = $true; dir = 'Chrome' }
    fill = @{ size = @(512, 64); fit = 'stretch'; key = $false; dir = 'Chrome' }
    icon = @{ size = @(128, 128); fit = 'crop'; key = $false; dir = 'Icons' }
    backdrop = @{ size = @(1024, 1024); fit = 'stretch'; key = $false; dir = 'Chrome' }
    celburst = @{ size = @(512, 512); fit = 'stretch'; key = $false; keyBlack = $true; dir = 'Chrome' }
    cel = @{ size = @(256, 256); fit = 'fit'; key = $true; dir = 'Chrome' }
    ribbon = @{ size = @(512, 128); fit = 'stretch'; key = $true; dir = 'Chrome' }
    coin = @{ size = @(128, 128); fit = 'fit'; key = $true; dir = 'Chrome'; despill = $true } # coin-<class>: the Class tab's done mark
    # Class tab round 4 (art/prompts.md "Round 4 style test"): ink drawn on pure white, the white
    # turned to transparency (inkKey: alpha from darkness, colour un-mixed from the white), so the
    # marks sit on the parchment map like more ink; metal pieces on magenta as usual.
    sketch = @{ size = @(128, 128); fit = 'fit'; inkKey = $true; dir = 'Chrome' }          # sketch-<class>: a stop not done yet
    'road-ink' = @{ size = @(128, 64); fit = 'fit'; inkKey = $true; dir = 'Chrome' }     # road-dash-ink-<n>
    'road-dot' = @{ size = @(32, 32); fit = 'fit'; inkKey = $true; dir = 'Chrome' }      # road-dot: a side path
    'road-gold' = @{ size = @(128, 64); fit = 'fit'; key = $true; dir = 'Chrome'; despill = $true } # road-dash-gold-<n>
    ring = @{ size = @(128, 128); fit = 'fit'; key = $true; dir = 'Chrome'; despill = $true } # you-ring: your portrait's ring
    # Class tab round 5 (art/prompts.md "Round 5"): the road band (tileable, stamped along the road),
    # the name cartouche (nine-slice), the milestones and the red-ink focus ring.
    band = @{ size = @(256, 64); fit = 'stretch'; key = $true; dir = 'Chrome'; despill = $true }   # road-band, road-band-gold
    cartouche = @{ size = @(512, 128); fit = 'stretch'; key = $true; dir = 'Chrome'; despill = $true } # cartouche
    milestone = @{ size = @(64, 64); fit = 'fit'; key = $true; dir = 'Chrome'; despill = $true }  # milestone[-rune-gold|-rune-red] (flag/cap: unused)
    'ink-ring' = @{ size = @(128, 128); fit = 'fit'; inkKey = $true; dir = 'Chrome' }               # focus-ring-red
}

# Ink on white -> ink with alpha: a pixel's alpha is how far it is from white (its darkest channel
# counts), and its colour is what, laid over white at that alpha, gives the original back.
function Set-InkAlpha([string]$path) {
    $src = [System.Drawing.Bitmap]::FromFile($path)
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.DrawImage($src, 0, 0, $src.Width, $src.Height); $g.Dispose(); $src.Dispose()
    $solid = 0
    for ($y = 0; $y -lt $bmp.Height; $y++) { for ($x = 0; $x -lt $bmp.Width; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $a = 255 - [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
        if ($a -lt 8) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)); continue }
        $f = 255.0 / $a
        $un = { param($v) [int][Math]::Max(0, [Math]::Min(255, [Math]::Round(255 - (255 - $v) * $f))) }
        $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, (& $un $c.R), (& $un $c.G), (& $un $c.B)))
        if ($a -gt 200) { $solid++ }
    } }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    return "ink keyed from white, $solid solid pixels"
}
# The Class tab's journey strips (art/prompts.md "Class tab art"): strip-<class>-<side>-<n>, three
# 3:4 panels top to bottom, stacked into one 512x2048 opaque DXT1 -> Media\Strips\<class>-<side>.blp
# (mockup: mockups/strip-art/<class>-<side>.png). Neighbouring panels overlap by $StripBlend rows
# and cross-fade there, so a change in light between panels doesn't show as a seam.
$StripSize = @(512, 2048)
$StripBlend = 48
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
    if ($name -match '^plaque-fill-[a-z0-9-]+$') { return 'texture' }
    if ($name -match '^rep-(hated|hostile|unfriendly|neutral|friendly|honored|revered|exalted)$') { return 'emblem' }
    if ($name -match '^plate-[a-z0-9-]+$') { return 'plate' }
    if ($name -match '^divider(-[a-z0-9-]+)?$') { return 'divider' }
    if ($name -match '^bar-fill(-[a-z0-9-]+)?$') { return 'fill' }
    if ($name -match '^icon-[a-z0-9-]+$') { return 'icon' }
    if ($name -match '^atlas-[a-z0-9-]+$') { return 'backdrop' }
    if ($name -eq 'cel-burst') { return 'celburst' }
    if ($name -eq 'cel-ribbon') { return 'ribbon' }
    if ($name -match '^cel-(laurel|seal-[a-z0-9-]+|claim-(alliance|horde))$') { return 'cel' }
    if ($name -match '^coin-[a-z]+$') { return 'coin' }
    if ($name -match '^sketch-[a-z]+$') { return 'sketch' }
    if ($name -match '^road-dash-ink-\d+$') { return 'road-ink' }
    if ($name -match '^road-dash-gold-\d+$') { return 'road-gold' }
    if ($name -eq 'road-dot') { return 'road-dot' }
    if ($name -eq 'you-ring') { return 'ring' }
    if ($name -match '^road-band(-gold)?$') { return 'band' }
    if ($name -eq 'cartouche') { return 'cartouche' }
    if ($name -match '^milestone(-flag-red|-cap-gold|-rune-gold|-rune-red)?$') { return 'milestone' }
    if ($name -eq 'focus-ring-red') { return 'ink-ring' }
    return $null
}

# Stacks a strip's panels (paths in order) into one image, cross-fading the overlaps, and writes
# the mockup PNG and the game BLP. Returns a report line.
function Convert-Strip([string]$key, [string[]]$panels) {
    $W, $H = $StripSize
    $n = $panels.Count
    # Each panel is drawn $ph tall; neighbours overlap by $StripBlend, so n panels fill $H.
    $ph = [int][Math]::Ceiling(($H + ($n - 1) * $StripBlend) / $n)
    $canvas = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $sizes = @()
    $ps = @()
    for ($i = 0; $i -lt $n; $i++) {
        $src = [System.Drawing.Image]::FromFile($panels[$i])
        $sizes += "$($src.Width)x$($src.Height)"
        $p = New-Object System.Drawing.Bitmap $W, $ph, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $pg = [System.Drawing.Graphics]::FromImage($p)
        $pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $pg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attrs = New-Object System.Drawing.Imaging.ImageAttributes
        $attrs.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $pg.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $W, $ph), 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
        $attrs.Dispose(); $pg.Dispose(); $src.Dispose()
        $ps += $p
    }
    # Line up each seam: find the sideways offset, then bend both panels halfway toward each
    # other over the overlap, fading out over $SeamTaper rows.
    $shifts = @()
    for ($i = 0; $i -lt $n; $i++) { $shifts += ,(New-Object 'double[]' $ph) }
    $seams = @()
    for ($i = 1; $i -lt $n; $i++) {
        $d = [AzfSeam]::Offset($ps[$i - 1], $ps[$i], $StripBlend, $SeamMax)
        $seams += $d
        for ($y = 0; $y -lt $ph; $y++) {
            # Lower panel: full -d/2 over the overlap, fading below it.
            $t = if ($y -lt $StripBlend) { 1 } else { [Math]::Max(0.0, 1.0 - ($y - $StripBlend) / [double]$SeamTaper) }
            $wt = $t * $t * (3 - 2 * $t)
            $shifts[$i][$y] += -$d / 2 * $wt
            # Upper panel: full +d/2 over its bottom overlap, fading above it.
            $u = $ph - 1 - $y
            $t = if ($u -lt $StripBlend) { 1 } else { [Math]::Max(0.0, 1.0 - ($u - $StripBlend) / [double]$SeamTaper) }
            $wt = $t * $t * (3 - 2 * $t)
            $shifts[$i - 1][$y] += $d / 2 * $wt
        }
    }
    for ($i = 0; $i -lt $n; $i++) {
        $p = $ps[$i]
        [AzfSeam]::Shift($p, $shifts[$i], $SeamEdge)
        # Fade in the top $StripBlend rows of every panel after the first.
        if ($i -gt 0) {
            for ($y = 0; $y -lt $StripBlend; $y++) {
                $a = [int][Math]::Round(255 * ($y + 0.5) / $StripBlend)
                for ($x = 0; $x -lt $W; $x++) {
                    $c = $p.GetPixel($x, $y)
                    $p.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B))
                }
            }
        }
        $top = [Math]::Min($H - $ph, $i * ($ph - $StripBlend))
        $g.DrawImage($p, 0, $top, $W, $ph)
        $p.Dispose()
    }
    $g.Dispose()
    $mockDir = Join-Path $PieceMockRoot 'strip-art'
    New-Item -ItemType Directory -Force $mockDir | Out-Null
    $png = Join-Path (Resolve-Path $mockDir).Path "$key.png"
    # Opaque: flatten onto black (every pixel is covered; this only drops the alpha channel).
    $flat = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $fg = [System.Drawing.Graphics]::FromImage($flat); $fg.DrawImage($canvas, 0, 0, $W, $H); $fg.Dispose(); $canvas.Dispose()
    $flat.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $flat.Dispose()
    $stripDir = Join-Path $MediaRoot 'Strips'
    New-Item -ItemType Directory -Force $stripDir | Out-Null
    $blp = Join-Path (Resolve-Path $stripDir).Path "$key.blp"
    $info = [AzfBlp]::Convert($png, $blp)
    return "strip $key ($n panels: $($sizes -join ', '); each ${W}x$ph, $StripBlend-row cross-fades; seams lined up by $(($seams | ForEach-Object { "$_ px" }) -join ', ')) -> Strips\$key.blp [$info]"
}

# Tinted textures (plaque-fill-*): a generator paints them very low contrast (209..229 for the
# first cloth), and multiplied onto a dark tint the pattern vanishes. Stretch the luminance range
# to $lo..255, the same mapping on every channel, so a grey texture stays grey.
function Set-Levels([string]$path, [int]$lo) {
    $src = [System.Drawing.Bitmap]::FromFile($path)
    $bmp = New-Object System.Drawing.Bitmap $src; $src.Dispose()
    $min = 255; $max = 0
    for ($y = 0; $y -lt $bmp.Height; $y++) { for ($x = 0; $x -lt $bmp.Width; $x++) {
        $c = $bmp.GetPixel($x, $y); $l = [int](($c.R + $c.G + $c.B) / 3); if ($l -lt $min) { $min = $l }; if ($l -gt $max) { $max = $l } } }
    if ($max -le $min) { $bmp.Dispose(); return 'levels: flat image, left as is' }
    $f = (255 - $lo) / ($max - $min)
    $map = { param($v) [int][Math]::Max(0, [Math]::Min(255, [Math]::Round($lo + ($v - $min) * $f))) }
    for ($y = 0; $y -lt $bmp.Height; $y++) { for ($x = 0; $x -lt $bmp.Width; $x++) {
        $c = $bmp.GetPixel($x, $y); $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, (& $map $c.R), (& $map $c.G), (& $map $c.B))) } }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    return "levels $min..$max -> $lo..255"
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
        elseif ($k.inkKey) { $g.Clear([System.Drawing.Color]::White) }
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
    } elseif ($k.inkKey) {
        $note = Set-InkAlpha $tmp
        Copy-Item $tmp $png -Force
        $null = [AzfBlp]::ConvertAlpha($png, $blp)
    } elseif ($k.key) {
        $note = [AzfBlp]::KeyMagenta($tmp, $png, [bool]$k.despill)
        if ($k.despill) { $note += ', despilled' }
        $null = [AzfBlp]::ConvertAlpha($png, $blp)
    } else {
        if ($k.levels) { $note = Set-Levels $tmp $k.levels }
        Copy-Item $tmp $png -Force
        $null = [AzfBlp]::Convert($png, $blp)
        $note = "${cw}x${ch}, opaque" + $(if ($note) { ", $note" } else { '' })
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
# Journey strips first: their panels are one image together.
$strips = @{}
foreach ($f in $files) {
    if ($f.BaseName -match '^strip-([a-z]+-(alliance|horde))-(\d+)$') {
        if (-not $strips.ContainsKey($Matches[1])) { $strips[$Matches[1]] = @() }
        $strips[$Matches[1]] += , @([int]$Matches[3], $f.FullName)
    }
}
foreach ($key in ($strips.Keys | Sort-Object)) {
    $panels = @($strips[$key] | Sort-Object { $_[0] } | ForEach-Object { $_[1] })
    Write-Output (Convert-Strip $key $panels)
    $processed++
}
$files = @($files | Where-Object { $_.BaseName -notmatch '^strip-' })
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
$lua += '    },'
# The Class tab's journey strips in Media\Strips, by "<class>-<side>" (paladin-alliance).
$stripsDir = Join-Path $MediaRoot 'Strips'
$stripNames = if (Test-Path $stripsDir) { @(Get-ChildItem $stripsDir -Filter *.blp | ForEach-Object { $_.BaseName } | Sort-Object) } else { @() }
$lua += '    strips = {'
foreach ($p in $stripNames) { $lua += "        [""$p""] = true," }
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
    ', ids: [' + ($ids -join ',') + '], banner: [' + $bannerJs + '], chrome: { ' + $chromeJs + ' }, icons: [' + $iconsJs + '], strips: [' +
    (($stripNames | ForEach-Object { $q + $_ + $q }) -join ',') + '] };' + "`n"
[IO.File]::WriteAllText((Join-Path (Resolve-Path $MockOut).Path 'index.js'), $js, (New-Object System.Text.UTF8Encoding $false))

Write-Output "Processed $processed image(s). Art available for $($ids.Count) zone(s); fallback: $hasFallback; banner pieces: $($pieces.Count); chrome: $($chrome.Count); icons: $($icons.Count); strips: $($stripNames.Count)."
