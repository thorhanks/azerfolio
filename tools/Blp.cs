// Minimal BLP2 writer/reader for Azerfolio art: DXT1 (no alpha) with a full mipmap chain.
// Compiled at runtime by tools/convert-blp.ps1 (Add-Type, C# 5). No external dependencies.
//
// BLP2 layout (little endian):
//   char[4] "BLP2" | uint32 type=1 | uint8 compression=2 (DXT) | uint8 alphaDepth=0 | uint8 alphaType=0 (DXT1)
//   uint8 hasMips=1 | uint32 width | uint32 height | uint32 mipOffsets[16] | uint32 mipSizes[16] | uint32 palette[256]
//   then the DXT1 data for each mip level.
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

    // ---------- Public API ----------
    // Converts an image (PNG/JPG) to BLP2 DXT1 with mipmaps. Width and height must be powers of two.
    public static string Convert(string inPath, string outPath)
    {
        int w, h;
        var px = ReadRgba(inPath, out w, out h);
        if ((w & (w - 1)) != 0 || (h & (h - 1)) != 0) throw new ArgumentException("Dimensions must be powers of two: " + w + "x" + h);
        var levels = new System.Collections.Generic.List<byte[]>();
        int lw = w, lh = h; var lp = px;
        while (true)
        {
            levels.Add(EncodeLevel(lp, lw, lh));
            if (lw == 1 && lh == 1) break;
            int nw, nh; lp = Downsample(lp, lw, lh, out nw, out nh); lw = nw; lh = nh;
            if (levels.Count == 16) break;
        }
        using (var fs = new FileStream(outPath, FileMode.Create))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write(new byte[] { (byte)'B', (byte)'L', (byte)'P', (byte)'2' });
            bw.Write((uint)1);          // type: DXT / uncompressed family
            bw.Write((byte)2);          // compression: DXT
            bw.Write((byte)0);          // alpha depth: none
            bw.Write((byte)0);          // alpha type: DXT1
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

    // Decodes mip 0 of a BLP2 DXT1 file to PNG (for verification).
    public static void Decode(string blpPath, string pngPath)
    {
        var bytes = File.ReadAllBytes(blpPath);
        if (bytes[0] != 'B' || bytes[1] != 'L' || bytes[2] != 'P' || bytes[3] != '2') throw new InvalidDataException("Not BLP2");
        if (bytes[8] != 2 || bytes[10] != 0) throw new InvalidDataException("Only DXT1 is supported");
        int w = (int)BitConverter.ToUInt32(bytes, 12), h = (int)BitConverter.ToUInt32(bytes, 16);
        int off = (int)BitConverter.ToUInt32(bytes, 20);
        var px = new byte[w * h * 4];
        int bw = Math.Max(1, (w + 3) / 4), bh = Math.Max(1, (h + 3) / 4);
        var a = new float[3]; var b = new float[3]; var p = new float[4, 3];
        for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
            {
                int o = off + (by * bw + bx) * 8;
                ushort c0 = BitConverter.ToUInt16(bytes, o), c1 = BitConverter.ToUInt16(bytes, o + 2);
                uint idx = BitConverter.ToUInt32(bytes, o + 4);
                From565(c0, a); From565(c1, b);
                for (int k = 0; k < 3; k++)
                {
                    p[0, k] = a[k]; p[1, k] = b[k];
                    if (c0 > c1) { p[2, k] = (2 * a[k] + b[k]) / 3f; p[3, k] = (a[k] + 2 * b[k]) / 3f; }
                    else { p[2, k] = (a[k] + b[k]) / 2f; p[3, k] = 0; }
                }
                for (int i = 0; i < 16; i++)
                {
                    int x = bx * 4 + (i & 3), y = by * 4 + (i >> 2);
                    if (x >= w || y >= h) continue;
                    int j = (int)((idx >> (i * 2)) & 3), d = (y * w + x) * 4;
                    px[d] = (byte)Math.Round(p[j, 0]); px[d + 1] = (byte)Math.Round(p[j, 1]); px[d + 2] = (byte)Math.Round(p[j, 2]); px[d + 3] = 255;
                }
            }
        WriteRgba(pngPath, px, w, h);
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
