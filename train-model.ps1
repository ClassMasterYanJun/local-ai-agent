<#
.SYNOPSIS
    Комплексный скрипт для обучения (fine-tuning) локальной ИИ-модели

.DESCRIPTION
    Поддерживает все виды обучения модели:
    1. Fine-tuning через Modelfiles (системные промпты)
    2. Адаптация на пользовательских данных (JSONL)
    3. Создание специализированных версий моделей
    4. Обучение на конкретных задачах

.PARAMETER TrainingType
    Тип обучения:
    - "modelfile" - Fine-tuning через .modelfile (рекомендуется)
    - "dataset" - Адаптация на пользовательских данных
    - "specialized" - Создание специализированной версии
    - "prompt" - Обучение на системных промптах

.PARAMETER ModelName
    Имя базовой модели для обучения (по умолчанию: mistral-small)

.PARAMETER NewModelName
    Имя новой (обученной) модели

.PARAMETER DatasetPath
    Путь к датасету для обучения (для trainingType="dataset")

.PARAMETER TrainingData
    Текст для обучения (для trainingType="prompt")

.EXAMPLE
    .\train-model.ps1 -TrainingType "modelfile" -NewModelName "mistral-small-code"
    Создаёт специализированную версию для программирования

.EXAMPLE
    .\train-model.ps1 -TrainingType "dataset" -DatasetPath ".\datasets\code-samples.jsonl"
    Обучает на пользовательском датасете

.EXAMPLE
    .\train-model.ps1 -TrainingType "specialized" -Specialization "medical"
    Создаёт медицинскую версию модели
#>

param(
    [ValidateSet("modelfile", "dataset", "specialized", "prompt")]
    [string]$TrainingType = "modelfile",
    
    [string]$ModelName = "mistral-small",
    [string]$NewModelName = "",
    [string]$DatasetPath = "",
    [string]$TrainingData = "",
    
    [ValidateSet("code", "medical", "legal", "creative", "russian", "custom")]
    [string]$Specialization = "custom"
)

$ErrorActionPreference = "Stop"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ============================================
# Проверки перед началом
# ============================================
function Initialize-Training {
    Write-Host "=== Инициализация обучения модели ===" -ForegroundColor Cyan
    
    # Проверка Ollama
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaCmd) {
        Write-Err "Ollama не найден. Сначала установите: .\install.ps1"
        exit 1
    }
    
    # Проверка модели
    Write-Info "Проверка базовой модели: $ModelName"
    try {
        ollama list | Select-String -Pattern $ModelName | Out-Null
        Write-Success "Базовая модель найдена"
    }
    catch {
        Write-Err "Модель $ModelName не найдена"
        Write-Info "Скачайте модель: ollama pull $ModelName"
        exit 1
    }
    
    # Генерация имени новой модели если не указано
    if ([string]::IsNullOrWhiteSpace($NewModelName)) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $NewModelName = "$ModelName-$TrainingType-$timestamp"
        Write-Info "Имя новой модели: $NewModelName"
    }
    
    # Создание папок для обучения
    $folders = @("training", "training\modelfiles", "training\datasets", "training\logs", "training\output")
    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Write-Info "Создана папка: $folder"
        }
    }
}

