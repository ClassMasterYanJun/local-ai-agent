<#
.SYNOPSIS
    Скрипт для подготовки датасетов для внешнего обучения модели

.DESCRIPTION
    Подготавливает данные в формате JSONL для отдельного контура fine-tuning.
    Портативный runtime llama.cpp из этого проекта не читает датасет и не меняет
    веса GGUF-файла.

.PARAMETER InputType
    Тип входных данных:
    - "text" - Текстовые файлы
    - "csv" - CSV файлы
    - "json" - JSON файлы
    - "qa" - Вопрос-ответ формат
    - "code" - Исходный код

.PARAMETER InputPath
    Путь к входным данным или папке с данными

.PARAMETER OutputPath
    Путь для сохранения подготовленного датасета

.PARAMETER DatasetType
    Тип датасета для создания:
    - "instruction" - Инструкции и ответы
    - "conversation" - Диалоги
    - "completion" - Текст для завершения
    - "classification" - Классификация текста

.PARAMETER SampleCount
    Количество образцов для датасета (0 = все)

.EXAMPLE
    .\prepare-dataset.ps1 -InputType "text" -InputPath ".\data\docs\" -DatasetType "instruction"
    Создаёт датасет инструкций из текстовых файлов

.EXAMPLE
    .\prepare-dataset.ps1 -InputType "qa" -InputPath ".\data\questions.json" -DatasetType "conversation"
    Создаёт диалоговый датасет из вопросов и ответов

.EXAMPLE
    .\prepare-dataset.ps1 -InputType "code" -InputPath ".\src\" -DatasetType "completion"
    Создаёт датасет для завершения кода
#>

param(
    [ValidateSet("text", "csv", "json", "qa", "code")]
    [string]$InputType = "text",
    
    [string]$InputPath = "",
    [string]$OutputPath = "training\datasets\dataset.jsonl",
    
    [ValidateSet("instruction", "conversation", "completion", "classification")]
    [string]$DatasetType = "instruction",
    
    [int]$SampleCount = 0
)

$ErrorActionPreference = "Stop"

# Цвета для вывода
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ============================================
# Инициализация
# ============================================
function Initialize-DatasetPreparation {
    Write-Host "=== Подготовка датасета для обучения ===" -ForegroundColor Cyan
    
    # Создание папок
    $folders = @("training", "training\datasets", "training\datasets\samples", "training\datasets\processed")
    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Write-Info "Создана папка: $folder"
        }
    }
    
    # Проверка входного пути
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        # Создание примера датасета если путь не указан
        $InputPath = "training\datasets\samples"
        Write-Info "Создаю пример датасета в: $InputPath"
        Create-SampleDataset
    }
}

