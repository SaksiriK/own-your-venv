@echo off
rem cmd.exe doesn't execute .ps1 files by name (Windows deliberately doesn't
rem wire that up, unlike .bat) - this wrapper is what lets `setup` work the
rem same way from cmd.exe as it does from PowerShell.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
