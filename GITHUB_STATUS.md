# Статус проекта

## Локальный автономный пакет

Проект запускает `Qwen2.5 7B Instruct (Q4_K_M)` через портативный `llama.cpp` без Ollama.

- `Install-LocalAI.vbs` — графический запуск подготовки;
- `install.ps1 -Console` — консольный режим;
- `Start-Chat.ps1` — повторное открытие локального чата;
- `runtime\llama.cpp\llama-server.exe` — сервер модели;
- `models\package\local-assistant.gguf` — поставляемый файл модели.

Для релизной поставки включайте каталог `runtime\llama.cpp` и GGUF в архив, хотя они исключены из обычного Git-коммита.
