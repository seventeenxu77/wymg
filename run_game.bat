@echo off
setlocal
title DEEP SEEK

where godot >nul 2>nul
if not errorlevel 1 (
  godot --path "%~dp0"
  exit /b %errorlevel%
)

where godot4 >nul 2>nul
if not errorlevel 1 (
  godot4 --path "%~dp0"
  exit /b %errorlevel%
)

if exist "%USERPROFILE%\bin\godot.cmd" (
  call "%USERPROFILE%\bin\godot.cmd" --path "%~dp0"
  exit /b %errorlevel%
)

echo Godot 4.7 command was not found in PATH or "%USERPROFILE%\bin".
pause
exit /b 1
