package backend;

#if LUA_ALLOWED
import psychlua.FunkinLua;
import flixel.FlxState;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

// Typedef para scripts watched (fuera de la clase)
typedef WatchedScript = {
    var path:String;
    var lastModified:Float;
    var luaScript:Dynamic;
    var isHscript:Bool;
    var onReload:Void->Void;
}

/**
 * ScriptHotReload - Sistema de Hot Reload para Scripts Lua/HScript
 * 
 * Permite recargar scripts sin perder el estado del juego.
 * Ideal para desarrollo rápido - edita el script, guarda, ve los cambios.
 * 
 * Uso:
 * ```haxe
 * // En PlayState.create():
 * ScriptHotReload.instance.init(this);
 * ScriptHotReload.instance.enableWatching(true);
 * 
 * // Para forzar reload de todos los scripts:
 * ScriptHotReload.instance.reloadAllScripts();
 * ```
 */
class ScriptHotReload
{
    // ============================================
    // SINGLETON
    // ============================================
    
    public static var instance(get, never):ScriptHotReload;
    private static var _instance:ScriptHotReload = null;
    
    private static inline function get_instance():ScriptHotReload
    {
        if (_instance == null) _instance = new ScriptHotReload();
        return _instance;
    }
    
    // ============================================
    // PROPIEDADES
    // ============================================
    
    /** Si el watching está activo */
    public var watchingEnabled:Bool = false;
    
    /** Intervalo de checking (en segundos) */
    public var checkInterval:Float = 0.5;
    
    /** Estado padre para agregar scripts */
    private var parentState:FlxState = null;
    
    /** Scripts registrados para watching */
    private var watchedScripts:Map<Int, WatchedScript> = new Map();
    
    /** Timer para checking */
    private var checkTimer:Float = 0;
    
    /** Scripts actualmente activos (por ID) */
    private var activeScripts:Map<Int, FunkinLua> = new Map();
    
    /** Próximo ID de script */
    private var nextScriptId:Int = 0;
    
    /** Si debe mostrar notifications */
    public var showNotifications:Bool = true;
    
    /** Último tiempo de log */
    private var lastNotificationTime:Float = 0;
    private var notificationCooldown:Float = 1.0;
    
    // ============================================
    // TIPOS
    // ============================================
    
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    private function new() {}
    
    // ============================================
    // INICIALIZACIÓN
    // ============================================
    
    /**
     * Inicializar el sistema de hot reload
     */
    public function init(?State:FlxState):Void
    {
        parentState = State;
        watchedScripts = new Map();
        activeScripts = new Map();
        nextScriptId = 0;
        checkTimer = 0;
        
        #if debug
        trace('[ScriptHotReload] Initialized');
        #end
    }
    
    /**
     * Establecer el estado padre
     */
    public function setParentState(State:FlxState):Void
    {
        parentState = State;
    }
    
    /**
     * Activar/desactivar watching
     */
    public function enableWatching(enabled:Bool):Void
    {
        watchingEnabled = enabled;
        
        #if debug
        trace('[ScriptHotReload] Watching ' + (enabled ? 'enabled' : 'disabled'));
        #end
    }
    
    // ============================================
    // REGISTRO DE SCRIPTS
    // ============================================
    
    /**
     * Registrar un script Lua para watching
     */
    public function registerLuaScript(lua:FunkinLua, path:String, ?onReload:Void->Void = null):Int
    {
        var id = nextScriptId++;
        
        var lastMod = 0.0;
        try {
            lastMod = FileSystem.stat(path).mtime.getTime();
        } catch (e:Dynamic) {}
        
        watchedScripts.set(id, {
            path: path,
            lastModified: lastMod,
            luaScript: lua,
            isHscript: false,
            onReload: onReload
        });
        
        activeScripts.set(id, lua);
        
        #if debug
        trace('[ScriptHotReload] Registered Lua script: ' + path + ' (id: ' + id + ')');
        #end
        
        return id;
    }
    
    /**
     * Registrar un script HScript para watching
     */
    public function registerHscript(script:Dynamic, path:String, ?onReload:Void->Void = null):Int
    {
        var id = nextScriptId++;
        
        var lastMod = 0.0;
        try {
            lastMod = FileSystem.stat(path).mtime.getTime();
        } catch (e:Dynamic) {}
        
        watchedScripts.set(id, {
            path: path,
            lastModified: lastMod,
            luaScript: script,
            isHscript: true,
            onReload: onReload
        });
        
        #if debug
        trace('[ScriptHotReload] Registered HScript: ' + path + ' (id: ' + id + ')');
        #end
        
        return id;
    }
    
    /**
     * Desregistrar un script
     */
    public function unregisterScript(id:Int):Void
    {
        watchedScripts.remove(id);
        activeScripts.remove(id);
        
        #if debug
        trace('[ScriptHotReload] Unregistered script id: ' + id);
        #end
    }
    
    // ============================================
    // UPDATE
    // ============================================
    
    /**
     * Update - verificar cambios en archivos
     */
    public function update(elapsed:Float):Void
    {
        if (!watchingEnabled) return;
        if (Lambda.count(watchedScripts) == 0) return;
        
        checkTimer += elapsed;
        
        if (checkTimer >= checkInterval) {
            checkTimer = 0;
            checkForChanges();
        }
    }
    
