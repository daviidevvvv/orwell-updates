@echo off
taskkill /IM Orwell.exe /F >nul 2>&1
taskkill /IM Telecamere.exe /F >nul 2>&1
taskkill /IM go2rtc.exe /F >nul 2>&1
taskkill /IM ClipExporter.exe /F >nul 2>&1
taskkill /IM ffmpeg.exe /F >nul 2>&1
echo Orwell e servizi video chiusi.
timeout /t 2 /nobreak >nul