# ============================================
# Создание примера датасета
# ============================================
function Create-SampleDataset {
    $samplePath = "training\datasets\samples"
    
    # Примеры для разных типов данных
    $samples = @{
        instruction = @(
            @{
                instruction = "Напиши функцию сложения двух чисел на Python"
                input = ""
                output = "def add(a, b):\n    '''Сложение двух чисел'''\n    return a + b\n\n# Пример использования:\nresult = add(5, 3)\nprint(result)  # Вывод: 8"
            },
            @{
                instruction = "Объясни принцип работы HTTP протокола"
                input = ""
                output = "HTTP (HyperText Transfer Protocol) - это протокол прикладного уровня для передачи гипертекстовых документов. Основные особенности:\n\n1. Клиент-серверная архитектура\n2. Статусless (не сохраняет состояние)\n3. Поддерживает методы GET, POST, PUT, DELETE\n4. Использует порт 80 (HTTP) или 443 (HTTPS)\n\nПример запроса:\nGET /index.html HTTP/1.1\nHost: example.com"
            }
        )
        
        conversation = @(
            @{
                messages = @(
                    @{role = "user"; content = "Привет! Как дела?"},
                    @{role = "assistant"; content = "Привет! У меня всё отлично, я готов помочь вам с любыми вопросами. Чем могу помочь?"},
                    @{role = "user"; content = "Расскажи о преимуществах Python"},
                    @{role = "assistant"; content = "Python имеет множество преимуществ:\n1. Простой и читаемый синтаксис\n2. Большое сообщество и библиотеки\n3. Кроссплатформенность\n4. Подходит для веб-разработки, анализа данных, машинного обучения\n5. Динамическая типизация"}
                )
            }
        )
        
        code = @(
            @{
                prompt = "def calculate_area(radius):\n    '''Calculate circle area'''\n    "
                completion = "import math\n    area = math.pi * radius ** 2\n    return area"
            }
        )
    }
    
    # Сохранение примеров
    foreach ($type in $samples.Keys) {
        $filePath = "$samplePath\$type-samples.json"
        $samples[$type] | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
        Write-Info "Создан пример: $filePath"
    }
    
    # Создание README
    $readmeContent = @"
# Примеры датасетов для обучения

## Форматы данных

### 1. Инструкции (instruction)
\`\`\`json
{
  "instruction": "Напиши функцию сложения",
  "input": "",
  "output": "def add(a, b): return a + b"
}
\`\`\`

### 2. Диалоги (conversation)
\`\`\`json
{
  "messages": [
    {"role": "user", "content": "Вопрос"},
    {"role": "assistant", "content": "Ответ"}
  ]
}
\`\`\`

### 3. Завершение кода (code completion)
\`\`\`json
{
  "prompt": "def calculate_area(radius):",
  "completion": "import math; return math.pi * radius**2"
}
\`\`\`

## Использование
1. Измените примеры под свои задачи
2. Используйте скрипт: .\prepare-dataset.ps1
3. Обучите модель: .\train-model.ps1
"@
    
    $readmeContent | Out-File "$samplePath\README.md" -Encoding UTF8
    
    return $samplePath
}

# ============================================
# Обработка текстовых файлов
# ============================================
function Process-TextFiles {
    param([string]$Path, [string]$DatasetType)
    
    Write-Info "Обработка текстовых файлов из: $Path"
    
    $samples = @()
    $files = Get-ChildItem -Path $Path -Filter "*.txt" -Recurse -ErrorAction SilentlyContinue
    
    if ($files.Count -eq 0) {
        Write-Warn "Текстовые файлы не найдены"
        return $null
    }
    
    $counter = 0
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        
        # Разбиваем текст на части для обучения
        $paragraphs = $content -split "(\n\n|\r\n\r\n|\. )" | Where-Object { $_ -match '\w' }
        
        foreach ($para in $paragraphs) {
            if ($para.Length -gt 50 -and $para.Length -lt 2000) {
                $sample = @{}
                
                switch ($DatasetType) {
                    "instruction" {
                        # Создаём инструкцию из текста
                        $sample.instruction = "Объясни или перескажи следующий текст"
                        $sample.input = $para.Trim()
                        $sample.output = $para.Trim()
                    }
                    "completion" {
                        # Разбиваем текст на промпт и завершение
                        $mid = [math]::Floor($para.Length / 2)
                        $sample.prompt = $para.Substring(0, $mid)
                        $sample.completion = $para.Substring($mid)
                    }
                    default {
                        $sample.text = $para.Trim()
                    }
                }
                
                $samples += $sample
                $counter++
                
                if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
                    break
                }
            }
        }
        
        if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
            break
        }
    }
    
    Write-Success "Обработано $counter образцов"
    return $samples
}

# ============================================
# Обработка JSON файлов
# ============================================
function Process-JsonFiles {
    param([string]$Path, [string]$DatasetType)
    
    Write-Info "Обработка JSON файлов из: $Path"
    
    $samples = @()
    
    if (Test-Path $Path -PathType Leaf) {
        # Один файл
        $files = @(Get-Item $Path)
    } else {
        # Папка с файлами
        $files = Get-ChildItem -Path $Path -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    }
    
    if ($files.Count -eq 0) {
        Write-Warn "JSON файлы не найдены"
        return $null
    }
    
    $counter = 0
    foreach ($file in $files) {
        try {
            $jsonContent = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            # Обработка в зависимости от структуры
            if ($jsonContent -is [array]) {
                # Массив объектов
                foreach ($item in $jsonContent) {
                    $sample = ConvertTo-Sample -Data $item -DatasetType $DatasetType
                    if ($sample) {
                        $samples += $sample
                        $counter++
                    }
                    
                    if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
                        break
                    }
                }
            }
            elseif ($jsonContent -is [PSCustomObject]) {
                # Один объект
                $sample = ConvertTo-Sample -Data $jsonContent -DatasetType $DatasetType
                if ($sample) {
                    $samples += $sample
                    $counter++
                }
            }
            
            if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
                break
            }
        }
        catch {
            Write-Warn "Ошибка обработки файла $($file.Name): $_"
        }
    }
    
    Write-Success "Обработано $counter образцов"
    return $samples
}

# ============================================
# Конвертация данных в образец
# ============================================
function ConvertTo-Sample {
    param($Data, [string]$DatasetType)
    
    $sample = @{}
    
    # Проверяем структуру данных и конвертируем в нужный формат
    $props = $Data.PSObject.Properties.Name
    
    switch ($DatasetType) {
        "instruction" {
            if ("instruction" -in $props -and "output" -in $props) {
                $sample.instruction = $Data.instruction
                $sample.input = if ("input" -in $props) { $Data.input } else { "" }
                $sample.output = $Data.output
                return $sample
            }
        }
        "conversation" {
            if ("messages" -in $props -and $Data.messages.Count -ge 2) {
                $sample.messages = $Data.messages
                return $sample
            }
        }
        "completion" {
            if ("prompt" -in $props -and "completion" -in $props) {
                $sample.prompt = $Data.prompt
                $sample.completion = $Data.completion
                return $sample
            }
        }
        default {
            # Пытаемся определить автоматически
            if ("instruction" -in $props) {
                $sample.instruction = $Data.instruction
                $sample.input = if ("input" -in $props) { $Data.input } else { "" }
                $sample.output = if ("output" -in $props) { $Data.output } else { $Data | ConvertTo-Json -Compress }
                return $sample
            }
        }
    }
    
    return $null
}

# ============================================
# Обработка вопросов-ответов
# ============================================
function Process-QA {
    param([string]$Path)
    
    Write-Info "Обработка вопросов-ответов из: $Path"
    
    # Здесь можно добавить обработку различных форматов QA
    # Пока создадим пример
    
    $qaExamples = @(
        @{
            question = "Что такое искусственный интеллект?"
            answer = "Искусственный интеллект (ИИ) - это область компьютерных наук, занимающаяся созданием систем, способных выполнять задачи, требующие человеческого интеллекта."
        },
        @{
            question = "Как работает нейронная сеть?"
            answer = "Нейронная сеть состоит из нейронов, организованных в слои. Каждый нейрон принимает входные данные, применяет веса и функцию активации, передаёт результат следующему слою."
        }
    )
    
    $samples = @()
    foreach ($qa in $qaExamples) {
        $samples += @{
            instruction = "Ответь на вопрос"
            input = $qa.question
            output = $qa.answer
        }
    }
    
    Write-Success "Создано $($samples.Count) QA образцов"
    return $samples
}

# ============================================
# Обработка исходного кода
# ============================================
function Process-Code {
    param([string]$Path)
    
    Write-Info "Обработка исходного кода из: $Path"
    
    $samples = @()
    $files = Get-ChildItem -Path $Path -Include "*.py", "*.js", "*.ts", "*.java", "*.cpp", "*.cs" -Recurse -ErrorAction SilentlyContinue
    
    if ($files.Count -eq 0) {
        Write-Warn "Файлы с кодом не найдены"
        return $null
    }
    
    $counter = 0
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        
        # Разбиваем код на функции/методы
        $lines = $content -split "`n"
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*(def|function|class|public|private|protected)\s") {
                # Нашли начало функции/класса
                $start = $i
                $end = $start
                
                # Ищем конец (по отступам или скобкам)
                while ($end -lt $lines.Count -and $lines[$end] -notmatch "^\s*$") {
                    $end++
                }
                
                $codeBlock = $lines[$start..($end-1)] -join "`n"
                
                if ($codeBlock.Length -gt 50 -and $codeBlock.Length -lt 2000) {
                    # Создаём инструкцию для кода
                    $functionName = if ($lines[$start] -match "(def|function)\s+(\w+)") { $matches[2] } else { "code" }
                    
                    $samples += @{
                        instruction = "Объясни или проанализируй следующий код"
                        input = $codeBlock
                        output = "Это код на $($file.Extension.TrimStart('.')). $functionName выполняет определенную задачу. Код структурирован и следует хорошим практикам."
                    }
                    
                    $counter++
                }
                
                $i = $end
            }
            
            if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
                break
            }
        }
        
        if ($SampleCount -gt 0 -and $counter -ge $SampleCount) {
            break
        }
    }
    
    Write-Success "Обработано $counter код-образцов"
    return $samples
}

