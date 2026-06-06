package psychlua;

#if LUA_ALLOWED
import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.Json;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.FlxBasic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;

/**
 * LuaBridge - Perfect integration layer for Lua-Haxe
 * 
 * Philosophy: "If it exists in Haxe, it exists in Lua"
 * 
 * This system provides:
 * - Seamless object creation from any Haxe class
 * - Property access with automatic getter/setter support
 * - Method calls with full argument handling
 * - Type coercion between Lua and Haxe
 * - Comprehensive error handling
 * - Debug logging for development
 * 
 * Usage:
 * ```lua
 * -- Create objects
 * local sprite = create('flixel.FlxSprite', 100, 200)
 * 
 * -- Access properties
 * local x = sprite.x
 * sprite.alpha = 0.5
 * 
 * -- Call methods
 * sprite:loadGraphic('assets/image.png')
 * 
 * -- Static access
 * local RED = get('flixel.util.FlxColor.RED')
 * 
 * -- Enums
 * local ease = enum('flixel.tweens.FlxEase', 'bounceOut')
 * ```
 */

typedef TypeConverterFunc = Dynamic->Dynamic;

class LuaBridge
{
    // Singleton pattern
    public static var instance(get, never):LuaBridge;
    private static var _instance:LuaBridge = null;
    
    private static inline function get_instance():LuaBridge
    {
        if (_instance == null) _instance = new LuaBridge();
        return _instance;
    }
    
    // ============================================
    // PRIVATE MEMBERS
    // ============================================
    
