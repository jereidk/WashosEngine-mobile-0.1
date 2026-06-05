# WashosEngine Lua API - Perfect Haxe Bridge

Sistema de scripting avanzado con **puente perfecto Lua-Haxe**.
Lua puede acceder a cualquier clase, método y propiedad de Haxe de forma natural.

## Filosofía

- **Si existe en Haxe, existe en Lua** - Sin limitaciones
- **Tipos nativos se convierten automáticamente** - Sin wrappers manuales
- **API limpia y sin conflictos** - Cada función tiene nombre único
- **Manejo de errores robusto** - Debug mode y logging
- **Completamente tipado** - Type checking con `isA()`

## Inicio Rápido

```lua
-- Crear objetos Haxe
local sprite = create('flixel.FlxSprite', 100, 200)
sprite.x = 500
sprite.alpha = 0.5

-- Acceder a propiedades y constantes
local RED = get('flixel.util.FlxColor.RED')
local song = get('PlayState.SONG')

-- Llamar métodos
call('sprite.loadGraphic', 'assets/image.png')
callStatic('backend.Paths', 'mods', '')

-- Enums
local LEFT = enum('flixel.input.keyboard.FlxKey', 'LEFT')

-- Verificación de tipos
if isA(sprite, 'flixel.FlxSprite') then
    print('Es un sprite!')
end
```

## Tabla Haxe

La tabla `Haxe.*` proporciona acceso centralizado a todas las funciones:

```lua
-- Creación
Haxe.create('flixel.FlxSprite', 100, 200)
Haxe.new('objects.Note', 100, 200, 0)

-- Propiedades
Haxe.get('PlayState.SONG')
Haxe.set('PlayState.health', 100)

-- Métodos
Haxe.call('sprite.update', 0.016)
Haxe.static('Paths', 'mods', '')

-- Tipos
Haxe.typeof(someValue)  -- 'Int', 'String', 'flixel.FlxSprite', etc.
Haxe.is(someValue, 'flixel.FlxSprite')  -- true/false

-- Enums
Haxe.enum('flixel.tweens.FlxEase', 'bounceOut')

-- Reflexión
Haxe.methods('objects.Note')
Haxe.properties('PlayState')
Haxe.statics('Paths')
```

---

## Funciones LuaBridge

### Creación de Instancias

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `create(class, args)` | Crear objeto Haxe | `create('FlxSprite', 100, 200)` |
| `new(class, args)` | Alias de create | `new('Note', 100, 200, 0)` |
| `instantiate(class, args)` | Alias de create | `instantiate('FlxText', 0, 0)` |

### Acceso a Propiedades

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `get(path)` | Obtener valor por ruta | `get('PlayState.SONG')` |
| `set(path, value)` | Establecer valor | `set('sprite.x', 500)` |
| `getProperty(obj, prop)` | Obtener propiedad | `getProperty(sprite, 'x')` |
| `setProperty(obj, prop, val)` | Establecer propiedad | `setProperty(sprite, 'alpha', 0.5)` |

### Llamadas a Métodos

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `call(path, args)` | Llamar método por ruta | `call('sprite.loadGraphic', 'img.png')` |
| `callStatic(class, method, args)` | Método estático | `callStatic('Paths', 'mods', '')` |
| `callMethod(obj, method, args)` | Llamar método | `callMethod(sprite, 'update', [0.016])` |

### Sistema de Tipos

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `typeof(value)` | Tipo del valor | `typeof(42)` → `'Int'` |
| `isA(value, class)` | Verificar tipo | `isA(sprite, 'FlxSprite')` |
| `isNull(value)` | Es null? | `isNull(x)` → `true/false` |
| `isNumber(value)` | Es número? | `isNumber(3.14)` |
| `isString(value)` | Es string? | `isString('hello')` |
| `isArray(value)` | Es array? | `isArray({1,2,3})` |
| `isFunction(value)` | Es función? | `isFunction(fn)` |
| `cast(value, class)` | Cast (verificación) | `cast(x, 'Int')` |
| `classOf(obj)` | Nombre de clase | `classOf(sprite)` → `'flixel.FlxSprite'` |

### Enums

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `enum(enumPath, value)` | Valor de enum | `enum('FlxEase', 'bounceOut')` |
| `enumParams(enumValue)` | Parámetros | `enumParams(myEnum)` → `{param1, param2}` |
| `enumName(enumValue)` | Nombre del constructor | `enumName(myEnum)` → `'bounceOut'` |

