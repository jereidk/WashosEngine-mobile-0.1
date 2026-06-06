package backend;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

/**
 * ReplaySystem - Sistema de grabación y reproducción de jugadas
 * 
 * Permite grabar inputs del jugador y reproducirlos para:
 * - Reproducción automática de jugadas
 * - Modo spectate
 * - Ghost notes (fantasma)
 * - AI opponent que replica jugadas
 * 
 * Uso:
 * ```haxe
 * // Para grabar:
 * ReplaySystem.instance.startRecording('tutorial');
 * // ... jugador juega ...
 * ReplaySystem.instance.stopRecording();
 * ReplaySystem.instance.saveReplay('tutorial');
 * 
 * // Para reproducir:
 * ReplaySystem.instance.loadReplay('tutorial');
 * ReplaySystem.instance.startPlayback();
 * ```
 */

typedef InputFrame = {
    var time:Float;          // Tiempo en segundos
    var key:Int;            // Tecla (0-3)
    var pressed:Bool;        // Si fue presionado o soltado
    var noteData:Int;       // Columna del note (0-3)
    }

typedef ReplayData = {
    var version:String;      // Versión del formato
    var songName:String;     // Nombre de la canción
    var songDifficulty:String; // Dificultad
    var date:String;        // Fecha de creación
    var score:Int;          // Score final
    var accuracy:Float;      // Accuracy final
    var perfects:Int;       // Notas perfectas
    var goods:Int;          // Notas good
    var bads:Int;           // Notas bad
    var misses:Int;         // Notas missed
    var maxCombo:Int;       // Combo máximo
    var inputs:Array<InputFrame>; // Lista de inputs
    var metadata:Dynamic;   // Datos adicionales
    }

class ReplaySystem
{
    // ============================================
    // CONSTANTES DE ESTADO
    // ============================================
    private static inline var STATE_IDLE:Int = 0;
    private static inline var STATE_RECORDING:Int = 1;
    private static inline var STATE_PLAYBACK:Int = 2;
    private static inline var STATE_PAUSED:Int = 3;

    // ============================================
    // SINGLETON
    // ============================================
    
    public static var instance(get, never):ReplaySystem;
    private static var _instance:ReplaySystem = null;
    
    private static inline function get_instance():ReplaySystem
    {
        if (_instance == null) _instance = new ReplaySystem();
        return _instance;
    }
    
    // ============================================
    // TIPOS DE DATOS
    // ============================================
    
    /** Un input individual */
    
    /** Datos del replay */
    
    
    // ============================================
    // PROPIEDADES
    // ============================================
    
    /** Estado actual */
    public var state(default, null):Int = 0;
    
    /** Nombre del replay actual */
    public var currentReplayName:String = '';
    
    /** Datos del replay */
    private var replayData:ReplayData = null;
    
    /** Inputs grabados */
    private var recordedInputs:Array<InputFrame> = [];
    
    /** Índice actual de reproducción */
    private var playbackIndex:Int = 0;
    
    /** Tiempo de inicio */
    private var startTime:Float = 0;
    
    /** Pausa acumulada */
    private var pausedTime:Float = 0;
    
    /** Si está en modo ghost (fantasma) */
    public var isGhostMode:Bool = false;
    
    /** Callback cuando se presiona una tecla (para playback) */
    public var onGhostInput:Int->Bool->Void = null;
    
    /** Callback cuando termina el replay */
    public var onPlaybackEnd:Void->Void = null;
    
    /** Velocidad de reproducción (1.0 = normal) */
    public var playbackSpeed:Float = 1.0;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    private function new() {}
    
    // ============================================
    // GRABACIÓN
    // ============================================
    
    /**
     * Iniciar grabación de un replay
     */
    public function startRecording(?name:String = 'replay'):Void
    {
        if (state != STATE_IDLE) {
            #if debug
            trace('[ReplaySystem] Cannot start recording - state is ' + state);
            #end
            return;
        }
        
        currentReplayName = name;
        recordedInputs = [];
        state = STATE_RECORDING;
        startTime = 0;
        pausedTime = 0;
        
        #if debug
        trace('[ReplaySystem] Started recording: ' + name);
        #end
    }
    
    /**
     * Registrar un input
     */
    public function recordInput(time:Float, key:Int, pressed:Bool, ?noteData:Int = -1):Void
    {
        if (state != STATE_RECORDING) return;
        
        if (startTime == 0) startTime = time;
        
        recordedInputs.push({
            time: time - startTime - pausedTime,
            key: key,
            pressed: pressed,
            noteData: noteData
        });
    }
    
