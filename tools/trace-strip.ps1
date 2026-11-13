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
    [int]$Smooth = 5,         # moving-average half width (points)
    # lane (round 5's narrow painted lane; use it for those strips): the cheapest path from the top edge to the
    #   bottom edge through plain, light pixels, kept to the lane's middle (follows any bend).
    # rows (default; round 4's wide corridor): the widest plain run in each row, near the previous row's.
    [ValidateSet('lane', 'rows')][string]$Method = 'rows',
    [double]$ColorTol = 38,   # lane: how far (RGB) a cell's colour may be from the lane's colour
    [string]$MaskDir = '',    # lane: write each strip's lane mask here (debugging)
    [int]$LaneSmooth = 2,      # lane: smoothing half width (the path already keeps to the middle)
    [int]$OffLaneWarn = 40    # report a trace that leaves the lane for longer than this (px)
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

if (-not ('AzfStripPath' -as [type]) -or -not [AzfStripPath].GetMethod('TraceLane')) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class AzfStripPath {
    public static double ColorTol = 38;
    public static string MaskOut = null;
    public static string Info = "";
    public static double WarmMin = 80;   // red minus blue for a cell to set a stretch's lane colour
    public static int LaneBand = 128;   // rows (cells) per stretch with its own lane colour
    // Returns x,y pairs (strip pixels) of the corridor's centre every `step` rows.
    // Lane method: plain (low detail) and light pixels form the lane mask; a distance transform
    // inside it makes the middle cheapest; Dijkstra (8-connected, on a grid of `cell` px) finds
    // the cheapest path from any top cell to any bottom cell. Points every `step` px along it,
    // smoothed. Returns x,y pairs in strip pixels.
    public static double[] TraceLane(string path, int step, int window, int smooth) {
        const int cell = 2;
        using (var src = new Bitmap(path)) {
            int w = src.Width, h = src.Height;
            var data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            var buf = new byte[data.Stride * h];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            src.UnlockBits(data);
            var lum = new double[w * h]; var cr = new double[w * h]; var cg = new double[w * h]; var cb = new double[w * h];
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                int i = y * data.Stride + x * 3;
                lum[y * w + x] = 0.114 * buf[i] + 0.587 * buf[i + 1] + 0.299 * buf[i + 2];
                cb[y * w + x] = buf[i]; cg[y * w + x] = buf[i + 1]; cr[y * w + x] = buf[i + 2];
            }
            var det = new double[w * h];
            for (int y = 1; y < h - 1; y++) for (int x = 1; x < w - 1; x++) {
                double gx = lum[y * w + x + 1] - lum[y * w + x - 1], gy = lum[(y + 1) * w + x] - lum[(y - 1) * w + x];
                det[y * w + x] = Math.Sqrt(gx * gx + gy * gy);
            }
            // Box averages of detail, lightness and colour (integral images).
            Func<double[], double[]> integral = (a) => {
                var I = new double[(w + 1) * (h + 1)];
                for (int y = 0; y < h; y++) { double row = 0; for (int x = 0; x < w; x++) { row += a[y * w + x]; I[(y + 1) * (w + 1) + x + 1] = I[y * (w + 1) + x + 1] + row; } }
                return I;
            };
            var iDet = integral(det); var iLum = integral(lum); var iR = integral(cr); var iG = integral(cg); var iB = integral(cb);
            int r = window / 2;
            Func<double[], int, int, double> avg = (I, x, y) => {
                int x0 = Math.Max(0, x - r), x1 = Math.Min(w - 1, x + r), y0 = Math.Max(0, y - r), y1 = Math.Min(h - 1, y + r);
                double s = I[(y1 + 1) * (w + 1) + x1 + 1] - I[y0 * (w + 1) + x1 + 1] - I[(y1 + 1) * (w + 1) + x0] + I[y0 * (w + 1) + x0];
                return s / ((x1 - x0 + 1) * (y1 - y0 + 1));
            };
            int gw = w / cell, gh = h / cell, n = gw * gh;
            var dv = new double[n]; var lv = new double[n]; var rv = new double[n]; var gv = new double[n]; var bv = new double[n];
            var sd = new System.Collections.Generic.List<double>(); var sl = new System.Collections.Generic.List<double>();
            for (int gy = 0; gy < gh; gy++) for (int gx = 0; gx < gw; gx++) {
                int x = gx * cell + cell / 2, y = gy * cell + cell / 2;
                dv[gy * gw + gx] = avg(iDet, x, y); lv[gy * gw + gx] = avg(iLum, x, y);
                rv[gy * gw + gx] = avg(iR, x, y); gv[gy * gw + gx] = avg(iG, x, y); bv[gy * gw + gx] = avg(iB, x, y);
                if (((gx | gy) & 1) == 0) { sd.Add(dv[gy * gw + gx]); sl.Add(lv[gy * gw + gx]); }
            }
            sd.Sort(); sl.Sort();
            double dThr = sd[(int)(sd.Count * 0.30)] * 1.6, lThr = sl[(int)(sl.Count * 0.55)];
            // The lane's colour, per stretch of the strip (blended between stretches): the median
            // of the lightest fifth of the plain cells in that stretch. The light changes down a
            // road (Warrior Horde's lane turns orange in the red wasteland and the trace cut across
            // the ground to the star, owner 2026-11-12), so one colour for the whole strip fails.
            // Only warm cells (red well above blue) can set the colour: every lane is a warm tan,
            // and in snowy stretches the lightest plain ground is snow. The lane is the cells
            // close to their stretch's colour and not busy.
            int bands = Math.Max(1, gh / LaneBand);
            var br = new double[bands]; var bg = new double[bands]; var bb = new double[bands];
            for (int k = 0; k < bands; k++) {
                int y0 = k * gh / bands, y1 = (k + 1) * gh / bands;
                var pl = new System.Collections.Generic.List<double>();
                for (int y = y0; y < y1; y++) for (int x = 0; x < gw; x++) { int i = y * gw + x; if (dv[i] <= dThr && lv[i] >= lThr && rv[i] - bv[i] >= WarmMin) pl.Add(lv[i]); }
                if (pl.Count < 20) { pl.Clear(); for (int y = y0; y < y1; y++) for (int x = 0; x < gw; x++) { int i = y * gw + x; if (dv[i] <= dThr) pl.Add(lv[i]); } }
                pl.Sort();
                double lTop = pl.Count > 0 ? pl[(int)(pl.Count * 0.80)] : 0;
                var pr = new System.Collections.Generic.List<double>(); var pg = new System.Collections.Generic.List<double>(); var pb = new System.Collections.Generic.List<double>();
                for (int y = y0; y < y1; y++) for (int x = 0; x < gw; x++) { int i = y * gw + x; if (dv[i] <= dThr * 1.5 && lv[i] >= lTop && rv[i] - bv[i] >= WarmMin) { pr.Add(rv[i]); pg.Add(gv[i]); pb.Add(bv[i]); } }
                pr.Sort(); pg.Sort(); pb.Sort();
                br[k] = pr.Count > 0 ? pr[pr.Count / 2] : 0; bg[k] = pg.Count > 0 ? pg[pg.Count / 2] : 0; bb[k] = pb.Count > 0 ? pb[pb.Count / 2] : 0;
            }
            Info = "lane colours";
            for (int k = 0; k < bands; k++) Info += string.Format(" {0:F0},{1:F0},{2:F0}", br[k], bg[k], bb[k]);
            var lane = new bool[n];
            for (int y = 0; y < gh; y++) {
                // Blend the two nearest stretches' colours by row.
                double fb = Math.Max(0, Math.Min(bands - 1, (y + 0.5) * bands / gh - 0.5));
                int k0 = (int)Math.Floor(fb), k1 = Math.Min(bands - 1, k0 + 1); double f = fb - k0;
                double mr = br[k0] * (1 - f) + br[k1] * f, mg = bg[k0] * (1 - f) + bg[k1] * f, mb = bb[k0] * (1 - f) + bb[k1] * f;
                for (int x = 0; x < gw; x++) {
                    int i = y * gw + x;
                    double d = Math.Sqrt((rv[i] - mr) * (rv[i] - mr) + (gv[i] - mg) * (gv[i] - mg) + (bv[i] - mb) * (bv[i] - mb));
                    lane[i] = d <= ColorTol && dv[i] <= dThr * 1.5;
                }
            }
            if (!string.IsNullOrEmpty(MaskOut)) {
                using (var m = new Bitmap(gw, gh)) { for (int i = 0; i < n; i++) m.SetPixel(i % gw, i / gw, lane[i] ? Color.White : Color.Black); m.Save(MaskOut); }
            }
            // Distance to the lane's edge (two-pass chamfer, in cells).
            var dist = new double[n];
            for (int i = 0; i < n; i++) dist[i] = lane[i] ? 1e9 : 0;
            for (int pass = 0; pass < 2; pass++) {
                int y0 = pass == 0 ? 0 : gh - 1, ye = pass == 0 ? gh : -1, yd = pass == 0 ? 1 : -1;
                for (int y = y0; y != ye; y += yd) {
                    int x0 = pass == 0 ? 0 : gw - 1, xe = pass == 0 ? gw : -1, xd = pass == 0 ? 1 : -1;
                    for (int x = x0; x != xe; x += xd) {
                        int i = y * gw + x; if (dist[i] == 0) continue;
                        double best = dist[i];
                        int px = x - xd, py = y - yd;
                        if (px >= 0 && px < gw) best = Math.Min(best, dist[y * gw + px] + 1);
                        if (py >= 0 && py < gh) {
                            best = Math.Min(best, dist[py * gw + x] + 1);
                            if (px >= 0 && px < gw) best = Math.Min(best, dist[py * gw + px] + 1.414);
                            int qx = x + xd; if (qx >= 0 && qx < gw) best = Math.Min(best, dist[py * gw + qx] + 1.414);
                        }
                        dist[i] = best;
                    }
                }
            }
            var cost = new double[n];
            for (int i = 0; i < n; i++) cost[i] = lane[i] ? 1 + 8.0 / (dist[i] * dist[i]) : 60;
            // Dijkstra from every top cell to the first bottom cell reached.
            var g = new double[n]; var from = new int[n];
            for (int i = 0; i < n; i++) { g[i] = double.MaxValue; from[i] = -1; }
            var heap = new System.Collections.Generic.SortedSet<Tuple<double, int>>();
            for (int x = 0; x < gw; x++) { g[x] = cost[x]; heap.Add(Tuple.Create(g[x], x)); }
            int end = -1;
            int[] ddx = { -1, 0, 1, -1, 1, -1, 0, 1 }, ddy = { -1, -1, -1, 0, 0, 1, 1, 1 };
            while (heap.Count > 0) {
                var top = heap.Min; heap.Remove(top);
                int i = top.Item2; if (top.Item1 > g[i]) continue;
                int x = i % gw, y = i / gw;
                if (y == gh - 1) { end = i; break; }
                for (int k = 0; k < 8; k++) {
                    int nx = x + ddx[k], ny = y + ddy[k];
                    if (nx < 0 || nx >= gw || ny < 0 || ny >= gh) continue;
                    int j = ny * gw + nx;
                    double c = g[i] + cost[j] * ((ddx[k] != 0 && ddy[k] != 0) ? 1.414 : 1);
                    if (c < g[j]) { if (g[j] != double.MaxValue) heap.Remove(Tuple.Create(g[j], j)); g[j] = c; from[j] = i; heap.Add(Tuple.Create(c, j)); }
                }
            }
            var cells = new System.Collections.Generic.List<int>();
            for (int i = end; i >= 0; i = from[i]) cells.Add(i);
            cells.Reverse();
            // The painted lane often begins just below the first landmark (a door, a chapel), not
            // at the top edge: drop the leading run before the path reaches the lane for good
            // (at least 85% of the next 60 cells on the lane; a bright sky patch at the top edge
            // counts as lane too, so a short run isn't enough), so the road doesn't cut through
            // the art to get there (Druid Alliance's trace ran down through the great tree,
            // 2026-11-12). Starts only in the top quarter of the strip.
            int startAt = 0;
            for (int k = 0; k + 60 < cells.Count && cells[k] / gw < gh / 4; k++) {
                if (!lane[cells[k]]) continue;
                int on = 0;
                for (int q = k; q < k + 60; q++) if (lane[cells[q]]) on++;
                if (on >= 51) { startAt = k; break; }
            }
            if (startAt > 0) cells.RemoveRange(0, startAt);
            // Resample every `step` px of arc length, then smooth.
            var xs = new System.Collections.Generic.List<double>(); var ys = new System.Collections.Generic.List<double>();
            double acc = step, lx = 0, ly = 0;
            for (int k = 0; k < cells.Count; k++) {
                double x = (cells[k] % gw) * cell + cell / 2.0, y = (cells[k] / gw) * cell + cell / 2.0;
                if (k > 0) acc += Math.Sqrt((x - lx) * (x - lx) + (y - ly) * (y - ly));
                if (acc >= step || k == cells.Count - 1) { xs.Add(x); ys.Add(y); acc = 0; }
                lx = x; ly = y;
            }
            // Re-centre: the cheapest path hugs the inside of bends; move each point to the middle
            // of the lane's cross-section across the path (where the lane is found on both sides).
            Func<double, double, bool> inLane = (px, py) => {
                int qx = (int)(px / cell), qy = (int)(py / cell);
                return qx >= 0 && qx < gw && qy >= 0 && qy < gh && lane[qy * gw + qx];
            };
            int moved = 0; double movedSum = 0;
            for (int pass = 0; pass < 2; pass++) {
                var nx2 = new System.Collections.Generic.List<double>(xs);
                var ny2 = new System.Collections.Generic.List<double>(ys);
                for (int i = 1; i < xs.Count - 1; i++) {
                    double ddxp = xs[i + 1] - xs[i - 1], ddyp = ys[i + 1] - ys[i - 1], len = Math.Sqrt(ddxp * ddxp + ddyp * ddyp);
                    if (len < 1e-6 || !inLane(xs[i], ys[i])) continue;
                    double ux = -ddyp / len, uy = ddxp / len, a = 0, b = 0;
                    while (a < 80 && inLane(xs[i] + ux * (a + 1), ys[i] + uy * (a + 1))) a++;
                    while (b < 80 && inLane(xs[i] - ux * (b + 1), ys[i] - uy * (b + 1))) b++;
                    if (a >= 80 || b >= 80) continue;
                    double shift = (a - b) / 2.0;
                    nx2[i] = xs[i] + ux * shift; ny2[i] = ys[i] + uy * shift;
                    moved++; movedSum += Math.Abs(shift);
                }
                xs = nx2; ys = ny2;
            }
            Info += string.Format(" | recentred {0} of {1} points, mean shift {2:F1}px", moved, 2 * xs.Count, moved > 0 ? movedSum / moved : 0);
            var outp = new double[xs.Count * 2];
            for (int i = 0; i < xs.Count; i++) {
                double sx = 0, sy = 0; int m = 0;
                for (int k = Math.Max(0, i - smooth); k <= Math.Min(xs.Count - 1, i + smooth); k++) { sx += xs[k]; sy += ys[k]; m++; }
                outp[2 * i] = i == 0 || i == xs.Count - 1 ? xs[i] : sx / m;
                outp[2 * i + 1] = i == 0 || i == xs.Count - 1 ? ys[i] : sy / m;
            }
            return outp;
        }
    }

    // A check on a traced path (strip pixels, x,y pairs): walks it every 4 px and returns the
    // longest stretch (px) over ground that isn't lane-like (warm: red at least 80 above blue;
    // light: luminance 140+, averaged over a 5x5 patch). The top and bottom 60 rows are left out.
    public static int LongestOffLane(string path, double[] pts) {
        using (var src = new Bitmap(path)) {
            int w = src.Width, h = src.Height;
            var data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            var buf = new byte[data.Stride * h];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            src.UnlockBits(data);
            int run = 0, longest = 0;
            for (int i = 2; i < pts.Length; i += 2) {
                double ax = pts[i - 2], ay = pts[i - 1], bx = pts[i], by = pts[i + 1];
                double len = Math.Sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
                int steps = Math.Max(1, (int)(len / 4));
                for (int s = 0; s < steps; s++) {
                    int x = (int)(ax + (bx - ax) * s / steps), y = (int)(ay + (by - ay) * s / steps);
                    if (y < 60 || y > h - 60 || x < 3 || x > w - 4) continue;
                    double r = 0, g = 0, b = 0;
                    for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) {
                        int k = (y + dy) * data.Stride + (x + dx) * 3; b += buf[k]; g += buf[k + 1]; r += buf[k + 2];
                    }
                    r /= 25; g /= 25; b /= 25;
                    bool lane = r - b >= 80 && 0.3 * r + 0.59 * g + 0.11 * b >= 140;
                    if (lane) run = 0; else { run += 4; if (run > longest) longest = run; }
                }
            }
            return longest;
        }
    }

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
    [AzfStripPath]::ColorTol = $ColorTol
    [AzfStripPath]::MaskOut = if ($MaskDir) { Join-Path $MaskDir "$($png.BaseName)-mask.png" } else { $null }
    $pts = if ($Method -eq 'lane') { [AzfStripPath]::TraceLane($png.FullName, $Step, $Window, [Math]::Min($Smooth, $LaneSmooth)) } else { [AzfStripPath]::Trace($png.FullName, $Step, $Window, $Smooth) }
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
    if ($MaskDir) { Write-Output ([AzfStripPath]::Info) }
    # The check: the longest stretch of the trace over ground that isn't lane-like. More than
    # ~40 px means it leaves the painted lane somewhere: look at the review image.
    $off = [AzfStripPath]::LongestOffLane($png.FullName, $pts)
    $warn = if ($off -gt $OffLaneWarn) { "  CHECK: leaves the lane for $off px" } else { '' }
    Write-Output "$($png.BaseName): $($pts.Count / 2) points, longest off-lane $off px -> review $($png.BaseName)-path.png$warn"
}
$lua += '}'
$js += '};'
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $OutLua)).Path + '\' + (Split-Path $OutLua -Leaf), $lua, (New-Object System.Text.UTF8Encoding $false))
[IO.File]::WriteAllLines((Resolve-Path (Split-Path $OutJs)).Path + '\' + (Split-Path $OutJs -Leaf), $js, (New-Object System.Text.UTF8Encoding $false))
