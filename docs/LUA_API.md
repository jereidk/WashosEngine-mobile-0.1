# WashosEngine Lua API

Sistema de scripting avanzado para modders. Permite acceso directo al código fuente del engine.

## Inicio Rápido

```lua
-- Obtener ayuda general
help()

-- Listar clases disponibles
local classes = listClasses()
print('Clases disponibles:', #classes)

-- Obtener ayuda de una clase específica
help('PlayState')
```

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