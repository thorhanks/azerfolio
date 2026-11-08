// Minimal BLP2 writer/reader for Azerfolio art with a full mipmap chain: DXT1 (no alpha) for
// zone art, DXT5 (8-bit alpha) for the war banner pieces, which are painted on flat magenta
// and keyed out here (KeyMagenta). Compiled at runtime (Add-Type, C# 5). No external dependencies.
//
// BLP2 layout (little endian):
//   char[4] "BLP2" | uint32 type=1 | uint8 compression=2 (DXT) | uint8 alphaDepth (0 or 8) |
//   uint8 alphaType (0 = DXT1, 7 = DXT5) | uint8 hasMips=1 | uint32 width | uint32 height |
//   uint32 mipOffsets[16] | uint32 mipSizes[16] | uint32 palette[256], then each mip level's blocks.
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class AzfBlp
{
    const int HeaderSize = 4 + 4 + 4 + 4 + 4 + 16 * 4 + 16 * 4 + 256 * 4; // 1172

    // ---------- Pixels ----------
    static byte[] ReadRgba(string path, out int w, out int h)
    {
        using (var src = new Bitmap(path))
        using (var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(bmp)) g.DrawImage(src, 0, 0, src.Width, src.Height);
            w = bmp.Width; h = bmp.Height;
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var raw = new byte[data.Stride * h];
            Marshal.Copy(data.Scan0, raw, 0, raw.Length);
            int stride = data.Stride;
            bmp.UnlockBits(data);
            var px = new byte[w * h * 4];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int s = y * stride + x * 4, d = (y * w + x) * 4;
                    px[d] = raw[s + 2]; px[d + 1] = raw[s + 1]; px[d + 2] = raw[s]; px[d + 3] = raw[s + 3];
                }
            return px;
        }
    }

    static void WriteRgba(string path, byte[] px, int w, int h)
    {
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var raw = new byte[data.Stride * h];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int s = (y * w + x) * 4, d = y * data.Stride + x * 4;
                    raw[d] = px[s + 2]; raw[d + 1] = px[s + 1]; raw[d + 2] = px[s]; raw[d + 3] = px[s + 3];
                }
            Marshal.Copy(raw, 0, data.Scan0, raw.Length);
            bmp.UnlockBits(data);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    // 2x2 box filter to the next mip level.
    static byte[] Downsample(byte[] px, int w, int h, out int nw, out int nh)
    {
        nw = Math.Max(1, w / 2); nh = Math.Max(1, h / 2);
        var o = new byte[nw * nh * 4];
        for (int y = 0; y < nh; y++)
            for (int x = 0; x < nw; x++)
                for (int c = 0; c < 4; c++)
                {
                    int x0 = Math.Min(x * 2, w - 1), x1 = Math.Min(x * 2 + 1, w - 1);
                    int y0 = Math.Min(y * 2, h - 1), y1 = Math.Min(y * 2 + 1, h - 1);
                    int sum = px[(y0 * w + x0) * 4 + c] + px[(y0 * w + x1) * 4 + c] + px[(y1 * w + x0) * 4 + c] + px[(y1 * w + x1) * 4 + c];
                    o[(y * nw + x) * 4 + c] = (byte)((sum + 2) / 4);
                }
        return o;
    }

    // ---------- DXT1 ----------
    static int Clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

    static ushort To565(float r, float g, float b)
    {
        int R = Clamp((int)Math.Round(r * 31f / 255f), 0, 31);
        int G = Clamp((int)Math.Round(g * 63f / 255f), 0, 63);
        int B = Clamp((int)Math.Round(b * 31f / 255f), 0, 31);
        return (ushort)((R << 11) | (G << 5) | B);
    }

    static void From565(ushort c, float[] rgb)
    {
        int r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
        rgb[0] = (r << 3) | (r >> 2); rgb[1] = (g << 2) | (g >> 4); rgb[2] = (b << 3) | (b >> 2);
    }

    // Encodes one 4x4 block (edges clamped) using the principal axis of the block's colours.
    static void EncodeBlock(byte[] px, int w, int h, int bx, int by, byte[] dst, int o)
    {
        var r = new float[16]; var g = new float[16]; var b = new float[16];
        float mr = 0, mg = 0, mb = 0;
        for (int i = 0; i < 16; i++)
        {
            int x = Math.Min(bx + (i & 3), w - 1), y = Math.Min(by + (i >> 2), h - 1);
            int s = (y * w + x) * 4;
            r[i] = px[s]; g[i] = px[s + 1]; b[i] = px[s + 2];
            mr += r[i]; mg += g[i]; mb += b[i];
        }
        mr /= 16; mg /= 16; mb /= 16;

        // Covariance and principal axis by power iteration.
        float crr = 0, crg = 0, crb = 0, cgg = 0, cgb = 0, cbb = 0;
        for (int i = 0; i < 16; i++)
        {
            float dr = r[i] - mr, dg = g[i] - mg, db = b[i] - mb;
            crr += dr * dr; crg += dr * dg; crb += dr * db; cgg += dg * dg; cgb += dg * db; cbb += db * db;
        }
        float ar = 1, ag = 1, ab = 1;
        for (int it = 0; it < 8; it++)
        {
            float nr = crr * ar + crg * ag + crb * ab, ng = crg * ar + cgg * ag + cgb * ab, nb = crb * ar + cgb * ag + cbb * ab;
            float len = (float)Math.Sqrt(nr * nr + ng * ng + nb * nb);
            if (len < 1e-6f) { ar = 0.577f; ag = 0.577f; ab = 0.577f; break; }
            ar = nr / len; ag = ng / len; ab = nb / len;
        }
        float tmin = float.MaxValue, tmax = float.MinValue;
        for (int i = 0; i < 16; i++)
        {
            float t = (r[i] - mr) * ar + (g[i] - mg) * ag + (b[i] - mb) * ab;
            if (t < tmin) tmin = t; if (t > tmax) tmax = t;
        }
        float inset = (tmax - tmin) / 16f; tmin += inset; tmax -= inset;
        ushort c0 = To565(mr + ar * tmax, mg + ag * tmax, mb + ab * tmax);
        ushort c1 = To565(mr + ar * tmin, mg + ag * tmin, mb + ab * tmin);
        if (c0 < c1) { ushort t = c0; c0 = c1; c1 = t; }

        uint indices = 0;
        if (c0 != c1) // 4-colour mode requires c0 > c1; equal endpoints leave every index at 0 (colour c0)
        {
            var p = new float[4, 3]; var a = new float[3]; var bb = new float[3];
            From565(c0, a); From565(c1, bb);
            for (int k = 0; k < 3; k++)
            {
                p[0, k] = a[k]; p[1, k] = bb[k];
                p[2, k] = (2 * a[k] + bb[k]) / 3f; p[3, k] = (a[k] + 2 * bb[k]) / 3f;
            }
            for (int i = 0; i < 16; i++)
            {
                int best = 0; float bestD = float.MaxValue;
                for (int j = 0; j < 4; j++)
                {
                    float dr = r[i] - p[j, 0], dg = g[i] - p[j, 1], db = b[i] - p[j, 2];
                    float d = dr * dr * 0.30f + dg * dg * 0.59f + db * db * 0.11f; // perceptual weights
                    if (d < bestD) { bestD = d; best = j; }
                }
                indices |= (uint)best << (i * 2);
            }
        }
        dst[o] = (byte)(c0 & 0xFF); dst[o + 1] = (byte)(c0 >> 8);
        dst[o + 2] = (byte)(c1 & 0xFF); dst[o + 3] = (byte)(c1 >> 8);
        dst[o + 4] = (byte)(indices & 0xFF); dst[o + 5] = (byte)((indices >> 8) & 0xFF);
        dst[o + 6] = (byte)((indices >> 16) & 0xFF); dst[o + 7] = (byte)(indices >> 24);
    }

    static byte[] EncodeLevel(byte[] px, int w, int h)
    {
        int bw = Math.Max(1, (w + 3) / 4), bh = Math.Max(1, (h + 3) / 4);
        var o = new byte[bw * bh * 8];
        for (int y = 0; y < bh; y++)
            for (int x = 0; x < bw; x++)
                EncodeBlock(px, w, h, x * 4, y * 4, o, (y * bw + x) * 8);
        return o;
    }

    // ---------- Alpha: magenta key and DXT5 ----------

    // Keys out a flat magenta background (#FF00FF): alpha falls off with "magenta-ness"
    // (min(R,B) - G), and the magenta spill left on soft edges is removed. Fully transparent
    // pixels get black colour (the encoder replaces it with the block's own colour).
    public static string KeyMagenta(string inPath, string outPath)
    {
        int w, h;
        var px = ReadRgba(inPath, out w, out h);
        const float lo = 60f, hi = 170f;
        int clear = 0, soft = 0;
        for (int i = 0; i < px.Length; i += 4)
        {
            float r = px[i], g = px[i + 1], b = px[i + 2];
            float m = Math.Min(r, b) - g;
            float a = 1f - Math.Max(0f, Math.Min(1f, (m - lo) / (hi - lo)));
            if (a < 1f && a > 0.004f)
            {
                // Un-mix: observed = a * paint + (1 - a) * magenta, so paint = (observed - (1 - a) * magenta) / a.
                r = (r - (1f - a) * 255f) / a; g = g / a; b = (b - (1f - a) * 255f) / a;
                px[i + 1] = (byte)Clamp((int)Math.Round(g), 0, 255);
            }
            a *= px[i + 3] / 255f;
            if (a <= 0.004f) { px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 0; clear++; continue; }
            if (a < 0.996f) soft++;
            px[i] = (byte)Clamp((int)Math.Round(r), 0, 255); px[i + 2] = (byte)Clamp((int)Math.Round(b), 0, 255);
            px[i + 3] = (byte)Clamp((int)Math.Round(a * 255f), 0, 255);
        }
        WriteRgba(outPath, px, w, h);
        return w + "x" + h + ", " + (100 * clear / (w * h)) + "% transparent, " + soft + " soft edge pixels";
    }

    // Like Downsample, but colour is averaged weighted by alpha (no dark or magenta fringes).
    static byte[] DownsampleAlpha(byte[] px, int w, int h, out int nw, out int nh)
    {
        nw = Math.Max(1, w / 2); nh = Math.Max(1, h / 2);
        var o = new byte[nw * nh * 4];
        for (int y = 0; y < nh; y++)
            for (int x = 0; x < nw; x++)
            {
                int x0 = Math.Min(x * 2, w - 1), x1 = Math.Min(x * 2 + 1, w - 1);
                int y0 = Math.Min(y * 2, h - 1), y1 = Math.Min(y * 2 + 1, h - 1);
                int[] s = { (y0 * w + x0) * 4, (y0 * w + x1) * 4, (y1 * w + x0) * 4, (y1 * w + x1) * 4 };
                float wa = 0, r = 0, g = 0, b = 0;
                foreach (int k in s) { float a = px[k + 3]; wa += a; r += px[k] * a; g += px[k + 1] * a; b += px[k + 2] * a; }
                int d = (y * nw + x) * 4;
                if (wa > 0) { o[d] = (byte)(r / wa); o[d + 1] = (byte)(g / wa); o[d + 2] = (byte)(b / wa); }
                o[d + 3] = (byte)((wa / 4f) + 0.5f);
            }
        return o;
    }

    // One DXT5 block: 8 bytes of alpha (two endpoints, 3-bit indices), then a DXT1 colour block
    // encoded from the visible pixels (transparent ones take the visible pixels' mean colour).
    static void EncodeBlockAlpha(byte[] px, int w, int h, int bx, int by, byte[] dst, int o)
    {
        var tmp = new byte[64]; var al = new int[16];
        float mr = 0, mg = 0, mb = 0; int vis = 0;
        for (int i = 0; i < 16; i++)
        {
            int x = Math.Min(bx + (i & 3), w - 1), y = Math.Min(by + (i >> 2), h - 1);
            int s = (y * w + x) * 4;
            for (int c = 0; c < 4; c++) tmp[i * 4 + c] = px[s + c];
            al[i] = px[s + 3];
            if (al[i] > 0) { mr += px[s]; mg += px[s + 1]; mb += px[s + 2]; vis++; }
        }
        if (vis > 0) { mr /= vis; mg /= vis; mb /= vis; }
        for (int i = 0; i < 16; i++)
            if (al[i] == 0) { tmp[i * 4] = (byte)mr; tmp[i * 4 + 1] = (byte)mg; tmp[i * 4 + 2] = (byte)mb; }
        int a0 = 0, a1 = 255;
        for (int i = 0; i < 16; i++) { if (al[i] > a0) a0 = al[i]; if (al[i] < a1) a1 = al[i]; }
        var pal = new int[8];
        pal[0] = a0; pal[1] = a1;
        for (int k = 2; k < 8; k++) pal[k] = ((8 - k) * a0 + (k - 1) * a1 + 3) / 7;
        ulong bits = 0;
        if (a0 != a1)
            for (int i = 0; i < 16; i++)
            {
                int best = 0, bestD = int.MaxValue;
                for (int k = 0; k < 8; k++) { int d = Math.Abs(al[i] - pal[k]); if (d < bestD) { bestD = d; best = k; } }
                bits |= (ulong)best << (3 * i);
            }
        dst[o] = (byte)a0; dst[o + 1] = (byte)a1;
        for (int k = 0; k < 6; k++) dst[o + 2 + k] = (byte)((bits >> (8 * k)) & 0xFF);
        EncodeBlock(tmp, 4, 4, 0, 0, dst, o + 8);
    }

    static byte[] EncodeLevelAlpha(byte[] px, int w, int h)
    {
        int bw = Math.Max(1, (w + 3) / 4), bh = Math.Max(1, (h + 3) / 4);
        var o = new byte[bw * bh * 16];
        for (int y = 0; y < bh; y++)
            for (int x = 0; x < bw; x++)
                EncodeBlockAlpha(px, w, h, x * 4, y * 4, o, (y * bw + x) * 16);
        return o;
    }

    // Converts an image with alpha (PNG) to BLP2 DXT5 with mipmaps. Powers of two only.
    public static string ConvertAlpha(string inPath, string outPath) { return Write(inPath, outPath, true); }

    // ---------- Public API ----------
    // Converts an image (PNG/JPG) to BLP2 DXT1 with mipmaps. Width and height must be powers of two.
    public static string Convert(string inPath, string outPath) { return Write(inPath, outPath, false); }

    static string Write(string inPath, string outPath, bool alpha)
    {
        int w, h;
        var px = ReadRgba(inPath, out w, out h);
        if ((w & (w - 1)) != 0 || (h & (h - 1)) != 0) throw new ArgumentException("Dimensions must be powers of two: " + w + "x" + h);
        var levels = new System.Collections.Generic.List<byte[]>();
        int lw = w, lh = h; var lp = px;
        while (true)
        {
            levels.Add(alpha ? EncodeLevelAlpha(lp, lw, lh) : EncodeLevel(lp, lw, lh));
            if (lw == 1 && lh == 1) break;
            int nw, nh; lp = alpha ? DownsampleAlpha(lp, lw, lh, out nw, out nh) : Downsample(lp, lw, lh, out nw, out nh); lw = nw; lh = nh;
            if (levels.Count == 16) break;
        }
        using (var fs = new FileStream(outPath, FileMode.Create))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write(new byte[] { (byte)'B', (byte)'L', (byte)'P', (byte)'2' });
            bw.Write((uint)1);          // type: DXT / uncompressed family
            bw.Write((byte)2);          // compression: DXT
            bw.Write((byte)(alpha ? 8 : 0)); // alpha depth
            bw.Write((byte)(alpha ? 7 : 0)); // alpha type: DXT5 or DXT1
            bw.Write((byte)1);          // has mips
            bw.Write((uint)w); bw.Write((uint)h);
            uint offset = HeaderSize;
            for (int i = 0; i < 16; i++) { bw.Write(i < levels.Count ? offset : 0u); if (i < levels.Count) offset += (uint)levels[i].Length; }
            for (int i = 0; i < 16; i++) bw.Write(i < levels.Count ? (uint)levels[i].Length : 0u);
            bw.Write(new byte[256 * 4]); // palette (unused for DXT)
            foreach (var l in levels) bw.Write(l);
        }
        return w + "x" + h + ", " + levels.Count + " mips, " + new FileInfo(outPath).Length + " bytes";
    }

    // Decodes mip 0 of a BLP2 DXT1 or DXT5 file to PNG (for verification).
    public static void Decode(string blpPath, string pngPath)
    {
        var bytes = File.ReadAllBytes(blpPath);
        if (bytes[0] != 'B' || bytes[1] != 'L' || bytes[2] != 'P' || bytes[3] != '2') throw new InvalidDataException("Not BLP2");
        bool dxt5 = bytes[10] == 7;
        if (bytes[8] != 2 || (bytes[10] != 0 && !dxt5)) throw new InvalidDataException("Only DXT1 and DXT5 are supported");
        int w = (int)BitConverter.ToUInt32(bytes, 12), h = (int)BitConverter.ToUInt32(bytes, 16);
        int off = (int)BitConverter.ToUInt32(bytes, 20);
        int size = dxt5 ? 16 : 8;
        var px = new byte[w * h * 4];
        int bw = Math.Max(1, (w + 3) / 4), bh = Math.Max(1, (h + 3) / 4);
        var a = new float[3]; var b = new float[3]; var p = new float[4, 3]; var pal = new int[8];
        for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
            {
                int o = off + (by * bw + bx) * size;
                ulong abits = 0;
                if (dxt5)
                {
                    int a0 = bytes[o], a1 = bytes[o + 1];
                    pal[0] = a0; pal[1] = a1;
                    if (a0 > a1) for (int k = 2; k < 8; k++) pal[k] = ((8 - k) * a0 + (k - 1) * a1) / 7;
                    else { for (int k = 2; k < 6; k++) pal[k] = ((6 - k) * a0 + (k - 1) * a1) / 5; pal[6] = 0; pal[7] = 255; }
                    for (int k = 0; k < 6; k++) abits |= (ulong)bytes[o + 2 + k] << (8 * k);
                    o += 8;
                }
                ushort c0 = BitConverter.ToUInt16(bytes, o), c1 = BitConverter.ToUInt16(bytes, o + 2);
                uint idx = BitConverter.ToUInt32(bytes, o + 4);
                From565(c0, a); From565(c1, b);
                for (int k = 0; k < 3; k++)
                {
                    p[0, k] = a[k]; p[1, k] = b[k];
                    if (dxt5 || c0 > c1) { p[2, k] = (2 * a[k] + b[k]) / 3f; p[3, k] = (a[k] + 2 * b[k]) / 3f; }
                    else { p[2, k] = (a[k] + b[k]) / 2f; p[3, k] = 0; }
                }
                for (int i = 0; i < 16; i++)
                {
                    int x = bx * 4 + (i & 3), y = by * 4 + (i >> 2);
                    if (x >= w || y >= h) continue;
                    int j = (int)((idx >> (i * 2)) & 3), d = (y * w + x) * 4;
                    px[d] = (byte)Math.Round(p[j, 0]); px[d + 1] = (byte)Math.Round(p[j, 1]); px[d + 2] = (byte)Math.Round(p[j, 2]);
                    px[d + 3] = dxt5 ? (byte)pal[(int)((abits >> (3 * i)) & 7)] : (byte)255;
                }
            }
        WriteRgba(pngPath, px, w, h);
    }

    // A keyed frame's border thickness for nine-slicing, as fractions of width and height:
    // along the middle row (and column), from the outside edge to where the empty centre begins.
    // Returns "x,y", or "" when the frame has no empty centre to measure.
    public static string MeasureFrame(string path)
    {
        int w, h;
        var px = ReadRgba(path, out w, out h);
        Func<int, int, int> a = (x, y) => px[(y * w + x) * 4 + 3];
        int row = h / 2, col = w / 2, left = -1, top = -1;
        int x0 = 0; while (x0 < w / 2 && a(x0, row) < 128) x0++;          // outside margin
        int x1 = x0; while (x1 < w / 2 && a(x1, row) >= 64) x1++;         // the border band
        if (x0 < w / 2 && x1 < w / 2 && x1 > x0) left = x1;
        int y0 = 0; while (y0 < h / 2 && a(col, y0) < 128) y0++;
        int y1 = y0; while (y1 < h / 2 && a(col, y1) >= 64) y1++;
        if (y0 < h / 2 && y1 < h / 2 && y1 > y0) top = y1;
        if (left < 0 || top < 0) return "";
        return ((double)left / w).ToString("0.####", System.Globalization.CultureInfo.InvariantCulture) + "," +
            ((double)top / h).ToString("0.####", System.Globalization.CultureInfo.InvariantCulture);
    }

    // Mean absolute alpha difference (0-255) between two same-size images.
    public static double AlphaError(string aPath, string bPath)
    {
        int aw, ah, bw2, bh2;
        var a = ReadRgba(aPath, out aw, out ah); var b = ReadRgba(bPath, out bw2, out bh2);
        if (aw != bw2 || ah != bh2) throw new ArgumentException("Size mismatch");
        double s = 0;
        for (int i = 3; i < a.Length; i += 4) s += Math.Abs(a[i] - b[i]);
        return s / (aw * ah);
    }

    // Peak signal-to-noise ratio (dB) between two same-size images, RGB only.
    public static double Psnr(string aPath, string bPath)
    {
        int aw, ah, bw2, bh2;
        var a = ReadRgba(aPath, out aw, out ah); var b = ReadRgba(bPath, out bw2, out bh2);
        if (aw != bw2 || ah != bh2) throw new ArgumentException("Size mismatch");
        double se = 0; long n = 0;
        for (int i = 0; i < a.Length; i += 4)
            for (int c = 0; c < 3; c++) { double d = a[i + c] - b[i + c]; se += d * d; n++; }
        double mse = se / n;
        return mse == 0 ? 99 : 10 * Math.Log10(255.0 * 255.0 / mse);
    }
}
