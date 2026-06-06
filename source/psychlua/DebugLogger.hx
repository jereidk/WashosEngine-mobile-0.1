package psychlua;

#if LUA_ALLOWED
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import haxe.ds.StringMap;
import flixel.util.FlxColor;
import flixel.FlxG;

/**
 * DebugLogger - Sistema de logging para Android y debugging
 * 
 * Este sistema permite:
 * - Guardar logs en archivo (para revisar después)
 * - Activar/desactivar debug mode ingame
 * - Filtrar logs por tipo (info, warning, error)
 * - Ver logs en overlay visual
 * - Exportar logs a archivo
 * 
 * Uso en Lua:
 * ```lua
 * -- Activar modo debug
 * debugMode(true)
 * 
 * -- Log personalizado
 * debugLog('info', 'Mi mensaje de info')
 * debugLog('warn', 'Mi warning')
 * debugLog('error', 'Mi error')
 * 
 * -- Guardar logs a archivo
 * saveDebugLog()
 * 
 * -- Limpiar logs
 * clearDebugLog()
 * 
 * -- Mostrar/ocultar overlay
 * toggleDebugOverlay()
 * ```
 */

typedef LogEntry = {
    var timestamp:Float;
    var level:String;
    var message:String;
    var ?source:String;
    var ?color:Int;
    }

class DebugLogger
{
    // Singleton
    public static var instance(get, never):DebugLogger;
    private static var _instance:DebugLogger = null;
    
    private static inline function get_instance():DebugLogger
    {
        if (_instance == null) _instance = new DebugLogger();
        return _instance;
    }
    
    // ============================================
    // CONFIGURACION
    // ============================================
    
    /** Habilitar/deshabilitar todo el sistema de debug */
    public var enabled:Bool = false;
    
    /** Mostrar overlay visual en pantalla */
    public var showOverlay:Bool = false;
    
    /** Guardar logs a archivo */
    public var saveToFile:Bool = false;
    
    /** Máximo de logs en memoria */
    public var maxLogs:Int = 100;
    
    /** Niveles de log habilitados */
    public var logLevels:StringMap<Bool>;
    
    // ============================================
    // ESTADO INTERNO
    // ============================================
    
    private var logs:Array<LogEntry>;
    private var logFilePath:String;
    private var sessionStartTime:Float;
    private var logCount:Int = 0;
    
    // Callbacks para UI
    private var onLogAdded:LogEntry->Void = null;
    private var onLogCleared:Void->Void = null;
    
    // ============================================
    // TIPOS
    // ============================================
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new()
    {
        logs = [];
        logLevels = new StringMap();
        
        // Por defecto, todos los niveles habilitados
        logLevels.set('info', true);
        logLevels.set('warn', true);
        logLevels.set('error', true);
        logLevels.set('debug', true);
        logLevels.set('trace', true);
        
        sessionStartTime = Sys.time();
        logFilePath = '';
    }
    
    // ============================================
    // FUNCIONES PUBLICAS
    // ============================================
    
    /**
     * Inicializar el debug logger
     */
    public function init(?filePath:String = null):Void
    {
        enabled = true;
        
        if (filePath != null) {
            logFilePath = filePath;
        } else {
            // Usar directorio de mods
        var modsPath = 'mods/debug/';
            if (!FileSystem.exists(modsPath)) {
                FileSystem.createDirectory(modsPath);
            }
        var timestamp = Date.now().toString().replace(':', '-').replace(' ', '_');
            logFilePath = modsPath + 'log_' + timestamp + '.txt';
        }
        
        log('info', 'DebugLogger inicializado');
        log('info', 'Log file: $logFilePath');
        
        // Inicializar interceptor de traces
        initTraceInterceptor();
    }
    
    /**
     * Activar/desactivar modo debug
     */
    public function setEnabled(value:Bool):Void
    {
        enabled = value;
        if (enabled && logFilePath == '') {
            init();
        }
        log('info', 'Debug mode: ${enabled ? "ON" : "OFF"}');
    }
    
    /**
     * Mostrar/ocultar overlay
     */
    public function toggleOverlay():Bool
    {
        showOverlay = !showOverlay;
        return showOverlay;
    }
    
    public function setShowOverlay(value:Bool):Void
    {
        showOverlay = value;
    }
    
    /**
     * Activar/desactivar guardado a archivo
     */
    public function setSaveToFile(value:Bool):Void
    {
        saveToFile = value;
        log('info', 'Save to file: ${saveToFile ? "ON" : "OFF"}');
    }
    
