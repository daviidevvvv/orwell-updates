@echo off
setlocal
cd /d "%~dp0"
if not exist "Orwell.exe" (
    echo Orwell.exe non trovato nella cartella dell'applicazione.
    pause
    exit /b 1
)
start "" "%~dp0Orwell.exe"
exit /b 0
