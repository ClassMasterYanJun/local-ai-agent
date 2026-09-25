# Локальная ИИ-модель (Agentic AI) для Windows

Проект для развертывания локальной ИИ-модели с использованием Ollama на Windows.

## Требования системы

### Минимальные требования
- **ОС**: Windows 10/11 (64-bit)
- **RAM**: 8 ГБ (рекомендуется 16+ ГБ)
- **Место на диске**: 10-20 ГБ (зависит от модели)
- **GPU**: Опционально (NVIDIA с CUDA 11+ или AMD с ROCm)

### Программное обеспечение
- **PowerShell 7+** (для скриптов установки)
- **Ollama** (устанавливается автоматически или вручную)

## Быстрый старт

### 1. Установка на текущей машине

```powershell
# Запуск скрипта установки
.\install.ps1
```

Скрипт автоматически:
1. Проверит наличие Ollama
2. Установит Ollama при необходимости
3. Загрузит выбранную модель
4. Проверит работоспособность

### 2. Выбор модели

Доступные модели в `models/models.json`:

| Модель | Размер | RAM | Описание |
|--------|--------|-----|----------|
| llama3.2:3b | ~2 ГБ | 4-6 ГБ | Для слабых машин |
| llama3.2:7b | ~4.7 ГБ | 8-12 ГБ | Оптимальная (рекомендуется) |
| llama3.2:latest | ~4.7 ГБ | 8-12 ГБ | Последняя версия |

Установка конкретной модели:

```powershell
# Установка оптимальной модели (7B)
ollama pull llama3.2:7b

# Установка компактной модели (3B)
ollama pull llama3.2:3b
```

### 3. Использование

```powershell
# Запуск чата с моделью
ollama run llama3.2:7b

# API запрос через curl
curl http://localhost:11434/api/generate -d '{"model": "llama3.2:7b", "prompt": "Привет!"}'
```

## Перенос на другой компьютер

### Экспорт модели (на текущей машине)

```powershell
# Создание папки для экспорта
New-Item -ItemType Directory -Force -Path ".\export"

# Экспорт модели в tar-архив
ollama save llama3.2:7b -o .\export\llama3.2-7b.tar

# Копирование проекта
Copy-Item -Path ".\*" -Destination "D:\AIModel-Portable" -Recurse
```

### Импорт модели (на другом компьютере)

**Вариант 1: Автоматический (через install.ps1)**

```powershell
# Установка с импортом из архива
.\install.ps1 -ModelArchive ".\export\llama3.2-7b.tar"
```

**Вариант 2: Ручной**

```powershell
# Импорт модели из архива
ollama load .\export\llama3.2-7b.tar

# Проверка
ollama list
```

## Структура проекта

```
C:\AIModel\
├── README.md              # Эта инструкция
├── install.ps1            # Скрипт автоматической установки
├── models/
│   └── models.json        # Конфигурация моделей
├── .env.example           # Шаблон переменных окружения
└── export/                # Папка для экспортируемых моделей
```

## Настройка переменных окружения

1. Скопируйте `.env.example` в `.env`:

```powershell
Copy-Item .env.example .env
```

2. Отредактируйте `.env` под свои нужды:

```powershell
notepad .env
```

3. Загрузите переменные в сессию:

```powershell
Get-Content .env | ForEach-Object {
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
        [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "User")
    }
}
```

## API Endpoints

После запуска Ollama доступен по адресу `http://localhost:11434`:

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/api/tags` | GET | Список установленных моделей |
| `/api/pull` | POST | Загрузка модели |
| `/api/generate` | POST | Генерация текста |
| `/api/chat` | POST | Чат с моделью |
| `/api/embeddings` | POST | Получение эмбеддингов |

### Примеры API запросов

```powershell
# Список моделей
Invoke-RestMethod -Uri "http://localhost:11434/api/tags"

# Генерация текста
$body = @{
    model = "llama3.2:7b"
    prompt = "Напиши функцию сортировки на Python"
    stream = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

## Решение проблем

### Ollama не запускается

```powershell
# Проверка статуса службы
Get-Process ollama -ErrorAction SilentlyContinue

# Перезапуск Ollama
ollama serve
```

### Модель не загружается

```powershell
# Проверка свободного места
Get-PSDrive C

# Очистка старых моделей
ollama rm <model_name>
```

### Медленная работа

- Убедитесь, что используется GPU (проверьте наличие CUDA)
- Увеличьте размер файла подкачки
- Закройте ресурсоемкие приложения

## Полезные команды

```powershell
# Список установленных моделей
ollama list

# Информация о модели
ollama show llama3.2:7b

# Удаление модели
ollama rm llama3.2:7b

# Обновление модели
ollama pull llama3.2:7b

# Остановка Ollama
ollama stop
```

## Ресурсы

- [Ollama Documentation](https://github.com/ollama/ollama)
- [LLaMA 3.2 Model Card](https://huggingface.co/meta-llama/Llama-3.2)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
