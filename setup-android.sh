#!/bin/bash
# ================================================
# WashosEngine - Android Setup Script
# ================================================
# Este script configura el entorno para compilar
# WashosEngine para Android sin usar GitHub Actions.
#
# Uso: ./setup-android.sh
#
# Requisitos:
# - Haxe instalado (https://haxe.org/download/)
# - Android SDK (ANDROID_HOME)
# - Android NDK (ANDROID_NDK_ROOT)
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
echo "  WashosEngine - Android Setup"
echo "================================================"
echo ""

# 1. Verificar Haxe
info "Verificando Haxe..."
if ! command -v haxe &> /dev/null; then
    error "Haxe no encontrado. Instálalo desde: https://haxe.org/download/"
    exit 1
fi

HAXE_VERSION=$(haxe -version 2>/dev/null || echo "unknown")
info "Haxe instalado: $HAXE_VERSION"

# 2. Verificar Haxelib
info "Verificando Haxelib..."
if ! command -v haxelib &> /dev/null; then
    error "Haxelib no encontrado. Instálalo con: haxe -v 4.0+"
    exit 1
fi

# 3. Configurar Haxelib
info "Configurando Haxelib..."
haxelib setup ~/haxelib || true

# 4. Instalar dependencias desde hmm.json
info "Instalando dependencias desde hmm.json..."

# Primero instalar hmm si no existe
haxelib install hmm --quiet 2>/dev/null || true

# Usar hmm para instalar todas las dependencias
if command -v hmm &> /dev/null; then
    info "Ejecutando hmm install..."
    haxelib run hmm install --quiet || true
else
    warn "hmm no disponible, instalando dependencias manualmente..."
    
    # Instalar dependencias con versiones fijas (compatibles con openfl 9.3.3)
    haxelib install lime 9.3.0 --quiet || true
    haxelib install openfl 9.3.3 --quiet || true
    haxelib install flixel 5.6.0 --quiet || true
    haxelib install flixel-addons 3.3.2 --quiet || true
    haxelib install hxcpp 4.3.0 --quiet || true
    haxelib install hxp 1.3.0 --quiet || true
    haxelib install tjson 1.4.0 --quiet || true
    haxelib install linc_luajit --quiet || true
    haxelib install hscript-iris 1.1.3 --quiet || true
    haxelib install hxvlc 2.0.1 --quiet --skip-dependencies || true
    haxelib install flxanimate --quiet || true
    haxelib install extension-androidtools 2.2.2 --quiet || true
fi

# 5. Configurar Lime
info "Configurando Lime..."
haxelib run lime setup -y || true

# 6. Verificar Android SDK
info "Verificando Android SDK..."

if [ -z "$ANDROID_HOME" ]; then
    warn "ANDROID_HOME no está configurado"
    
    # Buscar en ubicaciones comunes
    if [ -d "$HOME/Android/Sdk" ]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
        success "Encontrado Android SDK en: $ANDROID_HOME"
    elif [ -d "/usr/local/android-sdk" ]; then
        export ANDROID_HOME="/usr/local/android-sdk"
        success "Encontrado Android SDK en: $ANDROID_HOME"
    elif [ -d "/opt/android-sdk" ]; then
        export ANDROID_HOME="/opt/android-sdk"
        success "Encontrado Android SDK en: $ANDROID_HOME"
    else
        error "Android SDK no encontrado. Configura ANDROID_HOME manualmente."
        error "Descarga desde: https://developer.android.com/studio"
        exit 1
    fi
else
    success "ANDROID_HOME: $ANDROID_HOME"
fi

# 8. Verificar Android NDK
info "Verificando Android NDK..."

if [ -z "$ANDROID_NDK_ROOT" ]; then
    warn "ANDROID_NDK_ROOT no está configurado"
    
    # Buscar en ubicaciones comunes
    if [ -d "$ANDROID_HOME/ndk" ]; then
        # Usar la versión más reciente
        NDK_VERSION=$(ls -1 $ANDROID_HOME/ndk/ 2>/dev/null | sort -V | tail -1)
        if [ -n "$NDK_VERSION" ]; then
            export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/$NDK_VERSION"
            export ANDROID_NDK_LATEST_HOME="$ANDROID_NDK_ROOT"
            success "Encontrado Android NDK: $ANDROID_NDK_ROOT"
        fi
    fi
else
    success "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
fi

# 9. Configurar Lime para Android
info "Configurando Lime para Android..."

if [ -n "$ANDROID_HOME" ]; then
    haxelib run lime config ANDROID_SDK "$ANDROID_HOME" || true
fi

if [ -n "$ANDROID_NDK_LATEST_HOME" ]; then
    haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_LATEST_HOME" || true
fi

haxelib run lime config ANDROID_SETUP true || true

# 10. Verificar keystore
info "Verificando keystore..."

KEYSTORE_PATH="keystore/android/key.keystore"
if [ -f "$KEYSTORE_PATH" ]; then
    success "Keystore encontrado: $KEYSTORE_PATH"
else
    warn "Keystore no encontrado en: $KEYSTORE_PATH"
    warn "Para builds de release, necesitas el keystore en esta ubicación"
fi

# 11. Crear directorio de keystore si no existe
mkdir -p keystore/android

echo ""
echo "================================================"
success " Setup completado!"
echo "================================================"
echo ""
echo "Próximos pasos:"
echo "  1. Para compilar debug:   ./build-android.sh debug"
echo "  2. Para compilar release: ./build-android.sh release"
echo ""
echo "Variables de entorno necesarias:"
echo "  - ANDROID_HOME: $ANDROID_HOME"
echo "  - ANDROID_NDK_ROOT: ${ANDROID_NDK_ROOT:-no configurado}"
echo ""
echo "Si necesitas configurar manualmente:"
echo "  export ANDROID_HOME=/ruta/a/android/sdk"
echo "  export ANDROID_NDK_ROOT=/ruta/a/android/ndk"
echo ""