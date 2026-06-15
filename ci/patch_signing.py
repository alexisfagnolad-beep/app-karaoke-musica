#!/usr/bin/env python3
"""Inyecta un signingConfig 'debug' explícito en el build.gradle de Android
generado por `flutter create`, apuntando a una clave FIJA (karaoke.keystore).

Sin esto, Gradle genera un debug keystore aleatorio por máquina/run, así que
cada APK queda firmado distinto y Android rechaza la actualización con
"conflicto con un paquete". Con una firma estable, las updates se instalan
encima de la versión anterior.
"""
import os
import sys

KTS = "android/app/build.gradle.kts"
GROOVY = "android/app/build.gradle"

KTS_BLOCK = '''
    signingConfigs {
        getByName("debug") {
            storeFile = file("karaoke.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
'''

GROOVY_BLOCK = '''
    signingConfigs {
        debug {
            storeFile file("karaoke.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
'''


def main() -> int:
    path = KTS if os.path.exists(KTS) else GROOVY
    if not os.path.exists(path):
        print(f"ERROR: no encontré {KTS} ni {GROOVY}", file=sys.stderr)
        return 1

    src = open(path, encoding="utf-8").read()

    if "karaoke.keystore" in src:
        print(f"{path} ya tiene la firma fija; no hago nada.")
        return 0

    marker = "android {"
    idx = src.find(marker)
    if idx == -1:
        print(f"ERROR: no encontré 'android {{' en {path}", file=sys.stderr)
        return 1

    insert_at = idx + len(marker)
    block = KTS_BLOCK if path.endswith(".kts") else GROOVY_BLOCK
    patched = src[:insert_at] + block + src[insert_at:]
    open(path, "w", encoding="utf-8").write(patched)

    print(f"Firmado explícito inyectado en {path}:\n")
    print(patched[: insert_at + len(block) + 200])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
