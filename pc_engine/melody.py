"""Paso 2 del motor de PC: melodía de referencia.

Toma la voz aislada (`vocals.wav`, generada por Demucs) y extrae su afinación a
lo largo del tiempo (pitch tracking por autocorrelación FFT, tipo YIN). El
resultado (`melody.json`) es la "partitura de referencia" contra la que el
celular va a puntuar cómo cantás (afinación + duración + sostenimiento).

Uso:
    python melody.py "proyectos\\cancion"      (carpeta del proyecto)
    python melody.py "vocals.wav"              (un wav suelto)

Solo usa numpy + soundfile (ya instalados con el motor); no requiere modelos.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def read_mono(path: Path):
    data, sr = sf.read(str(path), always_2d=True)
    mono = data.mean(axis=1).astype(np.float64)
    return mono, sr


def autocorr_fft(x: np.ndarray) -> np.ndarray:
    n = len(x)
    spectrum = np.fft.rfft(x, 2 * n)
    acf = np.fft.irfft(spectrum * np.conj(spectrum))[:n]
    return acf


def estimate_f0(frame, sr, fmin=65.0, fmax=1200.0, clarity_threshold=0.28):
    """Devuelve (f0_hz, clarity). f0=0 significa sin tono (silencio/ruido).

    Umbrales bajos a propósito: capturamos MÁS de la melodía principal (voz
    suave/soplada, piano tenue) para que no falten barras. El celular después
    suaviza, une y simplifica."""
    frame = frame - frame.mean()
    if math.sqrt(float(np.mean(frame ** 2))) < 0.004:
        return 0.0, 0.0

    corr = autocorr_fft(frame)
    if corr[0] <= 0:
        return 0.0, 0.0

    tau_min = max(1, int(sr / fmax))
    tau_max = min(int(sr / fmin), len(corr) - 2)
    if tau_max <= tau_min:
        return 0.0, 0.0

    peak = int(np.argmax(corr[tau_min:tau_max])) + tau_min
    clarity = corr[peak] / corr[0]
    if clarity < clarity_threshold:
        return 0.0, clarity

    # Interpolación parabólica para precisión sub-muestra.
    a, b, c = corr[peak - 1], corr[peak], corr[peak + 1]
    denom = a - 2 * b + c
    shift = 0.5 * (a - c) / denom if denom != 0 else 0.0
    tau = peak + shift
    # Casteamos a float de Python: numpy.float64 no es serializable a JSON.
    return (float(sr / tau) if tau > 0 else 0.0), float(clarity)


def hz_to_note(freq: float):
    if freq <= 0:
        return None, None, None
    midi_float = 69 + 12 * math.log2(freq / 440.0)
    midi = round(midi_float)
    cents = (midi_float - midi) * 100.0
    name = f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"
    return name, midi, cents


def _fill_gaps(f0s, fps, max_gap_sec=0.3, max_semitones=5.0):
    """Rellena huecos cortos entre dos tramos con tono, para que la melodía
    principal quede CONTINUA (no cortada). Solo rellena si el hueco es corto y
    la nota de antes y después están cerca (no une saltos grandes ni silencios
    largos, que sí son pausas reales)."""
    n = len(f0s)
    max_gap = int(max_gap_sec * fps)
    i = 0
    while i < n:
        if f0s[i] > 0:
            i += 1
            continue
        j = i
        while j < n and f0s[j] == 0:
            j += 1
        if i - 1 >= 0 and j < n and f0s[i - 1] > 0 and f0s[j] > 0 \
                and (j - i) <= max_gap:
            a, b = f0s[i - 1], f0s[j]
            semis = abs(12 * math.log2(b / a)) if a > 0 and b > 0 else 99
            if semis <= max_semitones:
                span = j - (i - 1)
                for k in range(i, j):
                    frac = (k - (i - 1)) / span
                    f0s[k] = a * (b / a) ** frac  # interpolación geométrica
        i = j
    return f0s


def extract_melody(vocals_path: Path, fps: float = 50.0, window: int = 2048,
                   fmin: float = 65.0):
    sig, sr = read_mono(vocals_path)
    hop = max(1, int(sr / fps))
    f0s = []
    clars = []
    for i in range(0, max(0, len(sig) - window), hop):
        f0, clarity = estimate_f0(sig[i:i + window], sr, fmin=fmin)
        f0s.append(f0)
        clars.append(clarity)

    # Rellenamos huecos cortos para que la melodía principal sea continua.
    f0s = _fill_gaps(f0s, fps)

    frames = []
    for idx, f0 in enumerate(f0s):
        name, midi, cents = hz_to_note(f0)
        frames.append({
            "t": round(idx * hop / sr, 3),
            "f0": round(f0, 2),
            "midi": midi,
            "note": name,
            "cents": round(cents, 1) if cents is not None else None,
            "clarity": round(float(clars[idx]), 3),
            "voiced": f0 > 0,
        })
    return {
        "sampleRate": sr,
        "fps": fps,
        "window": window,
        "frameCount": len(frames),
        "frames": frames,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extrae la melodía de referencia (pitch de la voz).",
    )
    parser.add_argument("project", help="Carpeta del proyecto o un .wav")
    parser.add_argument("--fps", type=float, default=50.0, help="Cuadros por segundo (default 50)")
    parser.add_argument("--fmin", type=float, default=None,
                        help="Frecuencia mínima (Hz). Para bajo conviene ~40.")
    args = parser.parse_args()

    target = Path(args.project).expanduser().resolve()
    fmin = args.fmin
    if target.is_dir():
        # Preferimos target.wav (el instrumento aislado); si no, vocals.wav.
        vocals = None
        for name in ("target.wav", "vocals.wav"):
            candidate = target / name
            if candidate.exists():
                vocals = candidate
                break
        out_json = target / "melody.json"
        meta_path = target / "meta.json"
        # Si el proyecto trae fmin en meta.json y no se pasó por CLI, usarlo.
        if fmin is None and meta_path.exists():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
                fmin = float(meta.get("fmin", 65.0))
            except Exception:
                fmin = None
    else:
        vocals = target
        out_json = target.with_suffix(".melody.json")
        meta_path = None

    if fmin is None:
        fmin = 65.0

    if vocals is None or not vocals.exists():
        print("ERROR: no encontré la pista a analizar (target.wav/vocals.wav).",
              file=sys.stderr)
        print("       ¿Corriste antes separate.py?", file=sys.stderr)
        return 1

    print(f"Analizando: {vocals.name} (fmin={fmin:.0f} Hz) ...")
    melody = extract_melody(vocals, fps=args.fps, fmin=fmin)
    out_json.write_text(json.dumps(melody, ensure_ascii=False), encoding="utf-8")

    if meta_path and meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta.setdefault("files", {})["melody"] = "melody.json"
            meta["engineStep"] = "melody"
            meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception:
            pass

    voiced = sum(1 for f in melody["frames"] if f["voiced"])
    total = melody["frameCount"]
    pct = (100 * voiced / total) if total else 0
    print(f"OK: Melodía extraída: {total} cuadros, {voiced} con voz ({pct:.0f}%).")
    print(f"   Archivo: {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
