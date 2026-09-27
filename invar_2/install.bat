@echo off
setlocal
chcp 65001 >nul

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting admin rights
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo ============================================================
echo                        Установка ПО
echo ============================================================
echo.
echo   Основной набор:
echo     Chocolatey, Git, VS Code, Docker, PyCharm, Python, Julia,
echo     Rust, MSYS2, Maxima, KNIME, Anaconda, GIMP, Zettlr,
echo     MiKTeX, TeXstudio, Far, SumatraPDF, Flameshot, Qalculate!,
echo     7Zip, Chrome, Firefox, Edge, Arc, Yandex Browser,
echo     Yandex Telemost, Sber Jazz, WSL 2 (Ubuntu 22.04/24.04).
echo.
echo   Дополнительный набор (313):
echo     Ramus Educational, ARIS EXPRESS, Archi.
echo.

choice /C YN /M "Установить дополнительный набор для аудитории 313?"
if errorlevel 2 (
    set "INSTALL_313=0"
) else (
    set "INSTALL_313=1"
)
echo.

for %%F in (installer.ps1 installer313.ps1 configure.ps1) do (
    if not exist "%%F" (
        echo ERROR: file not found %%F
        pause
        exit /b 1
    )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer.ps1"
set STEP1=%errorlevel%
echo.

if not "%STEP1%"=="0" (
    echo [ВНИМАНИЕ] установка завершилась с кодом %STEP1%.
)
echo.

if "%INSTALL_313%"=="1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer313.ps1"
    echo.
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure.ps1"
echo.

:finish
echo Установка завершена. Рекомендуется перезагрузить устройство.
pause
endlocal