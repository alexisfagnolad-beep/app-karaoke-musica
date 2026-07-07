# Motor de PC — Paso 1: separación de voz (Demucs)

Este motor "cocina" las canciones en la computadora con calidad real: separa la
voz del instrumental con IA (Demucs), **sin** el truco de fase del celular (por
eso no suena metálico). Es la base para el karaoke de calidad y el puntaje.

> Requiere Windows + Python 3.11. Funciona en CPU (más lento) o con GPU NVIDIA
> (mucho más rápido). La primera instalación descarga ~1-2 GB.

## 1. Instalar Python (una vez)

1. Descargá **Python 3.11** desde https://www.python.org/downloads/release/python-3119/
   (bajá "Windows installer 64-bit").
2. Al instalar, **marcá la casilla "Add Python to PATH"**.

## 2. Instalar el motor (una vez)

En la carpeta `pc_engine`, hacé **doble clic en `instalar.bat`**.
- Crea un entorno aislado (`.venv`) e instala Demucs.
- Tarda un rato la primera vez (baja PyTorch y dependencias).
- Al final te dice si tenés GPU NVIDIA (opcional, para acelerar).

## 3. Procesar una canción

Opción fácil: **arrastrá un MP3 sobre `procesar.bat`**.

O desde la terminal, en `pc_engine`:

```bat
procesar.bat "C:\Users\vos\Music\cancion.mp3"
```

La primera canción tarda más porque descarga el modelo de Demucs (~unos cientos
de MB). En CPU, cada canción puede tardar varios minutos; con GPU, bastante menos.

## 4. Resultado

Queda una carpeta por canción en `pc_engine\proyectos\<nombre>\`:

```
instrumental.wav   ← la pista para cantar encima (voz separada)
vocals.wav         ← la voz aislada (servirá para el puntaje)
meta.json          ← datos del proyecto
```

Escuchá `instrumental.wav`: la voz tiene que estar **mucho** más limpia que con
el filtro del celular.

## Qué sigue (próximos pasos del motor)

- **Melodía de referencia**: extraer la afinación de `vocals.wav` a lo largo del
  tiempo → base del sistema de puntaje.
- **Formato de proyecto** portable para pasar al celular.
- **Cola en lote**: procesar varias canciones automáticamente.
- **App de escritorio** con interfaz para todo esto.

## Problemas comunes

- **"python no se reconoce"**: no marcaste "Add Python to PATH". Reinstalá Python
  con esa casilla, o usá el instalador de nuevo.
- **Instalación muy lenta / error de red**: reintentá `instalar.bat`; retoma lo
  descargado.
- **Se queda "procesando" mucho**: en CPU es normal que tarde varios minutos por
  canción. Si querés, después vemos de activar la GPU.
