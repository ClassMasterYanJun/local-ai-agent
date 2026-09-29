<#
.SYNOPSIS
    Подготавливает автономный локальный чат на базе llama.cpp для Windows.

.DESCRIPTION
    Скрипт использует только файлы из папки проекта: портативный llama-server.exe,
    его DLL и локальный GGUF. Он не устанавливает Ollama, не меняет переменные
    среды пользователя и не выполняет сетевых загрузок.
#>
[CmdletBinding()]
param(
    [switch]$Console,
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$RuntimeDirectory = Join-Path $ProjectRoot 'runtime\llama.cpp'
$ServerPath = Join-Path $RuntimeDirectory 'llama-server.exe'
$PackageManifest = Join-Path $ProjectRoot 'models\package\model.json'
$ChatLauncher = Join-Path $ProjectRoot 'Start-Chat.ps1'
$ApiBaseUrl = 'http://127.0.0.1:8080'
$script:LogLines = [System.Collections.Generic.List[string]]::new()

function Write-InstallLog {
    param([string]$Message, [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info')

    $line = '[{0:HH:mm:ss}] [{1}] {2}' -f (Get-Date), $Level.ToUpperInvariant(), $Message
    $script:LogLines.Add($line)
    $colors = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    if ($Console) { Write-Host $line -ForegroundColor $colors[$Level] }
}

function Get-Package {
    if (-not (Test-Path -LiteralPath $PackageManifest -PathType Leaf)) {
        throw "Не найден манифест локальной модели: $PackageManifest"
    }

    $package = Get-Content -LiteralPath $PackageManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in 'model_id', 'gguf_file', 'sha256', 'required_disk_gb') {
        if ([string]::IsNullOrWhiteSpace([string]$package.$field)) {
            throw "В манифесте модели не заполнено поле '$field'."
        }
    }

    $modelPath = Join-Path (Split-Path -Parent $PackageManifest) $package.gguf_file
    if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
        throw "Не найден локальный файл модели: $modelPath"
    }

    $actualHash = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $package.sha256.ToLowerInvariant()) {
        throw "Контрольная сумма модели не совпадает. Ожидалось: $($package.sha256); получено: $actualHash"
    }

    return [PSCustomObject]@{
        Id = $package.model_id
        Name = if ($package.display_name) { $package.display_name } else { $package.model_id }
        GgufPath = $modelPath
        RequiredDiskGb = [double]$package.required_disk_gb
    }
}

function Test-PortableRuntime {
    if (-not (Test-Path -LiteralPath $ServerPath -PathType Leaf)) {
        throw "Не найден портативный сервер llama.cpp: $ServerPath"
    }

    $requiredFiles = @('llama-server-impl.dll', 'llama.dll', 'ggml.dll', 'ggml-base.dll', 'libomp.dll')
    $missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory $_) -PathType Leaf) })
    if ($missingFiles.Count -gt 0) {
        throw "Пакет llama.cpp неполный. Не найдены файлы: $($missingFiles -join ', ')"
    }
}

function Get-SystemCheck {
    $ramGb = [math]::Round(((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB), 1)
    $drive = Get-PSDrive -Name ($ProjectRoot.Substring(0, 1)) -ErrorAction Stop
    $gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object Name)
    return [PSCustomObject]@{
        RamGb = $ramGb
        FreeDiskGb = [math]::Round($drive.Free / 1GB, 1)
        Gpus = if ($gpuNames) { $gpuNames -join '; ' } else { 'Не определён' }
    }
}

function Test-LlamaApi {
    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/v1/models" -TimeoutSec 2
        return $null -ne $response.data
    } catch {
        return $false
    }
}

function Start-LlamaServer {
    param([Parameter(Mandatory)]$Package)

    if (Test-LlamaApi) {
        $models = Invoke-RestMethod -Uri "$ApiBaseUrl/v1/models" -TimeoutSec 2
        if (@($models.data | Where-Object { $_.id -eq $Package.Id }).Count -eq 0) {
            throw "Порт 8080 уже занят сервером с другой моделью. Освободите порт и повторите запуск."
        }
        Write-InstallLog 'Портативный сервер llama.cpp уже запущен.' 'Success'
        return
    }

    Write-InstallLog 'Запуск портативного сервера llama.cpp...'
    $arguments = @('--model', ('"{0}"' -f $Package.GgufPath), '--alias', $Package.Id, '--host', '127.0.0.1', '--port', '8080', '--ctx-size', '8192', '--offline', '--no-webui')
    Start-Process -FilePath $ServerPath -WorkingDirectory $RuntimeDirectory -ArgumentList $arguments -WindowStyle Hidden | Out-Null

    for ($attempt = 1; $attempt -le 90; $attempt++) {
        Start-Sleep -Seconds 1
        if (Test-LlamaApi) {
            Write-InstallLog 'Локальный API llama.cpp доступен на http://127.0.0.1:8080.' 'Success'
            return
        }
    }
    throw 'Сервер llama.cpp не ответил за 90 секунд. Проверьте, что порт 8080 свободен и в системе достаточно памяти.'
}