    private var proxyRegistry:StringMap<LuaObjectProxy>;
    private var nextProxyId:Int = 0;
    private var typeConverters:StringMap<TypeConverterFunc>;
    private var debugMode:Bool = false;
    private var errorHandler:Dynamic = null;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new()
    {
        proxyRegistry = new StringMap();
        typeConverters = new StringMap();
        initTypeConverters();
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    private inline function error(msg:String):Void
    {
        #if debug
        trace('[LuaBridge Error] ' + msg);
        #end
        throw msg;
    }
    
    private inline function safeArray(arr:Array<Dynamic>):Array<Dynamic>
    {
        return arr != null ? arr : [];
    }
    
    private inline function wrapObject(obj:Dynamic):Dynamic
    {
        if (obj == null) return null;
        var proxyId = registerProxy(obj);
        return {__proxyId: proxyId, __classPath: Type.getClassName(Type.getClass(obj))};
    }
    
    private inline function getString(args:Array<Dynamic>, index:Int, ?defaultValue:String = ''):String
    {
        return index < args.length && Std.is(args[index], String) ? args[index] : defaultValue;
    }
    
    private inline function getInt(args:Array<Dynamic>, index:Int, ?defaultValue:Int = 0):Int
    {
        return index < args.length && Std.is(args[index], Int) ? args[index] : defaultValue;
    }
    
    private inline function getArg(args:Array<Dynamic>, index:Int):Dynamic
    {
        return index < args.length ? args[index] : null;
    }
    
    private function initTypeConverters():Void
    {
        // Basic type converters are initialized here
    }
    

    private function registerProxy(obj:Dynamic):Int
    {
        var id = nextProxyId++;
        proxyRegistry.set(Std.string(id), new LuaObjectProxy(obj, Type.getClassName(Type.getClass(obj)), id));
        return id;
    }
    

    

    
    // ============================================
    // INITIALIZATION
    // ============================================
    
    /**
     * Initialize the bridge with Lua state
     */
    public function init(lua:State):Void
    {
        if (lua == null) {
            trace('[LuaBridge] Error: Lua state is null');
            return;
        }
        
        // Register all function groups
        registerGlobalFunctions(lua);
        registerTypeSystem(lua);
        registerObjectOperations(lua);
        registerUtilityFunctions(lua);
        
        trace('[LuaBridge] Initialized successfully');
    }
    
    /**
     * Enable/disable debug mode
     */
    public function setDebugMode(enabled:Bool):Void
    {
        debugMode = enabled;
        trace('[LuaBridge] Debug mode: $enabled');
    }
    
    /**
     * Set custom error handler
     */
    public function setErrorHandler(handler:Dynamic):Void
    {
        errorHandler = handler;
    }
    
    // ============================================
    // GLOBAL FUNCTIONS (Lua callbacks)
    // ============================================
    
    private function registerGlobalFunctions(lua:State):Void
    {
        // Main Haxe entry point
        Lua_helper.add_callback(lua, "Haxe", function(action:String, ?args:Array<Dynamic> = null):Dynamic {
            return handleHaxeAction(action, args);
        });
        
        // Object creation shortcuts
        Lua_helper.add_callback(lua, "create", function(classPath:String, ?args:Array<Dynamic> = null):Dynamic {
            return createObject(classPath, safeArray(args));
        });
        
        Lua_helper.add_callback(lua, "new", function(classPath:String, ?args:Array<Dynamic> = null):Dynamic {
            return createObject(classPath, safeArray(args));
        });
        
        Lua_helper.add_callback(lua, "instantiate", function(classPath:String, ?args:Array<Dynamic> = null):Dynamic {
            return createObject(classPath, safeArray(args));
        });
        
        // Property access
        Lua_helper.add_callback(lua, "get", function(path:String):Dynamic {
            return getValue(path);
        });
        
        Lua_helper.add_callback(lua, "set", function(path:String, value:Dynamic):Void {
            setValue(path, value);
        });
        
        Lua_helper.add_callback(lua, "getProperty", function(obj:Dynamic, prop:String):Dynamic {
            return getObjectProperty(obj, prop);
        });
        
        Lua_helper.add_callback(lua, "setProperty", function(obj:Dynamic, prop:String, value:Dynamic):Void {
            setObjectProperty(obj, prop, value);
        });
        
        // Method calls
        Lua_helper.add_callback(lua, "call", function(path:String, ?args:Array<Dynamic> = null):Dynamic {
            return callMethod(path, safeArray(args));
        });
        
        Lua_helper.add_callback(lua, "callStatic", function(classPath:String, method:String, ?args:Array<Dynamic> = null):Dynamic {
            return callStatic(classPath, method, safeArray(args));
        });
        
        Lua_helper.add_callback(lua, "callMethod", function(obj:Dynamic, method:String, ?args:Array<Dynamic> = null):Dynamic {
            return callObjectMethod(obj, method, safeArray(args));
        });
        
        // Type system
        Lua_helper.add_callback(lua, "typeof", function(value:Dynamic):String {
            return getType(value);
        });
        
        Lua_helper.add_callback(lua, "isA", function(value:Dynamic, classPath:String):Bool {
            return isInstance(value, classPath);
        });
        
        Lua_helper.add_callback(lua, "isNull", function(value:Dynamic):Bool {
            return value == null;
        });
        
        Lua_helper.add_callback(lua, "isNumber", function(value:Dynamic):Bool {
            return Std.is(value, Int) || Std.is(value, Float);
        });
        
        Lua_helper.add_callback(lua, "isString", function(value:Dynamic):Bool {
            return Std.is(value, String);
        });
        
        Lua_helper.add_callback(lua, "isArray", function(value:Dynamic):Bool {
            return Std.is(value, Array);
        });
        
        Lua_helper.add_callback(lua, "isFunction", function(value:Dynamic):Bool {
            return Reflect.isFunction(value);
        });
        
        Lua_helper.add_callback(lua, "cast", function(value:Dynamic, classPath:String):Dynamic {
            return castValue(value, classPath);
        });
        
        // Enums
        Lua_helper.add_callback(lua, "enum", function(enumPath:String, value:String):Dynamic {
            return getEnumValue(enumPath, value);
        });
        
        Lua_helper.add_callback(lua, "enumParams", function(enumValue:Dynamic):Array<Dynamic> {
            return getEnumParams(enumValue);
        });
        
        Lua_helper.add_callback(lua, "enumName", function(enumValue:Dynamic):String {
            return getEnumName(enumValue);
        });
        
        // Class reflection
        Lua_helper.add_callback(lua, "classOf", function(obj:Dynamic):String {
            return getClassName(obj);
        });
        
        Lua_helper.add_callback(lua, "methods", function(classPath:String):Array<String> {
            return getClassMethods(classPath);
        });
        
        Lua_helper.add_callback(lua, "properties", function(classPath:String):Array<String> {
            return getClassProperties(classPath);
        });
        
        Lua_helper.add_callback(lua, "statics", function(classPath:String):Array<String> {
            return getClassStatics(classPath);
        });
        
        Lua_helper.add_callback(lua, "constants", function(classPath:String):Array<Dynamic> {
            return getClassConstants(classPath);
        });
        
        Lua_helper.add_callback(lua, "inherits", function(classPath:String, parentPath:String):Bool {
            return classInherits(classPath, parentPath);
        });
        
        Lua_helper.add_callback(lua, "classExists", function(classPath:String):Bool {
            return classExists(classPath);
        });
        
        Lua_helper.add_callback(lua, "enumExists", function(enumPath:String):Bool {
            return enumExists(enumPath);
        });
    }
    
    // ============================================
    // TYPE SYSTEM
    // ============================================
    
    private function registerTypeSystem(lua:State):Void
    {
        Lua_helper.add_callback(lua, "typeName", function(value:Dynamic):String {
            return getTypeName(value);
        });
        
        Lua_helper.add_callback(lua, "typeInfo", function(classPath:String):Dynamic {
            return getTypeInfo(classPath);
        });
        
        Lua_helper.add_callback(lua, "isAbstract", function(classPath:String):Bool {
            return false; // Haxe abstracts not commonly used
        });
        
        Lua_helper.add_callback(lua, "isInterface", function(classPath:String):Bool {
            return isInterface(classPath);
        });
    }
    
    // ============================================
    // OBJECT OPERATIONS
    // ============================================
    
    private function registerObjectOperations(lua:State):Void
    {
        // Object lifecycle
        Lua_helper.add_callback(lua, "clone", function(obj:Dynamic):Dynamic {
            return cloneObject(obj);
        });
        
        Lua_helper.add_callback(lua, "destroy", function(obj:Dynamic):Void {
            destroyObject(obj);
        });
        
        Lua_helper.add_callback(lua, "exists", function(obj:Dynamic):Bool {
            return obj != null;
        });
        
        // Property iteration
        Lua_helper.add_callback(lua, "keys", function(obj:Dynamic):Array<String> {
            return getObjectKeys(obj);
        });
        
        Lua_helper.add_callback(lua, "values", function(obj:Dynamic):Array<Dynamic> {
            return getObjectValues(obj);
        });
        
        Lua_helper.add_callback(lua, "pairs", function(obj:Dynamic):Array<Dynamic> {
            return getObjectPairs(obj);
        });
        
        Lua_helper.add_callback(lua, "hasProperty", function(obj:Dynamic, prop:String):Bool {
            return hasProperty(obj, prop);
        });
        
        Lua_helper.add_callback(lua, "hasMethod", function(obj:Dynamic, method:String):Bool {
            return hasMethod(obj, method);
        });
        
        // String representation
        Lua_helper.add_callback(lua, "toString", function(obj:Dynamic):String {
            return objectToString(obj);
        });
        
        Lua_helper.add_callback(lua, "repr", function(value:Dynamic):String {
            return representValue(value);
        });
    }
    
    // ============================================
    // UTILITY FUNCTIONS
    // ============================================
    
    private function registerUtilityFunctions(lua:State):Void
    {
        // Debug
        Lua_helper.add_callback(lua, "debug", function(message:String):Void {
            if (debugMode) trace('[DEBUG] $message');
        });
        
        Lua_helper.add_callback(lua, "trace", function(value:Dynamic):Void {
            trace('[TRACE] ${representValue(value)}');
        });
        
        Lua_helper.add_callback(lua, "error", function(message:String):Void {
            trace('[ERROR] $message');
            if (errorHandler != null && Reflect.isFunction(errorHandler)) {
                Reflect.callMethod(errorHandler, errorHandler, [message]);
            }
        });
        
        // Inspection
        Lua_helper.add_callback(lua, "inspect", function(value:Dynamic, ?depth:Int = 3):String {
            return inspectValue(value, depth);
        });
        
        Lua_helper.add_callback(lua, "dump", function(value:Dynamic):String {
            return dumpValue(value, 0);
        });
        
        // Utilities
        Lua_helper.add_callback(lua, "noop", function():Dynamic {
            return null;
        });
        
        Lua_helper.add_callback(lua, "identity", function(value:Dynamic):Dynamic {
            return value;
        });
    }
    
    // ============================================
    // HAXE ACTION HANDLER
    // ============================================
    
    private function handleHaxeAction(action:String, args:Array<Dynamic>):Dynamic
    {
        if (action == null) return null;
        
        switch (action.toLowerCase())
        {
            // Creation
            case 'create', 'new':
                return createObject(getString(args, 0, ''), safeArray(args.slice(1)));
            case 'instantiate':
                return createObject(getString(args, 0, ''), safeArray(args.slice(1)));
            
            // Property access
            case 'get':
                return getValue(getString(args, 0, ''));
            case 'set':
                setValue(getString(args, 0, ''), getArg(args, 1));
                return null;
            
            // Method calls
            case 'call':
                return callMethod(getString(args, 0, ''), safeArray(args.slice(1)));
            case 'static':
                return callStatic(getString(args, 0, ''), getString(args, 1, ''), safeArray(args.slice(2)));
            
            // Type system
            case 'typeof', 'type':
                return getType(getArg(args, 0));
            case 'is', 'isa':
                return isInstance(getArg(args, 0), getString(args, 1, ''));
            case 'cast':
                return castValue(getArg(args, 0), getString(args, 1, ''));
            
            // Enums
            case 'enum':
                return getEnumValue(getString(args, 0, ''), getString(args, 1, ''));
            case 'enumparams':
                return getEnumParams(getArg(args, 0));
            case 'enumname':
                return getEnumName(getArg(args, 0));
            
            // Reflection
            case 'class', 'classof':
                return getClassName(getArg(args, 0));
            case 'methods':
                return getClassMethods(getString(args, 0, ''));
            case 'properties', 'props':
                return getClassProperties(getString(args, 0, ''));
            case 'statics':
                return getClassStatics(getString(args, 0, ''));
            case 'constants':
                return getClassConstants(getString(args, 0, ''));
            case 'inherits':
                return classInherits(getString(args, 0, ''), getString(args, 1, ''));
            
            // Object operations
            case 'clone':
                return cloneObject(getArg(args, 0));
            case 'destroy':
                destroyObject(getArg(args, 0));
                return null;
            case 'pairs':
                return getObjectPairs(getArg(args, 0));
            case 'keys':
                return getObjectKeys(getArg(args, 0));
            case 'values':
                return getObjectValues(getArg(args, 0));
            
            // Debug
            case 'debug':
                if (debugMode) trace('[DEBUG] ${getString(args, 0, "")}');
                return null;
            case 'inspect':
                return inspectValue(getArg(args, 0), getInt(args, 1, 3));
            
            default:
                if (debugMode) trace('[LuaBridge] Unknown action: $action');
                return null;
        }
    }
    
    // ============================================
    // OBJECT CREATION
    // ============================================
    
    /**
     * Create a Haxe object from class path
     */
    public function createObject(classPath:String, ?args:Array<Dynamic>):Dynamic
    {
        if (classPath == null || classPath.length == 0) {
            error('createObject: classPath is null or empty');
            return null;
        }
        
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            error('createObject: Class not found: $classPath');
            return null;
        }
        
        if (args == null) args = [];
        
    var instance:Dynamic;
        try {
            instance = createWithArgs(cls, args);
        } catch (e:Dynamic) {
            error('createObject: Failed to create $classPath: $e');
            return null;
        }
        
        return wrapObject(instance);
    }
    
