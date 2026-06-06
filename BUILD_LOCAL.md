# Compilación Local de WashosEngine para Android

Este documento explica cómo compilar WashosEngine para Android en tu computadora local, sin necesidad de GitHub Actions.

## Requisitos del Sistema

### Software Necesario

1. **Haxe 4.3+**
   - Descarga desde: https://haxe.org/download/
   - Verifica la instalación: `haxe -version`

2. **Android SDK**
   - Descarga Android Studio desde: https://developer.android.com/studio
   - O descarga solo el SDK desde: https://developer.android.com/studio#command-line-tools-only
   - Necesario para compilar aplicaciones Android

3. **Android NDK r21 o superior**
   - Se instala junto con Android SDK
   - O descárgalo desde: https://developer.android.com/ndk/downloads

4. **Python 3.8+** (opcional, para herramientas de compilación)

### Variables de Entorno

Configura las siguientes variables de entorno:

```bash
# Linux/macOS - añade a ~/.bashrc o ~/.zshrc
export ANDROID_HOME=/ruta/a/Android/Sdk
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/ndk_version

# Ejemplo para Linux
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/25.2.9519653
```

```powershell
# Windows - añade a Variables de Entorno del Sistema
ANDROID_HOME=C:\Users\tu_usuario\AppData\Local\Android\Sdk
ANDROID_NDK_ROOT=C:\Users\tu_usuario\AppData\Local\Android\Sdk\ndk\25.2.9519653
```

## Instalación

### 1. Clonar el Repositorio

```bash
git clone https://github.com/jereidk/WashosEngine-mobile-0.1.git
cd WashosEngine-mobile-0.1
git checkout fix/android-build
```

### 2. Ejecutar Setup

```bash
# Dar permisos de ejecución a los scripts
chmod +x setup-android.sh build-android.sh

# Ejecutar setup (instala dependencias)
./setup-android.sh
```

El script de setup:
- Verifica que Haxe esté instalado
- Instala todas las dependencias de haxelib
- Configura Lime para Android
- Verifica el Android SDK y NDK

### 3. Configurar el Keystore (para Release)

El keystore para builds de release debe estar en:

```
keystore/android/key.keystore
```

El repositorio incluye un keystore de desarrollo. Para producción, usa tu propio keystore.

## Compilación

### Build de Debug

```bash
./build-android.sh debug
```

Genera un APK de debug en:
```
export/release/android/bin/app/build/outputs/apk/debug/WashosEngine.apk
```

### Build de Release

```bash
./build-android.sh release
```

Genera un APK de release (optimizado) en:
```
export/release/android/bin/app/build/outputs/apk/release/WashosEngine.apk
```

### Instalar en Dispositivo

```bash
# Conectar dispositivo y habilitar USB debugging
adb install export/release/android/bin/app/build/outputs/apk/release/WashosEngine.apk

# O instalar con transferencia directa
adb push export/release/android/bin/app/build/outputs/apk/release/WashosEngine.apk /sdcard/
```

## Solución de Problemas

### Error: "ANDROID_HOME not set"

```bash
# Linux/macOS
export ANDROID_HOME=/ruta/a/Android/Sdk
./build-android.sh debug

# Windows (PowerShell)
$env:ANDROID_HOME = "C:\ruta\a\Android\Sdk"
.\build-android.ps1 debug
```

### Error: "NDK not found"

1. Abre Android Studio
2. Ve a Tools > SDK Manager
3. En "SDK Tools", marca "NDK (Side by side)"
4. Instala la versión más reciente

### Error: "Lime setup required"

```bash
haxelib run lime setup android
```

### Error: "haxelib not found"

```bash
# Reinstalar haxelib
haxe -version  # debe mostrar la versión
```

### Dependencias Faltantes

Si hay errores de dependencias, ejecuta:

```bash
haxelib install lime
haxelib install openfl 9.3.3
haxelib install flixel 5.6.0
haxelib install flixel-addons 3.3.2
haxelib install hxcpp
haxelib install hxp
haxelib install tjson 1.4.0
haxelib install hscript-iris 1.1.3
haxelib install hxvlc 2.0.1
haxelib install flxanimate
haxelib git extension-androidtools https://github.com/MAJigsaw77/extension-androidtools
```

## Información Adicional

### Estructura de Archivos

```
WashosEngine/
├── setup-android.sh     # Script de configuración
├── build-android.sh      # Script de compilación
├── hmm.json             # Dependencias para hmm
├── keystore/
│   └── android/
│       └── key.keystore # Keystore para signing
├── assets/              # Recursos del juego
├── source/              # Código fuente Haxe
└── Project.xml          # Configuración del proyecto
```

### Comandos de Lime Útiles

```bash
# Ver configuración de Lime
haxelib run lime config

# Ver configuración de Android
haxelib run lime config ANDROID_SDK
haxelib run lime config ANDROID_NDK_ROOT

# Limpiar build anterior
haxelib run lime clean android

# Compilar con más información de debug
haxelib run lime build android -debug -v
```

### Versiones de Dependencias

| Paquete | Versión |
|---------|---------|
| lime | latest |
| openfl | 9.3.3 |
| flixel | 5.6.0 |
| flixel-addons | 3.3.2 |
| hxcpp | latest |
| hxvlc | 2.0.1 |
| hscript-iris | 1.1.3 |
| tjson | 1.4.0 |
| extension-androidtools | git (main) |

## Soporte

Si tienes problemas:
1. Revisa los errores en la consola
2. Verifica que ANDROID_HOME y ANDROID_NDK_ROOT estén configurados
3. Asegúrate de que todas las dependencias estén instaladas
4. Consulta la documentación de Lime: https://lime.openfl.org/