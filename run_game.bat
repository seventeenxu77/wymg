@echo off
title 老宅窃影
set "GODOT_EXE=C:\Users\SQ\Desktop\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7 executable was not found.
  pause
  exit /b 1
)
"%GODOT_EXE%" --path "%~dp0"
