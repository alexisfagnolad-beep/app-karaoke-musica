"""Motor de PC (ritmo): extrae los golpes (onsets) de una pista.

Detecta los instantes en que ocurren los golpes (por flujo espectral) y los
guarda en `rhythm.json`. El celular lo usa como referencia para puntuar cómo
seguís el ritmo (batería/percusión).

Uso:
    python rhythm.py "proyectos\\cancion"   (usa drums.wav / instrumental.wav)
    python rhythm.py "drums.wav"

Solo usa numpy + soundfile (ya instalados). Ideal aplicarlo a la pista de
batería (drums.wav) separada por Demucs.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf


def detect_onsets(sig, sr, hop=512, win=1024, min_interval=0.08, delta=0.12):
    """Devuelve la lista de tiempos (segundos) de los golpes detectados."""
    if len(sig) < win:
        return []
    n = 1 + (len(sig) - win) // hop
    window = np.hanning(win)
    prev_mag = None
    flux = np.zeros(n)
    for i in range(n):
        frame = sig[i * hop:i * hop + win] * window
        mag = np.abs(np.fft.rfft(frame))
        if prev_mag is not None:
            diff = mag - prev_mag
            flux[i] = float(np.sum(diff[diff > 0]))
        prev_mag = mag

    if flux.max() > 0:
        flux /= flux.max()

    onsets = []
    last = -1e9
    w = 8
    for i in range(n):
        lo = max(0, i - w)
        hi = min(n, i + w + 1)
        thr = flux[lo:hi].mean() + delta
        local_max = flux[max(0, i - 1):min(n, i + 2)].max()
        t = i * hop / sr
        if flux[i] > thr and flux[i] == local_max and (t - last) >= min_interval:
            onsets.append(round(t, 3))
            last = t
    return onsets


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extrae los golpes (ritmo) de una pista -> rhythm.json",
    )
    parser.add_argument("input", help="Carpeta del proyecto o un .wav")
    args = parser.parse_args()

    p = Path(args.input).expanduser().resolve()
    if p.is_dir():
        audio = None
        for name in ("drums.wav", "instrumental.wav", "vocals.wav"):
            candidate = p / name
            if candidate.exists():
                audio = candidate
                break
        out = p / "rhythm.json"
        meta_path = p / "meta.json"
    else:
        audio = p
        out = p.with_suffix(".rhythm.json")
        meta_path = None

    if audio is None or not audio.exists():
        print("ERROR: no encontré una pista de audio para analizar.", file=sys.stderr)
        return 1

    print(f"Analizando el ritmo de: {audio.name} ...")
    data, sr = sf.read(str(audio), always_2d=True)
    sig = data.mean(axis=1)
    onsets = detect_onsets(sig, sr)
    out.write_text(
        json.dumps({"onsets": onsets, "count": len(onsets)}, ensure_ascii=False),
        encoding="utf-8",
    )

    if meta_path and meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta.setdefault("files", {})["rhythm"] = "rhythm.json"
            meta_path.write_text(
                json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception:
            pass

    print(f"OK: {len(onsets)} golpes -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
