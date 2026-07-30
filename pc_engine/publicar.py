"""Publica un proyecto ya procesado para que el celular lo baje solo.

La idea (auto-sync por GitHub): en vez de pasar archivos por cable, la PC
"sube" el proyecto a una Release fija del repo (tag `proyectos`) y el celular,
desde la app, la ve y la descarga directo a su Biblioteca. Sin cables, sin
elegir archivos a mano.

Sube SOLO lo que el celular necesita para cantar con puntaje:
    - instrumental.wav  (la pista para cantar encima)
    - melody.json       (la melodía de referencia; opcional)
    - rhythm.json       (referencia de ritmo; opcional, si existe)
NO sube vocals.wav (es pesado y no se usa en el celular).

Además mantiene un índice `proyectos.json` en la misma Release con la lista de
canciones disponibles y sus datos (título, género, instrumentos).

Requiere un token de GitHub (para escribir en la Release). Solo usa la
librería estándar (urllib), sin dependencias extra.
"""

import json
import mimetypes
import re
import ssl
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

OWNER = "alexisfagnolad-beep"
REPO = "app-karaoke-musica"
RELEASE_TAG = "proyectos"
INDEX_NAME = "proyectos.json"

API = f"https://api.github.com/repos/{OWNER}/{REPO}"
_CTX = ssl.create_default_context()


def _slug(text: str) -> str:
    """Convierte un título a un id seguro para nombre de asset (ascii)."""
    text = text.strip().lower()
    text = text.replace("á", "a").replace("é", "e").replace("í", "i")
    text = text.replace("ó", "o").replace("ú", "u").replace("ñ", "n")
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or "cancion"


def _headers(token: str, accept: str = "application/vnd.github+json") -> dict:
    h = {
        "Accept": accept,
        "User-Agent": "karaoke-pc-publisher",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = (token or "").strip()
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def _request(method: str, url: str, token: str, *, data=None,
             accept="application/vnd.github+json", content_type=None):
    headers = _headers(token, accept)
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=120, context=_CTX) as resp:
        raw = resp.read()
    return raw


def _get_json(url: str, token: str):
    raw = _request("GET", url, token)
    return json.loads(raw.decode("utf-8"))


def get_or_create_release(token: str) -> dict:
    """Devuelve la Release del tag `proyectos`, creándola si no existe."""
    try:
        return _get_json(f"{API}/releases/tags/{RELEASE_TAG}", token)
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
    body = json.dumps({
        "tag_name": RELEASE_TAG,
        "name": "Proyectos para el celular",
        "body": "Canciones procesadas en la PC, listas para sincronizar con la app.",
        "draft": False,
        "prerelease": False,
    }).encode("utf-8")
    raw = _request("POST", f"{API}/releases", token, data=body,
                   content_type="application/json")
    return json.loads(raw.decode("utf-8"))


def _delete_asset_if_exists(release: dict, name: str, token: str) -> None:
    for asset in release.get("assets", []):
        if asset.get("name") == name:
            try:
                _request("DELETE", f"{API}/releases/assets/{asset['id']}", token)
            except urllib.error.HTTPError:
                pass


def _upload_asset(release: dict, file_path: Path, name: str, token: str) -> dict:
    """Sube (o reemplaza) un asset a la Release. Devuelve el asset creado."""
    _delete_asset_if_exists(release, name, token)
    # upload_url viene como https://uploads.github.com/.../assets{?name,label}
    upload_base = release["upload_url"].split("{", 1)[0]
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
    data = file_path.read_bytes()
    url = f"{upload_base}?name={urllib.parse.quote(name)}"
    raw = _request("POST", url, token, data=data, content_type=ctype)
    return json.loads(raw.decode("utf-8"))


def _upload_bytes(release: dict, data: bytes, name: str, token: str,
                  ctype: str) -> dict:
    _delete_asset_if_exists(release, name, token)
    upload_base = release["upload_url"].split("{", 1)[0]
    url = f"{upload_base}?name={urllib.parse.quote(name)}"
    raw = _request("POST", url, token, data=data, content_type=ctype)
    return json.loads(raw.decode("utf-8"))