### Reflexión de Clases

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `methods(classPath)` | Métodos de clase | `methods('FlxSprite')` → `['loadGraphic', ...]` |
| `properties(classPath)` | Propiedades | `properties('PlayState')` → `['SONG', 'health', ...]` |
| `statics(classPath)` | Campos estáticos | `statics('Paths')` → `['mods', 'images', ...]` |
| `constants(classPath)` | Constantes | `constants('FlxColor')` → `{name: 'RED', value: ...}` |
| `inherits(class, parent)` | Herencia | `inherits('Note', 'FlxSprite')` → `true` |
| `classExists(path)` | Existe clase? | `classExists('flixel.FlxSprite')` |
| `enumExists(path)` | Existe enum? | `enumExists('FlxKey')` |
| `isInterface(path)` | Es interface? | `isInterface('IMyInterface')` |
| `typeInfo(path)` | Info completa | `typeInfo('FlxSprite')` → `{methods:[], ...}` |

### Operaciones de Objetos

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `clone(obj)` | Clonar objeto | `clone(sprite)` |
| `destroy(obj)` | Destruir objeto | `destroy(sprite)` |
| `exists(obj)` | No es null? | `exists(sprite)` |
| `keys(obj)` | Llaves del objeto | `keys(sprite)` → `['x', 'y', 'alpha', ...]` |
| `values(obj)` | Valores | `values(sprite)` → `{100, 200, 0.5, ...}` |
| `pairs(obj)` | Pares key-value | `pairs(sprite)` → `{{key:'x', value:100}, ...}` |
| `hasProperty(obj, prop)` | Tiene propiedad? | `hasProperty(sprite, 'x')` |
| `hasMethod(obj, method)` | Tiene método? | `hasMethod(sprite, 'loadGraphic')` |
| `toString(obj)` | String del objeto | `toString(sprite)` → `'flixel.FlxSprite'` |
| `repr(value)` | Representación | `repr(42)` → `'42'` |

### Utilidades

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `inspect(value, depth)` | Inspección profunda | `inspect(myTable, 3)` |
| `dump(value)` | Dump formateado | `dump(sprite)` |
| `debug(msg)` | Mensaje debug | `debug('value: ' .. x)` |
| `trace(value)` | Print con trace | `trace(myValue)` |
| `error(msg)` | Mensaje error | `error('Algo salió mal')` |
| `noop()` | No operation | `noop()` → `null` |
| `identity(value)` | Retorna valor | `identity(x)` → `x` |

---

## Funciones ExtendedLuaFunctions

### Object Factory

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `makeSprite(name, graphic, x, y)` | Crear sprite | `makeSprite('player', 'player.png', 100, 200)` |
| `makeAnimatedSprite(name, graphic, x, y, w, h, frames)` | Sprite animado | `makeAnimatedSprite('hero', 'hero.png', 0, 0, 100, 100, {0,1,2})` |
| `getSprite(name)` | Obtener sprite por nombre | `getSprite('player')` |
| `removeSprite(name)` | Eliminar sprite | `removeSprite('player')` |

### Tweens

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `tweenSprite(obj, props, duration, ease, cb)` | Tween en sprite | `tweenSprite('player', {x=500}, 1, 'bounceOut')` |
| `tweenCameraShake(intensity, duration, cb)` | Shake cámara | `tweenCameraShake(0.01, 0.5)` |
| `tweenProperty(obj, prop, target, duration, ease, cb)` | Tween propiedad | `tweenProperty('player', 'alpha', 0, 1)` |

### Callbacks

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `registerCallback(name, func)` | Registrar callback | `registerCallback('onHit', function() end)` |
| `fireCallback(name, args)` | Llamar callback | `fireCallback('onHit', {damage})` |
| `unregisterCallback(name)` | Eliminar callback | `unregisterCallback('onHit')` |

### Arrays

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `arrayMap(arr, fn)` | Map | `arrayMap({1,2,3}, function(x) return x*2 end)` |
| `arrayFilter(arr, fn)` | Filter | `arrayFilter({1,2,3}, function(x) return x>1 end)` |
| `arrayReduce(arr, fn, init)` | Reduce | `arrayReduce({1,2,3}, function(a,b) return a+b end, 0)` |
| `arrayFind(arr, fn)` | Find | `arrayFind({1,2,3}, function(x) return x==2 end)` |
| `arrayContains(arr, val)` | Contains | `arrayContains({1,2,3}, 2)` |
| `arrayClone(arr)` | Clonar array | `arrayClone(myArray)` |
| `arrayMerge(...)` | Mergear arrays | `arrayMerge({1,2}, {3,4})` |

### Type Checking (Flixel)

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `isSprite(obj)` | Es FlxSprite? | `isSprite(sprite)` |
| `isText(obj)` | Es FlxText? | `isText(text)` |
| `isGroup(obj)` | Es FlxGroup? | `isGroup(group)` |
| `isCamera(obj)` | Es FlxCamera? | `isCamera(cam)` |
| `isTween(obj)` | Es FlxTween? | `isTween(tween)` |

