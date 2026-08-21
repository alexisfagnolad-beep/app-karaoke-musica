@echo off
REM ============================================================
REM  Procesa una cancion con Demucs.
REM  Uso: arrastra un MP3 sobre este archivo, o:
REM       procesar.bat "C:\ruta\cancion.mp3"
REM ============================================================
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo ERROR: primero corre instalar.bat
  pause
  exit /b 1
)

if "%~1"=="" (
  echo Uso: arrastra un archivo de audio sobre procesar.bat
  echo   o:  procesar.bat "C:\ruta\cancion.mp3"
  pause
  exit /b 1
)

call ".venv\Scripts\activate.bat"
python separate.py %*
pause
