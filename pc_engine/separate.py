"""Paso 1 del motor de PC: separación de pistas con Demucs (con caché).

La parte pesada (Demucs) separa las 4 pistas de una vez: batería, bajo, "otros"
(guitarras/teclados) y voz. Por eso las guardamos en caché dentro del proyecto
(`stems/`): la primera vez separa; después, elegir otro instrumento es casi
instantáneo porque reusa esa separación (no vuelve a correr Demucs).

Para el instrumento elegido arma:
  - instrumental.wav : la base para tocar/cantar encima (todo MENOS ese
                       instrumento).
  - target.wav       : el instrumento aislado (para sacar la referencia).
  - meta.json        : datos del proyecto (instrumento, tipo de referencia...).

Uso:
    python separate.py "cancion.mp3" --instrument voz
    python separate.py "cancion.mp3" -o proyectos --instrument bajo
"""

import argparse
import datetime
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

# Pistas que genera cada modelo de Demucs.
STEMS_BY_MODEL = {
    "htdemucs": ("drums", "bass", "other", "vocals"),
    # El modelo de 6 pistas separa además piano y guitarra.
    "htdemucs_6s": ("drums", "bass", "other", "vocals", "piano", "guitar"),
}

# Instrumento -> (stem de Demucs, tipo de referencia, fmin del pitch, modelo).
INSTRUMENTS = {
    "voz": ("vocals", "melody", 65.0, "htdemucs"),
    "bateria": ("drums", "rhythm", 65.0, "htdemucs"),
    "bajo": ("bass", "melody", 40.0, "htdemucs"),
    "otros": ("other", "melody", 65.0, "htdemucs"),
    # Piano y guitarra usan el modelo de 6 pistas (separación dedicada).
    "piano": ("piano", "melody", 55.0, "htdemucs_6s"),
    "guitarra": ("guitar", "melody", 80.0, "htdemucs_6s"),
}


def _console_python() -> str:
    """python.exe (con consola). Demucs/torch fallan bajo pythonw.exe."""
    candidate = Path(sys.executable).with_name("python.exe")
    return str(candidate) if candidate.exists() else sys.executable


