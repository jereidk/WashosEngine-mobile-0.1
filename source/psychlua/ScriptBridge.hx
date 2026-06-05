package psychlua;

#if LUA_ALLOWED
import haxe.DynamicAccess;
import haxe.ds.StringMap;
import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.system.FlxSound;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import sys.io.File;
import sys.FileSystem;

/**
 * ScriptBridge - Advanced Lua scripting system for WashosEngine
 * 
 * Provides direct access to engine internals for modders.
 * 
 * Usage in Lua:
 * ```lua
 * -- Get/set properties
 * engine.getProperty('PlayState.SONG')
 * engine.setProperty('PlayState.storyWeek', 2)
 * 
 * -- Call static functions
 * engine.callStatic('Paths', 'mods', 'images/character')
 * 
 * -- Create instances
 * local note = engine.createInstance('objects.Note', 100, 200)
 * note:makeGraphic(100, 20, '0xFFFF0000')
 * 
 * -- Hook functions
 * engine.hook('PlayState.onBeatHit', function(self)
 *     debugPrint('Beat: ' .. self.curBeat)
 * end)
 * 
 * -- Get all available classes/functions
 * engine.listClasses()
 * engine.help('PlayState')
 * ```
 */
class ScriptBridge
{
    // Static singleton
    public static var instance(get, never):ScriptBridge;
    private static var _instance:ScriptBridge = null;
    
    private static inline function get_instance():ScriptBridge
    {
        if (_instance == null) _instance = new ScriptBridge();
        return _instance;
    }
    
    // Registered hooks
    private var hooks:StringMap<Array<HookCallback>>;
    private var overriddenFunctions:StringMap<OverrideInfo>;
    
    // Cache for class lookups
    private var classCache:StringMap<Class<Dynamic>>;
    private var functionCache:StringMap<Dynamic>;
    
    public function new()
    {
        hooks = new StringMap();
        overriddenFunctions = new StringMap();
        classCache = new StringMap();
        functionCache = new StringMap();
    }
    
    /**
     * Initialize the bridge - called from FunkinLua constructor
     */
    public function init(funk:FunkinLua):Void
    {
        // Register engine table in Lua
        registerEngineTable(funk);
    }
    
    /**
     * Register the global 'engine' table in Lua
     */
    function registerEngineTable(funk:FunkinLua):Void
    {
        var lua:State = funk.lua;
        
        // Create engine table
        Lua_helper.add_callback(lua, "engine", function(action:String, args:Dynamic):Dynamic {
            return handleEngineCall(action, args, funk);
        });
        
        // Register individual functions for performance
        Lua_helper.add_callback(lua, "getProperty", function(variable:String, ?allowMaps:Bool = false):Dynamic {
            return getPropertyFromPath(variable, allowMaps);
        });
        
        Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic {
            return setPropertyFromPath(variable, value, allowMaps);
        });
        
        Lua_helper.add_callback(lua, "callMethod", function(objPath:String, methodName:String, ?args:Array<Dynamic>):Dynamic {
            return callMethodOnObject(objPath, methodName, args);
        });
        
        Lua_helper.add_callback(lua, "createInstance", function(classPath:String, ?args:Array<Dynamic>):Dynamic {
            return createInstanceFromPath(classPath, args);
        });
        
        Lua_helper.add_callback(lua, "callStatic", function(classPath:String, methodName:String, ?args:Array<Dynamic>):Dynamic {
            return callStaticMethod(classPath, methodName, args);
        });
        
        Lua_helper.add_callback(lua, "getClass", function(classPath:String):Dynamic {
            return getHaxeClass(classPath);
        });
        
        Lua_helper.add_callback(lua, "hook", function(path:String, callback:Dynamic):Void {
            registerHook(path, callback);
        });
        
        Lua_helper.add_callback(lua, "override", function(path:String, callback:Dynamic):Void {
            registerOverride(path, callback);
        });
        
