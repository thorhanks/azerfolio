# Serves the mockups/ folder on http://localhost:<Port>/ for the desktop app's browser pane.
# Dev only. Uses .NET HttpListener; no installs. Stop with Ctrl+C (or stop the preview).
param([int]$Port = 8765)

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\mockups')).Path
$types = @{ '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8';
            '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.json' = 'application/json' }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $root at http://localhost:$Port/"
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $res = $ctx.Response
        try {
            $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
            if ($rel -eq '') { $rel = 'index.html' }
            $file = [IO.Path]::GetFullPath((Join-Path $root $rel))
            if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)) {
                [byte[]]$bytes = [IO.File]::ReadAllBytes($file)
                $ext = [IO.Path]::GetExtension($file).ToLower()
                $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' })
                $res.Headers.Add('Cache-Control', 'no-store')
                if ($ctx.Request.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
            } else {
                $res.StatusCode = 404
            }
        } catch {
            Write-Output "Request failed: $($ctx.Request.Url) - $_"
            try { $res.StatusCode = 500 } catch {}
        } finally {
            try { $res.Close() } catch {}
        }
    }
} finally {
    $listener.Stop()
}
