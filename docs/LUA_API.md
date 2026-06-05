# WashosEngine Lua API - Perfect Haxe Bridge

Sistema de scripting avanzado con **puente perfecto Lua-Haxe**. 
Lua puede acceder a cualquier clase, método y propiedad de Haxe.

## Filosofía

- Si existe en Haxe, existe en Lua
- Los tipos nativos se convierten automáticamente
- Sin conflictos de nombres entre funciones
- API limpia y simple

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
```

## Funciones Principales (Haxe.*)

### Creación de Instancias

```lua
-- Método largo
local note = Haxe.create('objects.Note', 100, 200, 0)

-- Método corto
local sprite = create('flixel.FlxSprite', 100, 200)

-- También funciona
local sprite = new('flixel.FlxSprite', 100, 200)
```

### Acceso a Valores

```lua
-- Obtener propiedad (incluye getters)
local song = Haxe.get('PlayState.SONG')
local beat = Haxe.get('PlayState.curBeat')

-- Obtener constante
local RED = Haxe.get('flixel.util.FlxColor.RED')
local MAX_INT = Haxe.get('haxe.Math.NaN') -- No existe, pero el patrón sí

-- Establecer propiedad (incluye setters)
Haxe.set('PlayState.storyWeek', 2)
Haxe.set('PlayState.health', 100)
```

### Llamadas a Métodos

```lua
-- Llamar método en objeto
Haxe.call('sprite.update', 0.016)
Haxe.call('camera.shake', 0.01, 0.5)

-- Llamar método estático
Haxe.static('Paths', 'mods', 'images/character')
Haxe.static('CoolUtil', 'coolTextFile', {'data/list.txt'})
```

### Sistema de Tipos

```lua
-- Tipo de un valor
local type = typeof(someValue)  -- 'Int', 'String', 'flixel.FlxSprite', etc.

-- Verificar tipo
if isA(sprite, 'flixel.FlxSprite') then
    print('Es sprite')
end

-- Casting (para verificación)
local casted = cast(sprite, 'flixel.FlxSprite')
```

### Enums

```lua
-- Obtener valor de enum
local LEFT = Haxe.enum('flixel.input.keyboard.FlxKey', 'LEFT')
local EASE_IN = Haxe.enum('flixel.tweens.FlxEase', 'smoothStepIn')

-- Verificar si es enum
if isEnum(value) then
    print(value.__enum, value.__ctor)
end

-- Listar valores de enum
local keys = Haxe.get('flixel.input.keyboard.FlxKey')
-- methods('flixel.input.keyboard.FlxKey') muestra los constructores
```

### Reflexión

```lua
-- Listar métodos de una clase
local methods = methods('objects.Note')
for i, m in ipairs(methods) do
    print(m)
end

-- Listar propiedades
local props = properties('PlayState')

-- Listar estáticos
local statics = statics('Paths')

-- Listar constantes
local consts = constants('flixel.util.FlxColor')

-- Verificar herencia
if inherits('objects.Note', 'flixel.FlxSprite') then
    print('Note extiende de FlxSprite')
end
```

## Atajos Globales

```lua
-- create - Alias para Haxe.create
local sprite = create('flixel.FlxSprite', 100, 200)

-- get - Alias para Haxe.get
local value = get('PlayState.SONG')

-- set - Alias para Haxe.set
set('PlayState.health', 50)

-- call - Alias para Haxe.call
call('sprite.update', 0.016)

-- static - Alias para Haxe.static
local path = static('Paths', 'mods', '')

-- new - Alias para create
local note = new('objects.Note', 100, 200, 0)

-- typeof - Alias para Haxe.typeof
local type = typeof(someValue)

-- isA - Alias para Haxe.is
if isA(obj, 'flixel.FlxSprite') then end

-- cast - Alias para Haxe.cast
local casted = cast(obj, 'flixel.FlxSprite')

-- enum - Alias para Haxe.enum
local key = enum('flixel.input.keyboard.FlxKey', 'SPACE')

