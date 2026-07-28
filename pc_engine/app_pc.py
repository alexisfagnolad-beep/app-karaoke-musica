"""App de escritorio (ventana con botones) para procesar canciones en la PC.

No usa la terminal: abrís la ventana, elegís una canción y hace todo solo
(separar la voz con Demucs + extraer la melodía de referencia), mostrando el
progreso. Usa Tkinter, que viene incluido con Python.

Se lanza con `Karaoke.bat` (doble clic).
"""

import os
import queue
import subprocess
import sys
import threading
from pathlib import Path

import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

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

        root.title("Karaoke — Procesador (PC)")
        root.geometry("680x500")
        root.configure(bg="#12101A")

        tk.Label(root, text="Karaoke — Procesador",
                 font=("Segoe UI", 18, "bold"),
                 fg="white", bg="#12101A").pack(pady=(20, 4))
        tk.Label(root,
                 text="Separo la voz de la canción y la dejo lista para cantar y puntuar.",
                 font=("Segoe UI", 10), fg="#B9B4C7", bg="#12101A").pack()

        self.btn = tk.Button(root, text="🎵  Elegir canción y procesar",
                             font=("Segoe UI", 13, "bold"),
                             bg="#7C4DFF", fg="white", activebackground="#6A3EF0",
                             relief="flat", padx=18, pady=10, cursor="hand2",
                             command=self.choose)
        self.btn.pack(pady=18)

        self.progress = ttk.Progressbar(root, mode="indeterminate", length=600)
        self.progress.pack(pady=4)

        self.log = tk.Text(root, height=15, width=82, state="disabled",
                           font=("Consolas", 9), bg="#1C1926", fg="#D7D3E0",
                           relief="flat")
        self.log.pack(padx=18, pady=12)

        self.open_btn = tk.Button(root, text="📂  Abrir carpeta del resultado",
                                  font=("Segoe UI", 11), state="disabled",
                                  relief="flat", padx=10, pady=6, cursor="hand2",
                                  command=self.open_folder)
        self.open_btn.pack(pady=(0, 6))

        self.update_btn = tk.Button(root, text="🔄  Actualizar app",
                                    font=("Segoe UI", 9), fg="#B9B4C7",
                                    bg="#12101A", activebackground="#12101A",
                                    activeforeground="white", relief="flat",
                                    cursor="hand2", command=self.update_app)
        self.update_btn.pack(pady=(0, 12))

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
    def choose(self):
        path = filedialog.askopenfilename(
            title="Elegí una canción",
            filetypes=[("Audio", "*.mp3 *.wav *.m4a *.flac *.ogg"),
                       ("Todos los archivos", "*.*")],
        )
        if not path:
            return
        self.project = None
        self.btn.configure(state="disabled")
        self.open_btn.configure(state="disabled")
        self.progress.start(12)
        threading.Thread(target=self._run, args=(path,), daemon=True).start()

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

    def _run(self, path: str):
        try:
            inp = Path(path)
            projects = HERE / "proyectos"
            self.logln(f"Procesando: {inp.name}")
            self.logln("[1/2] Separando voz e instrumental (Demucs)...")
            self.logln("      La 1ª vez baja el modelo; si se corta por la red,")
            self.logln("      volvé a tocar 'Elegir canción' (retoma lo bajado).")
            rc = self._stream([PY, str(HERE / "separate.py"), str(inp),
                               "-o", str(projects)])
            if rc != 0:
                self.logln("")
                self.logln("⚠️  La separación no terminó. Probá de nuevo.")
                return
            self.project = projects / inp.stem
            self.logln("")
            self.logln("[2/2] Extrayendo melodía de referencia...")
            self._stream([PY, str(HERE / "melody.py"), str(self.project)])
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

    def open_folder(self):
        if self.project is not None:
            try:
                os.startfile(str(self.project))  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass

    # ---- auto-actualización ----
    def _get_token(self) -> str:
        if TOKEN_FILE.exists():
            saved = TOKEN_FILE.read_text(encoding="utf-8").strip()
            if saved:
                return saved
        token = simpledialog.askstring(
            "Token de GitHub",
            "Pegá tu token de GitHub (el mismo que usás en el celular).\n"
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
        # Repo privado: usa el token guardado, o lo pide la 1ª vez.
        token = self._get_token()
        if not token:
            return
        self.update_btn.configure(state="disabled")
        self.logln("Buscando actualización de la app...")

        def work():
            ok, msg = updater.download_and_apply(token, HERE)

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
