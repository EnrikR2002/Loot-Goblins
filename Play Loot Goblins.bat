@echo off
title Loot Goblins
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\play.ps1"
echo.
pause
