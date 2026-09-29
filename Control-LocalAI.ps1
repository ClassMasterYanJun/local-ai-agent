<#
.SYNOPSIS
    Управляет портативным сервером llama.cpp из папки проекта.

.DESCRIPTION
    По умолчанию открывает окно с кнопками запуска, остановки, проверки статуса
    и открытия чата. Режим Tray размещает значок управления в системном трее.
    Параметр -Action также предназначен для автоматизации.
#>
[CmdletBinding()]
param(
    [ValidateSet('Gui', 'Tray', 'Start', 'Stop', 'Status', 'Chat')]
    [string]$Action = 'Gui'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$RuntimeDirectory = Join-Path $ProjectRoot 'runtime\llama.cpp'
$LlamaServerPath = Join-Path $RuntimeDirectory 'llama-server.exe'
$ManifestPath = Join-Path $ProjectRoot 'models\package\model.json'
$ChatLauncher = Join-Path $ProjectRoot 'Start-Chat.ps1'
$ApiBaseUrl = 'http://127.0.0.1:8080'

function Get-Package {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Не найден манифест модели: $ManifestPath"
    }
    if (-not (Test-Path -LiteralPath $LlamaServerPath -PathType Leaf)) {
        throw "Не найден портативный llama-server.exe: $LlamaServerPath"
    }

    $package = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $modelPath = Join-Path (Split-Path -Parent $ManifestPath) $package.gguf_file
    if ([string]::IsNullOrWhiteSpace([string]$package.model_id) -or -not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
        throw "Не найден локальный GGUF-файл: $modelPath"
    }

    return [PSCustomObject]@{ Id = $package.model_id; Name = $package.display_name; GgufPath = $modelPath }
}

function Get-ApiModels {
    try {
        return @(Invoke-RestMethod -Uri "$ApiBaseUrl/v1/models" -TimeoutSec 2 | Select-Object -ExpandProperty data)
    } catch {
        return @()
    }
}

function Get-LocalServerProcesses {
    $serverFullPath = [System.IO.Path]::GetFullPath($LlamaServerPath)
    $modelFullPath = [System.IO.Path]::GetFullPath((Get-Package).GgufPath)
    return @(
        Get-CimInstance Win32_Process -Filter "Name = 'llama-server.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ExecutablePath -and $_.CommandLine -and
                [string]::Equals($_.ExecutablePath, $serverFullPath, [System.StringComparison]::OrdinalIgnoreCase) -and
                $_.CommandLine.IndexOf($modelFullPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
    )
}

function Get-ServerStatus {
    $package = Get-Package
    $models = @(Get-ApiModels)
    if (@($models | ForEach-Object id) -contains $package.Id) {
        return [PSCustomObject]@{ IsRunning = $true; Text = "ИИ запущен: $($package.Name)" }
    }
    if ($models.Count -gt 0) {
        return [PSCustomObject]@{ IsRunning = $false; Text = 'Порт 8080 занят другим локальным сервером.' }
    }
    return [PSCustomObject]@{ IsRunning = $false; Text = 'ИИ-сервер остановлен.' }
}

function Start-LocalAiServer {
    $package = Get-Package
    $status = Get-ServerStatus
    if ($status.IsRunning) { return $status.Text }
    if (@(Get-ApiModels).Count -gt 0) { throw 'Порт 8080 занят другим сервером. Освободите порт перед запуском.' }

    $arguments = @('--model', ('"{0}"' -f $package.GgufPath), '--alias', $package.Id, '--host', '127.0.0.1', '--port', '8080', '--ctx-size', '8192', '--offline', '--no-webui')
    Start-Process -FilePath $LlamaServerPath -WorkingDirectory $RuntimeDirectory -ArgumentList $arguments -WindowStyle Hidden | Out-Null

    for ($attempt = 1; $attempt -le 90; $attempt++) {
        Start-Sleep -Seconds 1
        if (@((Get-ApiModels) | ForEach-Object id) -contains $package.Id) {
            return "ИИ запущен: $($package.Name)"
        }
    }
    throw 'Сервер llama.cpp не ответил за 90 секунд. Проверьте свободную память и порт 8080.'
}

function Stop-LocalAiServer {
    $processes = @(Get-LocalServerProcesses)
    if ($processes.Count -eq 0) {
        if (@(Get-ApiModels).Count -gt 0) {
            throw 'На порту 8080 работает другой сервер. Скрипт не будет останавливать чужой процесс.'
        }
        return 'ИИ-сервер уже остановлен.'
    }

    $processes | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop }
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        Start-Sleep -Milliseconds 300
        if (@(Get-ApiModels).Count -eq 0) { return 'ИИ-сервер остановлен.' }
    }
    throw 'Не удалось подтвердить остановку ИИ-сервера.'
}

