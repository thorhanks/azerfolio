# Generates AzerfolioDiag/Media/test.tga (red-gold gradient) and test.png (blue-teal gradient), 128x128.
# Different colors let the extensionless texture test show which format the client prefers.
Add-Type -AssemblyName System.Drawing

$media = Join-Path $PSScriptRoot '..\AzerfolioDiag\Media'
New-Item -ItemType Directory -Force $media | Out-Null
$size = 128

# PNG via System.Drawing
$bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
        $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 20, [int](80 + $y), [int](120 + $x)))
    }
}
$bmp.Save((Join-Path $media 'test.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# TGA: uncompressed 32-bit BGRA, bottom-left origin
$header = [byte[]](0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, ($size -band 0xFF), ($size -shr 8), ($size -band 0xFF), ($size -shr 8), 32, 8)
$pixels = New-Object byte[] ($size * $size * 4)
$i = 0
for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
        $pixels[$i] = 30                        # B
        $pixels[$i + 1] = [byte](60 + $y)       # G
        $pixels[$i + 2] = [byte](127 + $x)      # R
        $pixels[$i + 3] = 255                   # A
        $i += 4
    }
}
[System.IO.File]::WriteAllBytes((Join-Path $media 'test.tga'), $header + $pixels)
Write-Output "Wrote test.png and test.tga to $media"