-- extends - Crear clase extendida
local MyClass = extends('flixel.FlxSprite', {
    customMethod = function(self)
        print('Custom!')
    end
})
```

## Objetos Wrapeados

Cuando creas o accedes a un objeto Haxe, se envuelve en una tabla Lua
con acceso natural a propiedades y métodos:

```lua
local sprite = create('flixel.FlxSprite', 100, 200)

-- Acceso a propiedades (usa getters/setters)
sprite.x = 500
sprite.y = 300
sprite.alpha = 0.5
sprite.angle = 45
sprite.visible = true

-- Llamadas a métodos con :syntax
sprite:loadGraphic('assets/image.png')
sprite:makeGraphic(100, 100, '0xFF0000')
sprite:setPosition(200, 200)
sprite:kill()
sprite:revive()
sprite:destroy()

-- Iteración de propiedades
for k, v in pairs(sprite) do
    print(k, v)
end

-- Tipo del objeto
print(sprite.type)  -- 'flixel.FlxSprite'

-- Clonación
local clone = sprite:clone()

-- Destrucción
sprite:destroy()
```

## Tipos Especiales

### FlxColor

```lua
local color = Haxe.get('flixel.util.FlxColor.RED')

-- Acceso a componentes
print(color.red, color.green, color.blue, color.alpha)
print(color.hex)  -- '0xFFFF0000'
print(color.int)  -- 4294901760

-- Crear desde entero
local custom = create('flixel.util.FlxColor', 0xFF0000)
```

### FlxPoint / FlxRect

```lua
local point = create('flixel.math.FlxPoint', 100, 200)
print(point.x, point.y)

local rect = create('flixel.math.FlxRect', 0, 0, 100, 50)
print(rect.x, rect.y, rect.width, rect.height)
```

### Enums como tablas

```lua
local ease = enum('flixel.tweens.FlxEase', 'bounceOut')

-- Se convierte a tabla
print(ease.__enum)    -- 'flixel.tweens.FlxEase'
print(ease.__ctor)   -- 'bounceOut'
```

## Ejemplos Prácticos

### Crear Note Personalizado

```lua
local note = create('objects.Note', 100, 200, 0)
note:makeGraphic(50, 50, '0xFF0000')
note.noteType = 'fire'
-- Añadir a escena
```

### Modificar Cámara

```lua
local cam = Haxe.get('FlxG.camera')
cam:shake(0.01, 0.5)
cam:flash('0xFFFFFF', 0.2)
cam.zoom = 1.5
```

### Tweens Avanzados

```lua
-- Crear sprite
local box = create('flixel.FlxSprite', 100, 100)
box:makeGraphic(100, 100, '0x00FF00')

-- Tween con Haxe
local tween = box:doTween(1, {x = 400, y = 300}, 2, 'bounceOut')

-- Cancelar si necesario
tween:cancel()
```

### Guardar/Cargar Estado

```lua
-- Guardar
local saveData = {
    health = get('PlayState.health'),
    score = get('PlayState.score'),
    week = get('PlayState.storyWeek')
}
writeFile('mods/myMod/save.json', json.stringify(saveData))

