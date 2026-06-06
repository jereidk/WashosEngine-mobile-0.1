#!/bin/bash
# ================================================
# WashosEngine - Android Build Script
# ================================================
# Este script compila WashosEngine para Android
# sin usar GitHub Actions.
#
# Uso: 
#   ./build-android.sh debug    # Build de debug
#   ./build-android.sh release  # Build de release (requiere keystore)
#
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mensajes
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo ""
echo "================================================"
echo "  WashosEngine - Android Build"
echo "================================================"
echo ""

# Verificar argumentos
BUILD_TYPE=${1:-debug}

if [ "$BUILD_TYPE" != "debug" ] && [ "$BUILD_TYPE" != "release" ]; then
    error "Uso incorrecto!"
    echo "Uso: $0 [debug|release]"
    exit 1
fi

info "Tipo de build: $BUILD_TYPE"

# 1. Verificar Haxe y Lime
info "Verificando herramientas..."

if ! command -v haxe &> /dev/null; then
    error "Haxe no encontrado. Ejecuta primero: ./setup-android.sh"
    exit 1
fi

if ! command -v haxelib &> /dev/null; then
    error "Haxelib no encontrado."
    exit 1
fi

# 2. Verificar variables de entorno
info "Verificando variables de entorno..."

if [ -z "$ANDROID_HOME" ]; then
    if [ -d "$HOME/Android/Sdk" ]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
    elif [ -d "/usr/local/android-sdk" ]; then
        export ANDROID_HOME="/usr/local/android-sdk"
    fi
fi

if [ -z "$ANDROID_HOME" ]; then
    error "ANDROID_HOME no está configurado"
    error "Ejecuta: export ANDROID_HOME=/ruta/a/android/sdk"
    exit 1
fi

success "ANDROID_HOME: $ANDROID_HOME"

# 3. Verificar NDK
if [ -z "$ANDROID_NDK_ROOT" ]; then
    if [ -d "$ANDROID_HOME/ndk" ]; then
        NDK_VERSION=$(ls -1 $ANDROID_HOME/ndk/ 2>/dev/null | sort -V | tail -1)
        if [ -n "$NDK_VERSION" ]; then
            export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/$NDK_VERSION"
            export ANDROID_NDK_LATEST_HOME="$ANDROID_NDK_ROOT"
        fi
    fi
fi

if [ -n "$ANDROID_NDK_ROOT" ]; then
    success "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
else
    warn "ANDROID_NDK_ROOT no está configurado"
fi

# 4. Verificar que las dependencias estén instaladas
info "Verificando dependencias..."

DEPENDENCIES=("lime" "openfl" "flixel" "flixel-addons" "hxcpp" "hxp" "tjson" "hscript-iris" "hxvlc" "flxanimate")

for dep in "${DEPENDENCIES[@]}"; do
    if haxelib list | grep -q "^  $dep "; then
        info "  ✓ $dep instalado"
    else
        warn "  ✗ $dep no instalado - instalando..."
        haxelib install "$dep" --quiet 2>/dev/null || true
    fi
done

# 5. Verificar extension-androidtools
if haxelib list | grep -q "extension-androidtools"; then
    info "  ✓ extension-androidtools instalado"
else
    warn "  ✗ extension-androidtools no instalado - instalando..."
    haxelib git extension-androidtools https://github.com/MAJigsaw77/extension-androidtools --quiet --skip-dependencies || true
fi

# 6. Verificar keystore para release
if [ "$BUILD_TYPE" == "release" ]; then
    KEYSTORE_PATH="keystore/android/key.keystore"
    if [ ! -f "$KEYSTORE_PATH" ]; then
        error "Keystore no encontrado: $KEYSTORE_PATH"
        error "Para builds de release, necesitas el keystore en esta ubicación"
        exit 1
    fi
    success "Keystore encontrado: $KEYSTORE_PATH"
fi

# 7. Construir comando de compilación
info "Preparando compilación..."

BUILD_CMD="haxelib run lime build android"

# Agregar flags según tipo de build
if [ "$BUILD_TYPE" == "release" ]; then
    BUILD_CMD="$BUILD_CMD -final"
    info "Modo: Release (optimizado)"
else
    BUILD_CMD="$BUILD_CMD -debug"
    info "Modo: Debug"
fi

# Solo ARM64 (para reducir tiempo de compilación)
BUILD_CMD="$BUILD_CMD -ONLY_ARM64"

# Usar ASTC para compresión de texturas
BUILD_CMD="$BUILD_CMD -D ASTC"

# Agregar flags adicionales
BUILD_CMD="$BUILD_CMD -D mobile"

echo ""
info "Comando de compilación:"
echo "  $BUILD_CMD"
echo ""

# 8. Ejecutar compilación
info "Iniciando compilación..."
echo "================================================"

# Exportar variables para el proceso
export ANDROID_HOME
export ANDROID_NDK_ROOT
export ANDROID_NDK_LATEST_HOME

# Ejecutar compilación
START_TIME=$(date +%s)

if eval "$BUILD_CMD"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo "================================================"
    success " Compilación exitosa!"
    echo "================================================"
    echo ""
    success "Tiempo de compilación: ${MINUTES}m ${SECONDS}s"
    echo ""
    
    # Mostrar ubicación del APK
    APK_PATH="export/release/android/bin/app/build/outputs/apk/release/WashosEngine.apk"
    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        success "APK generado: $APK_PATH"
        info "Tamaño: $APK_SIZE"
        echo ""
        info "Para instalar en dispositivo:"
        info "  adb install $APK_PATH"
    else
        warn "APK no encontrado en la ubicación esperada"
        warn "Busca en: export/release/android/"
    fi
else
    echo ""
    echo "================================================"
    error " Compilación fallida!"
    echo "================================================"
    echo ""
    error "Revisa los errores arriba para más información."
    echo ""
    echo "Sugerencias:"
    echo "  1. Verifica que ANDROID_HOME y ANDROID_NDK_ROOT estén configurados"
    echo "  2. Ejecuta: ./setup-android.sh"
    echo "  3. Verifica que todas las dependencias estén instaladas"
    echo ""
    exit 1
fi