function Open-Chat {
    if (-not (Test-Path -LiteralPath $ChatLauncher -PathType Leaf)) {
        throw "Не найден сценарий запуска чата: $ChatLauncher"
    }
    & $ChatLauncher
    return 'Чат открыт в браузере.'
}

function Start-ControlWindow {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = [System.Windows.Forms.Form]@{
        Text = 'Локальный ИИ — управление'
        Size = [System.Drawing.Size]::new(510, 285)
        StartPosition = 'CenterScreen'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox = $false
        Font = [System.Drawing.Font]::new('Segoe UI', 10)
    }
    $title = [System.Windows.Forms.Label]@{ Location = [System.Drawing.Point]::new(24, 20); Size = [System.Drawing.Size]::new(450, 32); Font = [System.Drawing.Font]::new('Segoe UI', 16, [System.Drawing.FontStyle]::Bold); Text = 'Управление локальным ИИ' }
    $statusLabel = [System.Windows.Forms.Label]@{ Location = [System.Drawing.Point]::new(26, 68); Size = [System.Drawing.Size]::new(450, 44); BorderStyle = 'FixedSingle'; TextAlign = 'MiddleLeft'; Padding = [System.Windows.Forms.Padding]::new(12, 0, 0, 0) }
    $startButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(26, 132); Size = [System.Drawing.Size]::new(142, 38); Text = 'Запустить ИИ' }
    $stopButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(180, 132); Size = [System.Drawing.Size]::new(142, 38); Text = 'Остановить ИИ' }
    $chatButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(334, 132); Size = [System.Drawing.Size]::new(142, 38); Text = 'Открыть чат' }
    $refreshButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(26, 190); Size = [System.Drawing.Size]::new(142, 34); Text = 'Обновить статус' }
    $closeButton = [System.Windows.Forms.Button]@{ Location = [System.Drawing.Point]::new(334, 190); Size = [System.Drawing.Size]::new(142, 34); Text = 'Закрыть' }
    $form.Controls.AddRange(@($title, $statusLabel, $startButton, $stopButton, $chatButton, $refreshButton, $closeButton))

    $refreshStatus = {
        try {
            $status = Get-ServerStatus
            $statusLabel.Text = $status.Text
            $statusLabel.ForeColor = if ($status.IsRunning) { [System.Drawing.Color]::FromArgb(18, 122, 65) } else { [System.Drawing.Color]::FromArgb(150, 50, 35) }
        } catch {
            $statusLabel.Text = $_.Exception.Message
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 50, 35)
        }
    }
    $runAction = {
        param([scriptblock]$Operation)
        $startButton.Enabled = $false; $stopButton.Enabled = $false; $chatButton.Enabled = $false; $refreshButton.Enabled = $false
        try { [System.Windows.Forms.MessageBox]::Show((& $Operation), 'Локальный ИИ', 'OK', 'Information') | Out-Null }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Локальный ИИ', 'OK', 'Error') | Out-Null }
        finally { & $refreshStatus; $startButton.Enabled = $true; $stopButton.Enabled = $true; $chatButton.Enabled = $true; $refreshButton.Enabled = $true }
    }
    $startButton.Add_Click({ & $runAction { Start-LocalAiServer } })
    $stopButton.Add_Click({ & $runAction { Stop-LocalAiServer } })
    $chatButton.Add_Click({ & $runAction { Open-Chat } })
    $refreshButton.Add_Click($refreshStatus)
    $closeButton.Add_Click({ $form.Close() })
    & $refreshStatus
    [void]$form.ShowDialog()
}

