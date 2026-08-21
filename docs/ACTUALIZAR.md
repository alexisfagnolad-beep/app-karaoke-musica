# Actualizar la app (celular y PC)

La app tiene un **actualizador integrado**: busca la última versión en las
Releases del repo, la descarga y la instala. Funciona igual en celular y PC.
Como el repo es privado, usa un **token de GitHub** que pegás una sola vez (se
guarda seguro en el dispositivo, no en el código).

## 1. Crear el token (una sola vez)

1. En GitHub: **Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token**.
2. **Repository access**: "Only select repositories" → elegí
   `app-karaoke-musica`.
3. **Permissions → Repository permissions → Contents: Read-only**.
   (Con leer Contents alcanza para bajar las Releases.)
4. Generá el token y copialo (empieza con `github_pat_…` o `ghp_…`).

> Cuidá ese token como una contraseña. Si se filtra, revocalo desde la misma
> pantalla y generá otro.

## 2. Cargarlo en la app

1. Abrí la app → **Actualizaciones** (tarjeta en el inicio o el ícono arriba).
2. Pegá el token → **Guardar token**.
3. La app busca sola si hay versión nueva.

## 3. Actualizar

- Si hay una versión nueva, aparece **Descargar e instalar**. Tocalo: baja el
  APK y abre el instalador.
- La primera vez, Android te pide permitir **"instalar apps de fuentes
  desconocidas"** para esta app. Aceptás y listo.
- También hay un cartel automático al abrir la app cuando hay novedades.

## Notas

- **Importante (una vez):** la versión que tengas instalada de antes estaba
  firmada con otra clave, así que esta primera vez **desinstalá la app vieja** e
  instalá la nueva. De ahí en más, las actualizaciones se instalan encima sin
  desinstalar nada.
- En PC el mecanismo es el mismo; los instaladores de escritorio se publican
  cuando se arme la versión de PC (fase posterior del proyecto).
