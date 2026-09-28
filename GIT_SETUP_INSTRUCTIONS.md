# Инструкция по добавлению Git в окружение Windows

## Обнаружение проблемы
Текущая сессия VS Code не может корректно выполнять команды в терминале из-за проблем с переменными окружения.

## Решение

### Вариант 1: Запустить PowerShell скрипт вручную
1. Откройте новый PowerShell от имени администратора
2. Перейдите в папку проекта:
   ```powershell
   cd c:\AIModel
   ```
3. Выполните скрипт настройки:
   ```powershell
   .\setup-git-env.ps1
   ```

### Вариант 2: Запустить batch файл вручную
1. Откройте командную строку (cmd)
2. Перейдите в папку проекта:
   ```
   cd /d c:\AIModel
   ```
3. Выполните скрипт:
   ```
   setup-git-env.bat
   ```

### Вариант 3: Ручное добавление Git в PATH

1. **Найдите где установлен Git:**
   - Проверьте стандартные пути:
     - `C:\Program Files\Git\bin\`
     - `C:\Program Files (x86)\Git\bin\`
     - `%LOCALAPPDATA%\Programs\Git\bin\`
     - `%USERPROFILE%\AppData\Local\Programs\Git\bin\`

2. **Добавьте Git в PATH:**
   - Откройте "Панель управления" → "Система" → "Дополнительные параметры системы"
   - Нажмите "Переменные среды"
   - В разделе "Системные переменные" найдите переменную `Path`
   - Нажмите "Изменить" → "Создать"
   - Добавьте путь к папке с Git (например: `C:\Program Files\Git\bin`)
   - Нажмите OK во всех окнах

3. **Перезапустите VS Code**
   - Закройте и снова откройте VS Code
   - Проверьте доступность Git:
     ```bash
     git --version
     ```

### Вариант 4: Использовать установщик

Если Git не установлен вообще:
1. Скачайте установщик: https://git-scm.com/download/win
2. Запустите установщик
3. **Важные настройки при установке:**
   - Выберите "Use Git from the Windows Command Prompt" (добавит Git в PATH)
   - Выберите "Checkout Windows-style, commit Unix-style line endings"
   - Используйте MinTTY как терминал
   - Выберите опции по умолчанию для остальных настроек

### Проверка работы

После настройки проверьте:
1. В терминале VS Code выполните:
   ```bash
   git --version
   ```
2. Результат должен показать версию Git (например: `git version 2.43.0`)

### Если проблемы остаются

1. **Проверьте путь к Git:**
   ```bash
   where git
   ```

2. **Проверьте переменные окружения:**
   - В PowerShell: `$env:PATH`
   - В CMD: `echo %PATH%`

3. **Перезагрузите компьютер** для применения изменений PATH

## Альтернативные решения

### Использовать Git Bash
Если есть проблемы с терминалом VS Code:
1. Запустите Git Bash (из меню Пуск)
2. Перейдите в папку проекта:
   ```bash
   cd /c/AIModel
   ```
3. Используйте Git команды из Git Bash

### Настройка через VS Code
1. Откройте настройки VS Code (Ctrl+,)
2. Найдите "Terminal › Integrated › Env: Windows"
3. Добавьте настройку:
   ```json
   "terminal.integrated.env.windows": {
     "PATH": "C:\\Program Files\\Git\\bin;${env:PATH}"
   }
   ```

## Готовые скрипты

В папке проекта созданы файлы:
- `setup-git-env.ps1` - PowerShell скрипт для автоматической настройки
- `setup-git-env.bat` - Batch скрипт для ручной настройки
- `git-setup.ps1` - Скрипт для создания Git репозитория

## Дополнительные настройки

После установки Git рекомендуется настроить:
1. Имя пользователя и email:
   ```bash
   git config --global user.name "Ваше Имя"
   git config --global user.email "ваш.email@example.com"
   ```
2. Базовые настройки:
   ```bash
   git config --global init.defaultBranch main
   git config --global core.autocrlf true
   ```

---

*Примечание: После добавления Git в PATH перезапустите VS Code для применения изменений.*