# Traces the road corridor in each Class tab journey strip (mockups/DESIGN.md "Class tab",
# round 4): the strips are painted with a clear, plain band of parchment where the road runs, and
# no road. This finds that band's middle, row by row, so the addon's road follows the painting.
#   mockups/strip-art/<class>-<side>.png (512x2048, made by tools/process-art.ps1)
#     -> Azerfolio/Data/StripPaths.lua   (ns.StripPaths["<class>-<side>"] = { {x, y}, ... } in the
#                                         Class tab's logical units: 420 wide, 1680 tall)
#     -> mockups/strip-art/paths.js      (the same for the mockup)
#     -> art/review/<class>-<side>-path.png (the strip with the traced line, to check by eye)
# How: a pixel's "detail" is how much it differs from its neighbours, averaged over a window; the
# corridor is the widest run of low-detail pixels in a row, near the previous row's run. The
# centres are smoothed. Run after process-art.ps1; never hand-edit the outputs.
param(
    [string]$StripDir = (Join-Path $PSScriptRoot '..\mockups\strip-art'),
    [string]$OutLua = (Join-Path $PSScriptRoot '..\Azerfolio\Data\StripPaths.lua'),
    [string]$OutJs = (Join-Path $PSScriptRoot '..\mockups\strip-art\paths.js'),
    [string]$ReviewDir = (Join-Path $PSScriptRoot '..\art\review'),
    [int]$Step = 16,          # rows between path points (strip pixels)
    [int]$Window = 13,        # detail averaging window (pixels)
    [int]$Smooth = 5          # moving-average half width (points)
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

if (-not ('AzfStripPath' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class AzfStripPath {
    // Returns x,y pairs (strip pixels) of the corridor's centre every `step` rows.
    public static double[] Trace(string path, int step, int window, int smooth) {
        using (var src = new Bitmap(path)) {
            int w = src.Width, h = src.Height;
            var data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            var buf = new byte[data.Stride * h];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            src.UnlockBits(data);
            var lum = new double[w * h];
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int i = y * data.Stride + x * 3;
                lum[y * w + x] = 0.114 * buf[i] + 0.587 * buf[i + 1] + 0.299 * buf[i + 2];
            }
            // Detail: gradient magnitude, then a box average (integral image).
            var det = new double[w * h];
            for (int y = 1; y < h - 1; y++) for (int x = 1; x < w - 1; x++) {
                double gx = lum[y * w + x + 1] - lum[y * w + x - 1], gy = lum[(y + 1) * w + x] - lum[(y - 1) * w + x];
                det[y * w + x] = Math.Sqrt(gx * gx + gy * gy);
            }
            var integ = new double[(w + 1) * (h + 1)];
            for (int y = 0; y < h; y++) { double row = 0; for (int x = 0; x < w; x++) { row += det[y * w + x]; integ[(y + 1) * (w + 1) + x + 1] = integ[y * (w + 1) + x + 1] + row; } }
            int r = window / 2;
            Func<int, int, double> avg = (x, y) => {
                int x0 = Math.Max(0, x - r), x1 = Math.Min(w - 1, x + r), y0 = Math.Max(0, y - r), y1 = Math.Min(h - 1, y + r);
                double s = integ[(y1 + 1) * (w + 1) + x1 + 1] - integ[y0 * (w + 1) + x1 + 1] - integ[(y1 + 1) * (w + 1) + x0] + integ[y0 * (w + 1) + x0];
                return s / ((x1 - x0 + 1) * (y1 - y0 + 1));
            };
            // The threshold: a little above the quietest third of the image.
            var sample = new System.Collections.Generic.List<double>();
            for (int y = 0; y < h; y += 4) for (int x = 0; x < w; x += 4) sample.Add(avg(x, y));
            sample.Sort();
            double thr = sample[(int)(sample.Count * 0.30)] * 1.6;
            var xs = new System.Collections.Generic.List<double>();
            var ys = new System.Collections.Generic.List<double>();
            double prev = w / 2.0;
            for (int y = step / 2; y < h; y += step) {
                // Runs of plain pixels; pick the widest, preferring one near the previous centre.
                double best = -1, bestC = prev; int x = 0;
                while (x < w) {
                    while (x < w && avg(x, y) > thr) x++;
                    int a = x;
                    while (x < w && avg(x, y) <= thr) x++;
                    int b = x - 1;
                    if (b >= a) {
                        double c = (a + b) / 2.0, len = b - a + 1;
                        double score = len - 0.6 * Math.Abs(c - prev);
                        if (score > best) { best = score; bestC = c; }
                    }
                }
                if (best < 0) bestC = prev;
                xs.Add(bestC); ys.Add(y); prev = bestC;
            }
            // Smooth the centres (moving average).
            var outp = new double[xs.Count * 2];
            for (int i = 0; i < xs.Count; i++) {
                double s = 0; int n = 0;
                for (int k = Math.Max(0, i - smooth); k <= Math.Min(xs.Count - 1, i + smooth); k++) { s += xs[k]; n++; }
                outp[2 * i] = s / n; outp[2 * i + 1] = ys[i];
            }
            return outp;
        }
    }
}
'@
}

New-Item -ItemType Directory -Force $ReviewDir | Out-Null
$W, $H = 420, 1680
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$lua = @('-- Generated by tools/trace-strip.ps1. Do not edit.',
         '-- The road corridor traced in each Class tab strip: points in the tab''s logical units (420 x 1680).',
         'local _, ns = ...',
         'ns.StripPaths = {')
$js = @('// Generated by tools/trace-strip.ps1. Do not edit.', 'window.AZF_STRIP_PATHS = {')
foreach ($png in (Get-ChildItem $StripDir -Filter *.png | Where-Object { $_.BaseName -match '^[a-z]+-(alliance|horde)$' })) {
    $pts = [AzfStripPath]::Trace($png.FullName, $Step, $Window, $Smooth)
    $img = [System.Drawing.Image]::FromFile($png.FullName)
    $sx, $sy = ($W / $img.Width), ($H / $img.Height)
    # The review image: the strip with the traced centre line.
    $bmp = New-Object System.Drawing.Bitmap $img
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 200, 30, 30)), 3
    for ($i = 2; $i -lt $pts.Count; $i += 2) { $g.DrawLine($pen, [float]$pts[$i - 2], [float]$pts[$i - 1], [float]$pts[$i], [float]$pts[$i + 1]) }
    $g.Dispose(); $img.Dispose()
    $bmp.Save((Join-Path $ReviewDir "$($png.BaseName)-path.png")); $bmp.Dispose()
    $items = @()
    for ($i = 0; $i -lt $pts.Count; $i += 2) {
        $items += ('{' + ([Math]::Round($pts[$i] * $sx, 1)).ToString($inv) + ', ' + ([Math]::Round($pts[$i + 1] * $sy, 1)).ToString($inv) + '}')
    }
    $lua += "    [""$($png.BaseName)""] = { " + ($items -join ', ') + ' },'
    $js += "  ""$($png.BaseName)"": [" + (($items | ForEach-Object { $_ -replace '\{', '[' -replace '\}', ']' }) -join ', ') + '],'
    Write-Output "$($png.BaseName): $($pts.Count / 2) points -> review $($png.BaseName)-path.png"
}
$lua += '}'
$js += '};'
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $OutLua)).Path + '\' + (Split-Path $OutLua -Leaf), $lua, (New-Object System.Text.UTF8Encoding $false))
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $OutJs)).Path + '\' + (Split-Path $OutJs -Leaf), $js, (New-Object System.Text.UTF8Encoding $false))
