# 🎓 Процесс обучения модели: полное руководство

## 📋 Содержание
1. [Введение](#-введение)
2. [Типы обучения](#-типы-обучения)
3. [Подготовка данных](#-подготовка-данных)
4. [Обучение модели](#-обучение-модели)
5. [Тестирование](#-тестирование)
6. [Экспорт и развёртывание](#-экспорт-и-развертывание)
7. [Примеры](#-примеры)
8. [Устранение проблем](#-устранение-проблем)

---

## 🎯 Введение

### Цель документа
Это руководство описывает полный процесс обучения (fine-tuning) модели **Mistral Small** с использованием инструментов проекта **ClassMasterYanJun/local-ai-agent**.

### Для кого это руководство
- 👨💻 Разработчики, которые хотят адаптировать модель под свои задачи
- 👨🏫 Исследователи, работающие с NLP и языковыми моделями
- 👨💼 Бизнес-пользователи, которым нужны специализированные ассистенты
- 👨🎓 Студенты и преподаватели, изучающие машинное обучение

### Требования
- Windows 10/11 с 8+ ГБ RAM
- Установленный Ollama (установка: `.\install.ps1`)
- Базовые знания PowerShell

---

## 📚 Типы обучения

### 1. 🚀 Modelfile Fine-tuning (быстрый)
**Когда использовать:** Когда нужно изменить стиль, тон или добавить базовую специализацию
**Время:** 2-5 минут
**Сложность:** 🟢 Низкая
**Пример:**
```powershell
.\train-model.ps1 -TrainingType modelfile -Specialization code -NewModelName "my-coder"
```

### 2. 📊 Dataset Training (глубокий)
**Когда использовать:** Когда есть свои данные для обучения
**Время:** Зависит от размера датасета (30+ минут)
**Сложность:** 🟡 Средняя
**Пример:**
```powershell
.\train-model.ps1 -TrainingType dataset -DatasetPath "my-data.jsonl" -NewModelName "my-assistant"
```

### 3. 🎯 Specialized Models (готовые шаблоны)
**Когда использовать:** Для стандартных специализаций
**Время:** 1-3 минуты
**Сложность:** 🟢 Низкая
**Пример:**
```powershell
.\train-model.ps1 -TrainingType specialized -Specialization medical -NewModelName "med-assistant"
```

### 4. 💬 Prompt Training (текстовые инструкции)
**Когда использовать:** Для задания поведения через промпты
**Время:** 1-2 минуты
**Сложность:** 🟢 Низкая
**Пример:**
```powershell
.\train-model.ps1 -TrainingType prompt -TrainingData "Ты вежливый помощник..." -NewModelName "polite-assistant"
```

---

## 📁 Подготовка данных

### Форматы данных

#### JSONL (рекомендуемый)
Каждая строка - отдельный JSON объект:
```json
{"instruction": "Задача", "input": "Контекст", "output": "Ответ"}
{"instruction": "Другая задача", "input": "", "output": "Другой ответ"}
```

#### Conversation формат
```json
{
  "messages": [
    {"role": "user", "content": "Вопрос"},
    {"role": "assistant", "content": "Ответ"},
    {"role": "user", "content": "Уточняющий вопрос"},
    {"role": "assistant", "content": "Уточнённый ответ"}
  ]
}
```

#### Code completion формат
```json
{"prompt": "def calculate_area(radius):", "completion": "    import math\n    return math.pi * radius ** 2"}
```

### Подготовка с помощью скрипта

#### Шаг 1: Подготовка текстовых данных
```powershell
.\prepare-dataset.ps1 -InputType text -InputPath ".\documents\" -DatasetType instruction
```
**Результат:** `training\datasets\dataset.jsonl`

#### Шаг 2: Подготовка JSON данных
```powershell
.\prepare-dataset.ps1 -InputType json -InputPath ".\data.json" -DatasetType conversation
```

#### Шаг 3: Подготовка кода
```powershell
.\prepare-dataset.ps1 -InputType code -InputPath ".\src\" -DatasetType completion
```

#### Шаг 4: Подготовка вопросов-ответов
```powershell
.\prepare-dataset.ps1 -InputType qa -InputPath ".\qa-data.json" -DatasetType instruction
```

### Лучшие практики подготовки данных

#### Качество данных
✅ **Хорошо:**
- Чёткие, ясные инструкции
- Полные, информативные ответы
- Соответствующий контекст
- Естественный язык

❌ **Плохо:**
- Неоднозначные формулировки
- Короткие или неполные ответы
- Несоответствующий контекст
- Искусственный или шаблонный язык

#### Объём данных
| Тип обучения | Минимум | Оптимум | Максимум |
|-------------|---------|---------|----------|
| Modelfile   | -       | 1 промпт | 10 промптов |
| Dataset     | 100 примеров | 1000 примеров | 10,000+ примеров |
| Specialized | 1 шаблон | 3-5 шаблонов | 10+ шаблонов |
| Prompt      | 50 слов | 200 слов | 1000+ слов |

#### Структура данных
```json
// Хорошая структура
{
  "instruction": "Напиши функцию сложения на Python",
  "input": "Функция должна принимать два числа",
  "output": "def add(a, b):\n    '''Сложение двух чисел'''\n    return a + b"
}

// Плохая структура
{
  "text": "как сложить числа? функция на python def add(a,b) return a+b"
}
```

---

## 🚀 Обучение модели

### Шаг 1: Выбор типа обучения

#### Вариант A: Быстрое обучение (Modelfile)
```powershell
# Программирование
.\train-model.ps1 -TrainingType modelfile -Specialization code -NewModelName "coder-pro"

# Русский язык
.\train-model.ps1 -TrainingType modelfile -Specialization russian -NewModelName "ru-assistant"

# Креативность
.\train-model.ps1 -TrainingType modelfile -Specialization creative -NewModelName "creative-pro"

# Аналитика
.\train-model.ps1 -TrainingType modelfile -Specialization analytical -NewModelName "analyst-pro"
```

#### Вариант B: Обучение на датасете
```powershell
.\train-model.ps1 -TrainingType dataset `
  -DatasetPath "training\datasets\dataset.jsonl" `
  -NewModelName "custom-assistant" `
  -SampleCount 1000
```

#### Вариант C: Создание специализированной версии
```powershell
.\train-model.ps1 -TrainingType specialized `
  -Specialization medical `
  -NewModelName "medic-assistant" `
  -ModelName "mistral-small"
```

#### Вариант D: Обучение через промпты
```powershell
$prompts = @"
Ты полезный ассистент, специализирующийся на технической поддержке.
Ты отвечаешь вежливо и профессионально.
Ты всегда предлагаешь несколько вариантов решения.
Ты используешь простой, понятный язык.
"@

.\train-model.ps1 -TrainingType prompt `
  -TrainingData $prompts `
  -NewModelName "support-assistant"
```

### Шаг 2: Мониторинг процесса обучения

#### Логи обучения
```powershell
# Просмотр логов
Get-Content training\logs\*.log -Tail 10

# Статус обучения
ollama list

# Проверка ресурсов
tasklist | findstr ollama
```

#### Индикаторы успеха
✅ **Хорошие признаки:**
- Модель успешно создана
- Нет ошибок в логах
- Размер модели соответствует ожиданиям
- Модель появляется в `ollama list`

⚠️ **Предупреждения:**
- Длительное время создания
- Предупреждения о памяти
- Частичное завершение

❌ **Проблемы:**
- Ошибки создания модели
- Недостаточно памяти
- Неверный формат данных

### Шаг 3: Параметры обучения

#### Основные параметры
```powershell
# Пример с параметрами
.\train-model.ps1 -TrainingType modelfile `
  -Specialization code `
  -NewModelName "my-model" `
  -ModelName "mistral-small" `
  -SampleCount 500
```

#### Параметры Modelfile
| Параметр | Значение по умолчанию | Описание | Диапазон |
|----------|-------------------|----------|----------|
| temperature | 0.7 | Креативность | 0.1-1.0 |
| top_p | 0.9 | Качество ответов | 0.5-1.0 |
| num_ctx | 8192 | Размер контекста | 1024-32768 |
| repeat_penalty | 1.1 | Штраф за повторения | 1.0-2.0 |

---

## 🧪 Тестирование

### Этап 1: Базовое тестирование

#### Проверка создания модели
```powershell
# Проверить список моделей
ollama list

# Должна появиться новая модель
# Пример вывода:
# NAME                SIZE      MODIFIED
# mistral-small       12.5 GB   2 hours ago
# my-coder            12.6 GB   5 minutes ago
```

#### Простой тест
```powershell
# Тест для программирования
ollama run my-coder "Напиши hello world на Python"

# Тест для русского языка
ollama run ru-assistant "Привет! Как дела?"

# Тест для креатива
ollama run creative-pro "Расскажи короткую историю"

# Тест для аналитики
ollama run analyst-pro "Проанализируй этот текст: [текст]"
```

### Этап 2: Глубокое тестирование

#### Тестовый набор вопросов
```powershell
# Создать тестовый файл
$testQuestions = @(
  "Напиши функцию сортировки пузырьком на Python",
  "Объясни принцип ООП простыми словами",
  "Как работает HTTP протокол?",
  "Напиши SQL запрос для выборки пользователей",
  "Объясни разницу между списком и кортежем в Python"
)

$testQuestions | Out-File "test-questions.txt"

# Запустить тестирование
$results = @()
foreach ($question in $testQuestions) {
    $result = ollama run my-coder $question
    $results += @{
        question = $question
        answer = $result
        timestamp = Get-Date
    }
}

$results | ConvertTo-Json | Out-File "test-results.json"
```

#### Оценка качества
| Критерий | Описание | Метод оценки |
|----------|----------|--------------|
| Релевантность | Соответствие ответа вопросу | Ручная проверка |
| Точность | Корректность информации | Сравнение с эталоном |
| Полнота | Исчерпывающий ли ответ | Анализ покрытия темы |
| Структура | Организация ответа | Оценка читаемости |
| Стиль | Соответствие желаемому стилю | Сравнение с образцом |

### Этап 3: Сравнение с базовой моделью

```powershell
# Тест базовой модели
$baseAnswer = ollama run mistral-small "Напиши функцию сложения на Python"

# Тест обученной модели
$trainedAnswer = ollama run my-coder "Напиши функцию сложения на Python"

# Сравнение
Write-Host "=== Сравнение результатов ===" -ForegroundColor Cyan
Write-Host "Базовая модель:" -ForegroundColor Yellow
Write-Host $baseAnswer -ForegroundColor Gray

Write-Host "`nОбученная модель:" -ForegroundColor Yellow
Write-Host $trainedAnswer -ForegroundColor Gray

# Анализ улучшений
Write-Host "`n=== Улучшения ===" -ForegroundColor Green
Write-Host "• Специализация: $($trainedAnswer.Contains('документация') ? '✅' : '❌')"
Write-Host "• Структура: $($trainedAnswer -match 'def.*return' ? '✅' : '❌')"
Write-Host "• Примеры: $($trainedAnswer.Contains('пример') ? '✅' : '❌')"
```

---

## 📦 Экспорт и развертывание

### Экспорт обученной модели

#### Шаг 1: Экспорт через скрипт
```powershell
.\export-model.ps1 -ModelName "my-coder" -ExportPath ".\models\"
```
**Результат:**
- `models\my-coder.tar` - Архив модели
- `models\my-coder-README.md` - Инструкция по импорту

#### Шаг 2: Ручной экспорт
```powershell
ollama export my-coder ".\export\my-coder.tar"

# Проверить размер
Get-Item ".\export\my-coder.tar" | Select-Object Name, Length, LastWriteTime
```

### Импорт на другом компьютере

#### Шаг 1: Копирование файлов
```powershell
# Скопировать архив модели
Copy-Item ".\export\my-coder.tar" "C:\путь\на\новом\компьютере\"
```

#### Шаг 2: Импорт модели
```powershell
# На новом компьютере
ollama import "C:\путь\на\новом\компьютере\my-coder.tar"

# Проверить
ollama list
```

#### Шаг 3: Использование
```powershell
# Запустить модель
ollama run my-coder "Помоги с программированием"

# Сделать модель доступной для API
ollama serve
```

### Развёртывание в команде

#### Вариант 1: Через GitHub
```powershell
# Добавить модель в репозиторий (если размер позволяет)
git add export\my-coder.tar
git commit -m "feat: add trained model my-coder"
git push origin main
```

#### Вариант 2: Через общий диск/облако
```powershell
# Создать пакет для развёртывания
$package = @{
    model = "my-coder.tar"
    readme = "README-IMPORT.md"
    install_script = "install-model.ps1"
    version = "1.0.0"
    trained_date = Get-Date -Format "yyyy-MM-dd"
}

$package | ConvertTo-Json | Out-File "deployment-package.json"

# Создать инсталляционный скрипт
$installScript = @"
# Установка обученной модели
Write-Host "Установка модели my-coder..." -ForegroundColor Cyan

# Проверка Ollama
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Error "Ollama не установлен. Сначала установите Ollama."
    exit 1
}

# Импорт модели
ollama import .\my-coder.tar

Write-Host "Модель успешно установлена!" -ForegroundColor Green
Write-Host "Использование: ollama run my-coder" -ForegroundColor Cyan
"@

$installScript | Out-File "install-model.ps1" -Encoding UTF8
```

#### Вариант 3: Через Docker (продвинутый)
```dockerfile
# Dockerfile для развёртывания
FROM ollama/ollama

# Копировать обученную модель
COPY my-coder.tar /root/.ollama/models/

# Импортировать модель
RUN ollama import /root/.ollama/models/my-coder.tar

# Экспозиция порта
EXPOSE 11434

# Запуск Ollama
CMD ["ollama", "serve"]
```

---

## 📝 Примеры

### Пример 1: Создание код-ассистента для команды разработки

#### Шаг 1: Подготовка данных
```powershell
# Собрать код из проектов команды
Get-ChildItem "C:\projects\team\" -Recurse -Include "*.py", "*.js", "*.ts" | 
    ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        # Преобразовать в формат инструкций
        @{
            instruction = "Объясни этот код: $($_.Name)"
            input = $content
            output = "Это код на $($_.Extension). Он выполняет..."
        }
    } | ConvertTo-Json | Out-File "team-code.jsonl"
```

#### Шаг 2: Обучение
```powershell
.\train-model.ps1 -TrainingType dataset `
  -DatasetPath "team-code.jsonl" `
  -NewModelName "team-coder" `
  -SampleCount 1000
```

#### Шаг 3: Тестирование
```powershell
# Тест на реальных задачах команды
ollama run team-coder "Как улучшить этот код? $(Get-Content 'problem-code.py')"
```

#### Шаг 4: Развёртывание
```powershell
# Экспортировать для всей команды
.\export-model.ps1 -ModelName "team-coder" -ExportPath "\\team-share\models\"

# Создать инструкцию
Write-Host "Для установки выполните:" -ForegroundColor Yellow
Write-Host "ollama import \\team-share\models\team-coder.tar" -ForegroundColor White
```

### Пример 2: Создание корпоративного ассистента

#### Шаг 1: Подготовка корпоративных данных
```powershell
# Собрать документацию, FAQ, руководства
$corporateData = @(
    @{
        instruction = "Как получить доступ к системе XYZ?"
        input = "Новый сотрудник"
        output = "Для доступа к системе XYZ нужно..."
    },
    @{
        instruction = "Куда обратиться с IT проблемой?"
        input = "Проблемы с компьютером"
        output = "Создайте тикет в системе ServiceNow..."
    }
    # Добавить больше данных...
)

$corporateData | ConvertTo-Json | Out-File "corporate-data.jsonl"
```

#### Шаг 2: Обучение корпоративному стилю
```powershell
.\train-model.ps1 -TrainingType modelfile `
  -Specialization analytical `
  -NewModelName "corp-assistant"

# Дополнительное обучение на данных
.\train-model.ps1 -TrainingType dataset `
  -DatasetPath "corporate-data.jsonl" `
  -NewModelName "corp-assistant-full"
```

#### Шаг 3: Интеграция
```powershell
# Создать API endpoint (пример на Python)
$pythonApi = @"
from flask import Flask, request, jsonify
import subprocess
import json

app = Flask(__name__)

@app.route('/api/ask', methods=['POST'])
def ask_assistant():
    question = request.json.get('question')
    
    # Вызов Ollama
    result = subprocess.run(
        ['ollama', 'run', 'corp-assistant-full', question],
        capture_output=True,
        text=True
    )
    
    return jsonify({'answer': result.stdout})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
"@

$pythonApi | Out-File "corp-api.py"
```

### Пример 3: Создание учебного ассистента

#### Шаг 1: Подготовка учебных материалов
```powershell
# Собрать лекции, учебники, тесты
$educationalData = @(
    @{
        instruction = "Объясни тему 'Методы сортировки'"
        input = "Студент первого курса"
        output = "Методы сортировки - это алгоритмы для упорядочивания элементов..."
    },
    @{
        instruction = "Помоги решить задачу по математике"
        input = "Найти производную функции f(x) = x^2 + 3x"
        output = "Для нахождения производной используем правила дифференцирования..."
    }
)

$educationalData | ConvertTo-Json | Out-File "educational-data.jsonl"
```

#### Шаг 2: Обучение
```powershell
.\train-model.ps1 -TrainingType dataset `
  -DatasetPath "educational-data.jsonl" `
  -NewModelName "edu-assistant" `
  -ModelName "mistral-small"
```

#### Шаг 3: Создание интерфейса
```powershell
# Простой веб-интерфейс (HTML + JavaScript)
$webInterface = @"
<!DOCTYPE html>
<html>
<head>
    <title>Образовательный ассистент</title>
    <style>
        body { font-family: Arial; padding: 20px; }
        .question { width: 100%; height: 100px; }
        .answer { background: #f0f0f0; padding: 15px; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>Образовательный ассистент</h1>
    <textarea class="question" placeholder="Задайте вопрос..."></textarea>
    <button onclick="askQuestion()">Спросить</button>
    <div class="answer" id="answer"></div>
    
    <script>
        async function askQuestion() {
            const question = document.querySelector('.question').value;
            const response = await fetch('/api/ask', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({question})
            });
            const data = await response.json();
            document.getElementById('answer').innerText = data.answer;
        }
    </script>
</body>
</html>
"@

$webInterface | Out-File "edu-assistant.html"
```

---

## 🐛 Устранение проблем

### Частые проблемы и решения

#### Проблема 1: Недостаточно памяти
**Симптомы:**
- Ошибки "Out of memory"
- Медленная работа системы
- Сбой обучения

**Решение:**
```powershell
# Использовать меньшую модель
.\train-model.ps1 -ModelName "llama3.2:3b"

# Уменьшить размер датасета
.\train-model.ps1 -SampleCount 100

# Освободить память
ollama ps
# Если есть запущенные модели, остановить ненужные
```

#### Проблема 2: Неверный формат данных
**Симптомы:**
- Ошибки парсинга JSON
- Модель не обучается
- Пустые результаты

**Решение:**
```powershell
# Проверить формат
Get-Content "dataset.jsonl" -First 3

# Исправить с помощью скрипта
.\prepare-dataset.ps1 -InputType json -InputPath "raw-data.json"
```

#### Проблема 3: Модель не создаётся
**Симптомы:**
- Ошибки в логах
- Модель не появляется в `ollama list`
- Процесс зависает

**Решение:**
```powershell
# Проверить логи
Get-Content "training\logs\*.log" -Tail 50

# Проверить Ollama
ollama --version
ollama ps

# Перезапустить Ollama
Stop-Process -Name ollama -Force
Start-Sleep -Seconds 5
# Ollama автоматически перезапустится при вызове
```

#### Проблема 4: Плохое качество результатов
**Симптомы:**
- Нерелевантные ответы
- Низкое качество текста
- Отсутствие специализации

**Решение:**
```powershell
# Улучшить качество данных
.\prepare-dataset.ps1 -InputType text -DatasetType instruction -SampleCount 1000

# Использовать другой тип обучения
.\train-model.ps1 -TrainingType modelfile -Specialization code

# Увеличить объём данных
# Собрать больше качественных примеров
```

### Мониторинг и диагностика

#### Команды для диагностики
```powershell
# Проверка состояния системы
systeminfo | Select-String "Total Physical Memory", "Available Physical Memory"

# Проверка процессов
Get-Process | Where-Object {$_.CPU -gt 10} | Select-Object Name, CPU, WorkingSet

# Проверка диска
Get-PSDrive C | Select-Object Used, Free

# Проверка сети
Test-Connection api.ollama.ai -Count 1
```

#### Логи для анализа
```powershell
# Логи Ollama
Get-Content "$env:USERPROFILE\.ollama\logs\ollama.log" -Tail 100

# Логи обучения
Get-ChildItem training\logs\*.log | ForEach-Object {
    Write-Host "=== $($_.Name) ===" -ForegroundColor Cyan
    Get-Content $_.FullName -Tail 20
}

# Логи системы
Get-EventLog -LogName Application -Newest 10 | Where-Object {
    $_.Source -match "Ollama|Application Error"
}
```

### Оптимизация производительности

#### Для слабых систем
```powershell
# Использовать меньшую модель
.\train-model.ps1 -ModelName "llama3.2:3b"

# Уменьшить параметры
# В modelfile:
# PARAMETER num_ctx 4096  # Вместо 8192
# PARAMETER temperature 0.5  # Вместо 0.7

# Использовать меньше примеров
.\prepare-dataset.ps1 -SampleCount 100
```

#### Для оптимальной работы
```powershell
# Оптимальные параметры для 16 ГБ RAM
.\train-model.ps1 -TrainingType modelfile `
  -Specialization code `
  -NewModelName "optimized-coder"

# Использовать GPU если есть
# Установить CUDA для NVIDIA GPU
# Ollama автоматически использует GPU если доступен
```

---

## 📈 Метрики успеха

### Количественные метрики
| Метрика | Целевое значение | Метод измерения |
|---------|------------------|-----------------|
| Время обучения | < 10 минут | Засечь время выполнения |
| Размер модели | < 15 ГБ | `ollama list` |
| Время ответа | < 5 секунд | Засечь время ответа |
| Точность | > 80% | Тестовый набор |
| Полнота | > 70% | Оценка покрытия |

### Качественные метрики
1. **Полезность:** Решает ли модель поставленные задачи?
2. **Качество:** Насколько хороши ответы?
3. **Специализация:** Видны ли улучшения по сравнению с базовой моделью?
4. **Стабильность:** Согласованы ли результаты?
5. **Удобство:** Легко ли использовать модель?

### Отслеживание прогресса
```powershell
# Создать журнал обучения
$trainingLog = @{
    training_id = [guid]::NewGuid()
    model_name = "my-coder"
    training_type = "modelfile"
    specialization = "code"
    start_time = Get-Date
    parameters = @{
        temperature = 0.7
        top_p = 0.9
        num_ctx = 8192
    }
    dataset_size = 1000
    expected_improvements = @(
        "Лучшее понимание кода",
        "Улучшенные примеры",
        "Структурированные ответы"
    )
}

$trainingLog | ConvertTo-Json -Depth 3 | Out-File "training-journal.json"

# После обучения добавить результаты
$trainingLog.end_time = Get-Date
$trainingLog.results = @{
    success = $true
    model_size = (ollama list | Where-Object {$_ -match "my-coder"} | ForEach-Object {($_ -split "\s+")[1]})
    test_results = $results  # Из тестирования
}

$trainingLog | ConvertTo-Json -Depth 3 | Out-File "training-journal-complete.json"
```

---

## 🔮 Дальнейшие шаги

### Улучшение модели
1. **Сбор обратной связи:** От пользователей модели
2. **Анализ ошибок:** Какие вопросы модель не может ответить?
3. **Дополнительное обучение:** На новых данных
4. **Создание семейства моделей:** Для разных задач

### Интеграция
1. **API:** Создание REST API для модели
2. **Интерфейсы:** Веб-интерфейс, чат-бот, плагины
3. **Автоматизация:** Интеграция в рабочие процессы
4. **Мониторинг:** Отслеживание использования и качества

### Масштабирование
1. **Обучение на больших данных:** При наличии ресурсов
2. **Создание специализированных версий:** Для разных отделов/задач
3. **Обмен моделями:** Создание репозитория обученных моделей
4. **Документация:** Создание руководств для пользователей

---

## 📞 Поддержка

### Ресурсы проекта
- **Репозиторий:** https://github.com/ClassMasterYanJun/local-ai-agent
- **Документация:** `README.md`, `MODEL_CAPABILITIES.md`, `TRAINING_PROCESS.md`
- **Примеры:** В папке `training\examples\`

### Дополнительные ресурсы
- [Ollama документация](https://ollama.com/docs)
- [Mistral AI](https://mistral.ai)
- [Fine-tuning руководства](https://github.com/ollama/ollama/blob/main/docs/modelfile.md)

### Сообщество
- Вопросы и обсуждения в Issues репозитория
- Обмен опытом и моделями
- Совместное улучшение инструментов

---

## 🎉 Заключение

Это руководство описывает полный процесс обучения модели **Mistral Small** с использованием инструментов проекта **ClassMasterYanJun**.

### Ключевые моменты:
1. **Простота:** Готовые скрипты и шаблоны
2. **Гибкость:** Множество вариантов обучения
3. **Практичность:** Реальные примеры и решения
4. **Масштабируемость:** От личного использования до корпоративного

### Начните с:
1. Простого обучения через Modelfile
2. Тестирования на ваших задачах
3. Постепенного улучшения по мере накопления данных

**Удачи в обучении ваших моделей! 🚀**