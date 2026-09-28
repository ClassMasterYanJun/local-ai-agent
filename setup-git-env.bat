@echo off
echo === Настройка Git окружения ===
echo.

:: Проверяем, доступен ли уже Git
echo Проверка доступности Git...
where git >nul 2>nul
if %errorlevel% equ 0 (
    git --version
    echo [OK] Git уже доступен
    goto :end
)

:: Поиск Git в стандартных местах
echo Поиск Git в системе...

set FOUND_PATH=

:: Проверяем стандартные пути
if exist "C:\Program Files\Git\bin\git.exe" (
    set "FOUND_PATH=C:\Program Files\Git\bin"
    goto :found_git
)
if exist "C:\Program Files (x86)\Git\bin\git.exe" (
    set "FOUND_PATH=C:\Program Files (x86)\Git\bin"
    goto :found_git
)
if exist "%LOCALAPPDATA%\Programs\Git\bin\git.exe" (
    set "FOUND_PATH=%LOCALAPPDATA%\Programs\Git\bin"
    goto :found_git
)
if exist "%ProgramFiles%\Git\bin\git.exe" (
    set "FOUND_PATH=%ProgramFiles%\Git\bin"
    goto :found_git
)
if exist "C:\Git\bin\git.exe" (
    set "FOUND_PATH=C:\Git\bin"
    goto :found_git
)
if exist "%USERPROFILE%\AppData\Local\Programs\Git\bin\git.exe" (
    set "FOUND_PATH=%USERPROFILE%\AppData\Local\Programs\Git\bin"
    goto :found_git
)

:not_found
echo [ERROR] Git не найден в стандартных местах!
echo.
echo Установите Git: https://git-scm.com/download/win
echo Или укажите путь к Git вручную
echo.
echo Пример: set "GIT_PATH=C:\ваш\путь\к\git\bin"
echo set "PATH=%%GIT_PATH%%;%%PATH%%"
echo.
pause
exit /b 1

:found_git
echo [OK] Найден Git: %FOUND_PATH%\git.exe

:: Добавляем Git в PATH текущей сессии
echo Добавление пути к Git в переменную PATH...
set "PATH=%FOUND_PATH%;%PATH%"

:: Проверяем работу Git
echo Проверка работы Git...
git --version >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Git успешно добавлен в окружение
    git --version
) else (
    echo [ERROR] Git не работает корректно
    pause
    exit /b 1
)

:: Проверяем основные команды
echo.
echo Проверка основных команд Git...
where git >nul 2>nul && echo  [OK] git - доступен
git --help >nul 2>nul && echo  [OK] git --help - работает

:end
echo.
echo === Настройка завершена ===
echo.
echo Для постоянного добавления Git в PATH:
echo 1. Откройте "Система" в Панели управления
echo 2. "Дополнительные параметры системы"
echo 3. "Переменные среды"
echo 4. Добавьте "%FOUND_PATH%" в переменную PATH
echo.
echo Нажмите любую клавишу для продолжения...
pause >nul