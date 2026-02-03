@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Fusion 360 - установка RU (pretty)

REM =========================
REM Настройки "красоты"
REM =========================
set "BAR_LEN=34"
set "ANIM_MS=1"
set "STEP_MS=1"

REM Всегда работать из папки батника
pushd "%~dp0" >nul

goto :MAIN

REM ==========================================================
REM Подпрограммы (НЕ УДАЛЯТЬ)
REM ==========================================================
:render
set "P=%~1"
set "TXT=%~2"
if "%P%"=="" set "P=0"

set /a FILL=P*BAR_LEN/100
set "BAR="

for /l %%i in (1,1,%BAR_LEN%) do (
  if %%i LEQ !FILL! (set "BAR=!BAR!#") else (set "BAR=!BAR!-")
)

cls
echo.
echo  +------------------------------------------------------+
echo  ^|  FUSION 360 - УСТАНОВЩИК РУССКОЙ ЛОКАЛИЗАЦИИ         ^|
echo  ^|  Версия: Pretty Progress Bar   ^|       ^|
echo  +------------------------------------------------------+
echo.
echo      [!BAR!]  !P!%%
echo      !TXT!
echo.
goto :EOF

:animate
set /a FROM=%~1
set /a TO=%~2
set "TXT=%~3"
if %TO% LSS %FROM% goto :EOF

for /l %%p in (%FROM%,1,%TO%) do (
  call :render %%p "%TXT%"
  call :sleep %ANIM_MS%
)
goto :EOF

:sleep
set "MS=%~1"
if "%MS%"=="" set "MS=10"
powershell -NoProfile -Command "Start-Sleep -Milliseconds %MS%" >nul 2>&1
if %errorlevel%==0 goto :EOF
REM запасной вариант (примерно 1 сек)
ping -n 1 127.0.0.1 >nul
goto :EOF

:chk_rc
set "MSG=%~1"
set "RC=%ERRORLEVEL%"
REM Robocopy: 0-7 = успех, 8+ = ошибка
if %RC% GEQ 8 call :fail "Ошибка Robocopy (%RC%): %MSG%"
goto :EOF

:fail
call :render 100 "ОШИБКА"
echo [X] %~1
echo.
pause
popd >nul
exit /b 1

REM ==========================================================
REM Основная логика
REM ==========================================================
:MAIN
call :render 0 "Запуск..."
call :sleep %STEP_MS%

REM ==== Исходники рядом с батником ====
set "SRC=%CD%"
set "SRC_RU_RU=%SRC%\ru-RU"
set "SRC_RU_HTML=%SRC%\ru-html"
set "SRC_RU_XML=%SRC%\russian_ru.xml"

if not exist "%SRC_RU_RU%\"  call :fail "Не найдена папка ru-RU рядом с .bat"
if not exist "%SRC_RU_HTML%\" call :fail "Не найдена папка ru-html рядом с .bat"
if not exist "%SRC_RU_XML%"   call :fail "Не найден файл russian_ru.xml рядом с .bat"

REM ==== Fusion должен быть закрыт ====
for %%P in (Fusion360.exe FusionLauncher.exe AutodeskFusion.exe) do (
  tasklist /FI "IMAGENAME eq %%P" 2>nul | find /I "%%P" >nul
  if !errorlevel! == 0 call :fail "Fusion 360 запущен (%%P). Закрой Fusion и запусти снова."
)

call :animate 0 15 "Проверяю файлы..."
call :sleep %STEP_MS%

call :animate 15 30 "Ищу папку установки Fusion 360..."
set "PROD=%LOCALAPPDATA%\Autodesk\webdeploy\production"
if not exist "%PROD%\" call :fail "Не найдена папка: %PROD%"

set "TARGET="

REM Берём самую свежую папку, где есть все нужные каталоги
for /f "delims=" %%D in ('dir /b /ad /o-d "%PROD%"') do (
  if exist "%PROD%\%%D\StringTable\" ^
  if exist "%PROD%\%%D\NeuCAM\UI\NeuCAMUI\Resources\Help\" ^
  if exist "%PROD%\%%D\Applications\CAM360\Data\Translations\" (
    set "TARGET=%PROD%\%%D"
    goto :FOUND
  )
)

:ASK
echo.
echo [!] Автопоиск не нашёл нужную папку.
echo     Вставь путь вида:
echo     C:\Users\ИМЯ\AppData\Local\Autodesk\webdeploy\production\XXXXXXXXXXXXXXXX
echo.
set /p "TARGET=Путь: "
echo.

:FOUND
REM Жёсткая проверка пути, чтобы ничего не создалось по ошибке
if "%TARGET%"=="" goto :BADTARGET
if not exist "%TARGET%\StringTable\" goto :BADTARGET
if not exist "%TARGET%\NeuCAM\UI\NeuCAMUI\Resources\Help\" goto :BADTARGET
if not exist "%TARGET%\Applications\CAM360\Data\Translations\" goto :BADTARGET

call :animate 30 40 "Папка найдена"
call :sleep %STEP_MS%

REM ==== Установка 1: ru-RU ====
call :animate 40 55 "Копирую ru-RU -> StringTable"
robocopy "%SRC_RU_RU%" "%TARGET%\StringTable\ru-RU" /E /R:1 /W:1 >nul
call :chk_rc "ru-RU -> StringTable"
call :sleep %STEP_MS%

REM ==== Установка 2: ru-html ====
call :animate 55 80 "Копирую ru-html -> Help"
robocopy "%SRC_RU_HTML%" "%TARGET%\NeuCAM\UI\NeuCAMUI\Resources\Help\ru-html" /E /R:1 /W:1 >nul
call :chk_rc "ru-html -> Help"
call :sleep %STEP_MS%

REM ==== Установка 3: russian_ru.xml ====
call :animate 80 95 "Копирую russian_ru.xml -> Translations"
copy /Y "%SRC_RU_XML%" "%TARGET%\Applications\CAM360\Data\Translations\russian_ru.xml" >nul
if errorlevel 1 call :fail "Не удалось скопировать russian_ru.xml (проверь права/антивирус)"
call :sleep %STEP_MS%

call :animate 95 100 "Готово!"

echo.
echo ------------------------------------------------------------
echo Установка завершена.
echo.
echo Дальше:
echo  1) Запусти Fusion 360
echo  2) Settings/Preferences -> Language -> Russian
echo ------------------------------------------------------------
echo.
pause
popd >nul
exit /b 0

:BADTARGET
echo [X] Неверный путь или в нём нет нужных папок:
echo     StringTable
echo     NeuCAM\UI\NeuCAMUI\Resources\Help
echo     Applications\CAM360\Data\Translations
echo.
goto :ASK