-- Cargar
local loaded = json.parse(readFile('mods/myMod/save.json'))
set('PlayState.health', loaded.health)
```

## Tabla de Equivalencias Haxe -> Lua

| Haxe | Lua |
|------|-----|
| `Class.method()` | `static('Class', 'method')` |
| `instance.method(arg)` | `call('instance.method', arg)` |
| `instance.property` | `get('instance.property')` |
| `instance.property = val` | `set('instance.property', val)` |
| `Class.CONSTANT` | `get('Class.CONSTANT')` |
| `Enum.Value` | `enum('Enum', 'Value')` |
| `Type.createInstance(Class, args)` | `create('Class', args)` |
| `Type.resolveClass(name)` | `Haxe.get('Class')` |

## Notas de Seguridad

- Los objetos creados deben destruirse manualmente si no son añadidos a un grupo
- No modifiques propiedades de `PlayState` durante `onCreate`
- Los archivos solo se pueden escribir en `mods/` y directorios permitidos
- Evita crear objetos en cada frame (cachealos)

## Tips de Rendimiento

1. **Cachea referencias** - No llames `Haxe.get()` en cada frame
2. **Reusa objetos** - Crea una vez, usa muchas veces
3. **Destruye objetos** - Libera memoria cuando no los necesites
4. **Agrupa sprites** - Usa `FlxGroup` en lugar de arrays manuales

## Funciones Principales

### Acceso a Propiedades

```lua
-- Obtener propiedad directamente
local song = getPropertyDirect('PlayState.SONG')
local beat = getPropertyDirect('PlayState.curBeat')

-- Establecer propiedad directamente
setPropertyDirect('PlayState.storyWeek', 2)
setPropertyDirect('PlayState.health', 100)

-- Usar notación de puntos
getProperty('PlayState.SONG.notes[0].type')
setProperty('PlayState.time', 30.5)
```

### Llamadas a Métodos

```lua
-- Llamar método en objeto
callMethod('playerStrums', 'update', {dt})

-- Llamar método estático
callStatic('Paths', 'mods', 'images/character')
callStatic('CoolUtil', 'coolTextFile', {'data/list.txt'})

-- Llamar con múltiples argumentos
callMethod('healthBar', 'updateBar', {1.0, 100})
```

### Creación de Instancias

```lua
-- Crear objeto Note
local note = new('objects.Note', 100, 200, 0)
note:kill()

-- Crear sprite con imagen
local spr = makeObject('mySprite', 'assets/images/character.png', 100, 200)

-- Crear sprite animado
local char = makeAnimatedObject('myChar', 'assets/images/spritemap.png', 100, 200, 100, 100, {0,1,2,3,4})
char:animation.play('idle')
```

### Sistema de Hooks

```lua
-- Hook a eventos del engine
onEvent('onBeatHit', function(beat)
    print('Beat:', beat)
    if beat % 4 == 0 then
        -- Cada 4 beats
    end
end)

onEvent('onUpdate', function(dt)
    -- Cada frame
end)

onEvent('onNoteHit', function(noteData)
    print('Hit note:', noteData)
end)

-- Registrar callback personalizado
registerCallback('myCustomCallback', function(arg1, arg2)
    print('Callback:', arg1, arg2)
    return arg1 + arg2
end)

-- Llamar callback
local result = callCallback('myCustomCallback', {1, 2})
```

### Reflexión

```lua
-- Listar métodos de una clase
local methods = listMethods('objects.Note')
for i, m in ipairs(methods) do
    print(m)
end

-- Listar propiedades
local props = listProperties('PlayState')
for i, p in ipairs(props) do
    print(p)
end

-- Listar clases con filtro
local chars = listClasses('character')
```

### Tweens Avanzados

```lua
-- Tween en objeto
tweenObject('mySprite', {x = 500, y = 300, alpha = 0}, 2, 'linear')

-- Tween con callback
tweenObject('mySprite', {x = 500}, 2, 'bounceOut', function()
    print('Completado!')
end)

-- Tween en cámara
tweenCamera({zoom = 1.5}, 1, 'easeIn')

-- Tween de propiedad individual
tweenProperty('mySprite', 'alpha', 0, 1, 'linear')
```

### Utilidades

```lua
-- Matemáticas
local lerped = lerp(a, b, t)
local clamped = clamp(value, min, max)
local rand = random(0, 100)
local randInt = randomInt(1, 10)
local dist = distance(x1, y1, x2, y2)
local angle = angle(x1, y1, x2, y2)
local rounded = round(value, 2)

-- Tiempo
local timeStr = formatTime(125.5)  -- "02:05.50"