    /**
     * Agregar un log
     */
    public function log(level:String, message:String, ?source:String = null):Void
    {
        if (!enabled) return;
        
    var levelLower = level.toLowerCase();
        if (!logLevels.exists(levelLower) || !logLevels.get(levelLower)) {
            return;
        }
        
    var entry:LogEntry = {
            timestamp: Sys.time(),
            level: levelLower,
            message: message,
            source: source,
            color: getColorForLevel(levelLower)
        };
        
        // Agregar a lista
        logs.push(entry);
        logCount++;
        
        // Limitar tamaño
        while (logs.length > maxLogs) {
            logs.shift();
        }
        
        // Guardar a archivo si está habilitado
        if (saveToFile && logFilePath != '') {
            saveToFileInternal(entry);
        }
        
        // Notificar a UI
        if (onLogAdded != null) {
            onLogAdded(entry);
        }
        
        #if debug
        // En debug, también usar trace nativo
        Sys.println('[' + levelLower.toUpperCase() + '] $message');
        #end
    }
    
    /**
     * Log de información
     */
    public function info(message:String, ?source:String = null):Void
    {
        log('info', message, source);
    }
    
    /**
     * Log de warning
     */
    public function warn(message:String, ?source:String = null):Void
    {
        log('warn', message, source);
    }
    
    /**
     * Log de error
     */
    public function error(message:String, ?source:String = null):Void
    {
        log('error', message, source);
    }
    
    /**
     * Log de debug
     */
    public function debug(message:String, ?source:String = null):Void
    {
        log('debug', message, source);
    }
    
    /**
     * Log de trace
     */
    public function trace(message:String, ?source:String = null):Void
    {
        log('trace', message, source);
    }
    
    /**
     * Limpiar todos los logs
     */
    public function clear():Void
    {
        logs = [];
        if (onLogCleared != null) {
            onLogCleared();
        }
        log('info', 'Logs cleared');
    }
    
    /**
     * Obtener todos los logs
     */
    public function getLogs():Array<LogEntry>
    {
        return logs.copy();
    }
    
    /**
     * Obtener logs filtrados por nivel
     */
    public function getLogsByLevel(level:String):Array<LogEntry>
    {
        return logs.filter(function(entry:LogEntry):Bool {
            return entry.level == level.toLowerCase();
        });
    }
    
    /**
     * Obtener últimos N logs
     */
    public function getLastLogs(count:Int):Array<LogEntry>
    {
    var start = logs.length - count;
        if (start < 0) start = 0;
        return logs.slice(start);
    }
    
    /**
     * Guardar logs a archivo
     */
    public function saveToFile():Bool
    {
        if (logFilePath == '') return false;
        
        try {
        var content = generateLogContent();
            File.saveContent(logFilePath, content);
            log('info', 'Logs guardados a: $logFilePath');
            return true;
        } catch (e:Dynamic) {
            #if debug
            Sys.println('Error guardando logs: $e');
            #end
            return false;
        }
    }
    
    /**
     * Guardar solo errores a archivo
     */
    public function saveErrorsToFile(?path:String = null):Bool
    {
    var filePath = path != null ? path : logFilePath.replace('.txt', '_errors.txt');
        
        try {
        var errorLogs = getLogsByLevel('error');
        var content = '# ERROR LOG - ' + Date.now() + '\n\n';
            
            for (entry in errorLogs) {
                content += '[' + formatTime(entry.timestamp) + '] ' + entry.message;
                if (entry.source != null) content += ' (${entry.source})';
                content += '\n';
            }
            
            File.saveContent(filePath, content);
            return true;
        } catch (e:Dynamic) {
            return false;
        }
    }
    
    /**
     * Configurar niveles de log
     */
    public function setLogLevel(level:String, enabled:Bool):Void
    {
        logLevels.set(level.toLowerCase(), enabled);
        log('info', 'Log level $level: ${enabled ? "enabled" : "disabled"}');
    }
    
    /**
     * Obtener estadísticas
     */
    public function getStats():Dynamic
    {
    var stats = {
            total: logs.length,
            info: 0,
            warn: 0,
            error: 0,
            debug: 0,
            trace: 0,
            sessionTime: Sys.time() - sessionStartTime
        };
        
        for (entry in logs) {
            switch (entry.level) {
                case 'info': stats.info++;
                case 'warn': stats.warn++;
                case 'error': stats.error++;
                case 'debug': stats.debug++;
                case 'trace': stats.trace++;
            }
        }
        
        return stats;
    }
    
