<#
.SYNOPSIS
    Добавляет Git в текущее окружение PowerShell/VS Code

.DESCRIPTION
    - Ищет установленный Git в стандартных местах
    - Добавляет путь к Git в переменную PATH текущей сессии
    - Проверяет доступность Git команд
    - Сохраняет настройки для текущей сессии

.PARAMETER GitPath
    Путь к папке с Git (необязательно)

.EXAMPLE
    .\setup-git-env.ps1
    Автоматический поиск и добавление Git в окружение

.EXAMPLE
    .\setup-git-env.ps1 -GitPath "C:\Program Files\Git\bin"
    Указать конкретный путь к Git
#>

param(
    [string]$GitPath = ""
)

$ErrorActionPreference = "Stop"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Host "`n=== Настройка Git окружения ===" -ForegroundColor Magenta

# 1. Проверяем, доступен ли уже Git
Write-Info "Проверка доступности Git..."
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $gitVersion -like "*git version*") {
        Write-Success "Git уже доступен: $gitVersion"
        Write-Success "Путь к Git: $(Get-Command git | Select-Object -ExpandProperty Source)"
        return
    }
} catch {}

# 2. Поиск Git в системе
Write-Info "Поиск Git в системе..."

$possibleGitPaths = @(
    "C:\Program Files\Git\bin",
    "C:\Program Files (x86)\Git\bin",
    "$env:LOCALAPPDATA\Programs\Git\bin",
    "$env:ProgramFiles\Git\cmd",
    "$env:ProgramFiles\Git\bin",
    "C:\Git\bin",
    "$env:USERPROFILE\AppData\Local\Programs\Git\bin",
    "C:\msys64\usr\bin",
    "C:\msys64\mingw64\bin"
)

# Если указан путь, добавляем его первым
if ($GitPath -and (Test-Path $GitPath)) {
    $possibleGitPaths = @($GitPath) + $possibleGitPaths
}

$foundGitPath = $null

foreach ($path in $possibleGitPaths) {
    if (Test-Path $path) {
        $gitExe = Join-Path $path "git.exe"
        if (Test-Path $gitExe) {
            $foundGitPath = $path
            Write-Success "Найден Git: $gitExe"
            break
        }
    }
}

if (-not $foundGitPath) {
    Write-Err "Git не найден в стандартных местах!"
    Write-Info "Возможные причины:"
    Write-Info "1. Git не установлен"
    Write-Info "2. Git установлен в нестандартном месте"
    Write-Info "`nУстановите Git: https://git-scm.com/download/win"
    Write-Info "Или укажите путь к Git с параметром: -GitPath 'C:\ваш\путь\к\git\bin'"
    exit 1
}

# 3. Добавляем Git в PATH текущей сессии
Write-Info "Добавление пути к Git в переменную PATH текущей сессии..."

# Добавляем путь в начало PATH
$env:PATH = "$foundGitPath;$env:PATH"

# 4. Проверяем работу Git
Write-Info "Проверка работы Git..."
try {
    $gitVersion = git --version
    if ($gitVersion -like "*git version*") {
        Write-Success "Git успешно добавлен в окружение: $gitVersion"
        Write-Success "Путь: $foundGitPath"
    } else {
        Write-Err "Git не работает корректно"
        exit 1
    }
} catch {
    Write-Err "Ошибка при проверке Git: $_"
    exit 1
}

# 5. Дополнительные проверки
Write-Info "Проверка основных команд Git..."
$commands = @("git", "git --help", "git status")
foreach ($cmd in $commands) {
    try {
        Invoke-Expression "$cmd --help 2>&1 | Out-Null"
        Write-Success "  $cmd - работает"
    } catch {
        Write-Warn "  $cmd - ошибка"
    }
}

Write-Success "`n=== Настройка завершена успешно! ==="
Write-Info "Git теперь доступен в текущем сеансе VS Code"
Write-Info "Для постоянного добавления Git в PATH добавьте путь к системным переменным окружения"

# 6. Создаем .gitconfig если его нет
$gitConfigPath = "$env:USERPROFILE\.gitconfig"
if (-not (Test-Path $gitConfigPath)) {
    Write-Info "Создание базового .gitconfig..."
    @"
[user]
    name = Ваше Имя
    email = ваш.email@example.com
[core]
    autocrlf = true
    safecrlf = warn
[init]
    defaultBranch = main
"@ | Out-File -FilePath $gitConfigPath -Encoding UTF8
    Write-Success "Создан файл конфигурации: $gitConfigPath"
    Write-Warn "Не забудьте настроить имя и email в $gitConfigPath"
}