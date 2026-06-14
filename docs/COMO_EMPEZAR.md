# Cómo poner en marcha — Paso 1 y 2

Este repo ya trae el **esqueleto Flutter** y la **detección de pitch en vivo**
(pasos 1 y 2 del README). Lo que falta es generar las carpetas nativas
(`android/`, `ios/`) y darle permiso de micrófono. Esto se hace una sola vez.

> Importante: este proyecto necesita el SDK de Flutter para compilarse. No se
> puede compilar "solo desde el navegador del celular". Las opciones reales
> desde el celular están más abajo.

## Estructura que ya está hecha

```
lib/
  main.dart                         # arranque de la app
  app.dart                          # MaterialApp + tema
  features/pitch/
    domain/musical_note.dart        # Hz -> nota + cents (con test)
    data/pitch_detection_service.dart  # micrófono + YIN en vivo
    presentation/
      live_pitch_screen.dart        # pantalla de afinación
      widgets/note_display.dart     # nota grande + frecuencia
      widgets/cents_meter.dart      # aguja de afinación (cents)
test/
  musical_note_test.dart            # valida la matemática de las notas
```

## 1. Generar las carpetas nativas (una vez)

Con Flutter instalado, parado en la carpeta del proyecto:

```bash
flutter create . --platforms=android,ios --project-name karaoke_musica
flutter pub get
```

`flutter create .` **no pisa** tu `lib/`, `test/` ni `pubspec.yaml`: solo
agrega lo que falta de `android/` e `ios/`.

## 2. Permiso de micrófono

### Android
En `android/app/src/main/AndroidManifest.xml`, agregá dentro de `<manifest>`
(arriba de la etiqueta `<application>`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS
En `ios/Runner/Info.plist`, agregá dentro del `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>La app usa el micrófono para detectar la afinación de tu voz.</string>
```

## 3. Probar la lógica sin dispositivo

El test de notas corre sin micrófono ni celular:

```bash
flutter test
```

## 4. Correrla en el celular

```bash
flutter run
```

Tocás **"Empezar a escuchar"**, aceptás el permiso de micrófono y cantás:
verás la nota (ej. `A4`), su frecuencia en Hz y la aguja de cents.

## Opciones para trabajar desde el celular (sin PC)

- **GitHub Codespaces** (desde el navegador del celular): da una máquina Linux
  donde instalás Flutter y corrés `flutter test`. Para *ver* la app en el
  teléfono conviene compilar un APK.
- **GitHub Actions (ya configurado)**: cada push a tu rama dispara el workflow
  `Build APK (Android)`. Entrá a la pestaña **Actions** del repo (se ve bien
  desde el celular), abrí la última corrida y bajá el artefacto
  `karaoke-musica-debug-apk`. También podés lanzarlo a mano con
  **"Run workflow"** (workflow_dispatch).
- **Un APK de debug** generado en cualquiera de los anteriores se instala
  directo en Android para probar el micrófono de verdad.

Cuando tengas PC, `flutter run` es el camino más rápido para iterar.