    /**
     * Registrar input de note hit
     */
    public function recordNoteHit(time:Float, noteData:Int, rating:String):Void
    {
        if (state != STATE_RECORDING) return;
        
        // 0-3 son las teclas de juego
        recordInput(time, noteData, true, noteData);
    }
    
    /**
     * Detener grabación
     */
    public function stopRecording():ReplayData
    {
        if (state != STATE_RECORDING) return null;
        
        replayData = createReplayData();
        state = STATE_IDLE;
        
        #if debug
        trace('[ReplaySystem] Stopped recording. Inputs: ' + recordedInputs.length);
        #end
        
        return replayData;
    }
    
    /**
     * Crear estructura de datos del replay
     */
    private function createReplayData(?score:Int = 0, ?accuracy:Float = 100, 
            ?perfects:Int = 0, ?goods:Int = 0, ?bads:Int = 0, ?misses:Int = 0, ?maxCombo:Int = 0):ReplayData
    {
        return {
            version: '1.0.0',
            songName: currentReplayName,
            songDifficulty: 'normal',
            date: Date.now().toString(),
            score: score,
            accuracy: accuracy,
            perfects: perfects,
            goods: goods,
            bads: bads,
            misses: misses,
            maxCombo: maxCombo,
            inputs: recordedInputs.copy(),
            metadata: {}
        };
    }
    
    // ============================================
    // GUARDADO / CARGA
    // ============================================
    
    /**
     * Guardar replay a archivo
     */
    public function saveReplay(?path:String = null):Bool
    {
        if (replayData == null && state == STATE_IDLE) {
            replayData = createReplayData();
        }
        
        if (replayData == null) return false;
        
        if (path == null) {
            path = 'replays/' + currentReplayName + '.json';
        }
        
        try {
            // Crear directorio si no existe
        var dir = haxe.io.Path.directory(path);
            if (!FileSystem.exists(dir)) {
                FileSystem.createDirectory(dir);
            }
            
        var jsonStr = Json.stringify(replayData, null, '  ');
            File.saveContent(path, jsonStr);
            
            #if debug
            trace('[ReplaySystem] Saved replay to: ' + path);
            #end
            
            return true;
        } catch (e:Dynamic) {
            #if debug
            trace('[ReplaySystem] Failed to save replay: ' + e);
            #end
            return false;
        }
    }
    
    /**
     * Cargar replay desde archivo
     */
    public function loadReplay(path:String):Bool
    {
        try {
        var content = File.getContent(path);
            replayData = Json.parse(content);
            
            // Reset playback
            playbackIndex = 0;
            startTime = 0;
            pausedTime = 0;
            
            #if debug
            trace('[ReplaySystem] Loaded replay from: ' + path);
            trace('  Inputs: ' + replayData.inputs.length);
            trace('  Score: ' + replayData.score);
            #end
            
            return true;
        } catch (e:Dynamic) {
            #if debug
            trace('[ReplaySystem] Failed to load replay: ' + e);
            #end
            return false;
        }
    }
    
    /**
     * Cargar replay desde JSON string
     */
    public function loadReplayFromJson(jsonStr:String):Bool
    {
        try {
            replayData = Json.parse(jsonStr);
            playbackIndex = 0;
            startTime = 0;
            pausedTime = 0;
            return true;
        } catch (e:Dynamic) {
            #if debug
            trace('[ReplaySystem] Failed to parse replay JSON: ' + e);
            #end
            return false;
        }
    }
    
    // ============================================
    // REPRODUCCIÓN
    // ============================================
    
    /**
     * Iniciar reproducción del replay
     */
    public function startPlayback(?ghostMode:Bool = false):Void
    {
        if (replayData == null) {
            #if debug
            trace('[ReplaySystem] No replay data to play');
            #end
            return;
        }
        
        isGhostMode = ghostMode;
        playbackIndex = 0;
        state = STATE_PLAYBACK;
        startTime = 0;
        
        #if debug
        trace('[ReplaySystem] Started playback' + (ghostMode ? ' (ghost mode)' : ''));
        #end
    }
    
    /**
     * Pausar reproducción
     */
    public function pausePlayback():Void
    {
        if (state == STATE_PLAYBACK) {
            state = STATE_PAUSED;
            #if debug
            trace('[ReplaySystem] Paused playback');
            #end
        }
    }
    
    /**
     * Reanudar reproducción
     */
    public function resumePlayback():Void
    {
        if (state == STATE_PAUSED) {
            state = STATE_PLAYBACK;
            #if debug
            trace('[ReplaySystem] Resumed playback');
            #end
        }
    }
    