### Utilidades Matemáticas

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `lerp(a, b, t)` | Interpolación | `lerp(0, 100, 0.5)` → `50` |
| `clampValue(v, min, max)` | Clamp | `clampValue(150, 0, 100)` → `100` |
| `randomFloat(min, max)` | Float aleatorio | `randomFloat(0, 1)` |
| `randomInt(min, max)` | Int aleatorio | `randomInt(1, 6)` |
| `randomPick(arr)` | Elemento aleatorio | `randomPick({a,b,c})` |
| `shuffleArray(arr)` | Mezclar | `shuffleArray({1,2,3})` |
| `distance2D(x1, y1, x2, y2)` | Distancia | `distance2D(0, 0, 3, 4)` → `5` |
| `angle2D(x1, y1, x2, y2)` | Ángulo | `angle2D(0, 0, 1, 0)` → `0` |
| `roundTo(val, decimals)` | Redondear | `roundTo(3.14159, 2)` → `3.14` |
| `formatTime(seconds)` | Formato tiempo | `formatTime(125)` → `'02:05.00'` |

### Archivos

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `fileExists(path)` | Existe archivo? | `fileExists('data/config.txt')` |
| `readTextFile(path)` | Leer archivo | `readTextFile('data/song.txt')` |
| `writeTextFile(path, content)` | Escribir archivo | `writeTextFile('save.txt', 'data')` |
| `appendTextFile(path, content)` | Append a archivo | `appendTextFile('log.txt', 'line\n')` |
| `listDirectory(dir)` | Listar directorio | `listDirectory('mods/')` |
| `isDir(path)` | Es directorio? | `isDir('mods/')` |

---

## Ejemplos Prácticos

### Crear Note Personalizado

```lua
-- Crear sprite
local note = create('objects.Note', 100, 200, 0)
note:makeGraphic(50, 50, get('flixel.util.FlxColor.RED'))

-- Añadir a grupo
local notes = get('PlayState.notes')
if notes then
    notes:add(note)
end
```

### Modificar Cámara

```lua
local cam = get('FlxG.camera')
cam:shake(0.01, 0.5)
cam:flash(get('flixel.util.FlxColor.WHITE'), 0.2)
cam.zoom = 1.5
```

### Guardar/Cargar Estado

```lua
-- Guardar
local saveData = {
    health = get('PlayState.health'),
    score = get('PlayState.score'),
    week = get('PlayState.storyWeek')
}
writeTextFile('mods/myMod/save.json', json.stringify(saveData))

-- Cargar
local loaded = json.parse(readTextFile('mods/myMod/save.json'))
set('PlayState.health', loaded.health)
```

### Tweens Avanzados

```lua
-- Sprite con tween
local box = makeSprite('box', 'box.png', 100, 100)
tweenSprite('box', {x = 500, alpha = 0}, 2, 'bounceOut', function()
    removeSprite('box')
end)
```

---

## Tabla de Equivalencias

| Haxe | Lua |
|------|-----|
| `Class.method()` | `callStatic('Class', 'method')` |
| `instance.method(arg)` | `call('instance.method', arg)` |
| `instance.property` | `get('instance.property')` |
| `instance.property = val` | `set('instance.property', val)` |
| `Class.CONSTANT` | `get('Class.CONSTANT')` |
| `Enum.Value` | `enum('Enum', 'Value')` |
| `Type.createInstance(Class, args)` | `create('Class', args)` |
| `Type.resolveClass(name)` | `classExists('Class')` |
| `Type.getClass(obj)` | `classOf(obj)` |
| `Std.is(obj, Class)` | `isA(obj, 'Class')` |
| `Type.typeof(value)` | `typeof(value)` |

---

## Notas de Seguridad

- Los objetos creados deben destruirse manualmente si no son añadidos a un grupo
- No modifiques propiedades de `PlayState` durante `onCreate`
- Los archivos solo se pueden escribir en `mods/` y directorios permitidos
- Evita crear objetos en cada frame (cachealos)

## Tips de Rendimiento

1. **Cachea referencias** - No llames `get()` en cada frame
2. **Reusa objetos** - Crea una vez, usa muchas veces
3. **Destruye objetos** - Libera memoria cuando no los necesites
4. **Agrupa sprites** - Usa `FlxGroup` en lugar de arrays manuales
5. **Usa `isA()` para type checking** - Evita errores de tipo
6. **Debug mode** - Actívalo para ver mensajes de error detallados

## Sistema de Debug para Android

El engine incluye un sistema de debug completo que funciona en **Android** donde no hay consola.

