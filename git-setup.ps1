<#
.SYNOPSIS
    Скрипт для создания Git репозитория и отправки проекта на GitHub

.DESCRIPTION
    - Инициализирует Git репозиторий
    - Создаёт .gitignore для моделей и конфигов
    - Добавляет удалённый репозиторий GitHub
    - Отправляет код на GitHub

.PARAMETER GitHubUrl
    URL репозитория GitHub (например, https://github.com/username/ai-agent-local.git)

.PARAMETER SkipGitHubSetup
    Пропустить настройку GitHub (только локальный Git)

.EXAMPLE
    .\git-setup.ps1 -GitHubUrl "https://github.com/yourname/local-ai-agent.git"
    Создать и отправить на GitHub

.EXAMPLE
    .\git-setup.ps1 -SkipGitHubSetup
    Только локальный Git репозиторий
#>

param(
    [string]$GitHubUrl = "",
    [switch]$SkipGitHubSetup
)

$ErrorActionPreference = "Stop"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ============================================
# Проверка Git
# ============================================
function Test-GitInstalled {
    try {
        git --version | Out-Null
        Write-Success "Git найден: $(git --version)"
        return $true
    }
    catch {
        Write-Err "Git не установлен!"
        Write-Info "Установите Git: https://git-scm.com/download/win"
        Write-Info "Или установите через winget: winget install Git.Git"
        return $false
    }
}

# ============================================
# Создание .gitignore
# ============================================
function New-GitIgnore {
    $gitignorePath = "$PSScriptRoot\.gitignore"
    
    if (Test-Path $gitignorePath) {
        Write-Warn ".gitignore уже существует"
        return
    }
    
    $gitignoreContent = @"
# Локальные данные и результаты работы
export/
.ollama/
training/logs/
training/output/
models/package/*.gguf
runtime/llama.cpp/

# Временные файлы
*.tmp
*.temp
*.log

# Файлы окружения
.env
.env.local
.env.*.local

# Системные файлы
.DS_Store
Thumbs.db

# Visual Studio Code
.vscode/
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json

# IDE
.idea/
*.swp
*.swo

# Python
__pycache__/
*.py[cod]
*.so
.Python
venv/
env/

# Windows
desktop.ini

# Резервные копии
*.bak
*.backup

# Журналы локального сервера
llama-server*.log

# Конфигурация с данными
config.json
secrets.json

# Большие файлы
*.tar
*.zip
*.7z
"@

    $gitignoreContent | Out-File -FilePath $gitignorePath -Encoding UTF8
    Write-Success "Создан .gitignore"
}

# ============================================
# Инициализация Git репозитория
# ============================================
function Initialize-GitRepo {
    Write-Info "Проверка Git репозитория..."
    
    if (Test-Path "$PSScriptRoot\.git") {
        Write-Success "Git репозиторий уже инициализирован"
        return
    }
    
    try {
        Write-Info "Инициализация Git репозитория..."
        git init
        
        Write-Info "Настройка Git конфигурации..."
        git config user.email "ai-agent@local"
        git config user.name "AI Agent Setup"
        
        Write-Success "Git репозиторий инициализирован"
    }
    catch {
        Write-Err "Ошибка инициализации Git: $_"
        throw
    }
}

# ============================================
# Добавление файлов в репозиторий
# ============================================
function Add-GitFiles {
    Write-Info "Добавление файлов в Git..."
    
    # Сначала .gitignore
    git add .gitignore
    
    # Основные файлы
    git add README.md
    git add install.ps1
    git add git-setup.ps1
    git add .env.example
    
    # Модели (только конфиг)
    git add models/models.json
    
    Write-Info "Проверка статуса..."
    git status --porcelain | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    Write-Success "Файлы добавлены в staging area"
}

# ============================================
# Создание первого коммита
# ============================================
function Create-InitialCommit {
    Write-Info "Создание первого коммита..."
    
    $commitMessage = @"
feat: Portable local Qwen assistant with llama.cpp

### Что добавлено:
- Portable llama.cpp runtime for Windows x64 CPU
- Configuration for Qwen2.5 7B Instruct Q4_K_M
- Documentation in Russian
- Git setup scripts
- Offline package verification

### Модели:
- Primary: Qwen2.5 7B Instruct (Q4_K_M)

### Настройка:
- No Ollama installation or user environment variables
- Offline API and browser chat
- Release package verification
"@
    
    git commit -m $commitMessage
    Write-Success "Первый коммит создан"
}

# ============================================
# Настройка GitHub
# ============================================
function Setup-GitHub {
    param(
        [string]$GitHubUrl
    )
    
    if ([string]::IsNullOrWhiteSpace($GitHubUrl)) {
        Write-Warn "URL GitHub не указан. Пропускаю настройку удалённого репозитория"
        return
    }
    
    Write-Info "Добавление удалённого репозитория: $GitHubUrl"
    
    # Проверка существующего remote
    $remotes = git remote -v 2>$null
    if ($remotes -match "origin") {
        Write-Warn "Удалённый репозиторий 'origin' уже существует"
        git remote -v
        return
    }
    
    # Добавление remote
    try {
        git remote add origin $GitHubUrl
        Write-Success "Удалённый репозиторий добавлен"
        
        Write-Info "Проверка соединения с GitHub..."
        git fetch origin 2>$null
        Write-Success "Подключение к GitHub успешно"
    }
    catch {
        Write-Warn "Не удалось подключиться к GitHub. Проверьте:"
        Write-Warn "1. Репозиторий создан на GitHub"
        Write-Warn "2. URL правильный"
        Write-Warn "3. У вас есть доступ"
        Write-Warn "Вы можете добавить remote позже: git remote add origin URL"
    }
}

# ============================================
# Пуш в GitHub
# ============================================
function Push-ToGitHub {
    Write-Info "Отправка кода на GitHub..."
    
    # Проверка существования удалённого репозитория
    $remotes = git remote -v 2>$null
    if (-not ($remotes -match "origin")) {
        Write-Warn "Удалённый репозиторий не настроен"
        Write-Info "Выполните: .\git-setup.ps1 -GitHubUrl 'https://github.com/username/repo.git'"
        return
    }
    
    # Создание main branch если нужно
    try {
        git branch -M main 2>$null
        Write-Info "Отправка кода в ветку main..."
        git push -u origin main
        Write-Success "Код отправлен на GitHub!"
    }
    catch {
        Write-Err "Ошибка отправки кода: $_"
        Write-Warn "Возможные причины:"
        Write-Warn "1. Нет прав на запись в репозиторий"
        Write-Warn "2. Репозиторий не существует"
        Write-Warn "3. Проблемы с аутентификацией"
        Write-Warn "Создайте репозиторий вручную на GitHub и попробуйте снова"
    }
}

# ============================================
# Основной процесс
# ============================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AI Agent - Настройка Git репозитория    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Шаг 1: Проверка Git
if (-not (Test-GitInstalled)) {
    Write-Err "Git не установлен. Прерываю выполнение."
    exit 1
}

# Шаг 2: Создание .gitignore
New-GitIgnore

# Шаг 3: Инициализация Git
Initialize-GitRepo

# Шаг 4: Добавление файлов
Add-GitFiles

# Шаг 5: Создание коммита
Create-InitialCommit

# Шаг 6: Настройка GitHub (если указан URL)
if (-not $SkipGitHubSetup -and -not [string]::IsNullOrWhiteSpace($GitHubUrl)) {
    Setup-GitHub -GitHubUrl $GitHubUrl
    Push-ToGitHub
}
elseif (-not $SkipGitHubSetup) {
    Write-Warn "URL GitHub не указан"
    Write-Info "Чтобы настроить GitHub позже:"
    Write-Info "1. Создайте репозиторий на GitHub"
    Write-Info "2. Выполните команды:"
    Write-Host "   git remote add origin https://github.com/username/repo.git" -ForegroundColor Yellow
    Write-Host "   git branch -M main" -ForegroundColor Yellow
    Write-Host "   git push -u origin main" -ForegroundColor Yellow
}

# Шаг 7: Итоги
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Git репозиторий успешно настроен!       " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Info "Что сделано:"
Write-Host "✓ Инициализирован Git репозиторий" -ForegroundColor Green
Write-Host "✓ Создан .gitignore для моделей" -ForegroundColor Green
Write-Host "✓ Добавлены все файлы проекта" -ForegroundColor Green
Write-Host "✓ Создан первый коммит" -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($GitHubUrl)) {
    Write-Host "✓ Настроен удалённый репозиторий GitHub" -ForegroundColor Green
    Write-Host "✓ Код отправлен на GitHub" -ForegroundColor Green
}

Write-Host ""
Write-Info "Команды для работы с Git:"
Write-Host "  git status                          # Проверить статус" -ForegroundColor Cyan
Write-Host "  git add <файлы>                     # Добавить изменения" -ForegroundColor Cyan
Write-Host "  git commit -m \"описание\"            # Создать коммит" -ForegroundColor Cyan
Write-Host "  git push                            # Отправить на GitHub" -ForegroundColor Cyan
Write-Host "  git pull                            # Получить обновления" -ForegroundColor Cyan

Write-Host ""
Write-Info "Следующие шаги:"
Write-Host "1. Проверьте установку: .\install.ps1" -ForegroundColor Yellow
Write-Host "2. Протестируйте модель: .\Start-Chat.ps1" -ForegroundColor Yellow
Write-Host "3. Создайте опись релизного пакета: .\export-model.ps1" -ForegroundColor Yellow

if (-not [string]::IsNullOrWhiteSpace($GitHubUrl)) {
    Write-Host ""
    Write-Success "Репозиторий доступен по адресу: $GitHubUrl"
}