    /**
     * Detener reproducción
     */
    public function stopPlayback():Void
    {
        state = STATE_IDLE;
        playbackIndex = 0;
        
        #if debug
        trace('[ReplaySystem] Stopped playback');
        #end
    }
    
    /**
     * Update - procesar inputs de playback
     */
    public function update(currentTime:Float):Void
    {
        if (state != STATE_PLAYBACK) return;
        if (replayData == null) return;
        
        if (startTime == 0) startTime = currentTime;
        
    var elapsedTime = (currentTime - startTime - pausedTime) * playbackSpeed;
        
        // Procesar todos los inputs hasta el tiempo actual
        while (playbackIndex < replayData.inputs.length) {
        var input = replayData.inputs[playbackIndex];
            
            if (input.time <= elapsedTime) {
                // Ejecutar input
                if (onGhostInput != null) {
                    onGhostInput(input.key, input.pressed);
                }
                playbackIndex++;
            } else {
                break;
            }
        }
        
        // Verificar fin del replay
        if (playbackIndex >= replayData.inputs.length) {
            if (onPlaybackEnd != null) {
                onPlaybackEnd();
            }
            stopPlayback();
        }
    }
    
    // ============================================
    // UTILIDADES
    // ============================================
    
    /**
     * Obtener replay actual como JSON
     */
    public function getReplayJson():String
    {
        if (replayData == null) return null;
        return Json.stringify(replayData);
    }
    
    /**
     * Obtener stats del replay
     */
    public function getStats():Dynamic
    {
        if (replayData == null) return null;
        
        return {
            songName: replayData.songName,
            score: replayData.score,
            accuracy: replayData.accuracy,
            perfects: replayData.perfects,
            goods: replayData.goods,
            bads: replayData.bads,
            misses: replayData.misses,
            maxCombo: replayData.maxCombo,
            totalInputs: replayData.inputs.length,
            duration: replayData.inputs.length > 0 ? replayData.inputs[replayData.inputs.length - 1].time : 0
        };
    }
    
    /**
     * Verificar si hay replay cargado
     */
    public function hasReplay():Bool
    {
        return replayData != null;
    }
    
    /**
     * Listar replays disponibles
     */
    public static function listReplays(?directory:String = 'replays'):Array<String>
    {
    var list:Array<String> = [];
        
        try {
            if (FileSystem.exists(directory)) {
                for (file in FileSystem.readDirectory(directory)) {
                    if (file.endsWith('.json')) {
                        list.push(file.substr(0, file.length - 5)); // Sin extensión
                    }
                }
            }
        } catch (e:Dynamic) {}
        
        return list;
    }
    
    /**
     * Eliminar un replay
     */
    public static function deleteReplay(name:String, ?directory:String = 'replays'):Bool
    {
    var path = directory + '/' + name + '.json';
        
        try {
            if (FileSystem.exists(path)) {
                FileSystem.deleteFile(path);
                return true;
            }
        } catch (e:Dynamic) {}
        
        return false;
    }
    
    /**
     * Clear datos actuales
     */
    public function clear():Void
    {
        state = STATE_IDLE;
        replayData = null;
        recordedInputs = [];
        playbackIndex = 0;
        currentReplayName = '';
        isGhostMode = false;
    }
    
    // ============================================
    // GHOST MODE HELPERS
    // ============================================
    
    /**
     * Crear un sprite fantasma (follows replay positions)
     */
    public function createGhost(?spritePath:String = null):GhostSprite
    {
        return new GhostSprite(this, spritePath);
    }
}
class GhostSprite extends FlxSprite
{
    private var replaySystem:ReplaySystem;
    private var replayData:ReplayData;
    private var currentIndex:Int = 0;
    private var startTime:Float = 0;
    
    public var ghostAlpha:Float = 0.5;
    
    public function new(replay:ReplaySystem, ?spritePath:String)
    {
        super();
        replaySystem = replay;
        
        if (spritePath != null && sys.FileSystem.exists(spritePath)) {
            loadGraphic(spritePath);
        }
        
        alpha = ghostAlpha;
    }
    
    public function setReplayData(data:ReplayData):Void
    {
        replayData = data;
        currentIndex = 0;
    }
    
    public function resetReplay():Void
    {
        currentIndex = 0;
        startTime = 0;
    }
    
    public function updatePosition(currentTime:Float, ?x:Float, ?y:Float):Void
    {
        if (replayData == null || replayData.inputs == null) return;
        
        if (startTime == 0) startTime = currentTime;
        
        // Por ahora solo muestra el sprite si hay inputs
        // La posición real vendría de los datos del note hit
        this.x = x ?? this.x;
        this.y = y ?? this.y;
    }
}