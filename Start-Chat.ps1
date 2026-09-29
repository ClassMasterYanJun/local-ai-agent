[CmdletBinding()]
param(
    [int]$Port = 8787,
    [int]$LlamaPort = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$serverScript = Join-Path $projectRoot 'Start-ChatServer.ps1'
$runtimeDirectory = Join-Path $projectRoot 'runtime\llama.cpp'
$llamaServer = Join-Path $runtimeDirectory 'llama-server.exe'
$manifestPath = Join-Path $projectRoot 'models\package\model.json'
$apiUrl = "http://127.0.0.1:$LlamaPort"

if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Не найден сервер веб-чата: $serverScript"
}
if (-not (Test-Path -LiteralPath $llamaServer -PathType Leaf)) {
    throw "Не найден портативный llama-server.exe: $llamaServer. Сначала проверьте содержимое папки runtime\llama.cpp."
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Не найден манифест модели: $manifestPath"
}

$package = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$modelPath = Join-Path (Split-Path -Parent $manifestPath) $package.gguf_file
if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
    throw "Не найден локальный GGUF-файл: $modelPath"
}

function Get-RunningModelIds {
    try {
        $response = Invoke-RestMethod -Uri "$apiUrl/v1/models" -TimeoutSec 2
        return @($response.data | ForEach-Object id)
    } catch {
        return @()
    }
}

$runningModelIds = @(Get-RunningModelIds)
if ($runningModelIds.Count -gt 0) {
    if ($runningModelIds -notcontains $package.model_id) {
        throw "Порт $LlamaPort уже занят сервером с другой моделью. Освободите порт и повторите запуск."
    }
} else {
    $arguments = @('--model', ('"{0}"' -f $modelPath), '--alias', $package.model_id, '--host', '127.0.0.1', '--port', $LlamaPort, '--ctx-size', '8192', '--offline', '--no-webui')
    Start-Process -FilePath $llamaServer -WorkingDirectory $runtimeDirectory -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    for ($attempt = 1; $attempt -le 90; $attempt++) {
        Start-Sleep -Seconds 1
        if ((Get-RunningModelIds) -contains $package.model_id) { break }
        if ($attempt -eq 90) { throw "Не удалось запустить локальный API llama.cpp: $apiUrl" }
    }
}

try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/" -UseBasicParsing -TimeoutSec 1 | Out-Null
} catch {
    Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$serverScript`" -Port $Port" -WindowStyle Hidden | Out-Null
    Start-Sleep -Milliseconds 700
}

Start-Process "http://127.0.0.1:$Port/"