function Write-AppConfiguration {
    param([Parameter(Mandatory)]$Package)

    [PSCustomObject]@{
        model = $Package.Id
        display_name = $Package.Name
        api_url = $ApiBaseUrl
        api_type = 'openai-compatible'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ProjectRoot 'app-config.json') -Encoding UTF8
}

function Test-ModelResponse {
    param([Parameter(Mandatory)]$Package)

    Write-InstallLog "Проверка ответа модели '$($Package.Id)'..."
    $body = @{
        model = $Package.Id
        messages = @(@{ role = 'user'; content = 'Ответь одним словом: готово' })
        temperature = 0
        max_tokens = 16
        stream = $false
    } | ConvertTo-Json -Depth 4
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/v1/chat/completions" -Method Post -Body $body -ContentType 'application/json; charset=utf-8' -TimeoutSec 180
    $answer = [string]$response.choices[0].message.content
    if ([string]::IsNullOrWhiteSpace($answer)) {
        throw "Модель '$($Package.Id)' не вернула ответ."
    }
    Write-InstallLog "Модель отвечает: $($answer.Trim().Substring(0, [Math]::Min(60, $answer.Trim().Length)))" 'Success'
}

function Invoke-Installation {
    Test-PortableRuntime
    $package = Get-Package
    $system = Get-SystemCheck
    Write-InstallLog "ОЗУ: $($system.RamGb) ГБ; свободно: $($system.FreeDiskGb) ГБ; GPU: $($system.Gpus)"
    if ($system.FreeDiskGb -lt $package.RequiredDiskGb) {
        throw "Недостаточно свободного места. Для пакета требуется не менее $($package.RequiredDiskGb) ГБ."
    }
    if ($system.RamGb -lt 8) {
        Write-InstallLog 'Обнаружено менее 8 ГБ ОЗУ: модель может не запуститься или будет работать нестабильно.' 'Warning'
    }
    Write-InstallLog "Проверена модель '$($package.Name)' и её SHA-256." 'Success'
    Start-LlamaServer -Package $package
    Test-ModelResponse -Package $package
    Write-AppConfiguration -Package $package
    Write-InstallLog 'Подготовка завершена. Интернет, Ollama и переменные среды пользователя не использовались.' 'Success'
    if (-not $NoBrowser) { & $ChatLauncher }
}

function Start-Wizard {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = [System.Windows.Forms.Form]@{
        Text = 'Локальный ИИ - подготовка'
        Size = [System.Drawing.Size]::new(720, 490)
        StartPosition = 'CenterScreen'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox = $false
        Font = [System.Drawing.Font]::new('Segoe UI', 10)
    }
    $title = [System.Windows.Forms.Label]@{ Location = [System.Drawing.Point]::new(24, 20); Size = [System.Drawing.Size]::new(650, 36); Font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold); Text = 'Мастер подготовки локального ИИ' }
    $steps = [System.Windows.Forms.Label]@{ Location = [System.Drawing.Point]::new(26, 68); Size = [System.Drawing.Size]::new(650, 28); Text = '1. Проверка пакета   2. Проверка компьютера   3. Запуск модели   4. Открытие чата' }
    $description = [System.Windows.Forms.Label]@{ Location = [System.Drawing.Point]::new(26, 108); Size = [System.Drawing.Size]::new(650, 52); Text = 'Мастер использует только llama.cpp, DLL и модель из этой папки. Ollama не требуется и не устанавливается.' }
    $logBox = [System.Windows.Forms.TextBox]@{ Location = [System.Drawing.Point]::new(26, 172); Size = [System.Drawing.Size]::new(650, 210); Multiline = $true; ReadOnly = $true; ScrollBars = 'Vertical'; BackColor = [System.Drawing.Color]::White }
    $startButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(450, 397); Size = [System.Drawing.Size]::new(108, 34); Text = 'Запустить' }
    $closeButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(568, 397); Size = [System.Drawing.Size]::new(108, 34); Text = 'Закрыть' }
    $form.Controls.AddRange(@($title, $steps, $description, $logBox, $startButton, $closeButton))
    $closeButton.Add_Click({ $form.Close() })
    $startButton.Add_Click({
        $startButton.Enabled = $false
        $logBox.Clear()
        try {
            Invoke-Installation
            $logBox.Lines = $script:LogLines.ToArray()
            [System.Windows.Forms.MessageBox]::Show('Локальная модель готова. Чат открыт в браузере.', 'Подготовка завершена', 'OK', 'Information') | Out-Null
        } catch {
            Write-InstallLog $_.Exception.Message 'Error'
            $logBox.Lines = $script:LogLines.ToArray()
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Подготовка не выполнена', 'OK', 'Error') | Out-Null
        } finally {
            $startButton.Enabled = $true
        }
    })
    [void]$form.ShowDialog()
}

if ($Console) {
    try { Invoke-Installation } catch { Write-InstallLog $_.Exception.Message 'Error'; exit 1 }
} else {
    Start-Wizard
}
