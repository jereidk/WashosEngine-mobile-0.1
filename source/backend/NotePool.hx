package backend;

import flixel.group.FlxGroup;
import flixel.FlxObject;
import objects.Note;

/**
 * NotePool - Sistema de Object Pooling especializado para Notes
 * 
 * Optimizado para el flujo de notas en un rhythm game.
 * Reduce significativamente el GC al reutilizar objetos Note.
 * 
 * Uso:
 * ```haxe
 * // En PlayState.create():
 * notePool = new NotePool(100);
 * 
 * // En vez de new Note(), usar:
 * var note:Note = notePool.get(spawnTime, noteColumn, oldNote);
 * 
 * // Para devolver al pool:
 * notePool.release(note);
 * ```
 */
class NotePool
{
    // Pool de Notes
    private var pool:FlxTypedGroup<Note>;
    private var inUse:FlxTypedGroup<Note>;
    
    // Factory
    private var createNote:Void->Note;
    
    // Stats
    public var totalCreated:Int = 0;
    public var totalRecycled:Int = 0;
    public var peakActive:Int = 0;
    
    /**
     * Crear un nuevo NotePool
     * @param initialSize Cuántos Notes pre-crear
     */
    public function new(initialSize:Int = 50)
    {
        pool = new FlxTypedGroup<Note>();
        inUse = new FlxTypedGroup<Note>();
        
        // Crear Notes iniciales
        for (i in 0...initialSize) {
            var note = new Note(0, 0, null, false);
            note.exists = false;
            note.active = false;
            pool.add(note);
        }
        
        totalCreated = initialSize;
        
        #if FLX_OBJECT_POOL
        trace('[NotePool] Initialized with $initialSize pre-allocated notes');
        #end
    }
    
    /**
     * Obtener un Note del pool
     * @param strumTime Tiempo de la nota
     * @param noteData Columna de la nota
     * @param prevNote Nota anterior
     * @param sustainNote Si es nota de sostenimiento
     * @return Note
     */
    public function get(?strumTime:Float = 0, ?noteData:Int = 0, ?prevNote:Note = null, ?sustainNote:Bool = false):Note
    {
        var note:Note = null;
        
        // Buscar nota disponible en el pool
        if (pool.length > 0) {
            note = pool.getFirstAvailable();
        }
        
        // Crear nueva si no hay disponibles
        if (note == null) {
            note = new Note(strumTime, noteData, prevNote, sustainNote);
            totalCreated++;
            
            #if FLX_OBJECT_POOL
            trace('[NotePool] Auto-expanded pool to $totalCreated notes');
            #end
        } else {
            // Resetear la nota existente
            note.resetNote(strumTime, noteData, prevNote, sustainNote);
            pool.remove(note);
        }
        
        inUse.add(note);
        note.exists = true;
        note.active = true;
        
        // Track peak
        var active = inUse.countLiving();
        if (active > peakActive) peakActive = active;
        
        totalRecycled++;
        
        return note;
    }
    
    /**
     * Devolver un Note al pool
     * @param note Nota a devolver
     */
    public function release(note:Note):Void
    {
        if (note == null) return;
        
        // Quitar de inUse y añadir a pool
        inUse.remove(note, true);
        pool.add(note);
        
        // Desactivar
        note.exists = false;
        note.active = false;
        
        // Limpiar tail/nextNote para evitar memory leaks
        note.tail = [];
        note.nextNote = null;
    }
    
    /**
     * Devolver múltiples Notes al pool
     * @param notes Array de notas
     */
    public function releaseAll(notes:Array<Note>):Void
    {
        for (note in notes) {
            release(note);
        }
    }
    
    /**
     * Limpiar todas las notas en uso y devolverlas al pool
     */
    public function clearAll():Void
    {
        for (note in inUse) {
            note.exists = false;
            note.active = false;
            pool.add(note);
        }
        inUse.clear();
    }
    
    /**
     * Pre-allocate más notas al pool
     * @param count Cuántas añadir
     */
    public function preallocate(count:Int):Void
    {
        for (i in 0...count) {
            var note = new Note(0, 0, null, false);
            note.exists = false;
            note.active = false;
            pool.add(note);
            totalCreated++;
        }
        
        #if FLX_OBJECT_POOL
        trace('[NotePool] Pre-allocated $count more notes');
        #end
    }
    
    // ============================================
    // GETTERS
    // ============================================
    
    /**
     * Número de notas en el pool (disponibles)
     */
    public var available(get, never):Int;
    private function get_available():Int return pool.length;
    
    /**
     * Número de notas en uso
     */
    public var used(get, never):Int;
    private function get_used():Int return inUse.countLiving();
    
    /**
     * Total de notas creadas
     */
    public var total(get, never):Int;
    private function get_total():Int return totalCreated;
    
    /**
     * Porcentaje de utilización
     */
    public var utilization(get, never):Float;
    private function get_utilization():Float
    {
        return totalCreated > 0 ? (totalRecycled / totalCreated) * 100 : 0;
    }
    
    // ============================================
    // DEBUG
    // ============================================
    
    /**
     * Generar reporte de estadísticas
     */
    public function getReport():String
    {
        return '[NotePool] Created: $totalCreated | In Pool: $available | In Use: $used | Peak: $peakActive | Recycles: $totalRecycled | Util: ${Math.round(utilization)}%';
    }
    
    /**
     * Debug print
     */
    public function debug():Void
    {
        #if debug
        trace(getReport());
        #end
    }
}