function Start-TrayControl {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $applicationContext = [System.Windows.Forms.ApplicationContext]::new()
    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $statusItem = [System.Windows.Forms.ToolStripMenuItem]::new('Проверка состояния...')
    $statusItem.Enabled = $false
    $startItem = [System.Windows.Forms.ToolStripMenuItem]::new('Запустить ИИ')
    $stopItem = [System.Windows.Forms.ToolStripMenuItem]::new('Остановить ИИ')
    $chatItem = [System.Windows.Forms.ToolStripMenuItem]::new('Открыть чат')
    $controlItem = [System.Windows.Forms.ToolStripMenuItem]::new('Открыть панель управления')
    $exitItem = [System.Windows.Forms.ToolStripMenuItem]::new('Выйти из трея')
    [void]$menu.Items.AddRange(@($statusItem, [System.Windows.Forms.ToolStripSeparator]::new(), $startItem, $stopItem, $chatItem, [System.Windows.Forms.ToolStripSeparator]::new(), $controlItem, $exitItem))

    $notifyIcon = [System.Windows.Forms.NotifyIcon]::new()
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    $notifyIcon.ContextMenuStrip = $menu
    $notifyIcon.Text = 'Локальный ИИ — проверка состояния'
    $notifyIcon.Visible = $true

    $updateTrayStatus = {
        try {
            $status = Get-ServerStatus
            $statusItem.Text = $status.Text
            $startItem.Enabled = -not $status.IsRunning
            $stopItem.Enabled = $status.IsRunning
            $notifyIcon.Icon = if ($status.IsRunning) { [System.Drawing.SystemIcons]::Information } else { [System.Drawing.SystemIcons]::Application }
            $notifyIcon.Text = if ($status.IsRunning) { 'Локальный ИИ — запущен' } else { 'Локальный ИИ — остановлен' }
        } catch {
            $statusItem.Text = $_.Exception.Message
            $startItem.Enabled = $false
            $stopItem.Enabled = $false
            $notifyIcon.Icon = [System.Drawing.SystemIcons]::Error
            $notifyIcon.Text = 'Локальный ИИ — ошибка настройки'
        }
    }
    $runTrayOperation = {
        param([scriptblock]$Operation, [string]$Title)
        try {
            $result = & $Operation
            & $updateTrayStatus
            $notifyIcon.ShowBalloonTip(3000, 'Локальный ИИ', $result, [System.Windows.Forms.ToolTipIcon]::Info)
        } catch {
            & $updateTrayStatus
            $notifyIcon.ShowBalloonTip(5000, 'Локальный ИИ — ошибка', $_.Exception.Message, [System.Windows.Forms.ToolTipIcon]::Error)
        }
    }

    $startItem.Add_Click({ & $runTrayOperation { Start-LocalAiServer } 'Запуск' })
    $stopItem.Add_Click({ & $runTrayOperation { Stop-LocalAiServer } 'Остановка' })
    $chatItem.Add_Click({ & $runTrayOperation { Open-Chat } 'Открытие чата' })
    $controlItem.Add_Click({ Start-ControlWindow; & $updateTrayStatus })
    $notifyIcon.Add_MouseClick({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Start-ControlWindow
            & $updateTrayStatus
        }
    })
    $exitItem.Add_Click({
        $timer.Stop()
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $menu.Dispose()
        $applicationContext.ExitThread()
    })

    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = 5000
    $timer.Add_Tick($updateTrayStatus)
    & $updateTrayStatus
    $timer.Start()
    $notifyIcon.ShowBalloonTip(3000, 'Локальный ИИ', 'Значок управления добавлен в системный трей.', [System.Windows.Forms.ToolTipIcon]::Info)
    [System.Windows.Forms.Application]::Run($applicationContext)
}

switch ($Action) {
    'Start' { Write-Output (Start-LocalAiServer) }
    'Stop' { Write-Output (Stop-LocalAiServer) }
    'Status' { Write-Output (Get-ServerStatus).Text }
    'Chat' { Write-Output (Open-Chat) }
    'Gui' { Start-ControlWindow }
    'Tray' { Start-TrayControl }
}
