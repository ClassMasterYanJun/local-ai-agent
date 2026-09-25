<#
.SYNOPSIS
    Скрипт автоматической установки Ollama и ИИ-модели на Windows

.DESCRIPTION
    - Проверяет наличие Ollama
    - Устанавливает Ollama при необходимости (через winget или прямой download)
    - Загружает или импортирует модель
    - Проверяет работоспособность

.PARAMETER Model
    Имя модели для установки (по умолчанию: llama3.2:7b)

.PARAMETER ModelArchive
    Путь к tar-архиву модели для импорта (опционально)

.PARAMETER SkipOllamaCheck
    Пропустить проверку Ollama (если уже установлен)

.EXAMPLE
    .\install.ps1
    Установка с параметрами по умолчанию

.EXAMPLE
    .\install.ps1 -Model "llama3.2:3b"
    Установка компактной модели для слабых машин

.EXAMPLE
    .\install.ps1 -ModelArchive ".\export\llama3.2-7b.tar"
    Импорт модели из архива
#>

param(
    [string]$Model = "mistral-small",
    [string]$ModelArchive = "",
    [switch]$SkipOllamaCheck
)

# ============================================
# Конфигурация
# ============================================
$ErrorActionPreference = "Stop"
$OllamaUrl = "https://ollama.com/download"
$OllamaApiBase = "http://localhost:11434"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ============================================
# Проверка прав администратора
# ============================================
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================
# Проверка установки Ollama
# ============================================
function Test-OllamaInstalled {
    try {
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        if ($null -ne $ollamaCmd) {
            Write-Success "Ollama найден: $($ollamaCmd.Source)"
            return $true
        }
    }
    catch {
        # Игнорируем ошибку
    }

    # Проверка в стандартных путях
    $defaultPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (Test-Path $defaultPath) {
        Write-Success "Ollama найден: $defaultPath"
        $env:PATH = "$env:PATH;$env:LOCALAPPDATA\Programs\Ollama"
        return $true
    }

    return $false
}

# ============================================
# Установка Ollama
# ============================================
function Install-Ollama {
    Write-Info "Начинаю установку Ollama..."

    # Способ 1: Попытка через winget
    try {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($null -ne $wingetCmd) {
            Write-Info "Установка через winget..."
            winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements
            
            if ($?) {
                Write-Success "Ollama установлен через winget"
                
                # Обновляем PATH
                $env:PATH = "$env:PATH;$env:LOCALAPPDATA\Programs\Ollama"
                return $true
            }
        }
    }
    catch {
        Write-Warn "Не удалось установить через winget: $_"
    }

    # Способ 2: Прямая загрузка
    Write-Info "Загрузка Ollama с официального сайта..."
    
    $downloadUrl = "https://ollama.com/download/OllamaSetup.exe"
    $installerPath = "$env:TEMP\OllamaSetup.exe"

    try {
        # Загрузка установщика
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
        Write-Info "Установщик загружен: $installerPath"

        # Запуск установки
        Write-Info "Запуск установщика (требуется взаимодействие пользователя)..."
        Start-Process -FilePath $installerPath -Wait
        
        # Проверка успешности
        if (Test-OllamaInstalled) {
            Write-Success "Ollama успешно установлен"
            return $true
        }
        else {
            Write-Err "Ollama не найден после установки"
            return $false
        }
    }
    catch {
        Write-Err "Ошибка при загрузке/установке: $_"
        return $false
    }
    finally {
        # Удаление установщика
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
}

# ============================================
# Запуск Ollama сервера
# ============================================
function Start-OllamaServer {
    Write-Info "Проверка статуса Ollama..."

    try {
        # Проверка доступности API
        $response = Invoke-WebRequest -Uri "$OllamaApiBase/api/tags" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -eq 200) {
            Write-Success "Ollama сервер работает"
            return $true
        }
    }
    catch {
        # Сервер не отвечает, запускаем
        Write-Info "Запуск Ollama сервера..."
        
        try {
            Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
            
            # Ожидание запуска
            $maxAttempts = 30
            $attempt = 0
            
            while ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds 1
                $attempt++
                
                try {
                    $response = Invoke-WebRequest -Uri "$OllamaApiBase/api/tags" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
                    if ($response.StatusCode -eq 200) {
                        Write-Success "Ollama сервер запущен"
                        return $true
                    }
                }
                catch {
                    # Продолжаем ожидание
                }
                
                Write-Info "Ожидание запуска сервера... ($attempt/$maxAttempts)"
            }
            
            Write-Err "Не удалось запустить сервер за $maxAttempts секунд"
            return $false
        }
        catch {
            Write-Err "Ошибка запуска сервера: $_"
            return $false
        }
    }
    
    return $false
}

