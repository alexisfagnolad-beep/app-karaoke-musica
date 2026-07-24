"""Procesa una canción de punta a punta con un solo paso:
  1) separa voz e instrumental (Demucs),
  2) extrae la melodía de referencia,
y abre la carpeta con el resultado.

Pensado para usarse arrastrando un archivo sobre `procesar.bat`.
"""

import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("Arrastrá un archivo de audio (mp3) sobre procesar.bat.")
        return 1

    here = Path(__file__).resolve().parent
    input_path = Path(sys.argv[1]).expanduser().resolve()
    if not input_path.exists():
        print(f"No encontré el archivo: {input_path}")
        return 1

    py = sys.executable
    projects_dir = here / "proyectos"
    title = input_path.stem
    project = projects_dir / title

    print("=" * 60)
    print(f"  Procesando: {input_path.name}")
    print("=" * 60)

    print("\n[1/2] Separando voz e instrumental (Demucs)...")
    print("      (la 1ª vez baja el modelo; si se corta por la red,")
    print("       volvé a arrastrar la canción y retoma).\n")
    r = subprocess.run([py, str(here / "separate.py"), str(input_path),
                        "-o", str(projects_dir)])
    if r.returncode != 0:
        print("\n⚠️  La separación no terminó. Volvé a arrastrar la canción.")
        return 1

    print("\n[2/2] Extrayendo melodía de referencia...")
    r = subprocess.run([py, str(here / "melody.py"), str(project)])
    if r.returncode != 0:
        print("\n⚠️  No se pudo extraer la melodía (pero el instrumental ya está).")

    print("\n✅ Listo. Abriendo la carpeta del resultado...")
    print(f"   {project}")
    try:
        os.startfile(str(project))  # abre la carpeta en Windows
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
