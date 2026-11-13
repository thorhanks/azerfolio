# Draws each Class tab strip with its traced road and stops, for review without a character of
# that class: art/review/<class>-<side>-stops.png (512 x 2048), plus art/review/strips-sheet.jpg
# (every road side by side). Stop positions come from tools/strip-stops.lua (Theme.classStrip,
# snapped like the addon does). Run after process-art.ps1 and trace-strip.ps1.
#   powershell -File tools/strip-preview.ps1 [-Only warrior-alliance,mage-horde]
param([string[]]$Only = @())
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$review = Join-Path $root 'art\review'
New-Item -ItemType Directory -Force $review | Out-Null

Push-Location $root
try { $lines = & luajit tools/strip-stops.lua } finally { Pop-Location }
$stops = @{}
foreach ($l in $lines) {
    $f = $l -split '\|'
    if ($f.Count -lt 6) { continue }
    if (-not $stops.ContainsKey($f[0])) { $stops[$f[0]] = @() }
    $stops[$f[0]] += , @($f[1], $f[2], $f[3], [double]::Parse($f[4], $inv), [double]::Parse($f[5], $inv))
}
$paths = @{}
foreach ($l in (Get-Content (Join-Path $root 'mockups\strip-art\paths.js'))) {
    if ($l -match '^\s*"([a-z]+-[a-z]+)": \[(.*)\],?$') {
        $paths[$Matches[1]] = @([regex]::Matches($Matches[2], '\[(-?[\d.]+), (-?[\d.]+)\]') | ForEach-Object {
            , @([double]::Parse($_.Groups[1].Value, $inv), [double]::Parse($_.Groups[2].Value, $inv)) })
    }
}
$keys = @($stops.Keys | Sort-Object)
if ($Only.Count) { $keys = @($keys | Where-Object { $Only -contains $_ }) }
$k = 512 / 420
$font = New-Object System.Drawing.Font 'Georgia', 13, ([System.Drawing.FontStyle]::Bold)
$plate = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 240, 226, 190))
$sheet = New-Object System.Drawing.Bitmap (($keys.Count * 206) - 6), 840
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear([System.Drawing.Color]::FromArgb(30, 24, 18)); $sg.InterpolationMode = 'HighQualityBicubic'
$small = New-Object System.Drawing.Font 'Arial', 9
$col = 0
foreach ($key in $keys) {
    $png = Join-Path $root "mockups\strip-art\$key.png"
    if (-not (Test-Path $png)) { continue }
    $img = [System.Drawing.Image]::FromFile($png)
    $b = New-Object System.Drawing.Bitmap 512, 2048
    $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'
    $g.DrawImage($img, 0, 0, 512, 2048); $img.Dispose()
    $P = $paths[$key]
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 215, 160, 40)), 8
    for ($i = 1; $i -lt $P.Count; $i++) {
        $g.DrawLine($pen, [float]($P[$i - 1][0] * $k), [float]($P[$i - 1][1] * $k), [float]($P[$i][0] * $k), [float]($P[$i][1] * $k))
    }
    foreach ($s in $stops[$key]) {
        $cx = $s[3] * $k; $cy = $s[4] * $k
        $r = 27; if ($s[1] -eq 'side') { $r = 20 }
        $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 150, 120, 60))
        $g.FillEllipse($fill, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 2), [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $sz = $g.MeasureString($s[2], $font)
        $lx = $cx + $r + 6; if ($lx + $sz.Width -gt 506) { $lx = $cx - $r - 6 - $sz.Width }
        $g.FillRectangle($plate, [float]$lx, [float]($cy - $sz.Height / 2), $sz.Width, $sz.Height)
        $g.DrawString($s[2], $font, [System.Drawing.Brushes]::Black, [float]$lx, [float]($cy - $sz.Height / 2))
    }
    $g.Dispose()
    $b.Save((Join-Path $review "$key-stops.png"))
    $sg.DrawImage($b, $col * 206, 0, 200, 800)
    $sg.DrawString($key, $small, [System.Drawing.Brushes]::White, [float]($col * 206), [float]806)
    $b.Dispose(); $col++
    Write-Output "$key -> art\review\$key-stops.png ($($stops[$key].Count) stops)"
}
$sg.Dispose()
$sheetPath = Join-Path $review 'strips-sheet.jpg'
$sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Jpeg); $sheet.Dispose()
Write-Output "sheet -> art\review\strips-sheet.jpg"
