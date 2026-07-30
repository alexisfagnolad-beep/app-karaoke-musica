"""App de escritorio (ventana con botones) para procesar canciones en la PC.

No usa la terminal: abrís la ventana, elegís una canción y hace todo solo
(separar la voz con Demucs + extraer la melodía de referencia), mostrando el
progreso. Usa Tkinter, que viene incluido con Python.

Se lanza con `Karaoke.bat` (doble clic).
"""

import json
import os
import queue
import shutil
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
        self.bg = "#12101A"
        self.panel = "#1C1926"
        self.accent = "#7C4DFF"
        self.teal = "#1DB6A2"
        self.muted = "#B9B4C7"

        root.title("Karaoke — Procesador (PC)")
        root.geometry("760x620")
        root.configure(bg=self.bg)
        root.minsize(660, 560)

        # Estilo de la barra de progreso.
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("Karaoke.Horizontal.TProgressbar",
                        troughcolor=self.panel, background=self.accent,
                        bordercolor=self.panel, lightcolor=self.accent,
                        darkcolor=self.accent)

        self._label_to_key = {
            "🎤  Voz (cantar)": "voz",
            "🥁  Batería (ritmo)": "bateria",
            "🎸  Bajo": "bajo",
            "🎹  Otros (guitarra/teclado)": "otros",
        }
        self.instrument = tk.StringVar(value="🎤  Voz (cantar)")

        # --- Navegación entre vistas ---
        self._current = None
        self._history = []
        self._forward = []
        self._views = {}

        self._build_header()
        self._container = tk.Frame(root, bg=self.bg)
        self._container.pack(fill="both", expand=True)
        self._build_home()
        self._build_procesar()
        self._build_proyectos()
        self._display("home")

        self.root.after(100, self._drain)

    # ---- barra superior con navegación ----
    def _build_header(self):
        header = tk.Frame(self.root, bg=self.accent)
        header.pack(fill="x")

        nav = tk.Frame(header, bg=self.accent)
        nav.pack(fill="x", padx=16, pady=(10, 0))
        self.back_btn = tk.Button(
            nav, text="←", font=("Segoe UI", 14, "bold"), fg="white",
            bg=self.accent, activebackground="#6A3EF0", activeforeground="white",
            disabledforeground="#B9A9FF", relief="flat", bd=0, cursor="hand2",
            width=3, command=self.go_back)
        self.back_btn.pack(side="left")
        self.fwd_btn = tk.Button(
            nav, text="→", font=("Segoe UI", 14, "bold"), fg="white",
            bg=self.accent, activebackground="#6A3EF0", activeforeground="white",
            disabledforeground="#B9A9FF", relief="flat", bd=0, cursor="hand2",
            width=3, command=self.go_forward)
        self.fwd_btn.pack(side="left")

        # Título clickeable: vuelve al inicio.
        self.title_lbl = tk.Label(
            nav, text="🎤  Karaoke — Procesador",
            font=("Segoe UI", 18, "bold"), fg="white", bg=self.accent,
            cursor="hand2")
        self.title_lbl.pack(side="left", padx=(12, 0))
        self.title_lbl.bind("<Button-1>", lambda e: self.go_home())

        self.subtitle = tk.Label(
            header, text="", font=("Segoe UI", 10), fg="#EDE9FF", bg=self.accent)
        self.subtitle.pack(anchor="w", padx=24, pady=(2, 14))

    def _display(self, name: str):
        for view in self._views.values():
            view.pack_forget()
        self._views[name].pack(fill="both", expand=True)
        self._current = name
        self._update_nav()
        if name == "proyectos":
            self._refresh_proyectos()

    def navigate(self, name: str):
        if name == self._current:
            return
        if self._current is not None:
            self._history.append(self._current)
        self._forward.clear()
        self._display(name)

    def go_back(self):
        if not self._history:
            return
        self._forward.append(self._current)
        self._display(self._history.pop())

    def go_forward(self):
        if not self._forward:
            return
        self._history.append(self._current)
        self._display(self._forward.pop())

    def go_home(self):
        self.navigate("home")

    def _update_nav(self):
        self.back_btn.configure(state="normal" if self._history else "disabled")
        self.fwd_btn.configure(state="normal" if self._forward else "disabled")
        subtitles = {
            "home": "Separo la voz, dejo la pista lista y la envío al celular.",
            "procesar": "Elegí el instrumento y la canción para procesar.",
            "proyectos": "Tus canciones procesadas: envialas, abrilas o borralas.",
        }
        self.subtitle.configure(text=subtitles.get(self._current, ""))

    # ---- vista: inicio ----
    def _home_button(self, parent, text, color, command, hover):
        b = tk.Button(parent, text=text, font=("Segoe UI", 13, "bold"),
                      fg="white", bg=color, activebackground=hover,
                      activeforeground="white", relief="flat", bd=0,
                      cursor="hand2", command=command, width=30, pady=13)
        b.pack(pady=7)
        return b

    def _build_home(self):
        v = tk.Frame(self._container, bg=self.bg)
        self._views["home"] = v
        inner = tk.Frame(v, bg=self.bg)
        inner.pack(expand=True)
        tk.Label(inner, text="¿Qué querés hacer?",
                 font=("Segoe UI", 15, "bold"), fg="white",
                 bg=self.bg).pack(pady=(24, 18))
        self._home_button(inner, "🎵  Procesar una canción", self.accent,
                          lambda: self.navigate("procesar"), "#6A3EF0")
        self._home_button(inner, "🗂️  Proyectos", self.teal,
                          lambda: self.navigate("proyectos"), "#159E8C")
        self.update_btn = self._home_button(
            inner, "🔄  Actualizar app", self.panel, self.update_app, "#272334")
        self.token_btn = self._home_button(
            inner, "🔑  Cambiar token de GitHub", self.panel,
            self.change_token, "#272334")

    # ---- vista: procesar ----
    def _build_procesar(self):
        v = tk.Frame(self._container, bg=self.bg)
        self._views["procesar"] = v
        content = tk.Frame(v, bg=self.bg)
        content.pack(fill="both", expand=True, padx=24, pady=18)

        picker = tk.Frame(content, bg=self.bg)
        picker.pack(fill="x", pady=(0, 12))
        tk.Label(picker, text="Instrumento a practicar:",
                 font=("Segoe UI", 10), fg=self.muted, bg=self.bg).pack(
            side="left")
        self.instrument_menu = tk.OptionMenu(
            picker, self.instrument, *self._label_to_key.keys())
        self.instrument_menu.configure(
            font=("Segoe UI", 10, "bold"), bg=self.panel, fg="white",
            activebackground="#272334", activeforeground="white",
            relief="flat", bd=0, highlightthickness=0, cursor="hand2",
            width=28, anchor="w")
        self.instrument_menu["menu"].configure(bg=self.panel, fg="white")
        self.instrument_menu.pack(side="left", padx=(10, 0))

        self.btn = tk.Button(content, text="🎵  Elegir canción y procesar",
                             font=("Segoe UI", 13, "bold"),
                             bg=self.accent, fg="white",
                             activebackground="#6A3EF0",
                             activeforeground="white", relief="flat",
                             padx=18, pady=12, cursor="hand2", bd=0,
                             command=self.choose)
        self.btn.pack(fill="x")

        self.status_var = tk.StringVar(value="")
        self.status_lbl = tk.Label(
            content, textvariable=self.status_var, font=("Segoe UI", 10),
            fg=self.muted, bg=self.bg, anchor="w", justify="left")
        self.status_lbl.pack(fill="x", pady=(10, 0))

        self.progress = ttk.Progressbar(
            content, mode="indeterminate",
            style="Karaoke.Horizontal.TProgressbar")
        self.progress.pack(fill="x", pady=(14, 10))

        self.log = tk.Text(content, height=12, state="disabled",
                           font=("Consolas", 9), bg=self.panel, fg="#D7D3E0",
                           relief="flat", padx=12, pady=10,
                           insertbackground="white", highlightthickness=0)
        self.log.pack(fill="both", expand=True)

        actions = tk.Frame(content, bg=self.bg)
        actions.pack(fill="x", pady=(12, 0))
        self.open_btn = tk.Button(actions, text="📂  Abrir carpeta",
                                  font=("Segoe UI", 11), state="disabled",
                                  bg=self.panel, fg="white",
                                  activebackground="#272334",
                                  activeforeground="white", relief="flat",
                                  padx=12, pady=8, cursor="hand2", bd=0,
                                  command=self.open_folder)
        self.open_btn.pack(side="left", expand=True, fill="x", padx=(0, 6))
        self.publish_btn = tk.Button(actions, text="📲  Enviar al celular",
                                     font=("Segoe UI", 11, "bold"),
                                     state="disabled", bg=self.teal, fg="white",
                                     activebackground="#159E8C",
                                     activeforeground="white", relief="flat",
                                     padx=12, pady=8, cursor="hand2", bd=0,
                                     command=self.publish)
        self.publish_btn.pack(side="left", expand=True, fill="x", padx=(6, 0))

    # ---- vista: proyectos ----
    def _build_proyectos(self):
        v = tk.Frame(self._container, bg=self.bg)
        self._views["proyectos"] = v
        content = tk.Frame(v, bg=self.bg)
        content.pack(fill="both", expand=True, padx=24, pady=18)

        tk.Label(content, text="Canciones procesadas",
                 font=("Segoe UI", 13, "bold"), fg="white", bg=self.bg).pack(
            anchor="w", pady=(0, 8))

        self.proj_list = tk.Listbox(
            content, font=("Segoe UI", 11), bg=self.panel, fg="white",
            selectbackground=self.accent, selectforeground="white",
            relief="flat", highlightthickness=0, activestyle="none")
        self.proj_list.pack(fill="both", expand=True)

        self.proj_empty = tk.Label(
            content, text="Todavía no procesaste ninguna canción.",
            font=("Segoe UI", 10), fg=self.muted, bg=self.bg)

        actions = tk.Frame(content, bg=self.bg)
        actions.pack(fill="x", pady=(12, 0))

        def act(text, color, hover, command):
            b = tk.Button(actions, text=text, font=("Segoe UI", 10, "bold"),
                          fg="white", bg=color, activebackground=hover,
                          activeforeground="white", relief="flat", bd=0,
                          cursor="hand2", pady=8, command=command)
            b.pack(side="left", expand=True, fill="x", padx=3)
            return b

        act("📲 Enviar", self.teal, "#159E8C", self._proj_publish)
        act("📂 Abrir", self.panel, "#272334", self._proj_open)
        act("🔁 Otro instrumento", self.panel, "#272334", self._proj_reprocess)
        act("🗑 Borrar", "#8A2740", "#A02F4C", self._proj_delete)

    def _list_projects(self):
        base = HERE / "proyectos"
        if not base.exists():
            return []
        out = []
        for d in sorted(base.iterdir()):
            if d.is_dir() and (d / "meta.json").exists():
                out.append(d)
        return out

    def _refresh_proyectos(self):
        self._project_dirs = self._list_projects()
        self.proj_list.delete(0, "end")
        labels = {"voz": "Voz", "bateria": "Batería", "bajo": "Bajo",
                  "otros": "Otros"}
        for d in self._project_dirs:
            title = d.name
            inst = ""
            try:
                meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
                title = meta.get("title", d.name)
                inst = labels.get(meta.get("instrument", ""), "")
            except Exception:  # noqa: BLE001
                pass
            self.proj_list.insert("end", f"{title}   —   {inst}")
        if self._project_dirs:
            self.proj_empty.pack_forget()
            self.proj_list.selection_clear(0, "end")
            self.proj_list.selection_set(0)
        else:
            self.proj_empty.pack(pady=8)

    def _selected_project(self):
        sel = self.proj_list.curselection()
        if not sel:
            messagebox.showinfo("Proyectos", "Elegí una canción de la lista.")
            return None
        return self._project_dirs[sel[0]]

    def _proj_publish(self):
        d = self._selected_project()
        if d is not None:
            self.navigate("procesar")  # para ver el progreso/log.
            self._do_publish(d)

    def _proj_open(self):
        d = self._selected_project()
        if d is not None:
            try:
                os.startfile(str(d))  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass

    def _proj_delete(self):
        d = self._selected_project()
        if d is None:
            return
        if messagebox.askyesno(
                "Borrar", f"¿Borrar el proyecto '{d.name}' del disco?"):
            try:
                shutil.rmtree(d, ignore_errors=True)
            except Exception:  # noqa: BLE001
                pass
            self._refresh_proyectos()

    def _proj_reprocess(self):
        d = self._selected_project()
        if d is None:
            return
        instrument = self._ask_instrument()
        if not instrument:
            return
        self.navigate("procesar")
        self.project = None
        self.btn.configure(state="disabled")
        self.open_btn.configure(state="disabled")
        self.publish_btn.configure(state="disabled")
        self.progress.start(12)
        threading.Thread(target=self._run_project, args=(d, instrument),
                         daemon=True).start()

    def _ask_instrument(self):
        """Modal para elegir instrumento. Devuelve la key o None."""
        win = tk.Toplevel(self.root)
        win.title("Instrumento")
        win.configure(bg=self.bg)
        win.transient(self.root)
        win.grab_set()
        result = {"key": None}
        tk.Label(win, text="¿Qué instrumento querés practicar?",
                 font=("Segoe UI", 12, "bold"), fg="white", bg=self.bg).pack(
            padx=24, pady=(18, 12))
        for label, key in self._label_to_key.items():
            tk.Button(
                win, text=label, font=("Segoe UI", 11, "bold"), fg="white",
                bg=self.panel, activebackground="#272334",
                activeforeground="white", relief="flat", bd=0, cursor="hand2",
                width=28, pady=8,
                command=lambda k=key: (result.__setitem__("key", k),
                                       win.destroy())).pack(padx=24, pady=4)
        tk.Button(win, text="Cancelar", font=("Segoe UI", 9), fg=self.muted,
                  bg=self.bg, activebackground=self.bg, relief="flat", bd=0,
                  cursor="hand2", command=win.destroy).pack(pady=(4, 16))
        win.wait_window()
        return result["key"]

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
            self._extract_reference(self.project, instrument)
        except Exception as exc:  # noqa: BLE001
            self.logln(f"Error: {exc}")
        finally:
            self.root.after(0, self._done)

    def _run_project(self, project_dir, instrument: str):
        """Reprocesa OTRO instrumento de un proyecto ya separado (usa el caché)."""
        try:
            project_dir = Path(project_dir)
            self.logln(f"Reprocesando: {project_dir.name}  (instrumento: {instrument})")
            self.logln("[1/2] Reusando la separación en caché (sin Demucs)...")
            rc = self._stream([PY, str(HERE / "separate.py"),
                               "--project", str(project_dir),
                               "--instrument", instrument])
            if rc != 0:
                self.logln("")
                self.logln("⚠️  No se pudo reprocesar (¿falta el caché?).")
                return
            self.project = project_dir
            self._extract_reference(project_dir, instrument)
        except Exception as exc:  # noqa: BLE001
            self.logln(f"Error: {exc}")
        finally:
            self.root.after(0, self._done)

    def _extract_reference(self, project_dir, instrument: str):
        """Extrae la referencia (melodía o ritmo) y, para voz, la letra."""
        ref_kind = "melody"
        try:
            meta = json.loads(
                (Path(project_dir) / "meta.json").read_text(encoding="utf-8"))
            ref_kind = meta.get("referenceKind", "melody")
        except Exception:  # noqa: BLE001
            pass

        self.logln("")
        if ref_kind == "rhythm":
            self.logln("[2/2] Extrayendo la referencia de ritmo...")
            self._stream([PY, str(HERE / "rhythm.py"), str(project_dir)])
        else:
            self.logln("[2/3] Extrayendo la melodía de referencia...")
            self._stream([PY, str(HERE / "melody.py"), str(project_dir)])
            if instrument == "voz":
                self.logln("")
                self.logln("[3/3] Transcribiendo la letra (Whisper)...")
                self.logln("      La 1ª vez baja el modelo; puede tardar.")
                rc_ly = self._stream(
                    [PY, str(HERE / "lyrics.py"), str(project_dir)])
                if rc_ly == 2:
                    self.logln("      (Sin letra esta vez; el resto quedó OK.)")
        self.logln("")
        self.logln("✅ ¡Listo! Ya podés abrir la carpeta del resultado.")

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
        self._do_publish(self.project)

    def _do_publish(self, project):
        if project is None:
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
        self.logln(f"Enviando al celular: {Path(project).name} ...")

        def work():
            ok, msg = publicar.publish_project(project, token, log=self.logln)

            def done():
                self.progress.stop()
                self.publish_btn.configure(state="normal")
                self.logln(msg)
                if ok:
                    messagebox.showinfo(
                        "Enviar al celular",
                        msg + "\n\nEn el celular se baja sola al abrir la app "
                        "(o entrá a 'Sincronizar con la PC').")
                elif publicar.is_token_error(msg):
                    # El token guardado no sirve: lo borramos y ofrecemos cambiarlo.
                    self._forget_token()
                    if messagebox.askyesno(
                            "Enviar al celular",
                            msg + "\n\n¿Querés pegar un token nuevo ahora?"):
                        if self._get_token():
                            self._do_publish(project)  # reintenta.
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
