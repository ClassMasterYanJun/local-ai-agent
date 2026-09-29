<#
.SYNOPSIS
    Создаёт проверяемую опись портативного пакета llama.cpp и локальной модели.

.DESCRIPTION
    GGUF и runtime уже являются переносимыми файлами. Скрипт не экспортирует и не
    конвертирует модель: он записывает контрольные суммы файлов для сборки релиза.
#>
[CmdletBinding()]
param([string]$ExportPath = (Join-Path $PSScriptRoot 'export'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$modelManifest = Join-Path $projectRoot 'models\package\model.json'
$runtimeManifest = Join-Path $projectRoot 'runtime\llama.cpp-package.json'
$runtimeDirectory = Join-Path $projectRoot 'runtime\llama.cpp'

foreach ($path in @($modelManifest, $runtimeManifest, (Join-Path $runtimeDirectory 'llama-server.exe'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Не найден необходимый файл: $path" }
}

New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
$model = Get-Content -LiteralPath $modelManifest -Raw -Encoding UTF8 | ConvertFrom-Json
$modelPath = Join-Path (Split-Path -Parent $modelManifest) $model.gguf_file
if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) { throw "Не найден GGUF-файл: $modelPath" }

$files = @($modelPath) + @(Get-ChildItem -LiteralPath $runtimeDirectory -File | ForEach-Object FullName)
$inventory = foreach ($file in $files) {
    $item = Get-Item -LiteralPath $file
    [PSCustomObject]@{
        path = $file.Substring($projectRoot.Length).TrimStart('\')
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

[PSCustomObject]@{
    created_at = (Get-Date).ToString('o')
    model_id = $model.model_id
    runtime = Get-Content -LiteralPath $runtimeManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    files = $inventory
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ExportPath 'portable-package-manifest.json') -Encoding UTF8

Write-Host "Создана опись пакета: $(Join-Path $ExportPath 'portable-package-manifest.json')" -ForegroundColor Green
Write-Host 'Для переноса скопируйте весь проект, включая models\package и runtime\llama.cpp.' -ForegroundColor Cyan