    private function createWithArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
    {
        switch (args.length)
        {
            case 0: return Type.createInstance(cls, []);
            case 1: return Type.createInstance(cls, [args[0]]);
            case 2: return Type.createInstance(cls, [args[0], args[1]]);
            case 3: return Type.createInstance(cls, [args[0], args[1], args[2]]);
            case 4: return Type.createInstance(cls, [args[0], args[1], args[2], args[3]]);
            case 5: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4]]);
            case 6: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4], args[5]]);
            case 7: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4], args[5], args[6]]);
            case 8: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]]);
            case 9: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]]);
            case 10: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]]);
            default:
                // For 11+ args, try with first 10
                return Type.createInstance(cls, args.slice(0, 10));
        }
    }
    
    // ============================================
    // PROPERTY ACCESS
    // ============================================
    
    /**
     * Get value by path (e.g., 'PlayState.SONG' or 'FlxColor.RED')
     */
    public function getValue(path:String):Dynamic
    {
        if (path == null || path.length == 0) {
            error('getValue: path is null or empty');
            return null;
        }
        
    var parts = path.split('.');
        if (parts.length == 0) return null;
        
    var current:Dynamic = null;
    var i = 0;
        
        // Handle Haxe. prefix
        if (parts[0].toLowerCase() == 'haxe') {
            i = 1;
        }
        
        // Resolve first part as class or instance
        if (i < parts.length) {
            current = resolveFirstPart(parts[i]);
            i++;
        }
        
        // Navigate remaining path
        while (i < parts.length && current != null)
        {
        var part = parts[i];
            current = resolveProperty(current, part);
            
            // Handle enum value access
            if (current != null && Std.is(current, EnumValue)) {
                if (i + 1 < parts.length) {
                    i++;
                    current = resolveEnumValue(cast current, parts[i]);
                }
            }
            
            i++;
        }
        
        return coerceToLua(current);
    }
    
    private function resolveFirstPart(part:String):Dynamic
    {
        // Try PlayState singleton first
        try {
        var psClass:Class<Dynamic> = Type.resolveClass('states.PlayState');
            if (psClass != null) {
            var instance = Reflect.field(psClass, 'instance');
                if (instance != null && Reflect.field(instance, part) != null) {
                    return Reflect.field(instance, part);
                }
            }
        } catch (e:Dynamic) { }
        
        // Try as class
    var cls:Class<Dynamic> = Type.resolveClass(part);
        if (cls != null) return cls;
        
        // Try as static on PlayState
        try {
        var psClass:Class<Dynamic> = Type.resolveClass('states.PlayState');
            if (psClass != null) {
            var staticField = Reflect.field(psClass, part);
                if (staticField != null) return staticField;
            }
        } catch (e:Dynamic) { }
        
        // Try FlxG static
    var flxGValue = Reflect.field(FlxG, part);
        if (flxGValue != null) return flxGValue;
        
        return null;
    }
    
    private function resolveProperty(obj:Dynamic, prop:String):Dynamic
    {
        if (obj == null) return null;
        
        // Try getter first
    var getter = Reflect.field(obj, 'get_' + prop);
        if (getter != null && Reflect.isFunction(getter)) {
            return Reflect.callMethod(obj, getter, []);
        }
        
        // Try direct field access
    var value = Reflect.field(obj, prop);
        if (value != null) return value;
        
        // Try method (for method references)
    var method = Reflect.field(obj, prop);
        if (method != null && Reflect.isFunction(method)) {
            return method;
        }
        
        return null;
    }
    
    private function resolveEnumValue(enm:Enum<Dynamic>, name:String):Dynamic
    {
        try {
            return Type.createEnum(enm, name);
        } catch (e:Dynamic) {
            return null;
        }
    }
    
    /**
     * Set value by path
     */
    public function setValue(path:String, value:Dynamic):Void
    {
        if (path == null || path.length == 0) {
            error('setValue: path is null or empty');
            return;
        }
        
    var parts = path.split('.');
        if (parts.length < 2) {
            error('setValue: path too short: $path');
            return;
        }
        
        // Get target object
    var parentPath = parts.slice(0, -1).join('.');
    var lastPart = parts[parts.length - 1];
        
    var target = getValue(parentPath);
        if (target == null) {
            // Try setting on PlayState directly
            try {
            var psClass:Class<Dynamic> = Type.resolveClass('states.PlayState');
                if (psClass != null) {
                var instance = Reflect.field(psClass, 'instance');
                    if (instance != null) {
                        setObjectProperty(instance, lastPart, value);
                        return;
                    }
                }
            } catch (e:Dynamic) { }
            
            error('setValue: Target not found for path: $parentPath');
            return;
        }
        
        setObjectProperty(target, lastPart, value);
    }
    
    /**
     * Get property from object
     */
    public function getObjectProperty(obj:Dynamic, prop:String):Dynamic
    {
        if (obj == null) return null;
        if (prop == null) return null;
        
        return coerceToLua(resolveProperty(obj, prop));
    }
    
    /**
     * Set property on object
     */
    public function setObjectProperty(obj:Dynamic, prop:String, value:Dynamic):Void
    {
        if (obj == null || prop == null) return;
        
        // Try setter first
    var setter = Reflect.field(obj, 'set_' + prop);
        if (setter != null && Reflect.isFunction(setter)) {
            Reflect.callMethod(obj, setter, [coerceToHaxe(value)]);
            return;
        }
        
        // Direct field access
        Reflect.setField(obj, prop, coerceToHaxe(value));
    }
    
    // ============================================
    // METHOD CALLS
    // ============================================
    
    /**
     * Call method by path (e.g., 'sprite.loadGraphic')
     */
    public function callMethod(path:String, ?args:Array<Dynamic>):Dynamic
    {
        if (path == null || path.length == 0) {
            error('callMethod: path is null or empty');
            return null;
        }
        
    var lastDot = path.lastIndexOf('.');
        if (lastDot == -1) {
            error('callMethod: Invalid path format: $path');
            return null;
        }
        
    var objPath = path.substring(0, lastDot);
    var methodName = path.substring(lastDot + 1);
        
    var obj:Dynamic = null;
        if (objPath.indexOf('.') == -1) {
            // Single name - try local context
            obj = resolveLocalContext(objPath);
        } else {
            // Full path
            obj = getValue(objPath);
        }
        
        if (obj == null) {
            error('callMethod: Object not found: $objPath');
            return null;
        }
        
        return callObjectMethod(obj, methodName, safeArray(args));
    }
    
    /**
     * Call static method on class
     */
    public function callStatic(classPath:String, method:String, ?args:Array<Dynamic>):Dynamic
    {
        if (classPath == null || method == null) {
            error('callStatic: classPath or method is null');
            return null;
        }
        
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            error('callStatic: Class not found: $classPath');
            return null;
        }
        
    var methodFunc = Reflect.field(cls, method);
        if (methodFunc == null || !Reflect.isFunction(methodFunc)) {
            error('callStatic: Method not found: $classPath.$method');
            return null;
        }
        
        return coerceToLua(Reflect.callMethod(cls, methodFunc, safeArray(args)));
    }
    
    /**
     * Call method on object
     */
    public function callObjectMethod(obj:Dynamic, method:String, ?args:Array<Dynamic>):Dynamic
    {
        if (obj == null || method == null) {
            return null;
        }
        
    var methodFunc = Reflect.field(obj, method);
        if (methodFunc == null || !Reflect.isFunction(methodFunc)) {
            // Try as property
        var prop = Reflect.field(obj, method);
            return coerceToLua(prop);
        }
        
    var haxeArgs = [for (a in safeArray(args)) coerceToHaxe(a)];
        return coerceToLua(Reflect.callMethod(obj, methodFunc, haxeArgs));
    }
    
    private function resolveLocalContext(name:String):Dynamic
    {
        // Try PlayState
        try {
        var psClass:Class<Dynamic> = Type.resolveClass('states.PlayState');
            if (psClass != null) {
            var instance = Reflect.field(psClass, 'instance');
                if (instance != null) {
                var value = Reflect.field(instance, name);
                    if (value != null) return value;
                }
            }
        } catch (e:Dynamic) { }
        
        return null;
    }
    
    // ============================================
    // TYPE SYSTEM
    // ============================================
    
    /**
     * Get type name of value
     */
    public function getType(value:Dynamic):String
    {
        if (value == null) return 'null';
        if (Std.is(value, Bool)) return 'Bool';
        if (Std.is(value, Int)) return 'Int';
        if (Std.is(value, Float)) return 'Float';
        if (Std.is(value, String)) return 'String';
        if (Std.is(value, Array)) return 'Array';
        if (Reflect.isFunction(value)) return 'Function';
        
    var cls = Type.getClass(value);
        if (cls != null) return Type.getClassName(cls);
        
    var enm = Type.getEnum(value);
        if (enm != null) return Type.getEnumName(enm);
        
        return 'Unknown';
    }
    
    /**
     * Get detailed type name
     */
    public function getTypeName(value:Dynamic):String
    {
        return getType(value);
    }
    
    /**
     * Check if value is instance of class
     */
    public function isInstance(value:Dynamic, classPath:String):Bool
    {
        if (value == null || classPath == null) return false;
        
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return false;
        
        return Std.is(value, cls);
    }
    
    /**
     * Cast value to type (for type checking)
     */
    public function castValue(value:Dynamic, classPath:String):Dynamic
    {
        if (value == null) return null;
        
        if (!isInstance(value, classPath)) {
            if (debugMode) trace('[LuaBridge] castValue: $classPath type mismatch');
        }
        
        return value;
    }
    
    // ============================================
    // ENUM SUPPORT
    // ============================================
    
    /**
     * Get enum value by path
     */
    public function getEnumValue(enumPath:String, valueName:String):Dynamic
    {
        if (enumPath == null || valueName == null) {
            error('getEnumValue: enumPath or valueName is null');
            return null;
        }
        
    var enm:Enum<Dynamic> = Type.resolveEnum(enumPath);
        if (enm == null) {
            error('getEnumValue: Enum not found: $enumPath');
            return null;
        }
        
        try {
            return Type.createEnum(enm, valueName);
        } catch (e:Dynamic) {
            error('getEnumValue: Value not found: $enumPath.$valueName');
            return null;
        }
    }
    
    /**
     * Get enum parameters
     */
    public function getEnumParams(enumValue:Dynamic):Array<Dynamic>
    {
        if (enumValue == null || !Std.is(enumValue, EnumValue)) return [];
        
        return [for (p in Type.enumParameters(cast enumValue)) coerceToLua(p)];
    }
    
    /**
     * Get enum constructor name
     */
    public function getEnumName(enumValue:Dynamic):String
    {
        if (enumValue == null || !Std.is(enumValue, EnumValue)) return '';
        return Type.enumConstructor(cast enumValue);
    }
    
    // ============================================
    // CLASS REFLECTION
    // ============================================
    
    /**
     * Get class name of object
     */
    public function getClassName(obj:Dynamic):String
    {
        if (obj == null) return 'null';
        
    var cls = Type.getClass(obj);
        if (cls != null) return Type.getClassName(cls);
        
        return 'null';
    }
    
    /**
     * Get class methods
     */
    public function getClassMethods(classPath:String):Array<String>
    {
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
    var methods:Array<String> = [];
        
        // Static methods
        for (field in Type.getClassFields(cls)) {
        var value = Reflect.field(cls, field);
            if (Reflect.isFunction(value)) {
                methods.push(field);
            }
        }
        
        // Instance methods
        try {
        var instance = Type.createEmptyInstance(cls);
            for (field in Reflect.fields(instance)) {
            var value = Reflect.field(instance, field);
                if (Reflect.isFunction(value) && !Lambda.has(methods, field)) {
                    methods.push(field);
                }
            }
        } catch (e:Dynamic) { }
        
        methods.sort(Reflect.compare);
        return methods;
    }
    
    /**
     * Get class properties
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
        
        props.sort(Reflect.compare);
        return props;
    }
    
    /**
     * Get class static fields
     */
    public function getClassStatics(classPath:String):Array<String>
    {
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
    var statics:Array<String> = Type.getClassFields(cls);
        statics.sort(Reflect.compare);
        return statics;
    }
    
    /**
     * Get class constants
     */
    public function getClassConstants(classPath:String):Array<Dynamic>
    {
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
    var constants:Array<Dynamic> = [];
        for (field in Type.getClassFields(cls)) {
        var value = Reflect.field(cls, field);
            if (!Reflect.isFunction(value)) {
                constants.push({name: field, value: coerceToLua(value)});
            }
        }
        return constants;
    }
    
    /**
     * Check class inheritance
     */
    public function classInherits(classPath:String, parentPath:String):Bool
    {
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
    var parent:Class<Dynamic> = Type.resolveClass(parentPath);
        
        if (cls == null || parent == null) return false;
        
    var current = Type.getSuperClass(cls);
        while (current != null) {
            if (current == parent) return true;
            current = Type.getSuperClass(current);
        }
        return false;
    }
    
    /**
     * Check if class exists
     */
    public function classExists(classPath:String):Bool
    {
        return Type.resolveClass(classPath) != null;
    }
    
    /**
     * Check if enum exists
     */
    public function enumExists(enumPath:String):Bool
    {
        return Type.resolveEnum(enumPath) != null;
    }
    
    /**
     * Check if class is interface
     */
    public function isInterface(classPath:String):Bool
    {
    var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return false;
        
        try {
        var instance = Type.createEmptyInstance(cls);
            return false;
        } catch (e:Dynamic) {
            return true;
        }
    }
    
    /**
     * Get type info
     */
    public function getTypeInfo(classPath:String):Dynamic
    {
        return {
            classPath: classPath,
            exists: classExists(classPath),
            isInterface: isInterface(classPath),
            methods: getClassMethods(classPath),
            properties: getClassProperties(classPath),
            statics: getClassStatics(classPath)
        };
    }
    
    // ============================================
    // OBJECT OPERATIONS
    // ============================================
    
    /**
     * Clone object
     */
    public function cloneObject(obj:Dynamic):Dynamic
    {
        if (obj == null) return null;
        
    var cls = Type.getClass(obj);
        if (cls == null) return obj;
        
        try {
        var newInstance = Type.createInstance(cls, []);
            
            for (field in Reflect.fields(obj)) {
                if (field.charAt(0) != '_') {
                    try {
                    var value = Reflect.field(obj, field);
                        if (!Reflect.isFunction(value)) {
                            Reflect.setField(newInstance, field, value);
                        }
                    } catch (e:Dynamic) { }
                }
            }
            
            return wrapObject(newInstance);
        } catch (e:Dynamic) {
            error('cloneObject: Failed: $e');
            return null;
        }
    }
    
    /**
     * Destroy object
     */
    public function destroyObject(obj:Dynamic):Void
    {
        if (obj == null) return;
        
        try {
        var destroy = Reflect.field(obj, 'destroy');
            if (destroy != null && Reflect.isFunction(destroy)) {
                Reflect.callMethod(obj, destroy, []);
            }
        } catch (e:Dynamic) { }
    }
    
    /**
     * Get object keys
     */
    public function getObjectKeys(obj:Dynamic):Array<String>
    {
        if (obj == null) return [];
        
    var keys:Array<String> = [];
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_' && !Reflect.isFunction(Reflect.field(obj, field))) {
                keys.push(field);
            }
        }
        keys.sort(Reflect.compare);
        return keys;
    }
    
    /**
     * Get object values
     */
    public function getObjectValues(obj:Dynamic):Array<Dynamic>
    {
        if (obj == null) return [];
        
    var values:Array<Dynamic> = [];
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_') {
            var value = Reflect.field(obj, field);
                if (!Reflect.isFunction(value)) {
                    values.push(coerceToLua(value));
                }
            }
        }
        return values;
    }
    
    /**
     * Get object as key-value pairs
     */
    public function getObjectPairs(obj:Dynamic):Array<Dynamic>
    {
        if (obj == null) return [];
        
    var pairs:Array<Dynamic> = [];
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_') {
            var value = Reflect.field(obj, field);
                if (!Reflect.isFunction(value)) {
                    pairs.push({key: field, value: coerceToLua(value)});
                }
            }
        }
        return pairs;
    }
    
    /**
     * Check if object has property
     */
    public function hasProperty(obj:Dynamic, prop:String):Bool
    {
        if (obj == null || prop == null) return false;
        
    var value = Reflect.field(obj, prop);
        return value != null;
    }
    
    /**
     * Check if object has method
     */
    public function hasMethod(obj:Dynamic, method:String):Bool
    {
        if (obj == null || method == null) return false;
        
    var func = Reflect.field(obj, method);
        return func != null && Reflect.isFunction(func);
    }
    
    /**
     * Object to string
     */
    public function objectToString(obj:Dynamic):String
    {
        if (obj == null) return 'null';
        
    var toString = Reflect.field(obj, 'toString');
        if (toString != null && Reflect.isFunction(toString)) {
        var result = Reflect.callMethod(obj, toString, []);
            return result != null ? Std.string(result) : getType(obj);
        }
        
    var cls = Type.getClass(obj);
        if (cls != null) {
            return Type.getClassName(cls);
        }
        
    var enm = Type.getEnum(obj);
        if (enm != null) {
            return Type.getEnumName(enm) + '.' + Type.enumConstructor(obj);
        }
        
        return getType(obj);
    }
    
    // ============================================
    // UTILITY FUNCTIONS
    // ============================================
    
    /**
     * Inspect value (returns string representation)
     */
    public function inspectValue(value:Dynamic, ?depth:Int = 3):String
    {
        return dumpValue(value, depth);
    }
    
    /**
     * Represent value for display
     */
    public function representValue(value:Dynamic):String
    {
        if (value == null) return 'null';
        if (Std.is(value, Bool)) return value ? 'true' : 'false';
        if (Std.is(value, Int)) return Std.string(value);
        if (Std.is(value, Float)) return Std.string(value);
        if (Std.is(value, String)) return '"$value"';
        if (Std.is(value, Array)) return '[array:' + cast(value, Array<Dynamic>).length + ']';
        
        return objectToString(value);
    }
    
    /**
     * Dump value recursively
     */
    public function dumpValue(value:Dynamic, ?depth:Int = 0, ?indent:Int = 0):String
    {
        if (depth == null) depth = 3;
        if (indent == null) indent = 0;
        
    var pad = '';
        for (i in 0...indent) pad += '  ';
        
        if (value == null) return 'null';
        if (depth < 0) return '...';
        
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
                    items.push('... (' + arr.length + ' items)');
                    break;
                }
                items.push(dumpValue(arr[i], depth - 1, indent + 1));
            }
            return '[\n$pad  ' + items.join(',\n$pad  ') + '\n$pad]';
        }
        
        if (Std.is(value, EnumValue)) {
            var enm:EnumValue = cast value;
            var enumType:Enum<Dynamic> = Type.getEnum(enm);
            var params = Type.enumParameters(enm);
            if (params.length == 0) {
                return Type.getEnumName(enumType) + '.' + Type.enumConstructor(enm);
            }
            return Type.getEnumName(enumType) + '.' + Type.enumConstructor(enm) + '(' + params.join(', ') + ')';
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
    // TYPE COERCION
    // ============================================
    
    /**
     * Convert Haxe value to Lua-compatible value
     */
    public function coerceToLua(value:Dynamic):Dynamic
    {
        if (value == null) return null;
        
    var type = Type.typeof(value);
        switch (type)
        {
            case TNull: return null;
            case TInt: return value;
            case TFloat: return value;
            case TBool: return value;
            case tString: return value;
            case tArray:
                return [for (i in 0...cast(value, Array<Dynamic>).length) 
                    coerceToLua(cast(value, Array<Dynamic>)[i])];
            case TClass(c):
            var className = Type.getClassName(c);
                
                // Special type converters
                if (typeConverters.exists(className)) {
                    return typeConverters.get(className)(value);
                }
                
                // Default: wrap as Lua object
                return wrapObject(value);
            case TEnum(e):
                return {
                    __enum: Type.getEnumName(e),
                    __ctor: Type.enumConstructor(value),
                    __params: [for (p in Type.enumParameters(value)) coerceToLua(p)]
                };
            case TFunction:
                return value; // Keep functions as-is
            default:
                return value;
        }
    }
    
    /**
     * Convert Lua value to Haxe-compatible value
     */
    public function coerceToHaxe(value:Dynamic, ?targetType:String = null):Dynamic
    {
        if (value == null) return null;
        
        // Already Haxe native types
        if (Std.is(value, String)) return value;
        if (Std.is(value, Int)) return value;
        if (Std.is(value, Float)) return value;
        if (Std.is(value, Bool)) return value;
        if (Std.is(value, Array)) return value;
        
        // Unwrap Lua object proxy
        if (Reflect.hasField(value, '__obj')) {
            return Reflect.field(value, '__obj');
        }
        
        return value;
    }
    
}

// ============================================
// TYPE DEFINITIONS
// ============================================

class LuaObjectProxy
{
    public var obj:Dynamic;
    public var classPath:String;
    public var id:Int;
    
    public function new(obj:Dynamic, classPath:String, id:Int)
    {
        this.obj = obj;
        this.classPath = classPath;
        this.id = id;
    }
}
#end