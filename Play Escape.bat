@echo off
rem Escape! - looks for updates, installs them and starts the game on Windows.
rem Everything below sits in one block: cmd reads the whole block before running it,
rem so an update may safely replace this file while it runs.
(
  if not exist "%~dp0tools\launcher\update_and_play.ps1" (
    rem Only this file is here: fetch the launcher, which then downloads the whole game.
    if not exist "%~dp0.launcher" mkdir "%~dp0.launcher"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/devilbane/escape/main/tools/launcher/update_and_play.ps1' -OutFile '%~dp0.launcher\update_and_play.ps1'"
  )
  if exist "%~dp0tools\launcher\update_and_play.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher\update_and_play.ps1" -GameDir "%~dp0." %*
  ) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0.launcher\update_and_play.ps1" -GameDir "%~dp0." %*
  )
  if errorlevel 1 pause
  exit /b
)