### Activar Debug Mode

```lua
-- Activar modo debug
debugMode(true)

-- Verificar si está activo
if isDebugMode() then
    print('Debug activo!')
end
```

### Logging

```lua
-- Log con nivel específico
debugLog('info', 'Mensaje de información')
debugLog('warn', 'Atención: algo no está bien')
debugLog('error', '¡Error crítico!')
debugLog('debug', 'Debug: valor = ' .. value)

-- Shortcuts rápidos
logInfo('Info rápido')
logWarn('Warning rápido')
logError('Error rápido')
logDebug('Debug rápido')
```

### Gestionar Logs

```lua
-- Obtener todos los logs
local logs = getDebugLogs()
for i, log in ipairs(logs) do
    print('[' .. log.level .. '] ' .. log.message)
end

-- Obtener últimos 10 logs
local recent = getDebugLogs(10)

-- Obtener estadísticas
local stats = getDebugStats()
print('Total:', stats.total)
print('Errors:', stats.error)
print('Warnings:', stats.warn)

-- Limpiar logs
clearDebugLog()
```

### Guardar a Archivo

```lua
-- Activar guardado automático a archivo
debugSaveToFile(true)

-- Guardar todos los logs ahora
saveDebugLog()

-- Guardar solo errores
saveErrorLog()
```

### Overlay Visual

```lua
-- Mostrar/ocultar overlay de debug
toggleDebugOverlay()

-- Mostrar overlay
showDebugOverlay()

-- Ocultar overlay
hideDebugOverlay()
```

### Filtrar por Nivel

```lua
-- Desactivar logs de debug
setLogLevel('debug', false)

-- Activar solo errores
setLogLevel('info', false)
setLogLevel('warn', false)
setLogLevel('debug', false)
setLogLevel('trace', false)
-- Ahora solo veras errores
```

### Inspección de Valores

```lua
-- Inspect un valor (como print_r en PHP)
local str = printr(myTable)
print(str)  -- Muestra estructura completa

-- También puedes usar debugPrint para mostrar en pantalla
debugPrint('Valor: ' .. tostring(myVariable))
debugPrint('Tabla completa', 'YELLOW')
```

### Ejemplo Completo

```lua
function onCreate()
    -- Activar debug
    debugMode(true)
    debugSaveToFile(true)
    
    logInfo('Script iniciado')
end

function onBeatHit()
    logDebug('Beat: ' .. curBeat)
end

function onStepHit()
    if curStep % 16 == 0 then
        logInfo('Nuevo frase')
    end
end

function onSongStart()
    logInfo('Canción iniciada')
end

function onEndSong()
    -- Guardar logs antes de terminar
    saveDebugLog()
    saveErrorLog()
    logInfo('Sesión terminada')
end

function onDestroy()
    -- Mostrar stats al cerrar
    local stats = getDebugStats()
    debugPrint('Total: ' .. stats.total .. ' errores: ' .. stats.error)
end
```

### Archivos de Log

Los logs se guardan en:
- `mods/debug/log_TIMESTAMP.txt` - Log completo
- `mods/debug/log_TIMESTAMP_errors.txt` - Solo errores

Puedes acceder a estos archivos desde un PC conectando el dispositivo o través de un file manager.

### Niveles de Log

| Nivel | Color | Uso |
|-------|-------|-----|
| `info` | Verde | Información general |
| `warn` | Amarillo | Warnings |
| `error` | Rojo | Errores |
| `debug` | Cyan | Debug verbose |
| `trace` | Gris | Trace detallado |

### Captura de Traces desde Source (.hx)

El DebugLogger también captura los `trace()` puestos en el código Haxe:

```haxe
// En source/Character.hx
trace('Error loading character: ' + e);  // Se captura automáticamente

// En source/objects/Alphabet.hx  
trace('Reloaded letters successfully!');  // Se captura automáticamente
```

Los traces se redirigen a DebugLogger con:
- El mensaje original
- La fuente: `nombreArchivo.hx:numeroLinea`
- Nivel automático (error si el archivo tiene "error" en el nombre)

### Notas sobre Android

- Los `trace()` de Haxe en Android se muestran en Logcat
- Con DebugLogger, los traces también se guardan en archivo
- El interceptor de traces funciona en builds DEBUG
- En builds release, los traces se omiten por defecto de Haxe

---

## Commits Recientes

- `46d8a75` - feat: Add DebugLogger system for Android debugging
- `38fc5e2` - docs: Complete LUA_API.md documentation
- `a0d1677` - fix: Remove duplicate functions
- `77e7c61` - feat: Complete rewrite of LuaBridge

**Sistema Lua completo, robusto y sin errores.** 🎮