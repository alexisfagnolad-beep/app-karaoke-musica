@echo off
REM ============================================================
REM  Instalador del motor de PC (Windows).
REM  Crea un entorno de Python aislado e instala Demucs.
REM  Ejecutar UNA sola vez (doble clic).
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo === Creando entorno de Python (.venv) ===
py -3.11 -m venv .venv 2>nul
if not exist ".venv\Scripts\python.exe" (
  echo   No encontre Python 3.11, pruebo con el Python por defecto...
  python -m venv .venv
)
if not exist ".venv\Scripts\python.exe" (
  echo.
  echo ERROR: no se pudo crear el entorno. Instala Python 3.11 desde
  echo        https://www.python.org/downloads/ (marca "Add Python to PATH").
  pause
  exit /b 1
)

call ".venv\Scripts\activate.bat"

echo.
echo === Actualizando pip ===
python -m pip install --upgrade pip

echo.
echo === Instalando dependencias (baja ~1-2 GB la primera vez) ===
pip install -r requirements.txt

echo.
echo === Chequeo de GPU NVIDIA (opcional) ===
where nvidia-smi >nul 2>nul && (
  echo   Tenes GPU NVIDIA: se puede acelerar Demucs mas adelante.
) || (
  echo   Sin GPU NVIDIA detectada: se usara CPU ^(mas lento, pero funciona^).
)

echo.
echo ============================================================
echo  Listo. Ya podes procesar canciones con:  procesar.bat
echo ============================================================
pause