        Lua_helper.add_callback(lua, "listClasses", function(?filter:String = null):Array<String> {
            return getAvailableClasses(filter);
        });
        
        Lua_helper.add_callback(lua, "listMethods", function(classPath:String):Array<String> {
            return getClassMethods(classPath);
        });
        
        Lua_helper.add_callback(lua, "listProperties", function(classPath:String):Array<String> {
            return getClassProperties(classPath);
        });
        
        Lua_helper.add_callback(lua, "help", function(?item:String = null):Dynamic {
            return getHelp(item);
        });
        
        Lua_helper.add_callback(lua, "eval", function(code:String):Dynamic {
            return evaluateExpression(code);
        });
        
        Lua_helper.add_callback(lua, "newTable", function(?name:String = null):Dynamic {
            return {};
        });
        
        Lua_helper.add_callback(lua, "typeOf", function(value:Dynamic):String {
            return getLuaType(value);
        });
        
        Lua_helper.add_callback(lua, "import", function(classPath:String):Void {
            // Import a class to make it available
            importClass(classPath);
        });
        
        Lua_helper.add_callback(lua, "require", function(classPath:String):Dynamic {
            return getHaxeClass(classPath);
        });
    }
    
    /**
     * Handle engine.* calls from Lua
     */
    function handleEngineCall(action:String, args:Dynamic, funk:FunkinLua):Dynamic
    {
        switch (action)
        {
            case 'get':
                var path:String = args;
                return getPropertyFromPath(path);
                
            case 'set':
                var obj:Dynamic = args;
                if (obj.path != null) {
                    setPropertyFromPath(obj.path, obj.value);
                }
                return null;
                
            case 'call':
                return callMethodOnObject(args.class, args.method, args.args);
                
            case 'new':
                return createInstanceFromPath(args.class, args.args);
                
            case 'static':
                return callStaticMethod(args.class, args.method, args.args);
                
            case 'hook':
                registerHook(args.path, args.callback);
                return true;
                
            case 'override':
                registerOverride(args.path, args.callback);
                return true;
                
            case 'list':
                return getAvailableClasses(args);
                
            case 'help':
                return getHelp(args);
                
            default:
                FunkinLua.luaTrace('ScriptBridge: Unknown action: $action', true, false, FlxColor.RED);
                return null;
        }
    }
    
    /**
     * Get a property using dot notation path (e.g., 'PlayState.SONG')
     */
    public function getPropertyFromPath(path:String, ?allowMaps:Bool = false):Dynamic
    {
        var parts:Array<String> = path.split('.');
        if (parts.length == 0) return null;
        
        var current:Dynamic = null;
        var firstPart:String = parts[0];
        
        // Try to resolve first part
        if (firstPart == 'engine' || firstPart == 'global')
        {
            current = this;
        }
        else if (firstPart == 'PlayState' || firstPart == 'PlayState.instance')
        {
            current = Type.resolveClass('states.PlayState');
            if (current != null) current = Reflect.field(current, 'instance');
        }
        else if (firstPart == 'FlxG' || firstPart == 'FlxG.state')
        {
            current = FlxG.state;
        }
        else
        {
            // Try PlayState static references first
            var playState:Dynamic = Type.resolveClass('states.PlayState');
            if (playState != null) {
                var staticField:Dynamic = Reflect.field(playState, firstPart);
                if (staticField != null) {
                    current = staticField;
                }
            }
            
            // Fallback to instance properties
            if (current == null && playState != null) {
                var instance:Dynamic = Reflect.field(playState, 'instance');
                if (instance != null) {
                    current = Reflect.field(instance, firstPart);
                }
            }
            
            // Try global lookup
            if (current == null) {
                current = resolveGlobalVar(firstPart);
            }
        }
        
        // Navigate through remaining parts
        for (i in 1...parts.length)
        {
            if (current == null) break;
            var part:String = parts[i];
            
            if (Std.is(current, Array)) {
                var index:Int = Std.parseInt(part);
                if (!Math.isNaN(index) && index < cast(current, Array<Dynamic>).length) {
                    current = cast(current, Array<Dynamic>)[index];
                }
            }
            else if (Std.is(current, Map)) {
                current = cast(current, Map<String, Dynamic>).get(part);
            }
            else {
                current = Reflect.field(current, part);
            }
        }
        
        return current;
    }
    
    /**
     * Set a property using dot notation path
     */
    public function setPropertyFromPath(path:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
    {
        var parts:Array<String> = path.split('.');
        if (parts.length == 0) return value;
        
        var target:Dynamic = null;
        var lastPart:String = '';
        
        // Resolve to parent object
        if (parts.length > 1)
        {
            var parentPath:String = parts.slice(0, -1).join('.');
            target = getPropertyFromPath(parentPath, allowMaps);
            lastPart = parts[parts.length - 1];
        }
        else
        {
            // Direct property on PlayState
            var playState:Dynamic = Type.resolveClass('states.PlayState');
            if (playState != null) {
                var instance:Dynamic = Reflect.field(playState, 'instance');
                target = instance;
            }
            lastPart = parts[0];
        }
        
        if (target != null)
        {
            Reflect.setField(target, lastPart, value);
        }
        
        return value;
    }
    
    /**
     * Call a method on an object
     */
    public function callMethodOnObject(objPath:String, methodName:String, ?args:Array<Dynamic>):Dynamic
    {
        var obj:Dynamic = getPropertyFromPath(objPath);
        if (obj == null) {
            FunkinLua.luaTrace('ScriptBridge: Object not found: $objPath', true, false, FlxColor.RED);
            return null;
        }
        
        var method = Reflect.field(obj, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            FunkinLua.luaTrace('ScriptBridge: Method not found: $methodName on $objPath', true, false, FlxColor.RED);
            return null;
        }
        
        if (args == null) args = [];
        return Reflect.callMethod(obj, method, args);
    }
    
    /**
     * Create an instance of a class using dot notation path
     */
    public function createInstanceFromPath(classPath:String, ?args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('ScriptBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        if (args == null) args = [];
        
        try {
            // Try creating with arguments
            switch (args.length) {
                case 0: return Type.createInstance(cls, []);
                case 1: return Type.createInstance(cls, [args[0]]);
                case 2: return Type.createInstance(cls, [args[0], args[1]]);
                case 3: return Type.createInstance(cls, [args[0], args[1], args[2]]);
                case 4: return Type.createInstance(cls, [args[0], args[1], args[2], args[3]]);
                default:
                    // For more args, use a different approach
                    return createInstanceWithArgs(cls, args);
            }
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('ScriptBridge: Failed to create instance: $e', true, false, FlxColor.RED);
            return null;
        }
    }
    
    /**
     * Call a static method on a class
     */
    public function callStaticMethod(classPath:String, methodName:String, ?args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('ScriptBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        var method:Dynamic = Reflect.field(cls, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            FunkinLua.luaTrace('ScriptBridge: Static method not found: $classPath.$methodName', true, false, FlxColor.RED);
            return null;
        }
        
        if (args == null) args = [];
        return Reflect.callMethod(cls, method, args);
    }
    
    /**
     * Get a Haxe class by path
     */
    public function getHaxeClass(classPath:String):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('ScriptBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        return cls;
    }
    
    /**
     * Register a hook callback
     */
    public function registerHook(path:String, callback:Dynamic):Void
    {
        if (!hooks.exists(path)) {
            hooks.set(path, []);
        }
        
        var hookList = hooks.get(path);
        if (!Lambda.has(hookList, callback)) {
            hookList.push(callback);
        }
        
        FunkinLua.luaTrace('ScriptBridge: Hook registered for $path', false, false, FlxColor.GREEN);
    }
    
    /**
     * Call registered hooks for a path
     */
    public function callHooks(path:String, ?args:Array<Dynamic>):Void
    {
        if (!hooks.exists(path)) return;
        
        for (callback in hooks.get(path)) {
            try {
                if (Reflect.isFunction(callback)) {
                    if (args != null) {
                        Reflect.callMethod(callback, callback, args);
                    } else {
                        Reflect.callMethod(callback, callback, []);
                    }
                }
            } catch (e:Dynamic) {
                FunkinLua.luaTrace('ScriptBridge: Hook error on $path: $e', true, false, FlxColor.RED);
            }
        }
    }
    
    /**
     * Register an override callback
     */
    public function registerOverride(path:String, callback:Dynamic):Void
    {
        overriddenFunctions.set(path, {
            original: null,
            override: callback,
            active: true
        });
        
        FunkinLua.luaTrace('ScriptBridge: Override registered for $path', false, false, FlxColor.GREEN);
    }
    
    /**
     * Get override for a path
     */
    public function getOverride(path:String):OverrideInfo
    {
        return overriddenFunctions.get(path);
    }
    
    /**
     * Get list of available classes
     */
    public function getAvailableClasses(?filter:String = null):Array<String>
    {
        var classes:Array<String> = [
            // Core
            'states.PlayState',
            'states.MainMenuState',
            'states.FreeplayState',
            'states.StoryMenuState',
            'objects.Character',
            'objects.Note',
            'objects.StrumNote',
            'objects.UIState',
            'objects.HealthIcon',
            'objects.Alphabet',
            'objects.NoteSplash',
            
            // Backend
            'backend.Paths',
            'backend.Controls',
            'backend.Mods',
            'backend.Highscore',
            'backend.MusicBeatState',
            'backend.CoolUtil',
            
            // Flixel
            'flixel.FlxG',
            'flixel.FlxSprite',
            'flixel.FlxObject',
            'flixel.FlxText',
            'flixel.FlxCamera',
            'flixel.FlxGroup',
            'flixel.FlxBasic',
            
            // Utilities
            'FlxTween',
            'FlxEase',
            'FlxColor'
        ];
        
        if (filter != null && filter.length > 0) {
            classes = classes.filter(function(c:String):Bool {
                return c.toLowerCase().indexOf(filter.toLowerCase()) != -1;
            });
        }
        
        return classes;
    }
    
    /**
     * Get methods of a class
     */
    public function getClassMethods(classPath:String):Array<String>
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
        var methods:Array<String> = [];
        
        for (field in Type.getClassFields(cls)) {
            if (Reflect.isFunction(Reflect.field(cls, field))) {
                methods.push(field);
            }
        }
        
        // Also check instance fields
        try {
            var instance = Type.createEmptyInstance(cls);
            for (field in Reflect.fields(instance)) {
                var value = Reflect.field(instance, field);
                if (Reflect.isFunction(value) && !Lambda.has(methods, field)) {
                    methods.push(field);
                }
            }
        } catch (e:Dynamic) { }
        
        methods.sort(function(a:String, b:String):Int {
            return Reflect.compare(a, b);
        });
        
        return methods;
    }
    
    /**
     * Get properties of a class
     */
    public function getClassProperties(classPath:String):Array<String>
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
        var props:Array<String> = [];
        
        // Static properties
        for (field in Type.getClassFields(cls)) {
            var value = Reflect.field(cls, field);
            if (!Reflect.isFunction(value)) {
                props.push(field);
            }
        }
        
        // Instance properties
        try {
            var instance = Type.createEmptyInstance(cls);
            for (field in Reflect.fields(instance)) {
                var value = Reflect.field(instance, field);
                if (!Reflect.isFunction(value) && !Lambda.has(props, field)) {
                    props.push(field);
                }
            }
        } catch (e:Dynamic) { }
        
        props.sort(function(a:String, b:String):Int {
            return Reflect.compare(a, b);
        });
        
        return props;
    }
    
    /**
     * Get help information
     */
    public function getHelp(?item:String = null):Dynamic
    {
        if (item == null || item.length == 0) {
            return {
                version: '1.0',
                engine: 'WashosEngine',
                functions: [
                    'getProperty(path) - Get a property using dot notation',
                    'setProperty(path, value) - Set a property',
                    'callMethod(objPath, method, args) - Call a method',
                    'callStatic(classPath, method, args) - Call static method',
                    'createInstance(classPath, args) - Create an instance',
                    'getClass(classPath) - Get a Haxe class reference',
                    'hook(path, callback) - Register a hook',
                    'override(path, callback) - Override a function',
                    'listClasses(filter) - List available classes',
                    'listMethods(classPath) - List class methods',
                    'listProperties(classPath) - List class properties',
                    'help(item) - Get help for an item'
                ],
                examples: [
                    "engine.get('PlayState.SONG')",
                    "engine.set('PlayState.storyWeek', 2)",
                    "local note = engine.new('objects.Note', 100, 200)",
                    "engine.hook('PlayState.onBeatHit', function() print('beat') end)"
                ]
            };
        }
        
        // Help for specific item
        if (getHaxeClass(item) != null) {
            return {
                class: item,
                methods: getClassMethods(item),
                properties: getClassProperties(item)
            };
        }
        
        // Help for function
        return {error: 'Not found: $item'};
    }
    
    /**
     * Evaluate a Haxe expression (advanced)
     */
    public function evaluateExpression(code:String):Dynamic
    {
        try {
            // Simple expression evaluation
            // For more complex needs, would need hscript or similar
            return null;
        } catch (e:Dynamic) {
            return {error: Std.string(e)};
        }
    }
    
    /**
     * Get Lua type of a value
     */
    public function getLuaType(value:Dynamic):String
    {
        if (value == null) return 'nil';
        if (Std.is(value, Bool)) return 'boolean';
        if (Std.is(value, Int) || Std.is(value, Float)) return 'number';
        if (Std.is(value, String)) return 'string';
        if (Std.is(value, Array)) return 'table';
        if (Std.is(value, haxe.ds.StringMap)) return 'table';
        if (Reflect.isFunction(value)) return 'function';
        if (Std.is(value, Class)) return 'class';
        return 'userdata';
    }
    
    /**
     * Import a class
     */
    public function importClass(classPath:String):Void
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls != null) {
            // Store in cache for later use
            classCache.set(classPath, cls);
        }
    }
    
    /**
     * Resolve a global variable
     */
    function resolveGlobalVar(name:String):Dynamic
    {
        // Try PlayState instance first
        var playState:Dynamic = Type.resolveClass('states.PlayState');
        if (playState != null) {
            var instance:Dynamic = Reflect.field(playState, 'instance');
            if (instance != null) {
                var value:Dynamic = Reflect.field(instance, name);
                if (value != null) return value;
            }
        }
        
        // Try FlxG
        var flxGValue = Reflect.field(FlxG, name);
        if (flxGValue != null) return flxGValue;
        
        // Try global classes
        var cls:Class<Dynamic> = Type.resolveClass(name);
        if (cls != null) return cls;
        
        return null;
    }
    
    /**
     * Create instance with many args
     */
    function createInstanceWithArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
    {
        var argsObj:Dynamic = {};
        Reflect.setField(argsObj, 'args', args);
        
        // Use macro if available, otherwise fail
        FunkinLua.luaTrace('ScriptBridge: Too many arguments for createInstance', true, false, FlxColor.YELLOW);
        return null;
    }
    
    /**
     * Clear all hooks and overrides
     */
    public function reset():Void
    {
        hooks.clear();
        overriddenFunctions.clear();
        FunkinLua.luaTrace('ScriptBridge: Reset complete', false, false, FlxColor.GREEN);
    }
}

/**
 * Hook callback wrapper
 */
typedef HookCallback = {
    var callback:Dynamic;
    var enabled:Bool;
}

/**
 * Override info
 */
typedef OverrideInfo = {
    var original:Dynamic;
    var override:Dynamic;
    var active:Bool;
}
#end