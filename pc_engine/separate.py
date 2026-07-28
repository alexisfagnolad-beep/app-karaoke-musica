"""Paso 1 del motor de PC: separación de voz con Demucs.

Toma un archivo de audio y genera un "proyecto" con la voz y el instrumental
separados por IA (Demucs), sin el truco de fase del celular (por eso NO suena
metálico). Es la base de la calidad real.

Uso:
    python separate.py "C:\\ruta\\a\\cancion.mp3"
    python separate.py "cancion.mp3" -o proyectos

Salida:
    proyectos/<nombre>/instrumental.wav   (para cantar encima)
    proyectos/<nombre>/vocals.wav         (voz aislada; base del puntaje)
    proyectos/<nombre>/meta.json          (datos del proyecto)
"""

import argparse
import datetime
import json
import shutil
import subprocess
import sys
from pathlib import Path


def _console_python() -> str:
    """python.exe (con consola). Demucs/torch fallan bajo pythonw.exe."""
    candidate = Path(sys.executable).with_name("python.exe")
    return str(candidate) if candidate.exists() else sys.executable


def run_demucs(input_path: Path, work_dir: Path, model: str) -> None:
    """Ejecuta Demucs en modo dos-stems (voz / no-voz)."""
    cmd = [
        _console_python(),
        "-m",
        "demucs",
        "--two-stems=vocals",
        "-n",
        model,
        "-o",
        str(work_dir),
        str(input_path),
    ]
    print("-> Ejecutando Demucs (la 1ª vez baja el modelo, puede tardar):")
    print("   " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def find_stems(work_dir: Path, model: str, title: str):
    """Ubica los archivos que genera Demucs."""
    stem_dir = work_dir / model / title
    vocals = stem_dir / "vocals.wav"
    instrumental = stem_dir / "no_vocals.wav"
    if vocals.exists() and instrumental.exists():
        return vocals, instrumental

    # Fallback: buscar por nombre en cualquier subcarpeta.
    vocals = next(work_dir.rglob("vocals.wav"), None)
    instrumental = next(work_dir.rglob("no_vocals.wav"), None)
    return vocals, instrumental


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Separa voz e instrumental con Demucs (motor de PC).",
    )
    parser.add_argument("input", help="Archivo de audio de entrada (mp3, wav, etc.)")
    parser.add_argument(
        "-o", "--out", default="proyectos", help="Carpeta de proyectos (por defecto: proyectos)"
    )
    parser.add_argument(
        "-n", "--model", default="htdemucs", help="Modelo de Demucs (por defecto: htdemucs)"
    )
    parser.add_argument(
        "--keep-temp", action="store_true", help="No borrar los archivos temporales de Demucs"
    )
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        print(f"ERROR: no encontré el archivo: {input_path}", file=sys.stderr)
        return 1

    title = input_path.stem
    project_dir = Path(args.out).expanduser().resolve() / title
    project_dir.mkdir(parents=True, exist_ok=True)
    work_dir = project_dir / "_demucs"

    print(f"Canción: {title}")
    print(f"Proyecto: {project_dir}")

    try:
        run_demucs(input_path, work_dir, args.model)
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: Demucs falló (código {exc.returncode}).", file=sys.stderr)
        return 1

    vocals, instrumental = find_stems(work_dir, args.model, title)
    if not vocals or not instrumental:
        print("ERROR: no encontré las pistas separadas que genera Demucs.", file=sys.stderr)
        return 1

    shutil.copy(instrumental, project_dir / "instrumental.wav")
    shutil.copy(vocals, project_dir / "vocals.wav")

    meta = {
        "title": title,
        "source": input_path.name,
        "model": args.model,
        "createdAt": datetime.datetime.now().isoformat(timespec="seconds"),
        "files": {
            "instrumental": "instrumental.wav",
            "vocals": "vocals.wav",
        },
        "engineStep": "separate",
    }
    (project_dir / "meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    if not args.keep_temp:
        shutil.rmtree(work_dir, ignore_errors=True)

    print("\nOK: Listo.")
    print(f"   Instrumental: {project_dir / 'instrumental.wav'}")
    print(f"   Voz:          {project_dir / 'vocals.wav'}")
    print(f"   Datos:        {project_dir / 'meta.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