def run_demucs(input_path: Path, work_dir: Path, model: str) -> None:
    """Separa las 4 pistas (drums, bass, other, vocals)."""
    cmd = [_console_python(), "-m", "demucs", "-n", model,
           "-o", str(work_dir), str(input_path)]
    print("-> Ejecutando Demucs (la 1ª vez baja el modelo, puede tardar):")
    print("   " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def _demucs_stem_dir(work_dir: Path, model: str, title: str) -> Path:
    d = work_dir / model / title
    if d.exists():
        return d
    for cand in work_dir.rglob("vocals.wav"):
        return cand.parent
    return d


def cached_stems(stems_dir: Path, stems):
    """Devuelve {stem: path} si están todas las pistas en caché, si no None."""
    if not stems_dir.exists():
        return None
    paths = {s: stems_dir / f"{s}.wav" for s in stems}
    if all(p.exists() for p in paths.values()):
        return paths
    return None


def _sum_wavs(paths, out_path: Path) -> None:
    """Suma (mezcla) varios wav en uno solo y lo guarda como PCM 16-bit
    (compatible con el decodificador de Android del celular)."""
    mix = None
    sr = None
    for p in paths:
        data, s = sf.read(str(p), always_2d=True)
        sr = s
        if mix is None:
            mix = np.zeros_like(data, dtype=np.float64)
        n = min(len(mix), len(data))
        mix[:n] += data[:n]
    if mix is None:
        raise RuntimeError("no hay pistas para mezclar")
    peak = float(np.max(np.abs(mix))) if mix.size else 0.0
    if peak > 1.0:
        mix = mix / peak
    sf.write(str(out_path), mix, sr, subtype="PCM_16")


def _stems_dir(project_dir: Path, model: str) -> Path:
    # Caché por modelo (htdemucs y htdemucs_6s pueden convivir).
    return project_dir / "stems" / model


def locate_stems(project_dir: Path, model: str, stems):
    """Busca las pistas en caché: primero por modelo, y como compatibilidad
    el caché viejo plano (`stems/`) para htdemucs de 4 pistas."""
    found = cached_stems(_stems_dir(project_dir, model), stems)
    if found:
        return found
    if model == "htdemucs":
        return cached_stems(project_dir / "stems", stems)
    return None


def ensure_stems(input_path: Path, project_dir: Path, model: str):
    """Garantiza las pistas del modelo en `project_dir/stems/<model>/`. Reusa
    el caché si ya están; si no, corre Demucs una sola vez."""
    stems = STEMS_BY_MODEL[model]
    stems_dir = _stems_dir(project_dir, model)
    existing = locate_stems(project_dir, model, stems)
    if existing:
        print("-> Uso la separación en caché (no vuelvo a correr Demucs).")
        return existing

    stems_dir.mkdir(parents=True, exist_ok=True)
    work_dir = project_dir / "_demucs"
    run_demucs(input_path, work_dir, model)
    src = _demucs_stem_dir(work_dir, model, input_path.stem)
    for s in stems:
        srcfile = src / f"{s}.wav"
        if not srcfile.exists():
            raise RuntimeError(f"Demucs no generó {s}.wav")
        shutil.copy(srcfile, stems_dir / f"{s}.wav")
    shutil.rmtree(work_dir, ignore_errors=True)
    return {s: stems_dir / f"{s}.wav" for s in stems}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Separa una pista con Demucs (con caché de pistas).",
    )
    parser.add_argument("input", nargs="?",
                        help="Archivo de audio de entrada (mp3, wav, etc.)")
    parser.add_argument("--project", default=None,
                        help="Carpeta de un proyecto ya separado: reusa el caché "
                             "de pistas (no necesita el audio original).")
    parser.add_argument("-o", "--out", default="proyectos",
                        help="Carpeta de proyectos (por defecto: proyectos)")
    parser.add_argument("-n", "--model", default="htdemucs",
                        help="Modelo de Demucs (por defecto: htdemucs)")
    parser.add_argument("--instrument", default="voz", choices=list(INSTRUMENTS),
                        help="Instrumento a practicar (por defecto: voz)")
    args = parser.parse_args()

    stem_name, ref_kind, fmin, model = INSTRUMENTS[args.instrument]
    stem_set = STEMS_BY_MODEL[model]
    source_name = None

    if args.project:
        # Reprocesar otro instrumento desde el caché (sin audio de entrada).
        project_dir = Path(args.project).expanduser().resolve()
        title = project_dir.name
        stems = locate_stems(project_dir, model, stem_set)
        if not stems:
            print(f"ERROR: este proyecto no tiene la separación de '{model}' "
                  "en caché. Reprocesá el piano/guitarra desde la canción "
                  "original (esos usan un modelo distinto).", file=sys.stderr)
            return 1
        print(f"Canción: {title}")
        print(f"Instrumento a practicar: {args.instrument}")
        print("-> Uso la separación en caché (no vuelvo a correr Demucs).")
    else:
        if not args.input:
            print("ERROR: falta la canción de entrada.", file=sys.stderr)
            return 1
        input_path = Path(args.input).expanduser().resolve()
        if not input_path.exists():
            print(f"ERROR: no encontré el archivo: {input_path}", file=sys.stderr)
            return 1
        title = input_path.stem
        source_name = input_path.name
        project_dir = Path(args.out).expanduser().resolve() / title
        project_dir.mkdir(parents=True, exist_ok=True)
        print(f"Canción: {title}")
        print(f"Instrumento a practicar: {args.instrument} (modelo {model})")
        print(f"Proyecto: {project_dir}")
        try:
            stems = ensure_stems(input_path, project_dir, model)
        except subprocess.CalledProcessError as exc:
            print(f"ERROR: Demucs falló (código {exc.returncode}).",
                  file=sys.stderr)
            return 1
        except Exception as exc:  # noqa: BLE001
            print(f"ERROR: no pude separar: {exc}", file=sys.stderr)
            return 1

    # Limpiamos referencias de un instrumento anterior (si cambiaste de
    # instrumento en la misma canción) para no publicar una vieja por error.
    for stale in ("melody.json", "rhythm.json"):
        f = project_dir / stale
        if f.exists():
            f.unlink()

    # Instrumento aislado a analizar.
    shutil.copy(stems[stem_name], project_dir / "target.wav")
    # Base = suma de las demás pistas del mismo modelo.
    print(f"-> Armando la base (todo menos {args.instrument})...")
    others = [stems[s] for s in stem_set if s != stem_name]
    _sum_wavs(others, project_dir / "instrumental.wav")

    meta = {
        "title": title,
        "source": source_name,
        "model": model,
        "instrument": args.instrument,
        "referenceKind": ref_kind,  # "melody" | "rhythm"
        "fmin": fmin,
        "createdAt": datetime.datetime.now().isoformat(timespec="seconds"),
        "files": {
            "instrumental": "instrumental.wav",
            "target": "target.wav",
        },
        "engineStep": "separate",
    }
    (project_dir / "meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print("\nOK: Listo.")
    print(f"   Base (para tocar): {project_dir / 'instrumental.wav'}")
    print(f"   Instrumento:       {project_dir / 'target.wav'}")
    print(f"   Referencia:        {ref_kind}")
    print("   (Las pistas quedaron en caché: cambiar de instrumento del mismo")
    print("    modelo será casi instantáneo.)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
