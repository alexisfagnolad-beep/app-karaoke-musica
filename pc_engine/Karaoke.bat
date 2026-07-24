@echo off
REM ============================================================
REM  Abre la app de escritorio del Karaoke (ventana con botones).
REM  Doble clic para usar. No abre terminal.
REM ============================================================
cd /d "%~dp0"

if not exist ".venv\Scripts\pythonw.exe" goto :noenv

start "" ".venv\Scripts\pythonw.exe" "app_pc.py"
exit /b 0

:noenv
echo No encuentro el entorno (.venv). Falta instalar el motor.
echo Segui la guia README_PC.md (instalar.bat).
pause