# ============================================
# Сохранение датасета в JSONL
# ============================================
function Save-Dataset {
    param([array]$Samples, [string]$OutputPath)
    
    if ($Samples.Count -eq 0) {
        Write-Err "Нет данных для сохранения"
        return $false
    }
    
    Write-Info "Сохранение датасета в: $OutputPath"
    
    # Создаём JSONL файл (каждая строка - отдельный JSON)
    $jsonlContent = @()
    foreach ($sample in $Samples) {
        $jsonlContent += ($sample | ConvertTo-Json -Compress)
    }
    
    $jsonlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    
    # Статистика
    $fileSize = (Get-Item $OutputPath).Length / 1KB
    Write-Success "Датасет сохранён"
    Write-Info "Образцов: $($Samples.Count)" -ForegroundColor Gray
    Write-Info "Размер: {0:N2} KB" -f $fileSize -ForegroundColor Gray
    Write-Info "Путь: $OutputPath" -ForegroundColor Gray
    
    # Создание README для датасета
    $datasetInfo = @{
        dataset_info = @{
            samples_count = $Samples.Count
            created_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            dataset_type = $DatasetType
            input_type = $InputType
            output_path = $OutputPath
        }
        sample_structure = $Samples[0]
    }
    
    $infoPath = $OutputPath -replace '\.jsonl$', '-info.json'
    $datasetInfo | ConvertTo-Json -Depth 5 | Out-File -FilePath $infoPath -Encoding UTF8
    
    Write-Info "Информация о датасете: $infoPath"
    
    return $true
}

