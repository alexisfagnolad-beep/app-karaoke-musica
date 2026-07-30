"""App de escritorio (ventana con botones) para procesar canciones en la PC.

No usa la terminal: abrís la ventana, elegís una canción y hace todo solo
(separar la voz con Demucs + extraer la melodía de referencia), mostrando el
progreso. Usa Tkinter, que viene incluido con Python.

Se lanza con `Karaoke.bat` (doble clic).
"""

import json
import os
import queue
import subprocess
import sys
import threading
from pathlib import Path

import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

import publicar
import updater

HERE = Path(__file__).resolve().parent
TOKEN_FILE = HERE / "token.txt"


def _console_python() -> str:
    """Devuelve el python.exe (con consola). La app corre con pythonw.exe,
    pero Demucs/torch fallan bajo pythonw, así que los subprocesos deben usar
    python.exe."""
    candidate = Path(sys.executable).with_name("python.exe")
    return str(candidate) if candidate.exists() else sys.executable


PY = _console_python()


class KaraokeApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.project = None
        self._msgs: "queue.Queue[str]" = queue.Queue()

        # Paleta (misma identidad que la app del celular).
        bg = "#12101A"
        panel = "#1C1926"
        accent = "#7C4DFF"
        teal = "#1DB6A2"
        muted = "#B9B4C7"

        root.title("Karaoke — Procesador (PC)")
        root.geometry("720x580")
        root.configure(bg=bg)
        root.minsize(640, 520)

        # Estilo de la barra de progreso.
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("Karaoke.Horizontal.TProgressbar",
                        troughcolor=panel, background=accent,
                        bordercolor=panel, lightcolor=accent, darkcolor=accent)

        # --- Encabezado con banda de color ---
        header = tk.Frame(root, bg=accent)
        header.pack(fill="x")
        tk.Label(header, text="🎤  Karaoke — Procesador",
                 font=("Segoe UI", 18, "bold"),
                 fg="white", bg=accent).pack(anchor="w", padx=24, pady=(18, 2))
        tk.Label(header,
                 text="Separo la voz, dejo la pista lista para cantar y la envío al celular.",
                 font=("Segoe UI", 10), fg="#EDE9FF", bg=accent).pack(
            anchor="w", padx=24, pady=(0, 16))

        # --- Contenido ---
        content = tk.Frame(root, bg=bg)
        content.pack(fill="both", expand=True, padx=24, pady=18)

        # Selector de instrumento a practicar (el valor visible es la etiqueta;
        # _instrument_key() la traduce al id que entiende el motor).
        self._label_to_key = {
            "🎤  Voz (cantar)": "voz",
            "🥁  Batería (ritmo)": "bateria",
            "🎸  Bajo": "bajo",
            "🎹  Otros (guitarra/teclado)": "otros",
        }
        self.instrument = tk.StringVar(value="🎤  Voz (cantar)")
        picker = tk.Frame(content, bg=bg)
        picker.pack(fill="x", pady=(0, 12))
        tk.Label(picker, text="Instrumento a practicar:",
                 font=("Segoe UI", 10), fg=muted, bg=bg).pack(side="left")
        self.instrument_menu = tk.OptionMenu(
            picker, self.instrument, *self._label_to_key.keys())
        self.instrument_menu.configure(
            font=("Segoe UI", 10, "bold"), bg=panel, fg="white",
            activebackground="#272334", activeforeground="white",
            relief="flat", bd=0, highlightthickness=0, cursor="hand2",
            width=28, anchor="w")
        self.instrument_menu["menu"].configure(bg=panel, fg="white")
        self.instrument_menu.pack(side="left", padx=(10, 0))

        self.btn = tk.Button(content, text="🎵  Elegir canción y procesar",
                             font=("Segoe UI", 13, "bold"),
                             bg=accent, fg="white", activebackground="#6A3EF0",
                             activeforeground="white", relief="flat",
                             padx=18, pady=12, cursor="hand2", bd=0,
                             command=self.choose)
        self.btn.pack(fill="x")

        # Línea de estado: avisa si la canción ya está separada (caché).
        self.status_var = tk.StringVar(value="")
        self.status_lbl = tk.Label(
            content, textvariable=self.status_var, font=("Segoe UI", 10),
            fg=muted, bg=bg, anchor="w", justify="left")
        self.status_lbl.pack(fill="x", pady=(10, 0))

        self.progress = ttk.Progressbar(
            content, mode="indeterminate",
            style="Karaoke.Horizontal.TProgressbar")
        self.progress.pack(fill="x", pady=(14, 10))

        self.log = tk.Text(content, height=13, state="disabled",
                           font=("Consolas", 9), bg=panel, fg="#D7D3E0",
                           relief="flat", padx=12, pady=10,
                           insertbackground="white", highlightthickness=0)
        self.log.pack(fill="both", expand=True)

        # --- Acciones secundarias ---
        actions = tk.Frame(content, bg=bg)
        actions.pack(fill="x", pady=(12, 0))

        self.open_btn = tk.Button(actions, text="📂  Abrir carpeta",
                                  font=("Segoe UI", 11), state="disabled",
                                  bg=panel, fg="white", activebackground="#272334",
                                  activeforeground="white", relief="flat",
                                  padx=12, pady=8, cursor="hand2", bd=0,
                                  command=self.open_folder)
        self.open_btn.pack(side="left", expand=True, fill="x", padx=(0, 6))

        self.publish_btn = tk.Button(actions, text="📲  Enviar al celular",
                                     font=("Segoe UI", 11, "bold"), state="disabled",
                                     bg=teal, fg="white",
                                     activebackground="#159E8C",
                                     activeforeground="white", relief="flat",
                                     padx=12, pady=8, cursor="hand2", bd=0,
                                     command=self.publish)
        self.publish_btn.pack(side="left", expand=True, fill="x", padx=(6, 0))

        links = tk.Frame(content, bg=bg)
        links.pack(pady=(10, 0))
        self.update_btn = tk.Button(links, text="🔄  Actualizar app",
                                    font=("Segoe UI", 9), fg=muted,
                                    bg=bg, activebackground=bg,
                                    activeforeground="white", relief="flat",
                                    cursor="hand2", bd=0, command=self.update_app)
        self.update_btn.pack(side="left", padx=(0, 16))
        self.token_btn = tk.Button(links, text="🔑  Cambiar token",
                                   font=("Segoe UI", 9), fg=muted,
                                   bg=bg, activebackground=bg,
                                   activeforeground="white", relief="flat",
                                   cursor="hand2", bd=0, command=self.change_token)
        self.token_btn.pack(side="left")

        self.root.after(100, self._drain)

    # ---- log en pantalla (desde el hilo de trabajo) ----
    def logln(self, text: str):
        self._msgs.put(text)

    def _drain(self):
        try:
            while True:
                line = self._msgs.get_nowait()
                self.log.configure(state="normal")
                self.log.insert("end", line + "\n")
                self.log.see("end")
                self.log.configure(state="disabled")
        except queue.Empty:
            pass
        self.root.after(100, self._drain)

    # ---- acciones ----
    def _instrument_key(self) -> str:
        return self._label_to_key.get(self.instrument.get(), "voz")

    def _is_cached(self, path: str) -> bool:
        """True si la canción ya tiene las 4 pistas separadas en caché."""
        stems = HERE / "proyectos" / Path(path).stem / "stems"
        return stems.is_dir() and all(
            (stems / f"{s}.wav").exists()
            for s in ("drums", "bass", "other", "vocals"))

    def choose(self):
        path = filedialog.askopenfilename(
            title="Elegí una canción",
            filetypes=[("Audio", "*.mp3 *.wav *.m4a *.flac *.ogg"),
                       ("Todos los archivos", "*.*")],
        )
        if not path:
            return
        if self._is_cached(path):
            self.status_var.set(
                "✓ Ya separada (caché): cambiar de instrumento es casi "
                "instantáneo.")
            self.status_lbl.configure(fg="#4AE3B5")
        else:
            self.status_var.set(
                "🕒 Primera vez para esta canción: la separación puede "
                "tardar unos minutos.")
            self.status_lbl.configure(fg="#FFB74D")
        self.project = None
        self.btn.configure(state="disabled")
        self.open_btn.configure(state="disabled")
        self.publish_btn.configure(state="disabled")
        self.progress.start(12)
        instrument = self._instrument_key()
        threading.Thread(target=self._run, args=(path, instrument),
                         daemon=True).start()

    def _stream(self, cmd) -> int:
        # Forzamos UTF-8 en el proceso hijo para evitar UnicodeEncodeError
        # en consolas en español (cp1252) al imprimir símbolos.
        env = os.environ.copy()
        env["PYTHONUTF8"] = "1"
        env["PYTHONIOENCODING"] = "utf-8"
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", cwd=str(HERE),
            env=env,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            self.logln(line.rstrip())
        proc.wait()
        return proc.returncode

    def _run(self, path: str, instrument: str = "voz"):
        try:
            inp = Path(path)
            projects = HERE / "proyectos"
            self.logln(f"Procesando: {inp.name}  (instrumento: {instrument})")
            self.logln("[1/2] Separando pistas (Demucs)...")
            self.logln("      La 1ª vez baja el modelo; si se corta por la red,")
            self.logln("      volvé a tocar 'Elegir canción' (retoma lo bajado).")
            if instrument != "voz":
                self.logln("      (separar 4 pistas tarda más que solo la voz)")
            rc = self._stream([PY, str(HERE / "separate.py"), str(inp),
                               "-o", str(projects), "--instrument", instrument])
            if rc != 0:
                self.logln("")
                self.logln("⚠️  La separación no terminó. Probá de nuevo.")
                return
            self.project = projects / inp.stem

            # Tipo de referencia según lo que dejó separate.py en meta.json.
            ref_kind = "melody"
            try:
                meta = json.loads(
                    (self.project / "meta.json").read_text(encoding="utf-8"))
                ref_kind = meta.get("referenceKind", "melody")
            except Exception:  # noqa: BLE001
                pass

            self.logln("")
            if ref_kind == "rhythm":
                self.logln("[2/2] Extrayendo la referencia de ritmo...")
                self._stream([PY, str(HERE / "rhythm.py"), str(self.project)])
            else:
                self.logln("[2/3] Extrayendo la melodía de referencia...")
                self._stream([PY, str(HERE / "melody.py"), str(self.project)])
                # La letra solo tiene sentido para la voz.
                if instrument == "voz":
                    self.logln("")
                    self.logln("[3/3] Transcribiendo la letra (Whisper)...")
                    self.logln("      La 1ª vez baja el modelo; puede tardar.")
                    rc_ly = self._stream(
                        [PY, str(HERE / "lyrics.py"), str(self.project)])
                    if rc_ly == 2:
                        self.logln("      (Sin letra esta vez; el resto quedó OK.)")
            self.logln("")
            self.logln("✅ ¡Listo! Ya podés abrir la carpeta del resultado.")
        except Exception as exc:  # noqa: BLE001
            self.logln(f"Error: {exc}")
        finally:
            self.root.after(0, self._done)

    def _done(self):
        self.progress.stop()
        self.btn.configure(state="normal")
        if self.project is not None:
            self.open_btn.configure(state="normal")
            self.publish_btn.configure(state="normal")
            # Ya quedó separada: el próximo instrumento será instantáneo.
            self.status_var.set(
                "✓ Separada y en caché: probá otro instrumento y sale al toque.")
            self.status_lbl.configure(fg="#4AE3B5")

    def open_folder(self):
        if self.project is not None:
            try:
                os.startfile(str(self.project))  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass

    # ---- publicar al celular (auto-sync por GitHub) ----
    def publish(self):
        if self.project is None:
            return
        token = self._get_token()
        if not token:
            messagebox.showwarning(
                "Enviar al celular",
                "Necesito un token de GitHub (con permiso de escritura) para "
                "subir el proyecto. El mismo que usás para actualizar.")
            return
        self.publish_btn.configure(state="disabled")
        self.progress.start(12)
        self.logln("")
        self.logln("Enviando al celular (subiendo a GitHub)...")
        project = self.project

        def work():
            ok, msg = publicar.publish_project(project, token, log=self.logln)

            def done():
                self.progress.stop()
                self.publish_btn.configure(state="normal")
                self.logln(msg)
                if ok:
                    messagebox.showinfo(
                        "Enviar al celular",
                        msg + "\n\nAbrí la app en el celular y tocá "
                        "'Sincronizar con la PC'.")
                elif publicar.is_token_error(msg):
                    # El token guardado no sirve: lo borramos y ofrecemos cambiarlo.
                    self._forget_token()
                    if messagebox.askyesno(
                            "Enviar al celular",
                            msg + "\n\n¿Querés pegar un token nuevo ahora?"):
                        if self._get_token():
                            self.publish()  # reintenta con el token nuevo.
                else:
                    messagebox.showwarning("Enviar al celular", msg)

            self.root.after(0, done)

        threading.Thread(target=work, daemon=True).start()

    # ---- token de GitHub ----
    def change_token(self):
        """Borra el token guardado y pide uno nuevo."""
        self._forget_token()
        if self._get_token():
            messagebox.showinfo(
                "Cambiar token",
                "Token guardado. Ya podés tocar 'Enviar al celular'.")

    def _forget_token(self) -> None:
        """Borra el token guardado (cuando GitHub lo rechazó)."""
        try:
            if TOKEN_FILE.exists():
                TOKEN_FILE.unlink()
        except Exception:  # noqa: BLE001
            pass

    def _get_token(self) -> str:
        if TOKEN_FILE.exists():
            saved = TOKEN_FILE.read_text(encoding="utf-8").strip()
            if saved:
                return saved
        token = simpledialog.askstring(
            "Token de GitHub",
            "Pegá tu Personal Access Token de GitHub (empieza con 'ghp_' o\n"
            "'github_pat_'), con permiso de escritura del repo.\n"
            "Se guarda solo en esta PC (token.txt), no se comparte.",
            show="*", parent=self.root,
        )
        if token:
            token = token.strip()
            try:
                TOKEN_FILE.write_text(token, encoding="utf-8")
            except Exception:  # noqa: BLE001
                pass
        return token or ""

    def update_app(self):
        # Repo público: actualizar NO usa token. (Un token viejo/inválido
        # guardado rompía la actualización con 401.)
        self.update_btn.configure(state="disabled")
        self.logln("Buscando actualización de la app...")

        def work():
            ok, msg = updater.download_and_apply('', HERE)

            def done():
                self.update_btn.configure(state="normal")
                self.logln(msg)
                if ok:
                    messagebox.showinfo("Actualizar",
                                        msg + "\n\nCerrá y volvé a abrir la app.")
                else:
                    messagebox.showwarning("Actualizar", msg)

            self.root.after(0, done)

        threading.Thread(target=work, daemon=True).start()


def main():
    root = tk.Tk()
    KaraokeApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