# ============================================
# Загрузка модели
# ============================================
function Install-Model {
    param([string]$ModelName)
    
    Write-Info "Загрузка модели $ModelName..."

    try {
        # Проверка, не установлена ли уже модель
        $models = ollama list 2>$null
        if ($models -match $ModelName.Split(':')[0]) {
            Write-Success "Модель $ModelName уже установлена"
            return $true
        }

        # Загрузка модели
        Write-Info "Загрузка модели (это может занять несколько минут)..."
        ollama pull $ModelName

        if ($?) {
            Write-Success "Модель $ModelName успешно загружена"
            return $true
        }
        else {
            Write-Err "Не удалось загрузить модель $ModelName"
            return $false
        }
    }
    catch {
        Write-Err "Ошибка при загрузке модели: $_"
        return $false
    }
}

# ============================================
# Импорт модели из архива
# ============================================
function Import-ModelFromArchive {
    param([string]$ArchivePath)

    Write-Info "Импорт модели из архива: $ArchivePath"

    if (-not (Test-Path $ArchivePath)) {
        Write-Err "Архив не найден: $ArchivePath"
        return $false
    }

    try {
        ollama load $ArchivePath

        if ($?) {
            Write-Success "Модель успешно импортирована"
            return $true
        }
        else {
            Write-Err "Не удалось импортировать модель"
            return $false
        }
    }
    catch {
        Write-Err "Ошибка при импорте модели: $_"
        return $false
    }
}

# ============================================
# Проверка работоспособности
# ============================================
function Test-ModelWorking {
    param([string]$ModelName)

    Write-Info "Проверка работоспособности модели..."

    try {
        $body = @{
            model = $ModelName
            prompt = "Say 'Hello, World!' in Russian"
            stream = $false
        } | ConvertTo-Json -Depth 2

        $response = Invoke-RestMethod `
            -Uri "$OllamaApiBase/api/generate" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec 60

        if ($response.response) {
            Write-Success "Модель отвечает на запросы"
            Write-Info "Ответ модели: $($response.response.Substring(0, [Math]::Min(100, $response.response.Length)))..."
            return $true
        }
        else {
            Write-Warn "Модель не вернула ответ"
            return $false
        }
    }
    catch {
        Write-Err "Ошибка при проверке модели: $_"
        return $false
    }
}

# ============================================
# Отображение информации о системе
# ============================================
function Show-SystemInfo {
    Write-Info "Информация о системе:"
    
    # RAM
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    Write-Host "  RAM: $([Math]::Round($ram, 1)) ГБ"
    
    # GPU
    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA|AMD|Intel" }
        if ($gpu) {
            Write-Host "  GPU: $($gpu.Name)"
        }
        else {
            Write-Host "  GPU: Не обнаружено (будет использоваться CPU)"
        }
    }
    catch {
        Write-Host "  GPU: Не удалось определить"
    }
    
    # Место на диске
    $drive = Get-PSDrive C
    $freeSpace = $drive.Free / 1GB
    Write-Host "  Свободно на диске C: $([Math]::Round($freeSpace, 1)) ГБ"
    
    Write-Host ""
}

# ============================================
# Главная функция
# ============================================
function Main {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Magenta
    Write-Host "  Установка локальной ИИ-модели" -ForegroundColor Magenta
    Write-Host "======================================" -ForegroundColor Magenta
    Write-Host ""

    # Информация о системе
    Show-SystemInfo

    # 1. Проверка/установка Ollama
    if (-not $SkipOllamaCheck) {
        if (-not (Test-OllamaInstalled)) {
            Write-Warn "Ollama не установлен"
            
            if (-not (Install-Ollama)) {
                Write-Err "Не удалось установить Ollama. Установите вручную с $OllamaUrl"
                exit 1
            }
        }
    }

    # 2. Запуск сервера
    if (-not (Start-OllamaServer)) {
        Write-Err "Не удалось запустить Ollama сервер"
        exit 1
    }

    # 3. Установка/импорт модели
    if ($ModelArchive -ne "") {
        # Импорт из архива
        if (-not (Import-ModelFromArchive -ArchivePath $ModelArchive)) {
            Write-Err "Не удалось импортировать модель из архива"
            
            # Попытка загрузить из интернета
            Write-Info "Попытка загрузить модель из интернета..."
            if (-not (Install-Model -ModelName $Model)) {
                exit 1
            }
        }
    }
    else {
        # Загрузка из интернета
        if (-not (Install-Model -ModelName $Model)) {
            exit 1
        }
    }

    # 4. Проверка работоспособности
    if (-not (Test-ModelWorking -ModelName $Model)) {
        Write-Warn "Модель установлена, но проверка не прошла"
    }

    # Итог
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "  Установка завершена!" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "Для запуска чата выполните: ollama run $Model"
    Write-Info "API доступен по адресу: $OllamaApiBase"
    Write-Host ""

    # Список установленных моделей
    Write-Info "Установленные модели:"
    ollama list
    Write-Host ""
}

# Запуск
try {
    Main
}
catch {
    Write-Err "Критическая ошибка: $_"
    Write-Host $_.ScriptStackTrace
    exit 1
}