-- Arrays
local doubled = tableMap({1,2,3}, function(x) return x * 2 end)
local filtered = tableFilter({1,2,3,4}, function(x) return x > 2 end)
local found = tableFind({1,2,3}, function(x) return x == 2 end)
local has = tableContains({1,2,3}, 2)
local shuffled = shuffle({1,2,3,4,5})
```

### Verificación de Tipos

```lua
-- Verificar tipo de objeto
if isSprite(obj) then
    obj:kill()
end

if isGroup(group) then
    group:clear()
end

-- Verificar tipos básicos
if isString(val) then print('Es string') end
if isNumber(val) then print('Es número') end
if isFunction(func) then print('Es función') end
if isTable(tbl) then print('Es tabla') end

-- Obtener tipo como string
local type = getType(obj)  -- 'FlxSprite', 'number', etc.
```

### Operaciones de Archivo

```lua
-- Verificar existencia
if fileExists('mods/myMod/data.txt') then
    local content = readFile('mods/myMod/data.txt')
end

-- Escribir archivo
writeFile('mods/myMod/save.txt', 'data aquí')

-- Agregar a archivo
appendFile('mods/myMod/log.txt', 'nueva línea\n')

-- Listar directorio
local files = listFiles('mods/')
for i, f in ipairs(files) do
    print(f)
end

-- Verificar si es directorio
if isDirectory('mods/myMod') then
    print('Es directorio')
end
```

### Llamar Funciones de Objetos

```lua
-- Guardar objeto
setVar('myNote', new('objects.Note', 100, 200, 0))

-- Llamar método
objectCall('myNote', 'kill')
objectCall('myNote', 'setAlpha', {0.5})

-- Obtener objeto
local note = object('myNote')
note:kill()

-- Remover objeto
removeObject('myNote')
```

### Inspección de Objetos

```lua
-- Inspeccionar estructura de objeto
local info = inspect(PlayState.instance)
print_r(info)

-- Ver todas las variables del script
debugVars()
```

### Acceso a Clases Estáticas

```lua
-- Obtener referencia a clase
local PlayState = getClass('states.PlayState')
local FlxG = getClass('flixel.FlxG')

-- Listar estáticos de una clase
local statics = listStatics('Paths')
```

## Ejemplos Prácticos

### Crear Note Personalizado

```lua
-- Crear note con propiedades especiales
local note = new('objects.Note', 100, 200, 0)
note.noteType = 'fire'
note:makeGraphic(50, 50, '0xFF0000')
addObjectToScene(note)

-- Apply shader
setProperty('note.shader', myShader)
```

### Modificar Salud

```lua
onEvent('onNoteHit', function(data)
    if data.noteType == 'heal' then
        local health = getPropertyDirect('PlayState.health')
        setPropertyDirect('PlayState.health', health + 10)
    end
end)
```

### Efecto de Cámara

```lua
onEvent('onBeatHit', function(beat)
    if beat % 8 == 0 then
        tweenCamera({shake = 0.01}, 0.2)
    end
end)
```

### Guardar Datos

```lua
-- Guardar estado
local saveData = {
    highscore = getPropertyDirect('PlayState.highscore'),
    unlocked = {'char1', 'char2'}
}
writeFile('mods/myMod/save.json', json.stringify(saveData))

-- Cargar estado
local loaded = json.parse(readFile('mods/myMod/save.json'))
```

## Tips y Trucos

1. **Usa `setVar` para guardar referencias** - Los objetos creados necesitan guardarse
2. **Los hooks se mantienen entre estados** - Si necesitas limpiarlos, llama `ScriptBridge.reset()`
3. **Inspecciona con `print_r`** - Para ver qué propiedades tiene un objeto
4. **Los tweens retornan el Tween** - Puedes cancelarlo con `tween:cancel()`

## Notas de Seguridad

- No modifiques propiedades de `PlayState` directamente durante `onCreate`
- Usa `callCallback` en lugar de `call` para funciones registradas
- Los archivos solo se pueden escribir en `mods/` y directorios permitidos