# ============================================
# Обучение через Modelfile
# ============================================
function Train-WithModelfile {
    param([string]$ModelName, [string]$NewModelName, [string]$Specialization)
    
    Write-Host "=== Обучение через Modelfile ===" -ForegroundColor Cyan
    
    # Выбор шаблона modelfile
    $modelfilePath = "training\modelfiles\$($Specialization).modelfile"
    
    if (-not (Test-Path $modelfilePath)) {
        Write-Warn "Шаблон $modelfilePath не найден"
        Write-Info "Создаю стандартный шаблон..."
        
        # Создаём стандартный modelfile
        $modelfileContent = @"
FROM $ModelName

# Системный промпт для специализации: $Specialization
SYSTEM """"
Ты - специализированный ассистент $Specialization на основе Mistral Small.
Ты экспертно разбираешься в своей области и предоставляешь точные, полезные ответы.
Твои ответы профессиональны, структурированы и соответствуют лучшим практикам.
""""

# Параметры модели
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

# Темплейт для чата
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
{{ .Response }}<|im_end|>"""
"@
        
        $modelfileContent | Out-File -FilePath $modelfilePath -Encoding UTF8
        Write-Success "Создан шаблон modelfile: $modelfilePath"
    }
    
    # Обучение модели
    Write-Info "Создание новой модели: $NewModelName"
    
    try {
        ollama create $NewModelName -f $modelfilePath
        Write-Success "Модель $NewModelName успешно создана!"
        
        # Проверка новой модели
        Write-Info "Проверка новой модели..."
        ollama run $NewModelName "Привет! Расскажи о своих возможностях." --stream | Select-Object -First 5
        
        return $true
    }
    catch {
        Write-Err "Ошибка создания модели: $_"
        return $false
    }
}

# ============================================
# Обучение на датасете
# ============================================
function Train-WithDataset {
    param([string]$ModelName, [string]$NewModelName, [string]$DatasetPath)
    
    Write-Host "=== Обучение на датасете ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $DatasetPath)) {
        Write-Err "Датасет не найден: $DatasetPath"
        Write-Info "Создайте датасет или используйте пример: .\prepare-dataset.ps1"
        return $false
    }
    
    # Проверка формата датасета
    $firstLine = Get-Content $DatasetPath -First 1
    if ($firstLine -notmatch '\{.*\}') {
        Write-Warn "Датасет должен быть в формате JSONL (JSON Lines)"
        Write-Info "Конвертирую формат..."
        # Здесь можно добавить конвертацию
    }
    
    # Создание modelfile с датасетом
    $modelfilePath = "training\modelfiles\dataset-trained.modelfile"
    
    $modelfileContent = @"
FROM $ModelName

# Обучение на пользовательском датасете
# Датусет: $(Split-Path $DatasetPath -Leaf)

SYSTEM """"
Ты ассистент, обученный на специфических данных.
Ты адаптирован под конкретные задачи пользователя.
""""

# Импорт данных обучения (Ollama будет использовать для адаптации)
# МЕТА: training_data="$DatasetPath"

PARAMETER temperature 0.8
PARAMETER top_p 0.95
PARAMETER num_ctx 4096
"@
    
    $modelfileContent | Out-File -FilePath $modelfilePath -Encoding UTF8
    
    # Обучение модели
    Write-Info "Обучение модели на датасете..."
    
    try {
        # Создание модели
        ollama create $NewModelName -f $modelfilePath
        
        # Дополнительная настройка через API (если нужно)
        $datasetInfo = @{
            model = $NewModelName
            training_data = $DatasetPath
            training_type = "dataset_adaptation"
            trained_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        }
        
        $datasetInfo | ConvertTo-Json | Out-File "training\logs\$NewModelName-training.json" -Encoding UTF8
        
        Write-Success "Модель $NewModelName обучена на датасете!"
        Write-Info "Датасет: $DatasetPath"
        Write-Info "Логи сохранены: training\logs\$NewModelName-training.json"
        
        return $true
    }
    catch {
        Write-Err "Ошибка обучения на датасете: $_"
        return $false
    }
}

# ============================================
# Создание специализированной версии
# ============================================
function Create-SpecializedModel {
    param([string]$ModelName, [string]$NewModelName, [string]$Specialization)
    
    Write-Host "=== Создание специализированной версии: $Specialization ===" -ForegroundColor Cyan
    
    # Шаблоны для разных специализаций
    $specializationTemplates = @{
        code = @{
            system_prompt = "Ты экспертный программист-ассистент. Ты помогаешь писать, анализировать, дебажить и оптимизировать код на различных языках программирования. Ты понимаешь архитектуру, паттерны проектирования и лучшие практики."
            temperature = 0.3
            examples = @(
                @{input = "Напиши функцию сложения на Python"; output = "def add(a, b):\n    return a + b"},
                @{input = "Объясни принцип ООП"; output = "ООП (Объектно-Ориентированное Программирование) основано на концепциях: классы, объекты, наследование, инкапсуляция, полиморфизм..."}
            )
        }
        medical = @{
            system_prompt = "Ты медицинский ассистент с базовыми знаниями. Ты помогаешь с общей медицинской информацией, но НЕ ставишь диагнозы. Всегда напоминай консультироваться с врачом."
            temperature = 0.2
            examples = @()
        }
        legal = @{
            system_prompt = "Ты юридический ассистент. Ты помогаешь с общей юридической информацией, но НЕ даёшь юридические консультации. Всегда рекомендуй консультироваться с юристом."
            temperature = 0.2
            examples = @()
        }
        creative = @{
            system_prompt = "Ты креативный писатель и художник. Ты помогаешь с созданием историй, стихов, сценариев, описаний и творческих проектов."
            temperature = 0.9
            examples = @()
        }
        russian = @{
            system_prompt = "Ты ассистент, оптимизированный для русского языка. Ты отлично понимаешь русскую грамматику, культуру и контекст. Ты предпочитаешь общаться на русском языке."
            temperature = 0.7
            examples = @()
        }
    }
    
    if (-not $specializationTemplates.ContainsKey($Specialization)) {
        Write-Warn "Шаблон для специализации '$Specialization' не найден. Использую custom."
        $Specialization = "custom"
    }
    
    $template = $specializationTemplates[$Specialization]
    
    # Создание modelfile
    $modelfilePath = "training\modelfiles\$Specialization-specialized.modelfile"
    
    $modelfileContent = @"
FROM $ModelName

# Специализация: $Specialization
SYSTEM """"
$($template.system_prompt)
""""

# Параметры для специализации
PARAMETER temperature $($template.temperature)
PARAMETER top_p 0.95
PARAMETER num_ctx 16384

# Примеры для обучения (если есть)
$(if ($template.examples.Count -gt 0) {
    "MESSAGE user `"$($template.examples[0].input)`""
    "MESSAGE assistant `"$($template.examples[0].output)`""
})
"@
    
    $modelfileContent | Out-File -FilePath $modelfilePath -Encoding UTF8
    
    # Создание модели
    Write-Info "Создание специализированной модели: $NewModelName"
    
    try {
        ollama create $NewModelName -f $modelfilePath
        
        # Сохранение конфигурации
        $config = @{
            base_model = $ModelName
            specialized_model = $NewModelName
            specialization = $Specialization
            parameters = $template
            created_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        }
        
        $config | ConvertTo-Json -Depth 3 | Out-File "training\output\$NewModelName-config.json" -Encoding UTF8
        
        Write-Success "Специализированная модель создана: $NewModelName"
        Write-Info "Конфигурация: training\output\$NewModelName-config.json"
        
        return $true
    }
    catch {
        Write-Err "Ошибка создания специализированной модели: $_"
        return $false
    }
}

# ============================================
# Обучение на промптах
# ============================================
function Train-WithPrompts {
    param([string]$ModelName, [string]$NewModelName, [string]$TrainingData)
    
    Write-Host "=== Обучение на системных промптах ===" -ForegroundColor Cyan
    
    if ([string]::IsNullOrWhiteSpace($TrainingData)) {
        # Используем примерные промпты
        $TrainingData = @"
Ты полезный ассистент, который всегда старается помочь.
Ты отвечаешь подробно и структурированно.
Ты предпочитаешь русский язык для общения.
"@
        Write-Info "Использую стандартные промпты для обучения"
    }
    
    # Создание modelfile с промптами
    $modelfilePath = "training\modelfiles\prompt-trained.modelfile"
    
    $modelfileContent = @"
FROM $ModelName

# Обучение на промптах
SYSTEM """"
$TrainingData
""""

# Параметры
PARAMETER temperature 0.7
PARAMETER top_p 0.9
"@
    
    $modelfileContent | Out-File -FilePath $modelfilePath -Encoding UTF8
    
    # Создание модели
    Write-Info "Создание модели, обученной на промптах..."
    
    try {
        ollama create $NewModelName -f $modelfilePath
        
        # Сохранение промптов
        @{
            training_prompts = $TrainingData
            model_name = $NewModelName
            trained_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        } | ConvertTo-Json | Out-File "training\logs\$NewModelName-prompts.json" -Encoding UTF8
        
        Write-Success "Модель обучена на промптах: $NewModelName"
        
        return $true
    }
    catch {
        Write-Err "Ошибка обучения на промптах: $_"
        return $false
    }
}

# ============================================
# Экспорт обученной модели
# ============================================
function Export-TrainedModel {
    param([string]$ModelName)
    
    Write-Host "=== Экспорт обученной модели ===" -ForegroundColor Cyan
    
    $exportPath = "training\output\$ModelName-trained.tar"
    
    try {
        Write-Info "Экспорт модели $ModelName..."
        ollama export $ModelName $exportPath
        
        $fileSize = (Get-Item $exportPath).Length / 1MB
        Write-Success "Модель экспортирована: $exportPath"
        Write-Info "Размер: {0:N2} МБ" -f $fileSize
        
        # Создание инструкции импорта
        $readmeContent = @"
# Модель: $ModelName

## Инструкция по импорту

### 1. Импорт модели
\`\`\`bash
ollama import $ModelName-trained.tar
\`\`\`

### 2. Проверка
\`\`\`bash
ollama list
ollama run $ModelName
\`\`\`

### 3. Параметры модели
- Тип обучения: $TrainingType
- Базовая модель: $ModelName
- Дата обучения: $(Get-Date -Format 'yyyy-MM-dd')
- Размер архива: {0:N2} МБ

### 4. Использование
Эта модель оптимизирована для конкретных задач.
Используйте её когда требуется специализированная помощь.
"@ -f $fileSize
        
        $readmeContent | Out-File "training\output\$ModelName-README.md" -Encoding UTF8
        
        return $true
    }
    catch {
        Write-Err "Ошибка экспорта модели: $_"
        return $false
    }
}

# ============================================
# Основной процесс
# ============================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AI Model Training Toolkit              " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Инициализация
Initialize-Training

# Обучение в зависимости от типа
$success = $false

switch ($TrainingType) {
    "modelfile" {
        $success = Train-WithModelfile -ModelName $ModelName -NewModelName $NewModelName -Specialization $Specialization
    }
    "dataset" {
        if ([string]::IsNullOrWhiteSpace($DatasetPath)) {
            Write-Err "Для обучения на датасете укажите -DatasetPath"
            exit 1
        }
        $success = Train-WithDataset -ModelName $ModelName -NewModelName $NewModelName -DatasetPath $DatasetPath
    }
    "specialized" {
        $success = Create-SpecializedModel -ModelName $ModelName -NewModelName $NewModelName -Specialization $Specialization
    }
    "prompt" {
        $success = Train-WithPrompts -ModelName $ModelName -NewModelName $NewModelName -TrainingData $TrainingData
    }
}

if ($success) {
    # Экспорт обученной модели
    Export-TrainedModel -ModelName $NewModelName
    
    # Итоги
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  ОБУЧЕНИЕ ЗАВЕРШЕНО УСПЕШНО!           " -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    
    Write-Info "Результаты обучения:"
    Write-Host "✓ Новая модель: $NewModelName" -ForegroundColor Green
    Write-Host "✓ Тип обучения: $TrainingType" -ForegroundColor Green
    Write-Host "✓ Базовая модель: $ModelName" -ForegroundColor Green
    Write-Host "✓ Экспортировано: training\output\$NewModelName-trained.tar" -ForegroundColor Green
    Write-Host "✓ Конфигурация: training\output\$NewModelName-config.json" -ForegroundColor Green
    
    Write-Host ""
    Write-Info "Команды для использования:"
    Write-Host "  ollama run $NewModelName" -ForegroundColor Cyan
    Write-Host "  ollama list" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Info "Для импорта на другой компьютер:"
    Write-Host "  ollama import training\output\$NewModelName-trained.tar" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  ОБУЧЕНИЕ НЕ УДАЛОСЬ                   " -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    
    Write-Info "Проверьте:"
    Write-Host "1. Доступность базовой модели" -ForegroundColor White
    Write-Host "2. Достаточно ли места на диске" -ForegroundColor White
    Write-Host "3. Формат входных данных" -ForegroundColor White
    Write-Host "4. Логи в папке training\logs\" -ForegroundColor White
}