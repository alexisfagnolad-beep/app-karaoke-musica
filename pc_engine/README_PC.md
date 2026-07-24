# Karaoke PC — motor de calidad (Demucs)

App de escritorio que separa la voz de tus canciones con calidad real (Demucs)
y prepara la melodía de referencia para el puntaje. **Un solo lanzador que se
instala solo.**

## Requisito (una vez)

Tener **Python 3.11** instalado (https://www.python.org/downloads/, marcando
**"Add Python to PATH"**). Nada más.

## Usar (dead simple)

1. Poné la carpeta **`pc_engine`** en una ruta corta, por ejemplo **`C:\Karaoke`**.
2. Doble clic en **`Karaoke.bat`**.
   - **La primera vez** se prepara solo (crea el entorno e instala Demucs;
     puede tardar unos minutos). Si se corta por la red, volvé a hacer doble
     clic: retoma.
   - **Las siguientes veces** abre directo la **app** (ventana con botones).
3. En la app: **"Elegir canción y procesar"** → elegí un MP3 → esperá →
   **"Abrir carpeta del resultado"**.

## Resultado

Por cada canción, una carpeta en `proyectos\<nombre>\`:

```
instrumental.wav   ← para cantar encima (voz separada, sin lo metálico)
vocals.wav         ← voz aislada
melody.json        ← melodía de referencia (para el puntaje)
meta.json          ← datos del proyecto
```

## Notas

- Todo corre **local**, sin nube.
- La 1ª canción baja el modelo de Demucs (~unos cientos de MB), una sola vez.
- En CPU cada canción tarda varios minutos; con GPU NVIDIA, menos.
- `instalar.bat` / `procesar.bat` quedan como alternativas por línea de
  comandos, pero con `Karaoke.bat` no hacen falta.
