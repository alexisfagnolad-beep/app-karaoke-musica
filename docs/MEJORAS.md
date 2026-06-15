# Mejoras y funciones nuevas — App de Karaoke / Práctica / Transcripción

> Complemento del README/LÉAME del repositorio. Recoge decisiones y funciones nuevas surgidas durante las pruebas. Leer junto al README principal.

---

## 1. Corrección del Modo Karaoke Rápido (celular)

**Problema detectado en pruebas:** el filtro liviano de cancelación por fase suena metálico y hueco; la atenuación de voz no queda bien.

**Decisión:**
- El Modo Karaoke Rápido queda como **opción secundaria** ("modo fiesta / calidad básica"), NO como modo principal de calidad.
- Avisar al usuario en la interfaz que en este modo el sonido puede salir metálico, porque prioriza la inmediatez.
- Ofrecer dentro de este modo la posibilidad de **NO atenuar la voz** (cantar sobre la canción original tal cual), porque para divertirse a veces alcanza con eso y suena mejor que el filtro.
- La separación de voz de **calidad real** vive en la PC (Demucs). Ver sección 2.

## 2. Procesamiento de calidad en PC (confirmado)

- En PC se usa **Demucs**, que separa la voz de verdad con IA. NO usa el truco de fase, por lo que NO suena metálico: el resultado es limpio.
- Sobre esas pistas limpias funcionan bien la detección de **altura (afinación)**, la **duración** de las notas y la **evaluación** tanto para canto como para instrumentos (batería, bajo, guitarra, teclado).
- Conclusión: la experiencia seria y de buena calidad se procesa en PC; el celular reproduce el resultado ya procesado.

## 3. Cambio de tonalidad (pitch shift) — función nueva

Para que cada cantante pueda ajustar la canción a su registro (voces graves o agudas).

- Implementar **cambio de tono en semitonos** (botones -2, -1, +1, +2, etc.) que suba o baje la canción **sin alterar la velocidad**.
- Aplicar tanto sobre la pista instrumental (karaoke) como, idealmente, sobre los ejercicios de instrumentos.
- Opcional/deseable: **detectar y mostrar la tonalidad original** de la canción (por ejemplo "La menor"), como información, además de los botones de semitonos.
- Nota de implementación: el ajuste por semitonos es más simple y directo para el usuario que pedir una tonalidad de destino concreta; priorizar esa interfaz.

## 4. Biblioteca y repertorio por géneros — función nueva

Organización interactiva del repertorio.

- Biblioteca de canciones procesadas, agrupadas por **género**: folclore, rock, jazz, balada, internacional, folclore mexicano, etc. (categorías editables por el usuario).
- **Filtrable por instrumento**: voz, guitarra, bajo, teclado, batería. Al elegir un instrumento, mostrar el repertorio disponible para ese instrumento.
- Interfaz interactiva: tocar un género o un instrumento filtra la lista.
- Cada canción puede pertenecer a un género y tener disponibles uno o varios instrumentos según lo que se haya procesado.

## 5. Procesamiento en lote (cola) en PC — función nueva

Para armar una buena oferta de canciones sin hacerlas de a una.

- Permitir cargar **varias canciones a la vez** y encolarlas.
- La PC procesa la cola **automáticamente, una tras otra**, sin intervención (aunque tarde).
- Mostrar el progreso de la cola (cuántas listas, cuál se está procesando, cuántas faltan).
- Al terminar cada canción, guardarla como proyecto reutilizable (ver sección 6).

## 6. Dónde viven las canciones procesadas (confirmado)

- Las canciones se **procesan en la PC** (separación, melodía de referencia, etc.).
- Una vez listas, quedan **guardadas como proyectos** y se pueden **pasar al celular**, donde quedan **fijas** para usar sin volver a procesar.
- Flujo: la PC "cocina" → el celular "guarda y reproduce". El celular no reprocesa.

---

## Resumen para el desarrollador

Funciones nuevas a contemplar en el diseño general (no todas en el MVP):
1. Modo Karaoke Rápido degradado a opción secundaria + opción de no atenuar voz.
2. Demucs en PC para separación limpia (calidad real).
3. Cambio de tonalidad por semitonos (+ detección de tono original, opcional).
4. Biblioteca por géneros, filtrable por instrumento.
5. Procesamiento en lote (cola automática) en PC.
6. Canciones procesadas en PC, sincronizadas y fijas en el celular.

Prioridad de construcción mientras se trabaja desde celular sin PC: lo que se pueda probar sin el motor pesado (interfaz de biblioteca, navegación por géneros, controles, y la detección de pitch en vivo). El resto (Demucs, lote, separación de calidad) se valida cuando haya PC.
