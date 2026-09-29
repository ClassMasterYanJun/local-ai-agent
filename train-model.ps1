<#
.SYNOPSIS
    Сохраняет профиль системной инструкции для локальной Qwen-модели.

.DESCRIPTION
    llama.cpp обслуживает неизменяемый GGUF-файл и не выполняет дообучение весов.
    Скрипт создаёт JSON-профиль с системной инструкцией для применения клиентом API.
    Датасет сохраняется только как ссылка в профиле и не меняет веса модели.
#>
[CmdletBinding()]
param(
    [ValidateSet('prompt', 'specialized', 'dataset')]
    [string]$TrainingType = 'prompt',
    [string]$Name = 'custom-assistant',
    [string]$SystemPrompt = 'Ты полезный ассистент. Отвечай точно, структурированно и на русском языке, если пользователь не попросил другой язык.',
    [string]$DatasetPath = '',
    [ValidateSet('code', 'medical', 'legal', 'creative', 'russian', 'custom')]
    [string]$Specialization = 'custom'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$manifestPath = Join-Path $projectRoot 'models\package\model.json'
$outputDirectory = Join-Path $projectRoot 'training\output'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Не найден манифест базовой модели: $manifestPath"
}
if ([string]::IsNullOrWhiteSpace($Name) -or $Name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
    throw 'Имя профиля не должно быть пустым и не должно содержать недопустимых символов имени файла.'
}
if ($TrainingType -eq 'dataset') {
    if ([string]::IsNullOrWhiteSpace($DatasetPath) -or -not (Test-Path -LiteralPath $DatasetPath -PathType Leaf)) {
        throw 'Для режима dataset укажите существующий файл через -DatasetPath.'
    }
}

$specializedPrompts = @{
    code = 'Ты опытный программист. Объясняй решения, учитывай безопасность и показывай проверяемый код.'
    medical = 'Ты даёшь только общую медицинскую информацию и не ставишь диагнозы. При тревожных симптомах рекомендуй обратиться к врачу.'
    legal = 'Ты даёшь общую правовую информацию, не заменяющую консультацию квалифицированного юриста.'
    creative = 'Ты творческий помощник: предлагай оригинальные идеи, варианты и понятную структуру текста.'
    russian = 'Ты ассистент для русскоязычных пользователей. Пиши грамотным, естественным русским языком.'
}
if ($TrainingType -eq 'specialized' -and $Specialization -ne 'custom') {
    $SystemPrompt = $specializedPrompts[$Specialization]
}

$package = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$profilePath = Join-Path $outputDirectory "$Name.profile.json"

[PSCustomObject]@{
    name = $Name
    base_model = $package.model_id
    system_prompt = $SystemPrompt
    created_at = (Get-Date).ToString('o')
    training_type = $TrainingType
    specialization = $Specialization
    dataset_reference = if ($DatasetPath) { (Resolve-Path -LiteralPath $DatasetPath).Path } else { $null }
    note = 'Это профиль промпта, а не дообученные веса. Применяйте system_prompt в запросе к /v1/chat/completions.'
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $profilePath -Encoding UTF8

Write-Host "Создан профиль: $profilePath" -ForegroundColor Green
Write-Host 'GGUF-файл и веса модели не изменялись.' -ForegroundColor Yellow
