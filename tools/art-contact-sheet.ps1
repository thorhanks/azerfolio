# Builds contact sheets of the zone art for review: each tile is the processed 2:1 crop with the
# UI crop guides drawn on (yellow = card strip 16:5, cyan = Zone Detail banner 9:1, red = core).
# Usage: powershell -File tools/art-contact-sheet.ps1 [-OutDir <folder>] [-Guides:$false]
param(
    [string]$Source = (Join-Path $PSScriptRoot '..\art\source'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\art\review'),
    [int]$Columns = 4, [int]$PerSheet = 12, [int]$TileW = 420,
    [switch]$Guides = $true
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
$names = @{}
Select-String -Path (Join-Path $PSScriptRoot '..\art\prompts.md') -Pattern '^\| (\d+) \| [a-z0-9-]+ \| ([^|]+) \|' |
    ForEach-Object { $names[$_.Matches[0].Groups[1].Value] = $_.Matches[0].Groups[2].Value.Trim() }

$files = @(Get-ChildItem $Source -File | Where-Object { $_.Extension -match '^\.(png|jpe?g)$' } | Sort-Object Name)
$tileH = [int]($TileW / 2); $labelH = 22; $pad = 8
$font = New-Object System.Drawing.Font 'Segoe UI', 10, ([System.Drawing.FontStyle]::Bold)
$sheet = 0
for ($start = 0; $start -lt $files.Count; $start += $PerSheet) {
    $batch = $files[$start..([Math]::Min($start + $PerSheet, $files.Count) - 1)]
    $rows = [Math]::Ceiling($batch.Count / $Columns)
    $W = $Columns * ($TileW + $pad) + $pad; $H = $rows * ($tileH + $labelH + $pad) + $pad
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(30, 24, 18))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    for ($i = 0; $i -lt $batch.Count; $i++) {
        $f = $batch[$i]; $x = $pad + ($i % $Columns) * ($TileW + $pad); $y = $pad + [Math]::Floor($i / $Columns) * ($tileH + $labelH + $pad)
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $ch = [int]($img.Width / 2); $cy = [int](($img.Height - $ch) / 2)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle $x, $y, $TileW, $tileH), 0, $cy, $img.Width, $ch, [System.Drawing.GraphicsUnit]::Pixel)
        $img.Dispose()
        if ($Guides) {
            $g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::Yellow), 1), $x, $y + $tileH * 0.1875, $TileW - 1, $tileH * 0.625)
            $g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::Cyan), 2), $x, $y + $tileH * 0.40, $TileW - 1, $tileH * 0.22)
            $g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::Red), 2), $x + $TileW * 0.30, $y + $tileH * 0.40, $TileW * 0.40, $tileH * 0.22)
        }
        $id = if ($f.BaseName -match '^(\d+)') { $Matches[1] } else { 'fallback' }
        $label = if ($names[$id]) { "$id  $($names[$id])" } else { $f.BaseName }
        $g.DrawString($label, $font, [System.Drawing.Brushes]::Gold, $x, $y + $tileH + 2)
    }
    $g.Dispose()
    $sheet++
    $path = Join-Path $OutDir ("sheet-{0}.png" -f $sheet)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output $path
}
