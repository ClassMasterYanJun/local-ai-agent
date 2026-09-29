[CmdletBinding()]
param([int]$Port = 8787)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

$contentTypes = @{
    '.html' = 'text/html; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
    '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'web-chat.html' }
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
        if (-not $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $context.Response.StatusCode = 404
            $context.Response.Close()
            continue
        }
        $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
        $context.Response.ContentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { 'application/octet-stream' }
        $bytes = [System.IO.File]::ReadAllBytes($candidate)
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
