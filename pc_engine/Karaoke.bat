@echo off
REM ============================================================
REM  KARAOKE PC - Lanzador unico (auto-instalable).
REM  Doble clic:
REM   - La 1a vez: prepara todo solo (entorno + Demucs).
REM   - Despues: abre la app (ventana con botones).
REM ============================================================
setlocal
cd /d "%~dp0"
title Karaoke PC

REM Si ya esta instalado, abrir la app directamente.
if exist ".venv\Scripts\pythonw.exe" goto :launch

echo ============================================================
echo   Primera vez: preparando el motor. Puede tardar unos
echo   minutos. NO cierres esta ventana.
echo ============================================================
echo.

REM --- Buscar Python ---
set "PY="
py -3.11 --version >nul 2>nul && set "PY=py -3.11"
if not defined PY ( py --version >nul 2>nul && set "PY=py" )
if not defined PY ( python --version >nul 2>nul && set "PY=python" )
if not defined PY goto :nopython

echo Creando entorno de Python...
%PY% -m venv .venv
if not exist ".venv\Scripts\python.exe" goto :venvfail

call ".venv\Scripts\activate.bat"
python -m pip install --upgrade pip

echo.
echo Instalando PyTorch (servidor de PyTorch, estable)...
pip install torch --index-url https://download.pytorch.org/whl/cpu --timeout 300 --retries 20
if errorlevel 1 goto :installfail

echo.
echo Instalando Demucs y dependencias...
pip install -r requirements.txt --timeout 300 --retries 20
if errorlevel 1 goto :installfail

echo.
echo Instalacion completa. Abriendo la app...

:launch
start "" ".venv\Scripts\pythonw.exe" "app_pc.py"
exit /b 0

:nopython
echo.
echo ERROR: No encontre Python.
echo Instala Python 3.11 desde https://www.python.org/downloads/
echo (marca "Add Python to PATH") y volve a hacer doble clic aca.
pause
exit /b 1

:venvfail
echo.
echo ERROR: no se pudo crear el entorno de Python.
pause
exit /b 1

:installfail
echo.
echo La instalacion se corto (probablemente la red).
echo Volve a hacer DOBLE CLIC en Karaoke.bat: retoma lo descargado.
pause
exit /b 1
