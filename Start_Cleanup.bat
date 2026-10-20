@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Resolve20_Cleanup.ps1"
if errorlevel 1 pause
