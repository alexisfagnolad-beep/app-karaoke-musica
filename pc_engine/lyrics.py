"""Motor de PC (letra): transcribe la voz aislada a letra sincronizada.

Usa Whisper (IA) sobre la voz que ya separó Demucs (target.wav/vocals.wav) y
saca la letra con los tiempos línea por línea y palabra por palabra. El celular
la muestra debajo de las barras y resalta la palabra que va sonando.

Salida: lyrics.json
    {
      "language": "es",
      "lines": [
        {"start": 1.2, "end": 3.8, "text": "...",
         "words": [{"start": 1.2, "end": 1.5, "text": "hola"}, ...]},
        ...
      ]
    }

Uso:
    python lyrics.py "proyectos\\cancion"     (usa target.wav / vocals.wav)
    python lyrics.py "vocals.wav" --model base

Whisper reusa el PyTorch que ya trae Demucs. La 1ª vez baja el modelo (~150MB
para "base"). Sin GPU corre en CPU: tarda unos minutos, pero como la voz está
aislada la transcripción sale bastante limpia.
"""

import argparse
import json
import sys
from pathlib import Path


def _find_audio(target: Path):
    if target.is_dir():
        for name in ("target.wav", "vocals.wav"):
            cand = target / name
            if cand.exists():
                return cand, target / "lyrics.json", target / "meta.json"
        return None, target / "lyrics.json", target / "meta.json"
    return target, target.with_suffix(".lyrics.json"), None


def _to_lines(segments):
    """Convierte los segmentos de Whisper en líneas con palabras."""
    lines = []
    for seg in segments:
        text = (seg.get("text") or "").strip()
        if not text:
            continue
        words = []
        for w in seg.get("words", []) or []:
            wt = (w.get("word") or "").strip()
            if not wt:
                continue
            words.append({
                "start": round(float(w.get("start", seg["start"])), 3),
                "end": round(float(w.get("end", seg["end"])), 3),
                "text": wt,
            })
        lines.append({
            "start": round(float(seg["start"]), 3),
            "end": round(float(seg["end"]), 3),
            "text": text,
            "words": words,
        })
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transcribe la voz a letra sincronizada -> lyrics.json",
    )
    parser.add_argument("project", help="Carpeta del proyecto o un .wav")
    parser.add_argument("--model", default="base",
                        help="Modelo de Whisper (tiny/base/small; default base)")
    parser.add_argument("--language", default=None,
                        help="Idioma (ej. es, en). Por defecto autodetecta.")
    args = parser.parse_args()

    target = Path(args.project).expanduser().resolve()
    audio, out_json, meta_path = _find_audio(target)
    if audio is None or not audio.exists():
        print("ERROR: no encontré la voz a transcribir (target.wav/vocals.wav).",
              file=sys.stderr)
        return 1

    try:
        import whisper  # noqa: WPS433
    except Exception:  # noqa: BLE001
        print("AVISO: Whisper no está instalado; salto la letra.", file=sys.stderr)
        print("       (pip install openai-whisper)", file=sys.stderr)
        return 2

    print(f"Transcribiendo la letra de: {audio.name} (modelo {args.model}) ...")
    print("   La 1ª vez baja el modelo; sin GPU puede tardar unos minutos.")
    try:
        model = whisper.load_model(args.model)
        result = model.transcribe(
            str(audio),
            word_timestamps=True,
            language=args.language,
            verbose=False,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"AVISO: no pude transcribir la letra: {exc}", file=sys.stderr)
        return 2

    lines = _to_lines(result.get("segments", []))
    data = {
        "language": result.get("language"),
        "lineCount": len(lines),
        "lines": lines,
    }
    out_json.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    if meta_path and meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta.setdefault("files", {})["lyrics"] = "lyrics.json"
            meta_path.write_text(
                json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception:  # noqa: BLE001
            pass

    print(f"OK: Letra: {len(lines)} líneas -> {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
