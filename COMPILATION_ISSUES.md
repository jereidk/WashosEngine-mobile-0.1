# Análisis de Problemas Potenciales - Compilación Android

## Resumen Ejecutivo

Este documento identifica problemas potenciales que podrían impedir la compilación de WashosEngine para Android localmente (sin GitHub Actions).

---

## Problemas Identificados

### 1. ⚠️ CRÍTICO: Versiones "latest" en hmm.json

**Problema:**
```json
"lime": { "type": "haxelib", "version": "latest" }
"hxcpp": { "type": "haxelib", "version": "latest" }
"hxp": { "type": "haxelib", "version": "latest" }
"flxanimate": { "type": "haxelib", "version": "latest" }
```

**Riesgo:** 
- Actualizaciones pueden romper builds de forma inesperada
- No reproducible - diferentes máquinas pueden tener diferentes versiones
- Conflictos entre dependencias

**Solución:** Fijar versiones específicas

---

### 2. ⚠️ MODERADO: extension-androidtools desde git

**Problema:**
```json
{
  "name": "extension-androidtools",
  "type": "git",
  "url": "https://github.com/MAJigsaw77/extension-androidtools"
}
```
Usa branch "main" que puede cambiar.

**Solución:** Usar versión haxelib 2.2.2 (como Funkin Crew)

---

### 3. ✅ VERIFICADO: Keystore

- Ubicación: `keystore/android/key.keystore` ✅
- Configuración en Project.xml: ✅
- Password: psychengine ✅

**Estado:** Correcto

---

### 4. ✅ VERIFICADO: extension-androidtools en código

El proyecto usa correctamente extension-androidtools para:
- Android Context
- Toast notifications
- Permissions
- Settings
- Environment

**Estado:** Necesario para el proyecto

---

### 5. ⚠️ MODERADO: hxvlc con skip-dependencies

**Problema:**
```bash
haxelib install hxvlc 2.0.1 --quiet --skip-dependencies
```

El `--skip-dependencies` puede causar errores en tiempo de ejecución si faltan dependencias.

**Solución:** Verificar que hxvlc funcione sin dependencias faltantes.

---

### 6. ⚠️ BAJO: submódulos git

**Problema:**
El workflow usa `submodules: true` pero el repositorio no tiene `.gitmodules`.

**Impacto:** Puede causar warnings pero no rompe la compilación.

**Solución:** Remover `submodules: true` del workflow o dejar como está (no afecta).

---

## Comparación con Proyectos Funcionales

| Aspecto | WashosEngine | Funkin Crew | ShadowEngine |
|---------|--------------|-------------|--------------|
| lime | haxelib latest | git (SHA) | git (SHA) |
| openfl | 9.3.3 | git (SHA) | git (SHA) |
| extension-androidtools | git (main) | 2.2.2 | ❌ |
| Estabilidad | ⚠️ Baja | ✅ Alta | ✅ Alta |

---

## Acciones Recomendadas

### Inmediatas (Requeridas para compilación estable)

1. **Fijar versiones en hmm.json:**
   ```json
   "lime": "9.3.0"  // o versión compatible con openfl 9.3.3
   "hxcpp": "4.3.0"
   "hxp": "1.3.0"
   ```

2. **Cambiar extension-androidtools a haxelib:**
   ```json
   {
     "name": "extension-androidtools",
     "type": "haxelib",
     "version": "2.2.2"
   }
   ```

### Opcionales (Mejora de estabilidad)

3. Remover `submodules: true` del workflow si no hay submódulos
4. Verificar hxvlc dependencias

---

## Testing Checklist

Para verificar que la compilación funciona:

- [ ] `./setup-android.sh` ejecuta sin errores
- [ ] `haxelib list` muestra todas las dependencias instaladas
- [ ] `haxelib run lime config` muestra Android SDK configurado
- [ ] `./build-android.sh debug` compila sin errores
- [ ] `./build-android.sh release` genera APK válido

---

## Recursos

- [Documentación Lime](https://lime.openfl.org/)
- [Documentación OpenFL](https://openfl.org/)
- [extension-androidtools](https://github.com/MAJigsaw77/extension-androidtools)
- [ShadowEngine Build Docs](https://github.com/ShadowEngineTeam/FNF-Shadow-Engine)