<#
.SYNOPSIS
    Скрипт для экспорта модели и создания портативной копии

.DESCRIPTION
    - Экспортирует модель в tar архив
    - Создаёт конфигурацию для импорта
    - Сохраняет пользовательские промпты и настройки

.PARAMETER ModelName
    Имя модели для экспорта (по умолчанию: mistral-small)

.PARAMETER ExportPath
    Путь для сохранения экспорта (по умолчанию: .\export\)

.EXAMPLE
    .\export-model.ps1
    Экспорт модели mistral-small в папку export/

.EXAMPLE
    .\export-model.ps1 -ModelName "llama3.2:7b" -ExportPath "C:\backup"
    Экспорт другой модели в указанную папку
#>

param(
    [string]$ModelName = "mistral-small",
    [string]$ExportPath = "$PSScriptRoot\export"
)

$ErrorActionPreference = "Stop"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ============================================
# Проверка Ollama
# ============================================
function Test-OllamaRunning {
    try {
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        if ($null -eq $ollamaCmd) {
            Write-Err "Ollama не найден"
            Write-Info "Сначала установите: .\install.ps1"
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

# ============================================
# Проверка модели
# ============================================
function Test-ModelExists {
    param([string]$Model)
    
    try {
        Write-Info "Проверка модели $Model..."
        ollama list | Select-String -Pattern $Model | Out-Null
        Write-Success "Модель $Model найдена"
        return $true
    }
    catch {
        Write-Err "Модель $Model не найдена"
        Write-Info "Скачайте модель: ollama pull $Model"
        return $false
    }
}

# ============================================
# Создание папки экспорта
# ============================================
function Initialize-ExportFolder {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Info "Создание папки экспорта: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    
    Write-Success "Папка экспорта: $Path"
}

# ============================================
# Экспорт модели
# ============================================
function Export-Model {
    param(
        [string]$Model,
        [string]$ExportPath
    )
    
    $exportFile = "$ExportPath\$Model.tar"
    
    if (Test-Path $exportFile) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = "$ExportPath\$Model-backup-$timestamp.tar"
        Write-Warn "Файл $exportFile уже существует"
        Write-Info "Создание резервной копии: $backupFile"
        Move-Item $exportFile $backupFile -Force
    }
    
    Write-Info "Экспорт модели $Model в $exportFile..."
    
    try {
        ollama export $Model $exportFile
        Write-Success "Модель успешно экспортирована"
        
        # Проверка размера
        $fileSize = (Get-Item $exportFile).Length / 1GB
        Write-Info "Размер архива: {0:N2} ГБ" -f $fileSize
    }
    catch {
        Write-Err "Ошибка экспорта модели: $_"
        Write-Info "Проверьте, что модель существует: ollama list"
        throw
    }
}

# ============================================
# Создание конфигурации
# ============================================
function Create-ExportConfig {
    param(
        [string]$Model,
        [string]$ExportPath
    )
    
    $configFile = "$ExportPath\export-config.json"
    
    $config = @{
        model = $Model
        exportedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        system = @{
            os = [System.Environment]::OSVersion.VersionString
            architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
            ollamaVersion = $(ollama --version 2>$null | Select-String -Pattern "version")
        }
        files = @{
            modelArchive = "$Model.tar"
            configFile = "export-config.json"
            readme = "README-IMPORT.md"
        }
        instructions = @{
            import = "ollama import $Model.tar"
            verify = "ollama run $Model"
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
    Write-Success "Конфигурация экспорта сохранена"
}

# ============================================
# Создание инструкции импорта
# ============================================
function Create-ImportReadme {
    param([string]$ExportPath)
    
    $readmeFile = "$ExportPath\README-IMPORT.md"
    
    $readmeContent = @"
# Инструкция по импорту модели

## Требования
- Windows 10/11 с 8+ ГБ RAM
- Установленный Ollama (установить: .\install.ps1)

## Быстрый импорт

### 1. Копирование файлов
Скопируйте содержимое папки export на новый компьютер

### 2. Импорт модели
```powershell
# Перейдите в папку с экспортированной моделью
cd C:\path\to\export\folder

# Импорт модели
ollama import .\mistral-small.tar
```

### 3. Проверка импорта
```powershell
# Проверить список моделей
ollama list

# Запустить модель
ollama run mistral-small
```

## Полный сценарий

### Шаг 1: Установка Ollama
Если Ollama не установлен:
```powershell
# Скачайте проект с GitHub
git clone https://github.com/ваш-репозиторий/ai-agent-local.git

# Установите Ollama
cd ai-agent-local
.\install.ps1 -SkipModel
```

### Шаг 2: Импорт модели
```powershell
# Импорт
ollama import .\export\mistral-small.tar

# Альтернативно через скрипт
.\import-model.ps1 -ModelArchive .\export\mistral-small.tar
```

### Шаг 3: Настройка окружения
```powershell
# Копирование конфигурации
Copy-Item .\.env.example .\.env

# Редактирование настроек (опционально)
notepad .\.env
```

## Устранение проблем

### "Model not found"
```powershell
# Скачайте модель напрямую
ollama pull mistral-small
```

### Недостаточно памяти
```powershell
# Используйте меньшую модель
ollama import .\export\llama3.2-3b.tar
```

### Ошибка импорта
```powershell
# Проверьте целостность архива
Get-FileHash .\mistral-small.tar -Algorithm SHA256
```

## Контакты
- Исходный репозиторий: https://github.com/ваш-репозиторий/ai-agent-local
- Документация Ollama: https://ollama.com/docs
- Модели Mistral AI: https://mistral.ai

"@

    $readmeContent | Out-File -FilePath $readmeFile -Encoding UTF8
    Write-Success "Инструкция по импорту создана"
}

# ============================================
# Основной процесс
# ============================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AI Agent - Экспорт модели              " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Шаг 1: Проверка Ollama
if (-not (Test-OllamaRunning)) {
    Write-Err "Ollama не запущен. Прерываю выполнение."
    exit 1
}

# Шаг 2: Проверка модели
if (-not (Test-ModelExists -Model $ModelName)) {
    Write-Err "Модель не найдена"
    Write-Info "Скачайте модель: ollama pull $ModelName"
    Write-Info "Или выберите другую модель из списка: ollama list"
    exit 1
}

# Шаг 3: Создание папки экспорта
Initialize-ExportFolder -Path $ExportPath

# Шаг 4: Экспорт модели
Export-Model -Model $ModelName -ExportPath $ExportPath

# Шаг 5: Создание конфигурации
Create-ExportConfig -Model $ModelName -ExportPath $ExportPath

# Шаг 6: Инструкция импорта
Create-ImportReadme -ExportPath $ExportPath

# Итоги
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Экспорт завершён успешно!              " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Info "Что экспортировано:"
Write-Host "✓ Модель: $ModelName" -ForegroundColor Green
Write-Host "✓ Архив: $ExportPath\$ModelName.tar" -ForegroundColor Green
Write-Host "✓ Конфигурация: $ExportPath\export-config.json" -ForegroundColor Green
Write-Host "✓ Инструкция: $ExportPath\README-IMPORT.md" -ForegroundColor Green

Write-Host ""
Write-Info "Следующие шаги:"
Write-Host "1. Скопируйте папку $ExportPath на другой компьютер" -ForegroundColor Yellow
Write-Host "2. На новом компьютере используйте: ollama import путь\к\модели.tar" -ForegroundColor Yellow
Write-Host "3. Или используйте скрипт: .\import-model.ps1" -ForegroundColor Yellow

Write-Host ""
Write-Info "Команда для проверки размера:"
Write-Host "  Get-Item $ExportPath\$ModelName.tar | Select-Object Name, Length, LastWriteTime" -ForegroundColor Cyan

Write-Host ""
Write-Success "Теперь вы можете перенести модель на другой компьютер!"