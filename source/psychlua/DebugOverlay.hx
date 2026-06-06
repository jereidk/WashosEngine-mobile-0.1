package psychlua;

#if LUA_ALLOWED
import flixel.FlxSprite;
import flixel.FlxText;
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
 */

typedef LogEntryData = {
    var timestamp:Float;
    var level:String;
    var message:String;
    var ?source:String;
    var ?color:Int;
    }

class DebugOverlay extends FlxTypedGroup<FlxSprite>
{
    // Singleton
    public static var instance(get, never):DebugOverlay;
    private static var _instance:DebugOverlay = null;
    
    private static inline function get_instance():DebugOverlay
    {
        if (_instance == null) _instance = new DebugOverlay();
        return _instance;
    }
    
    // Log entry structure (local copy)
    
    // Configuration
    public var position:FlxPoint = new FlxPoint(10, 50);
    public var overlayWidth:Int = 400;
    public var overlayHeight:Int = 300;
    public var maxVisibleLines:Int = 12;
    public var backgroundColor:Int = 0xCC000000;
    
    // Elements
    private var background:FlxSprite;
    private var logTexts:Array<FlxText>;
    private var headerText:FlxText;
    private var scrollOffset:Int = 0;
    
    // State
    private var isShowing:Bool = false;
    private var logs:Array<LogEntryData> = [];
    
    public function new()
    {
        super();
        
        // Background
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
        
        // Log texts
        logTexts = [];
        for (i in 0...maxVisibleLines) {
        var text = new FlxText(position.x + 5, position.y + 25 + (i * 20), overlayWidth - 10, '');
            text.setFormat(null, 12, FlxColor.WHITE, LEFT);
            text.scrollFactor.set();
            text.alpha = 0;
            logTexts.push(text);
            add(text);
        }
        
        // Setup callbacks
        DebugLogger.instance.setOnLogAdded(onLogAdded);
        DebugLogger.instance.setOnLogCleared(onLogCleared);
        
        visible = false;
        exists = false;
    }
    
    // Toggle visibility
    public function toggle():Void
    {
        isShowing = !isShowing;
        visible = isShowing;
        exists = isShowing;
        DebugLogger.instance.setShowOverlay(isShowing);
        
        if (isShowing) {
            refreshLogs();
        }
    }
    
    // Show overlay
    public function show():Void
    {
        isShowing = true;
        visible = true;
        exists = true;
        DebugLogger.instance.setShowOverlay(true);
        refreshLogs();
    }
    
    // Hide overlay
    public function hide():Void
    {
        isShowing = false;
        visible = false;
        exists = false;
        DebugLogger.instance.setShowOverlay(false);
    }
    
    // Scroll up
    public function scrollUp():Void
    {
        if (scrollOffset < logs.length - maxVisibleLines) {
            scrollOffset++;
            updateDisplay();
        }
    }
    
    // Scroll down
    public function scrollDown():Void
    {
        if (scrollOffset > 0) {
            scrollOffset--;
            updateDisplay();
        }
    }
    
    // Refresh logs display
    public function refreshLogs():Void
    {
        logs = [];
    var allLogs = DebugLogger.instance.getLogs();
        for (log in allLogs) {
        var entry:LogEntryData = {
                timestamp: log.timestamp,
                level: log.level,
                message: log.message,
                source: log.source,
                color: log.color
            };
            logs.push(entry);
        }
        updateDisplay();
    }
    
    // Clear display
    public function clearDisplay():Void
    {
        for (text in logTexts) {
            text.text = '';
            text.alpha = 0;
        }
        scrollOffset = 0;
    }
    
    // Check if showing
    public function isActive():Bool
    {
        return isShowing;
    }
    
    // Callback: log added
    private function onLogAdded(entry:Dynamic):Void
    {
    var logData:LogEntryData = {
            timestamp: entry.timestamp,
            level: entry.level,
            message: entry.message,
            source: entry.source,
            color: entry.color
        };
        logs.push(logData);
        if (isShowing) {
            updateDisplay();
        }
    }
    
    // Callback: logs cleared
    private function onLogCleared():Void
    {
        logs = [];
        clearDisplay();
    }
    
    // Update display
    private function updateDisplay():Void
    {
        // Clear texts
        for (text in logTexts) {
            text.text = '';
            text.alpha = 0;
        }
        
        // Calculate range
    var startIdx = logs.length - maxVisibleLines - scrollOffset;
    var endIdx = logs.length - scrollOffset;
        
        if (startIdx < 0) startIdx = 0;
        if (endIdx > logs.length) endIdx = logs.length;
        
        // Show logs
    var displayIdx = 0;
        for (i in startIdx...endIdx) {
            if (displayIdx >= maxVisibleLines) break;
            
        var entry = logs[i];
        var text = logTexts[displayIdx];
            
        var time = formatTimestamp(entry.timestamp);
            text.text = '[' + time + '] [' + entry.level.toUpperCase() + '] ' + entry.message;
            text.color = entry.color;
            text.alpha = 1;
            
            displayIdx++;
        }
        
        // Update header
    var stats = DebugLogger.instance.getStats();
        headerText.text = 'DEBUG LOG (' + stats.total + ' logs, E:' + stats.error + ' W:' + stats.warn + ')';
    }
    
    // Format timestamp
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
    
    // Destroy
    override public function destroy():Void
    {
        DebugLogger.instance.setOnLogAdded(null);
        DebugLogger.instance.setOnLogCleared(null);
        super.destroy();
    }
}
#end