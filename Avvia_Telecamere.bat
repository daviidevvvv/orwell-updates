@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Telecamere Brezza - Avvio

if not exist "bin\go2rtc.exe" (
    echo Primo avvio: scarico go2rtc ufficiale da GitHub...
    if not exist "bin" mkdir "bin"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_win64.zip' -OutFile 'bin\go2rtc_win64.zip'; Expand-Archive -LiteralPath 'bin\go2rtc_win64.zip' -DestinationPath 'bin' -Force; Remove-Item 'bin\go2rtc_win64.zip' -Force"
    if errorlevel 1 (
        echo.
        echo Download non riuscito. Controlla la connessione Internet e riprova.
        pause
        exit /b 1
    )
)

if not exist "bin\go2rtc.exe" (
    echo File bin\go2rtc.exe non trovato.
    pause
    exit /b 1
)

if not exist "bin\ffmpeg.exe" (
    echo File bin\ffmpeg.exe non trovato nella cartella condivisa.
    pause
    exit /b 1
)

set "TELECAMERE_RUNTIME=%LOCALAPPDATA%\TelecamereBrezza"
if not exist "%TELECAMERE_RUNTIME%" mkdir "%TELECAMERE_RUNTIME%"
copy /Y "bin\go2rtc.yaml" "%TELECAMERE_RUNTIME%\go2rtc.runtime.yaml" >nul
if errorlevel 1 (
    echo Impossibile preparare la configurazione locale di go2rtc.
    pause
    exit /b 1
)

set "PATH=%~dp0bin;%PATH%"
taskkill /IM go2rtc.exe /F >nul 2>&1
taskkill /IM ClipExporter.exe /F >nul 2>&1
timeout /t 1 /nobreak >nul

set "GUARD_EXIT=1"
if exist "bin\ClipExporter.exe" (
    echo Verifico la compatibilita H.264 dei SUB Brezza...
    start "ClipExporter Telecamere Brezza" /min "%~dp0bin\ClipExporter.exe"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "$fine=(Get-Date).AddSeconds(8); $seen=$false; $q=[char]34; $ok=$q+'state'+$q+':'+$q+'ok'+$q; $repaired=$q+'state'+$q+':'+$q+'repaired'+$q; $degraded=$q+'state'+$q+':'+$q+'degraded'+$q; do { try { $body=(Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 'http://127.0.0.1:1986/health').Content; $seen=$true; if($body.Contains($ok) -or $body.Contains($repaired)) { exit 0 }; if($body.Contains($degraded)) { exit 2 } } catch {}; Start-Sleep -Milliseconds 300 } while ((Get-Date) -lt $fine); if($seen) { exit 2 } else { exit 1 }"
    set "GUARD_EXIT=!ERRORLEVEL!"
) else (
    echo bin\ClipExporter.exe non trovato: il guardiano H.264 non puo essere avviato.
)

if "!GUARD_EXIT!"=="0" (
    echo Compatibilita WebRTC H.264 verificata.
) else if "!GUARD_EXIT!"=="2" (
    echo Guardiano H.264 in recupero: la diretta parte comunque e il controllo ritentera automaticamente.
) else (
    echo Impossibile contattare il guardiano H.264: la diretta parte comunque.
)

start "go2rtc Telecamere Brezza" /min /D "%~dp0" "%~dp0bin\go2rtc.exe" -config "%TELECAMERE_RUNTIME%\go2rtc.runtime.yaml"

powershell.exe -NoProfile -Command ^
  "$fine=(Get-Date).AddSeconds(20); do { try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 'http://127.0.0.1:1984/' | Out-Null; exit 0 } catch { Start-Sleep -Milliseconds 400 } } while ((Get-Date) -lt $fine); exit 1"

if errorlevel 1 (
    echo.
    echo go2rtc non ha risposto entro 20 secondi.
    echo Apri tools\Apri_Pannello_Diagnostica.bat per controllare.
    pause
    exit /b 1
)

start "" "http://127.0.0.1:1984/dashboard.html?v=20261118"
exit /b 0
