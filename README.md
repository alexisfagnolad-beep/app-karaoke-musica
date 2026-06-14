# App de Karaoke, Práctica Musical y Transcripción — Guía para Claude Code

> Punto de entrada del proyecto. Leer completo antes de escribir código.

## 1. Qué construimos

Una única app que integra tres usos sobre el mismo motor de audio:
1. Karaoke (entretenimiento).
2. Práctica de instrumentos (canto, batería, bajo, guitarra, piano).
3. Transcripción a partitura con acordes.

Concepto base (tipo afinador Guitar Tuner): acertar notas objetivo en altura (afinación) y duración (ritmo), con retroalimentación en tiempo real.

## 2. Principios que NO se negocian

- Funcionamiento LOCAL, sin nube. Los archivos nunca salen del equipo. Sin servidores, sin costos, funciona sin internet.
- Entrada solo con archivos propios del usuario. NO descargar de YouTube ni Spotify (ilegal / viola términos / bloquea publicación en tiendas). La app ABRE archivos, no descarga de plataformas.
- Honestidad sobre fidelidad: la transcripción polifónica (piano, guitarra con acordes) NO es perfecta en ninguna herramienta actual. Objetivo: mejor borrador automático + editor de corrección integrado.

## 2-bis. Modo Karaoke Rápido (celular) — caso de uso central

Para reuniones: gente cantando, sin saber qué canciones van a elegir, sin PC. Debe funcionar en el momento, en el celular, sin esperas.

- El usuario abre un MP3 propio desde el celular ahí mismo.
- La app ATENÚA la voz con un filtro liviano de cancelación por fase (NO usa Demucs aquí). No la elimina del todo: la baja lo suficiente para cantar encima. Es instantáneo y corre en cualquier teléfono.
- Muestra la guía de afinación en vivo.
- Sistema de puntaje (lo competitivo): mide cuánto afinó, cuánto SOSTUVO la nota, y cumplimiento de DURACIÓN a lo largo de toda la canción.

Diferencia con el modo PC: este modo prioriza inmediatez sobre calidad. El filtro por fase baja bien la voz si está centrada, a medias en otras grabaciones; es el precio de ser instantáneo. La separación limpia de calidad (Demucs) queda para el procesamiento de escritorio.

## 3. Arquitectura tecnológica (decidida)

- Interfaz / app: FLUTTER (una sola base para escritorio Win/Mac/Linux y celular Android/iOS).
- Motor de audio pesado: PYTHON, empaquetado en la versión de escritorio.

Modelo híbrido: la canción se "cocina" una vez en la PC (procesamiento pesado en Python) y se "consume" en cualquier dispositivo. El Modo Karaoke Rápido del celular NO usa el motor pesado.

Librerías del motor (Python):
- Demucs — separación de pistas (solo en PC).
- Basic Pitch (Spotify) o MT3 — transcripción audio a MIDI.
- YIN / CREPE — detección de pitch en tiempo real y sobre archivos.
- Detección de onsets — ritmo y golpes de batería.
- Filtro de cancelación por fase — liviano, para el Modo Karaoke Rápido en celular.

## 4. Por dónde empezar

Trabajo desde el celular sin PC por ahora. Empezar SOLO por el Modo Karaoke Rápido (sección 2-bis), que es lo que se puede probar sin computadora. NO tocar todavía el motor pesado de PC (Demucs, transcripción).

Orden de trabajo (validar cada paso antes de seguir):
1. Esqueleto del proyecto Flutter.
2. Detección de pitch en vivo: capturar micrófono y mostrar en pantalla la nota cantada con su desviación en cents.
3. Abrir y reproducir un MP3 propio desde el celular.
4. Filtro liviano de atenuación de voz por fase.
5. Guía de afinación en vivo sobre la canción.
6. Sistema de puntaje (afinación + sostenimiento + duración).
7. Pantalla de resultado con puntaje.

## 5. Fases siguientes (NO ahora, solo contexto)

- Fase PC: separación de calidad con Demucs, práctica de instrumentos, transcripción a partitura con acordes + editor + export MusicXML/MIDI/PDF.
- Requisitos PC para el motor pesado: ideal GPU NVIDIA + 16 GB RAM; mínimo sin GPU + 8 GB RAM (más lento pero funciona).

## Primera tarea concreta

Armá el esqueleto del proyecto Flutter e implementá la detección de pitch en vivo: capturar el micrófono y mostrar en pantalla, en tiempo real, la nota que canto con su desviación en cents. Ese es el "hola mundo" que valida todo lo demás.
