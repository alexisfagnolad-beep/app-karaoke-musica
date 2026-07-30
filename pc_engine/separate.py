"""Paso 1 del motor de PC: separación de pistas con Demucs.

Toma un archivo de audio y arma un "proyecto" con:
  - instrumental.wav : la base para tocar/cantar encima (todo MENOS el
                       instrumento que vas a practicar).
  - target.wav       : el instrumento aislado que se va a analizar (para sacar
                       la referencia: melodía o ritmo).
  - meta.json        : datos del proyecto (instrumento, tipo de referencia...).

Podés elegir qué instrumento practicar:
    voz      -> separa la voz (rápido, two-stems).       referencia: melodía
    bateria  -> separa la batería (4 pistas).            referencia: ritmo
    bajo     -> separa el bajo (4 pistas).               referencia: melodía
    otros    -> guitarras/teclados (4 pistas).           referencia: melodía

Uso:
    python separate.py "cancion.mp3" --instrument voz
    python separate.py "cancion.mp3" -o proyectos --instrument bateria
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

# Instrumento -> (stem de Demucs, tipo de referencia, fmin del pitch).
INSTRUMENTS = {
    "voz": ("vocals", "melody", 65.0),
    "bateria": ("drums", "rhythm", 65.0),
    "bajo": ("bass", "melody", 40.0),
    "otros": ("other", "melody", 65.0),
}


def _console_python() -> str:
    """python.exe (con consola). Demucs/torch fallan bajo pythonw.exe."""
    candidate = Path(sys.executable).with_name("python.exe")
    return str(candidate) if candidate.exists() else sys.executable


def run_demucs(input_path: Path, work_dir: Path, model: str,
               two_stems: bool) -> None:
    """Ejecuta Demucs. Con two_stems separa voz/no-voz (rápido); sin él,
    separa las 4 pistas (drums, bass, other, vocals)."""
    cmd = [_console_python(), "-m", "demucs", "-n", model]
    if two_stems:
        cmd.append("--two-stems=vocals")
    cmd += ["-o", str(work_dir), str(input_path)]
    print("-> Ejecutando Demucs (la 1ª vez baja el modelo, puede tardar):")
    print("   " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def _stem_dir(work_dir: Path, model: str, title: str) -> Path:
    d = work_dir / model / title
    if d.exists():
        return d
    # Fallback: primera subcarpeta con .wav.
    for cand in work_dir.rglob("*.wav"):
        return cand.parent
    return d


def _sum_wavs(paths, out_path: Path) -> None:
    """Suma (mezcla) varios wav en uno solo (misma longitud/sr)."""
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
    # Evitar clipping.
    peak = float(np.max(np.abs(mix))) if mix.size else 0.0
    if peak > 1.0:
        mix = mix / peak
    # PCM 16-bit: compatible con el decodificador de Android del celular.
    sf.write(str(out_path), mix, sr, subtype="PCM_16")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Separa una pista con Demucs (motor de PC).",
    )
    parser.add_argument("input", help="Archivo de audio de entrada (mp3, wav, etc.)")
    parser.add_argument("-o", "--out", default="proyectos",
                        help="Carpeta de proyectos (por defecto: proyectos)")
    parser.add_argument("-n", "--model", default="htdemucs",
                        help="Modelo de Demucs (por defecto: htdemucs)")
    parser.add_argument("--instrument", default="voz", choices=list(INSTRUMENTS),
                        help="Instrumento a practicar (por defecto: voz)")
    parser.add_argument("--keep-temp", action="store_true",
                        help="No borrar los archivos temporales de Demucs")
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        print(f"ERROR: no encontré el archivo: {input_path}", file=sys.stderr)
        return 1

    stem_name, ref_kind, fmin = INSTRUMENTS[args.instrument]
    two_stems = args.instrument == "voz"

    title = input_path.stem
    project_dir = Path(args.out).expanduser().resolve() / title
    project_dir.mkdir(parents=True, exist_ok=True)
    work_dir = project_dir / "_demucs"

    print(f"Canción: {title}")
    print(f"Instrumento a practicar: {args.instrument}")
    print(f"Proyecto: {project_dir}")

    try:
        run_demucs(input_path, work_dir, args.model, two_stems)
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: Demucs falló (código {exc.returncode}).", file=sys.stderr)
        return 1

    stem_dir = _stem_dir(work_dir, args.model, title)

    if two_stems:
        # voz: Demucs da vocals.wav + no_vocals.wav.
        target = stem_dir / "vocals.wav"
        backing = stem_dir / "no_vocals.wav"
        if not target.exists() or not backing.exists():
            print("ERROR: no encontré las pistas de voz separadas.", file=sys.stderr)
            return 1
        shutil.copy(target, project_dir / "target.wav")
        shutil.copy(backing, project_dir / "instrumental.wav")
    else:
        # 4 pistas: target = el instrumento; instrumental = suma del resto.
        target = stem_dir / f"{stem_name}.wav"
        if not target.exists():
            print(f"ERROR: no encontré la pista '{stem_name}.wav'.", file=sys.stderr)
            return 1
        others = [p for p in stem_dir.glob("*.wav") if p.name != f"{stem_name}.wav"]
        if not others:
            print("ERROR: no encontré las demás pistas para la base.", file=sys.stderr)
            return 1
        shutil.copy(target, project_dir / "target.wav")
        print(f"-> Armando la base (todo menos {args.instrument})...")
        _sum_wavs(others, project_dir / "instrumental.wav")

    meta = {
        "title": title,
        "source": input_path.name,
        "model": args.model,
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

    if not args.keep_temp:
        shutil.rmtree(work_dir, ignore_errors=True)

    print("\nOK: Listo.")
    print(f"   Base (para tocar): {project_dir / 'instrumental.wav'}")
    print(f"   Instrumento:       {project_dir / 'target.wav'}")
    print(f"   Referencia:        {ref_kind}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
