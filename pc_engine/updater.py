"""Auto-actualizador del motor de PC.

Descarga el repositorio (zipball autenticado, para repo privado) usando un
token de GitHub y reemplaza los scripts de `pc_engine` en el disco, SIN tocar
el entorno (`.venv`), los proyectos ni el token guardado.

Solo usa la librería estándar (urllib, zipfile), sin dependencias extra.
"""

import io
import ssl
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

OWNER = "alexisfagnolad-beep"
REPO = "app-karaoke-musica"
BRANCH = "claude/charming-thompson-21cbj2"

# Carpetas/archivos locales que NUNCA se sobrescriben al actualizar.
SKIP_TOP = {".venv", "proyectos", "token.txt", "__pycache__"}


def zipball_url() -> str:
    return f"https://api.github.com/repos/{OWNER}/{REPO}/zipball/{BRANCH}"


def _apply_zip(data: bytes, dest_dir: Path) -> int:
    """Extrae los archivos de pc_engine del zipball sobre dest_dir.
    Devuelve la cantidad de archivos actualizados."""
    zf = zipfile.ZipFile(io.BytesIO(data))
    count = 0
    for name in zf.namelist():
        # GitHub arma nombres tipo:  owner-repo-<sha>/pc_engine/archivo
        parts = name.split("/")
        if len(parts) < 3 or parts[1] != "pc_engine":
            continue
        rel = "/".join(parts[2:])
        if not rel:
            continue
        if rel.split("/")[0] in SKIP_TOP:
            continue
        target = dest_dir / rel
        if name.endswith("/"):
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(name) as src, open(target, "wb") as out:
            out.write(src.read())
        count += 1
    return count


def download_and_apply(token: str, dest_dir: Path):
    """Descarga y aplica la última versión. Devuelve (ok: bool, mensaje: str)."""
    token = (token or "").strip()
    if not token:
        return False, "Falta el token de GitHub."

    request = urllib.request.Request(
        zipball_url(),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "karaoke-pc-updater",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        ctx = ssl.create_default_context()
        with urllib.request.urlopen(request, timeout=90, context=ctx) as resp:
            data = resp.read()
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return False, (
                f"GitHub rechazó el token ({exc.code}). Revisá que sea válido "
                "y tenga permiso de lectura del repositorio."
            )
        return False, f"Error de GitHub ({exc.code})."
    except Exception as exc:  # noqa: BLE001
        return False, f"No se pudo descargar (¿internet?): {exc}"

    try:
        count = _apply_zip(data, dest_dir)
    except Exception as exc:  # noqa: BLE001
        return False, f"No se pudo aplicar la actualización: {exc}"

    if count == 0:
        return False, "No encontré archivos para actualizar en el paquete."
    return True, f"Listo: {count} archivos actualizados. Cerrá y volvé a abrir la app."
