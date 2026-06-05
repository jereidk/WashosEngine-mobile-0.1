package psychlua;

#if LUA_ALLOWED
import flixel.FlxSprite;
import flixel.FlxText;
import flixel.FlxGroup;
import flixel.util.FlxColor;
import flixel.group.FlxTypedGroup;
import flixel.math.FlxPoint;

/**
 * DebugOverlay - Visual debug display for Android
 * 
 * Muestra logs en pantalla con colores según el nivel:
 * - Verde: Info
 * - Amarillo: Warning  
 * - Rojo: Error
 * - Cyan: Debug
 * - Gris: Trace
 * 
 * Características:
 * - Scroll para ver logs antiguos
 * - Indicador de nivel de log
 * - Botón para guardar logs
 * - Toggle con tecla/botón
 */
class DebugOverlay extends FlxTypedGroup<FlxSprite>
{
    // Singleton para acceso global
    public static var instance(get, never):DebugOverlay;
    private static var _instance:DebugOverlay = null;
    
    private static inline function get_instance():DebugLogger
    {
        return DebugLogger.instance;
    }
    
    // ============================================
    // CONFIGURACION
    // ============================================
    
    /** Posición en pantalla */
    public var position:FlxPoint = new FlxPoint(10, 50);
    
    /** Tamaño del overlay */
    public var overlayWidth:Int = 400;
    public var overlayHeight:Int = 300;
    
    /** Máximo de líneas visibles */
    public var maxVisibleLines:Int = 12;
    
    /** Color de fondo */
    public var backgroundColor:Int = 0xCC000000; // Negro semi-transparente
    
    // ============================================
    // ELEMENTOS VISUALES
    // ============================================
    
    private var background:FlxSprite;
    private var logTexts:Array<FlxText>;
    private var headerText:FlxText;
    private var scrollOffset:Int = 0;
    
    // ============================================
    // ESTADO
    // ============================================
    
    private var isVisible:Bool = false;
    private var logs:Array<DebugLogger.LogEntry> = [];
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new()
    {
        super();
        
        // Fondo
        background = new FlxSprite(position.x, position.y);
        background.makeGraphic(overlayWidth, overlayHeight, backgroundColor);
        background.scrollFactor.set();
        add(background);
        
        // Header
        headerText = new FlxText(position.x + 5, position.y + 5, overlayWidth - 10, 'DEBUG LOG');
        headerText.setFormat(null, 14, FlxColor.WHITE, LEFT);
        headerText.bold = true;
        headerText.scrollFactor.set();
        add(headerText);
        
        // Textos de log
        logTexts = [];
        for (i in 0...maxVisibleLines) {
            var text = new FlxText(position.x + 5, position.y + 25 + (i * 20), overlayWidth - 10, '');
            text.setFormat(null, 12, FlxColor.WHITE, LEFT);
            text.scrollFactor.set();
            text.alpha = 0;
            logTexts.push(text);
            add(text);
        }
        
        // Configurar callback
        DebugLogger.instance.setOnLogAdded(onLogAdded);
        DebugLogger.instance.setOnLogCleared(onLogCleared);
        
        visible = false;
        exists = false;
    }
    
    // ============================================
    // FUNCIONES PUBLICAS
    // ============================================
    
    /**
     * Mostrar/ocultar overlay
     */
    public function toggle():Void
    {
        isVisible = !isVisible;
        visible = isVisible;
        exists = isVisible;
        
        DebugLogger.instance.setShowOverlay(isVisible);
        
        if (isVisible) {
            refreshLogs();
        }
    }
    
    /**
     * Mostrar overlay
     */
    public function show():Void
    {
        isVisible = true;
        visible = true;
        exists = true;
        DebugLogger.instance.setShowOverlay(true);
        refreshLogs();
    }
    
    /**
     * Ocultar overlay
     */
    public function hide():Void
    {
        isVisible = false;
        visible = false;
        exists = false;
        DebugLogger.instance.setShowOverlay(false);
    }
    
    /**
     * Scroll hacia arriba
     */
    public function scrollUp():Void
    {
        if (scrollOffset < logs.length - maxVisibleLines) {
            scrollOffset++;
            updateDisplay();
        }
    }
    
    /**
     * Scroll hacia abajo
     */
    public function scrollDown():Void
    {
        if (scrollOffset > 0) {
            scrollOffset--;
            updateDisplay();
        }
    }
    
    /**
     * Scroll al inicio
     */
    public function scrollToStart():Void
    {
        scrollOffset = 0;
        updateDisplay();
    }
    
    /**
     * Scroll al final
     */
    public function scrollToEnd():Void
    {
        scrollOffset = logs.length - maxVisibleLines;
        if (scrollOffset < 0) scrollOffset = 0;
        updateDisplay();
    }
    
    /**
     * Actualizar logs mostrados
     */
    public function refreshLogs():Void
    {
        logs = DebugLogger.instance.getLogs();
        updateDisplay();
    }
    
    /**
     * Limpiar visualización
     */
    public function clearDisplay():Void
    {
        for (text in logTexts) {
            text.text = '';
            text.alpha = 0;
        }
        scrollOffset = 0;
    }
    
    /**
     * Verificar si está visible
     */
    public function isShowing():Bool
    {
        return isVisible;
    }
    
    // ============================================
    // CALLBACKS
    // ============================================
    
    private function onLogAdded(entry:DebugLogger.LogEntry):Void
    {
        logs.push(entry);
        if (isVisible) {
            updateDisplay();
        }
    }
    
    private function onLogCleared():Void
    {
        logs = [];
        clearDisplay();
    }
    
    // ============================================
    // ACTUALIZACION
    // ============================================
    
    private function updateDisplay():Void
    {
        // Limpiar textos
        for (text in logTexts) {
            text.text = '';
            text.alpha = 0;
        }
        
        // Calcular rango de logs a mostrar
        var startIdx = logs.length - maxVisibleLines - scrollOffset;
        var endIdx = logs.length - scrollOffset;
        
        if (startIdx < 0) startIdx = 0;
        if (endIdx > logs.length) endIdx = logs.length;
        
        // Mostrar logs
        var displayIdx = 0;
        for (i in startIdx...endIdx) {
            if (displayIdx >= maxVisibleLines) break;
            
            var entry = logs[i];
            var text = logTexts[displayIdx];
            
            // Formato: [HH:MM:SS] [LEVEL] mensaje
            var time = formatTimestamp(entry.timestamp);
            text.text = '[$time] [${entry.level.toUpperCase()}] ${entry.message}';
            text.color = FlxColor.fromInt(entry.color);
            text.alpha = 1;
            
            displayIdx++;
        }
        
        // Actualizar header
        var stats = DebugLogger.instance.getStats();
        headerText.text = 'DEBUG LOG (${stats.total} logs, E:${stats.error} W:${stats.warn})';
    }
    
    private function formatTimestamp(time:Float):String
    {
        var totalSeconds = time;
        var minutes = Std.int(totalSeconds / 60);
        var seconds = Std.int(totalSeconds % 60);
        var ms = Std.int((totalSeconds % 1) * 100);
        
        return StringTools.lpad(Std.string(minutes), '0', 2) + ':' + 
               StringTools.lpad(Std.string(seconds), '0', 2) + '.' + 
               StringTools.lpad(Std.string(ms), '0', 2);
    }
    
    // ============================================
    // DESTRUCCION
    // ============================================
    
    override public function destroy():Void
    {
        DebugLogger.instance.setOnLogAdded(null);
        DebugLogger.instance.setOnLogCleared(null);
        super.destroy();
    }
}
#end