def _load_index(release: dict, token: str) -> dict:
    """Descarga el índice actual (proyectos.json) o devuelve uno vacío."""
    for asset in release.get("assets", []):
        if asset.get("name") == INDEX_NAME:
            try:
                raw = _request("GET", asset["url"], token,
                               accept="application/octet-stream")
                return json.loads(raw.decode("utf-8"))
            except Exception:  # noqa: BLE001
                break
    return {"version": 1, "projects": []}


def publish_project(project_dir: Path, token: str, *, genre=None,
                    instruments=None, log=print):
    """Publica un proyecto a la Release. Devuelve (ok, mensaje).

    project_dir: carpeta con instrumental.wav, melody.json y meta.json.
    """
    project_dir = Path(project_dir)
    instrumental = project_dir / "instrumental.wav"
    if not instrumental.exists():
        return False, "No encontré instrumental.wav en la carpeta del proyecto."

    meta = {}
    meta_path = project_dir / "meta.json"
    if meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            meta = {}
    title = meta.get("title") or project_dir.name
    instrument = meta.get("instrument", "voz")
    ref_kind = meta.get("referenceKind", "melody")
    # El id incluye el instrumento: así conviven en el celular la voz, la
    # batería, el bajo, etc. de la misma canción (sin pisarse).
    slug = f"{_slug(title)}-{instrument}"
    # Etiqueta de instrumento para mostrar en el celular.
    instrument_label = {
        "voz": "Voz",
        "bateria": "Batería",
        "bajo": "Bajo",
        "otros": "Otros",
    }.get(instrument, "Voz")

    melody = project_dir / "melody.json"
    rhythm = project_dir / "rhythm.json"
    lyrics = project_dir / "lyrics.json"

    log("Conectando con GitHub...")
    try:
        release = get_or_create_release(token)
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return False, (f"GitHub rechazó el token ({exc.code}). "
                           "Necesitás un token con permiso de escritura del repo.")
        return False, f"Error de GitHub ({exc.code})."
    except Exception as exc:  # noqa: BLE001
        return False, f"No pude conectar (¿internet?): {exc}"

    try:
        entry = {
            "id": slug,
            "title": title,
            "genre": genre,
            "instrument": instrument,
            "referenceKind": ref_kind,
            "instruments": instruments or [instrument_label],
        }

        log(f"Subiendo instrumental de '{title}'...")
        name_inst = f"{slug}__instrumental.wav"
        _upload_asset(release, instrumental, name_inst, token)
        entry["instrumental"] = name_inst

        if melody.exists():
            log("Subiendo melodía de referencia...")
            name_mel = f"{slug}__melody.json"
            _upload_asset(release, melody, name_mel, token)
            entry["melody"] = name_mel

        if rhythm.exists():
            log("Subiendo referencia de ritmo...")
            name_rhy = f"{slug}__rhythm.json"
            _upload_asset(release, rhythm, name_rhy, token)
            entry["rhythm"] = name_rhy

        if lyrics.exists():
            log("Subiendo la letra...")
            name_ly = f"{slug}__lyrics.json"
            _upload_asset(release, lyrics, name_ly, token)
            entry["lyrics"] = name_ly

        log("Actualizando el índice de proyectos...")
        # Recargamos la release para tener los assets recién subidos.
        release = get_or_create_release(token)
        index = _load_index(release, token)
        projects = [p for p in index.get("projects", []) if p.get("id") != slug]
        projects.insert(0, entry)
        index["projects"] = projects
        _upload_bytes(release, json.dumps(index, ensure_ascii=False).encode("utf-8"),
                      INDEX_NAME, token, "application/json")
    except urllib.error.HTTPError as exc:
        return False, f"Falló la subida (GitHub {exc.code})."
    except Exception as exc:  # noqa: BLE001
        return False, f"Falló la publicación: {exc}"

    return True, f"Listo: '{title}' ya está disponible para sincronizar en el celular."