# ============================================
# Основной процесс
# ============================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Dataset Preparation Tool               " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Инициализация
Initialize-DatasetPreparation

# Обработка данных в зависимости от типа
$samples = @()

switch ($InputType) {
    "text" {
        $samples = Process-TextFiles -Path $InputPath -DatasetType $DatasetType
    }
    "json" {
        $samples = Process-JsonFiles -Path $InputPath -DatasetType $DatasetType
    }
    "qa" {
        $samples = Process-QA -Path $InputPath
    }
    "code" {
        $samples = Process-Code -Path $InputPath
    }
    "csv" {
        Write-Warn "Обработка CSV пока не реализована"
        Write-Info "Используйте JSON или текстовый формат"
    }
}

if ($samples -and $samples.Count -gt 0) {
    # Сохранение датасета
    if (Save-Dataset -Samples $samples -OutputPath $OutputPath) {
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "  ДАТАСЕТ ПОДГОТОВЛЕН УСПЕШНО!          " -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        
        Write-Info "Что сделано:"
        Write-Host "✓ Образцов подготовлено: $($samples.Count)" -ForegroundColor Green
        Write-Host "✓ Формат: $DatasetType" -ForegroundColor Green
        Write-Host "✓ Сохранено: $OutputPath" -ForegroundColor Green
        
        Write-Host ""
        Write-Info "Чтобы сохранить профиль системной инструкции, используйте:"
        Write-Host "  .\train-model.ps1 -TrainingType dataset -DatasetPath '$OutputPath'" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Info "Следующие шаги:"
        Write-Host "1. Проверьте датасет: Get-Content '$OutputPath' -First 3" -ForegroundColor White
        Write-Host "2. При необходимости создайте профиль: .\train-model.ps1" -ForegroundColor White
        Write-Host "3. Для реального fine-tuning используйте отдельный внешний контур" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  ДАТАСЕТ НЕ ПОДГОТОВЛЕН                 " -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    
    Write-Info "Возможные причины:"
    Write-Host "1. Нет входных данных" -ForegroundColor White
    Write-Host "2. Неправильный формат данных" -ForegroundColor White
    Write-Host "3. Нет доступа к файлам" -ForegroundColor White
    
    Write-Host ""
    Write-Info "Попробуйте:"
    Write-Host "1. Создать пример датасета: .\prepare-dataset.ps1 -InputType text" -ForegroundColor Cyan
    Write-Host "2. Проверить входные данные" -ForegroundColor Cyan
    Write-Host "3. Изменить тип данных: -InputType json или -InputType code" -ForegroundColor Cyan
}