    /**
     * Verificar si hay cambios en los scripts
     */
    private function checkForChanges():Void
    {
        for (id => watched in watchedScripts) {
            try {
                var stat = FileSystem.stat(watched.path);
                var currentMod = stat.mtime.getTime();
                
                if (currentMod > watched.lastModified) {
                    // El archivo cambió
                    notifyChange(watched.path);
                    watched.lastModified = currentMod;
                    
                    // Hacer reload
                    reloadScript(id);
                }
            } catch (e:Dynamic) {
                // Archivo no encontrado o error
            }
        }
    }
    
    /**
     * Recargar un script específico
     */
    public function reloadScript(id:Int):Bool
    {
        var watched = watchedScripts.get(id);
        if (watched == null) return false;
        
        try {
            if (watched.isHscript) {
                // Recargar HScript
                return reloadHscript(id, watched);
            } else {
                // Recargar Lua
                return reloadLua(id, watched);
            }
        } catch (e:Dynamic) {
            #if debug
            trace('[ScriptHotReload] Error reloading script: ' + e);
            #end
            return false;
        }
    }
    
    /**
     * Recargar script Lua
     */
    private function reloadLua(id:Int, watched:WatchedScript):Bool
    {
        var oldLua:FunkinLua = cast watched.luaScript;
        if (oldLua == null) return false;
        
        // Guardar estado importante (si existe el método)
        
        // Crear nuevo script
        var newLua = new FunkinLua();
        
        // Copiar referencias importantes del viejo
        // (Este paso depende de cómo FunkinLua maneje sus refs)
        
        // Intentar cargar el script
        try {
            newLua.doLuaFile(watched.path);
            
            // Reemplazar en watched
            watched.luaScript = newLua;
            
            // Callback
            if (watched.onReload != null) {
                watched.onReload();
            }
            
            #if debug
            trace('[ScriptHotReload] Reloaded Lua: ' + watched.path);
            #end
            
            return true;
        } catch (e:Dynamic) {
            #if debug
            trace('[ScriptHotReload] Failed to reload Lua: ' + e);
            #end
            return false;
        }
    }
    
    /**
     * Recargar script HScript
     */
    private function reloadHscript(id:Int, watched:WatchedScript):Bool
    {
        // HScript reload es más complejo, depende de la implementación
        // Por ahora solo marcamos como recargado
        
        if (watched.onReload != null) {
            watched.onReload();
        }
        
        #if debug
        trace('[ScriptHotReload] HScript reload triggered: ' + watched.path);
        #end
        
        return true;
    }
    
    // ============================================
    // FUNCIONES PÚBLICAS
    // ============================================
    
    /**
     * Recargar todos los scripts
     */
    public function reloadAllScripts():Int
    {
        var reloaded = 0;
        
        for (id in watchedScripts.keys()) {
            if (reloadScript(id)) {
                reloaded++;
            }
        }
        
        #if debug
        trace('[ScriptHotReload] Reloaded ' + reloaded + ' of ' + Lambda.count(watchedScripts) + ' scripts');
        #end
        
        return reloaded;
    }
    
    /**
     * Forzar reload de un script específico por path
     */
    public function reloadByPath(path:String):Bool
    {
        for (id => watched in watchedScripts) {
            if (watched.path == path || watched.path.endsWith(path)) {
                return reloadScript(id);
            }
        }
        return false;
    }
    
    /**
     * Verificar si un script está siendo watched
     */
    public function isWatched(path:String):Bool
    {
        for (watched in watchedScripts) {
            if (watched.path == path) return true;
        }
        return false;
    }
    
    /**
     * Obtener estadísticas
     */
    public function getStats():Dynamic
    {
        return {
            watchingEnabled: watchingEnabled,
            totalScripts: Lambda.count(watchedScripts),
            activeScripts: Lambda.count(activeScripts),
            checkInterval: checkInterval
        };
    }
    
    // ============================================
    // NOTIFICATIONS
    // ============================================
    
    private function notifyChange(path:String):Void
    {
        if (!showNotifications) return;
        
        var now = Sys.time();
        if (now - lastNotificationTime < notificationCooldown) return;
        lastNotificationTime = now;
        
        var filename = Path.withoutDirectory(path);
        
        #if debug
        trace('[ScriptHotReload] 🔄 Reloading: ' + filename);
        #end
        
        // Aquí podrías mostrar un texto en pantalla
        // Por ahora solo log
    }
    
    // ============================================
    // UTILIDADES
    // ============================================
    
    /**
     * Clear todos los scripts watcheados
     */
    public function clearAll():Void
    {
        watchedScripts.clear();
        activeScripts.clear();
        
        #if debug
        trace('[ScriptHotReload] Cleared all watched scripts');
        #end
    }
    
    /**
     * Lista de scripts activos
     */
    public function getActiveScripts():Array<String>
    {
        var list = [];
        for (watched in watchedScripts) {
            list.push(watched.path);
        }
        return list;
    }
}
#end