    // ============================================
    // CALLBACKS PARA UI
    // ============================================
    
    public function setOnLogAdded(callback:LogEntry->Void):Void
    {
        onLogAdded = callback;
    }
    
    public function setOnLogCleared(callback:Void->Void):Void
    {
        onLogCleared = callback;
    }
    
    // ============================================
    // FUNCIONES PRIVADAS
    // ============================================
    
    private function saveToFileInternal(entry:LogEntry):Void
    {
        try {
        var line = '[' + formatTime(entry.timestamp) + '] [' + entry.level.toUpperCase() + '] ' + entry.message;
            if (entry.source != null) line += ' (${entry.source})';
            line += '\n';
            
            File.saveContent(logFilePath, File.getContent(logFilePath) + line);
        } catch (e:Dynamic) {
            // Silenciar errores de archivo
        }
    }
    
    private function generateLogContent():String
    {
    var content = '# DEBUG LOG - WashosEngine\n';
        content += '# Generated: ' + Date.now() + '\n';
        content += '# Session start: ' + formatTime(sessionStartTime) + '\n';
        content += '# Total logs: ${logs.length}\n\n';
        content += '---\n\n';
        
        for (entry in logs) {
            content += '[' + formatTime(entry.timestamp) + '] [' + entry.level.toUpperCase() + '] ' + entry.message;
            if (entry.source != null) content += ' (${entry.source})';
            content += '\n';
        }
        
        content += '\n---\n';
        content += '# END OF LOG\n';
        
        return content;
    }
    
    private function formatTime(time:Float):String
    {
    var totalSeconds = time - sessionStartTime;
    var minutes = Std.int(totalSeconds / 60);
    var seconds = Std.int(totalSeconds % 60);
    var ms = Std.int((totalSeconds % 1) * 1000);
        
        return StringTools.lpad(Std.string(minutes), '0', 2) + ':' + 
               StringTools.lpad(Std.string(seconds), '0', 2) + '.' + 
               StringTools.lpad(Std.string(ms), '0', 3);
    }
    
    private function getColorForLevel(level:String):Int
    {
        switch (level) {
            case 'info': return 0xFF00FF00;  // Verde
            case 'warn': return 0xFFFFFF00;  // Amarillo
            case 'error': return 0xFFFF0000; // Rojo
            case 'debug': return 0xFF00FFFF; // Cyan
            case 'trace': return 0xFF888888;  // Gris
            default: return 0xFFFFFFFF;      // Blanco
        }
    }
    
    // ============================================
    // INSPECTION
    // ============================================
    
    /**
     * Inspect a value and return its string representation
     */
    public function inspect(value:Dynamic, ?depth:Int = 3):String
    {
        return dumpValue(value, depth, 0);
    }
    
    private function dumpValue(value:Dynamic, depth:Int, indent:Int):String
    {
        if (depth < 0) return '...';
        
    var pad = '';
        for (i in 0...indent) pad += '  ';
        
        if (value == null) return 'null';
        
        if (Std.is(value, Bool)) return value ? 'true' : 'false';
        if (Std.is(value, Int)) return Std.string(value);
        if (Std.is(value, Float)) return Std.string(value);
        if (Std.is(value, String)) return '"$value"';
        
        if (Std.is(value, Array)) {
        var arr = cast(value, Array<Dynamic>);
            if (arr.length == 0) return '[]';
            
        var items:Array<String> = [];
            for (i in 0...arr.length) {
                if (i >= 10) {
                    items.push('... (${arr.length} items)');
                    break;
                }
                items.push(dumpValue(arr[i], depth - 1, indent + 1));
            }
            return '[\n$pad  ' + items.join(',\n$pad  ') + '\n$pad]';
        }
        
        // Object
    var fields:Array<String> = [];
    var count = 0;
        for (field in Reflect.fields(value)) {
            if (field.charAt(0) != '_' && count < 20) {
            var fieldValue = Reflect.field(value, field);
                if (!Reflect.isFunction(fieldValue)) {
                    fields.push('$field: ' + dumpValue(fieldValue, depth - 1, indent + 1));
                    count++;
                }
            }
        }
        
        if (fields.length == 0) return '{}';
        return '{\n$pad  ' + fields.join(',\n$pad  ') + '\n$pad}';
    }
    
    // ============================================
    // TRACE INTERCEPTOR
    // ============================================
    
    /**
     * Initialize trace interceptor to capture all Haxe traces
     * Esto permite que trace() en source/ se capture en DebugLogger
     */
}
#end