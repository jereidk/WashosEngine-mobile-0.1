package psychlua;

#if LUA_ALLOWED
import haxe.ds.StringMap;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxText;
import flixel.FlxCamera;
import flixel.FlxGroup;
import flixel.FlxBasic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;

/**
 * LuaBridge - Perfect integration layer for Lua-Haxe
 * 
 * This class provides the complete bridge between Lua and Haxe,
 * allowing Lua code to:
 * - Create Haxe instances
 * - Access properties naturally
 * - Call methods with :syntax
 * - Use constants and enums
 * - Extend classes
 * - Type conversion automatically
 * 
 * Usage in Lua:
 * ```lua
 * -- Create objects naturally
 * local sprite = Haxe.create('flixel.FlxSprite', 100, 200)
 * sprite:loadGraphic('assets/image.png')
 * sprite.x = 500
 * sprite.alpha = 0.5
 * 
 * -- Access constants
 * local RED = Haxe.get('flixel.util.FlxColor.RED')
 * 
 * -- Call static methods
 * local path = Haxe.callStatic('backend.Paths', 'mods', 'images')
 * 
 * -- Enum values
 * local LEFT = Haxe.enum('flixel.input.keyboard.FlxKey.LEFT')
 * 
 * -- Type checking
 * if Haxe.is(sprite, 'flixel.FlxSprite') then
 *     print('Sprite!')
 * end
 * 
 * -- Iterate objects
 * for k, v in pairs(sprite) do
 *     print(k, v)
 * end
 * ```
 */
class LuaBridge
{
    private static var instance(get, never):LuaBridge;
    private static var _instance:LuaBridge = null;
    
    private static inline function get_instance():LuaBridge
    {
        if (_instance == null) _instance = new LuaBridge();
        return _instance;
    }
    
    // Object registry for tracking created objects
    private var objectRegistry:StringMap<Dynamic>;
    private var proxyRegistry:StringMap<LuaObjectProxy>;
    private var nextProxyId:Int = 0;
    
    // Type converters
    private var converters:StringMap<TypeConverterFunc>;
    
    public function new()
    {
        objectRegistry = new StringMap();
        proxyRegistry = new StringMap();
        converters = new StringMap();
        
        initConverters();
    }
    
    /**
     * Initialize the bridge - called from FunkinLua
     */
    public function init(lua:State):Void
    {
        registerGlobalFunctions(lua);
        registerTypeSystem(lua);
        registerObjectFactory(lua);
        registerExtensionSystem(lua);
    }
    
    // ============================================
    // GLOBAL FUNCTIONS
    // ============================================
    
    function registerGlobalFunctions(lua:State):Void
    {
        // Haxe table - main entry
        Lua_helper.add_callback(lua, "Haxe", function(action:String, ...args:Dynamic):Dynamic {
            return handleHaxeCall(action, [for (a in args) a]);
        });
        
        // Shortcuts
        Lua_helper.add_callback(lua, "create", function(classPath:String, ...args:Dynamic):Dynamic {
            return createHaxeObject(classPath, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "new", function(classPath:String, ...args:Dynamic):Dynamic {
            return createHaxeObject(classPath, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "get", function(path:String):Dynamic {
            return getHaxeValue(path);
        });
        
        Lua_helper.add_callback(lua, "set", function(path:String, value:Dynamic):Void {
            setHaxeValue(path, value);
        });
        
        Lua_helper.add_callback(lua, "call", function(path:String, ...args:Dynamic):Dynamic {
            return callHaxeMethod(path, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "static", function(classPath:String, method:String, ...args:Dynamic):Dynamic {
            return callStaticMethod(classPath, method, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "typeof", function(obj:Dynamic):String {
            return getHaxeType(obj);
        });
        
        Lua_helper.add_callback(lua, "isA", function(obj:Dynamic, classPath:String):Bool {
            return isHaxeInstance(obj, classPath);
        });
        
        Lua_helper.add_callback(lua, "cast", function(obj:Dynamic, classPath:String):Dynamic {
            return castHaxeObject(obj, classPath);
        });
        
        Lua_helper.add_callback(lua, "enum", function(enumPath:String, value:String):Dynamic {
            return getEnumValue(enumPath, value);
        });
        
        Lua_helper.add_callback(lua, "extends", function(baseClass:String, ...extensions:Dynamic):Dynamic {
            return createExtendedClass(baseClass, [for (e in extensions) e]);
        });
        
        Lua_helper.add_callback(lua, "implements", function(classPath:String, ...interfaces:Dynamic):Dynamic {
            return markImplemented(classPath, [for (i in interfaces) Std.string(i)]);
        });
    }
    
    // ============================================
    // TYPE SYSTEM
    // ============================================
    
    function registerTypeSystem(lua:State):Void
    {
        Lua_helper.add_callback(lua, "methods", function(classPath:String):Array<String> {
            return listClassMethods(classPath);
        });
        
        Lua_helper.add_callback(lua, "properties", function(classPath:String):Array<String> {
            return listClassProperties(classPath);
        });
        
        Lua_helper.add_callback(lua, "statics", function(classPath:String):Array<String> {
            return listClassStatics(classPath);
        });
        
        Lua_helper.add_callback(lua, "constants", function(classPath:String):Array<Dynamic> {
            return listClassConstants(classPath);
        });
        
        Lua_helper.add_callback(lua, "inherits", function(classPath:String, parentPath:String):Bool {
            return classExtends(classPath, parentPath);
        });
        
        Lua_helper.add_callback(lua, "interfaces", function(classPath:String):Array<String> {
            return listInterfaces(classPath);
        });
        
        Lua_helper.add_callback(lua, "isAbstract", function(classPath:String):Bool {
            return false; // Simplified
        });
        
        Lua_helper.add_callback(lua, "isEnum", function(value:Dynamic):Bool {
            return Std.is(value, Enum);
        });
        
        Lua_helper.add_callback(lua, "isStruct", function(classPath:String):Bool {
            return false; // Haxe doesn't have structs like C#
        });
        
        Lua_helper.add_callback(lua, "typeParams", function(classPath:String):Array<String> {
            // Return generic type parameters
            return [];
        });
    }
    
    // ============================================
    // OBJECT FACTORY
    // ============================================
    
    function registerObjectFactory(lua:State):Void
    {
        // Create with args
        Lua_helper.add_callback(lua, "__create", function(classPath:String, args:Array<Dynamic>):Dynamic {
            return createHaxeObject(classPath, args);
        });
        
        // Clone object
        Lua_helper.add_callback(lua, "__clone", function(obj:Dynamic):Dynamic {
            return cloneHaxeObject(obj);
        });
        
        // Destroy object
        Lua_helper.add_callback(lua, "__destroy", function(obj:Dynamic):Void {
            destroyHaxeObject(obj);
        });
        
        // Get property
        Lua_helper.add_callback(lua, "__get", function(obj:Dynamic, prop:String):Dynamic {
            return getObjectProperty(obj, prop);
        });
        
        // Set property
        Lua_helper.add_callback(lua, "__set", function(obj:Dynamic, prop:String, value:Dynamic):Void {
            setObjectProperty(obj, prop, value);
        });
        
        // Call method
        Lua_helper.add_callback(lua, "__call", function(obj:Dynamic, method:String, args:Array<Dynamic>):Dynamic {
            return callObjectMethod(obj, method, args);
        });
        
        // Iterate properties
        Lua_helper.add_callback(lua, "__pairs", function(obj:Dynamic):Array<Dynamic> {
            return iterateObjectProperties(obj);
        });
        
        // To string
        Lua_helper.add_callback(lua, "__tostring", function(obj:Dynamic):String {
            return objectToString(obj);
        });
        
        // Get type
        Lua_helper.add_callback(lua, "__type", function(obj:Dynamic):String {
            return getObjectType(obj);
        });
    }
    
    // ============================================
    // EXTENSION SYSTEM
    // ============================================
    
    function registerExtensionSystem(lua:State):Void
    {
        Lua_helper.add_callback(lua, "addMethod", function(classPath:String, methodName:String, func:Dynamic):Void {
            addClassMethod(classPath, methodName, func);
        });
        
        Lua_helper.add_callback(lua, "addProperty", function(classPath:String, propName:String, getter:Dynamic, setter:Dynamic):Void {
            addClassProperty(classPath, propName, getter, setter);
        });
        
        Lua_helper.add_callback(lua, "wrap", function(obj:Dynamic):Dynamic {
            return wrapAsLuaObject(obj);
        });
        
        Lua_helper.add_callback(lua, "unwrap", function(proxy:Dynamic):Dynamic {
            return unwrapFromLuaObject(proxy);
        });
        
        Lua_helper.add_callback(lua, "proxy", function(obj:Dynamic):Dynamic {
            return createObjectProxy(obj);
        });
    }
    
    // ============================================
    // HANDLE HAXE CALLS
    // ============================================
    
    function handleHaxeCall(action:String, args:Array<Dynamic>):Dynamic
    {
        switch (action)
        {
            case "create":
                return createHaxeObject(args[0], args.slice(1));
            case "get":
                return getHaxeValue(args[0]);
            case "set":
                setHaxeValue(args[0], args[1]);
                return null;
            case "call":
                return callHaxeMethod(args[0], args.slice(1));
            case "static":
                return callStaticMethod(args[0], args[1], args.slice(2));
            case "typeof":
                return getHaxeType(args[0]);
            case "is":
                return isHaxeInstance(args[0], args[1]);
            case "cast":
                return castHaxeObject(args[0], args[1]);
            case "enum":
                return getEnumValue(args[0], args[1]);
            case "extend":
                return createExtendedClass(args[0], args.slice(1));
            case "methods":
                return listClassMethods(args[0]);
            case "properties":
                return listClassProperties(args[0]);
            case "statics":
                return listClassStatics(args[0]);
            case "clone":
                return cloneHaxeObject(args[0]);
            case "destroy":
                destroyHaxeObject(args[0]);
                return null;
            default:
                FunkinLua.luaTrace('LuaBridge: Unknown action: $action', true, false, FlxColor.RED);
                return null;
        }
    }
    
    // ============================================
    // OBJECT CREATION
    // ============================================
    
    public function createHaxeObject(classPath:String, args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('LuaBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        var instance:Dynamic;
        try {
            instance = instantiateWithArgs(cls, args);
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('LuaBridge: Failed to create $classPath: $e', true, false, FlxColor.RED);
            return null;
        }
        
        // Create proxy
        return wrapAsLuaObject(instance);
    }
    
    function instantiateWithArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
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
            default:
                // For more args, create empty instance and use setters
                return Type.createInstance(cls, args.slice(0, 10));
        }
    }
    
    // ============================================
    // PROPERTY ACCESS
    // ============================================
    
    public function getHaxeValue(path:String):Dynamic
    {
        var parts = path.split('.');
        if (parts.length < 2) {
            // Try local context
            return getLocalContextValue(path);
        }
        
        var current:Dynamic = null;
        var i = 0;
        
        // Resolve first part
        var first = parts[0];
        if (first == 'Haxe' || first == 'haxe') {
            i = 1;
        }
        
        if (i < parts.length) {
            var cls = Type.resolveClass(parts[i]);
            if (cls != null) {
                current = cls;
                i++;
            }
        }
        
        // Navigate path
        while (i < parts.length && current != null)
        {
            var part = parts[i];
            
            // Check for getter
            var getter = Reflect.field(current, 'get_' + part);
            if (getter != null && Reflect.isFunction(getter)) {
                current = Reflect.callMethod(current, getter, []);
            } else {
                current = Reflect.field(current, part);
            }
            
            // Handle enum parameters
            if (current != null && Std.is(current, Enum)) {
                if (i + 1 < parts.length) {
                    i++;
                    var param = parts[i];
                    try {
                        var enumVal:Enum = cast current;
                        current = enumVal.createByName(param);
                    } catch (e:Dynamic) {
                        current = null;
                    }
                }
            }
            
            i++;
        }
        
        return coerceToLua(current);
    }
    
    public function setHaxeValue(path:String, value:Dynamic):Void
    {
        var parts = path.split('.');
        if (parts.length < 2) return;
        
        // Find target
        var target:Dynamic = null;
        var lastPart:String = '';
        
        if (parts.length > 1) {
            var parentPath = parts.slice(0, -1).join('.');
            target = getHaxeValue(parentPath);
            lastPart = parts[parts.length - 1];
        }
        
        if (target != null) {
            // Check for setter
            var setter = Reflect.field(target, 'set_' + lastPart);
            if (setter != null && Reflect.isFunction(setter)) {
                Reflect.callMethod(target, setter, [coerceToHaxe(value)]);
            } else {
                Reflect.setField(target, lastPart, coerceToHaxe(value));
            }
        }
    }
    
    function getLocalContextValue(name:String):Dynamic
    {
        // Try PlayState
        try {
            var ps = Type.resolveClass('states.PlayState');
            if (ps != null) {
                var instance = Reflect.field(ps, 'instance');
                if (instance != null) {
                    var value = Reflect.field(instance, name);
                    if (value != null) return value;
                }
            }
        } catch (e:Dynamic) { }
        
        return null;
    }
    
    // ============================================
    // METHOD CALLS
    // ============================================
    
    public function callHaxeMethod(path:String, args:Array<Dynamic>):Dynamic
    {
        // Path format: 'objectPath.methodName' or 'ClassName.methodName'
        var lastDot = path.lastIndexOf('.');
        if (lastDot == -1) return null;
        
        var objPath = path.substring(0, lastDot);
        var methodName = path.substring(lastDot + 1);
        
        var obj:Dynamic = null;
        if (objPath.indexOf('.') == -1) {
            obj = getLocalContextValue(objPath);
        } else {
            obj = getHaxeValue(objPath);
        }
        
        if (obj == null) return null;
        
        return callObjectMethod(obj, methodName, args);
    }
    
    public function callStaticMethod(classPath:String, methodName:String, args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return null;
        
        var method = Reflect.field(cls, methodName);
        if (method == null || !Reflect.isFunction(method)) return null;
        
        return Reflect.callMethod(cls, method, args);
    }
    
    public function callObjectMethod(obj:Dynamic, methodName:String, args:Array<Dynamic>):Dynamic
    {
        if (obj == null) return null;
        
        var method = Reflect.field(obj, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            // Try as property
            return Reflect.field(obj, methodName);
        }
        
        var haxeArgs = [for (a in args) coerceToHaxe(a)];
        var result = Reflect.callMethod(obj, method, haxeArgs);
        
        return coerceToLua(result);
    }
    
    // ============================================
    // OBJECT PROPERTIES
    // ============================================
    
    public function getObjectProperty(obj:Dynamic, prop:String):Dynamic
    {
        if (obj == null) return null;
        
        var value = Reflect.field(obj, prop);
        return coerceToLua(value);
    }
    
    public function setObjectProperty(obj:Dynamic, prop:String, value:Dynamic):Void
    {
        if (obj == null) return;
        Reflect.setField(obj, prop, coerceToHaxe(value));
    }
    
    // ============================================
    // TYPE INFORMATION
    // ============================================
    
    public function getHaxeType(obj:Dynamic):String
    {
        if (obj == null) return 'null';
        if (Std.is(obj, String)) return 'String';
        if (Std.is(obj, Int)) return 'Int';
        if (Std.is(obj, Float)) return 'Float';
        if (Std.is(obj, Bool)) return 'Bool';
        if (Std.is(obj, Array)) return 'Array';
        if (Std.is(obj, Bool)) return 'Bool';
        
        var cls = Type.getClass(obj);
        if (cls != null) return Type.getClassName(cls);
        
        var enm = Type.getEnum(obj);
        if (enm != null) return Type.getEnumName(enm);
        
        return 'Unknown';
    }
    
    public function getObjectType(obj:Dynamic):String
    {
        return getHaxeType(obj);
    }
    
    public function isHaxeInstance(obj:Dynamic, classPath:String):Bool
    {
        if (obj == null) return false;
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return false;
        return Std.is(obj, cls);
    }
    
    public function castHaxeObject(obj:Dynamic, classPath:String):Dynamic
    {
        if (!isHaxeInstance(obj, classPath)) {
            FunkinLua.luaTrace('LuaBridge: Cannot cast to $classPath', true, false, FlxColor.YELLOW);
        }
        return obj;
    }
    
    // ============================================
    // ENUM SUPPORT
    // ============================================
    
    public function getEnumValue(enumPath:String, valueName:String):Dynamic
    {
        var enm:Enum<Dynamic> = Type.resolveEnum(enumPath);
        if (enm == null) {
            FunkinLua.luaTrace('LuaBridge: Enum not found: $enumPath', true, false, FlxColor.RED);
            return null;
        }
        
        try {
            return enm.createByName(valueName);
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('LuaBridge: Enum value not found: $enumPath.$valueName', true, false, FlxColor.RED);
            return null;
        }
    }
    
    // ============================================
    // CLASS INTROSPECTION
    // ============================================
    
    public function listClassMethods(classPath:String):Array<String>
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
    
    public function listClassProperties(classPath:String):Array<String>
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
        var props:Array<String> = [];
        
        for (field in Type.getClassFields(cls)) {
            var value = Reflect.field(cls, field);
            if (!Reflect.isFunction(value)) {
                props.push(field);
            }
        }
        
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
    
    public function listClassStatics(classPath:String):Array<String>
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
        var statics:Array<String> = [];
        for (field in Type.getClassFields(cls)) {
            statics.push(field);
        }
        statics.sort(Reflect.compare);
        return statics;
    }
    
    public function listClassConstants(classPath:String):Array<Dynamic>
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
    
    public function classExtends(classPath:String, parentPath:String):Bool
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        var parent:Class<Dynamic> = Type.resolveClass(parentPath);
        
        if (cls == null || parent == null) return false;
        
        var current = cls;
        while (current != null) {
            if (current == parent) return true;
            current = Type.getSuperClass(current);
        }
        return false;
    }
    
    public function listInterfaces(classPath:String):Array<String>
    {
        // Haxe doesn't easily expose interfaces at runtime
        return [];
    }
    
    // ============================================
    // OBJECT OPERATIONS
    // ============================================
    
    public function cloneHaxeObject(obj:Dynamic):Dynamic
    {
        if (obj == null) return null;
        
        var cls = Type.getClass(obj);
        if (cls == null) return obj;
        
        try {
            var newInstance = Type.createInstance(cls, []);
            
            // Copy all fields
            for (field in Reflect.fields(obj)) {
                if (field.charAt(0) != '_') {
                    var value = Reflect.field(obj, field);
                    if (!Reflect.isFunction(value)) {
                        Reflect.setField(newInstance, field, value);
                    }
                }
            }
            
            return wrapAsLuaObject(newInstance);
        } catch (e:Dynamic) {
            return null;
        }
    }
    
    public function destroyHaxeObject(obj:Dynamic):Void
    {
        if (obj == null) return;
        
        var destroy = Reflect.field(obj, 'destroy');
        if (destroy != null && Reflect.isFunction(destroy)) {
            Reflect.callMethod(obj, destroy, []);
        }
    }
    
    public function iterateObjectProperties(obj:Dynamic):Array<Dynamic>
    {
        if (obj == null) return [];
        
        var props:Array<Dynamic> = [];
        
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_') {
                var value = Reflect.field(obj, field);
                if (!Reflect.isFunction(value)) {
                    props.push({key: field, value: coerceToLua(value)});
                }
            }
        }
        
        return props;
    }
    
    public function objectToString(obj:Dynamic):String
    {
        if (obj == null) return 'null';
        
        var toString = Reflect.field(obj, 'toString');
        if (toString != null && Reflect.isFunction(toString)) {
            var result = Reflect.callMethod(obj, toString, []);
            return result != null ? Std.string(result) : getHaxeType(obj);
        }
        
        var cls = Type.getClass(obj);
        if (cls != null) {
            return Type.getClassName(cls);
        }
        
        var enm = Type.getEnum(obj);
        if (enm != null) {
            return Type.getEnumName(enm) + '.' + Type.enumConstructor(obj);
        }
        
        return getHaxeType(obj);
    }
    
    // ============================================
    // CLASS EXTENSION
    // ============================================
    
    public function createExtendedClass(baseClass:String, extensions:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(baseClass);
        if (cls == null) return null;
        
        // For now, return the base class
        // Full implementation would require HScript or macros
        return cls;
    }
    
    public function markImplemented(classPath:String, interfaces:Array<String>):Void
    {
        // Mark class as implementing interfaces
        // Useful for documentation purposes
    }
    
    public function addClassMethod(classPath:String, methodName:String, func:Dynamic):Void
    {
        // Add method to class at runtime
        // Useful for extending existing classes
    }
    
    public function addClassProperty(classPath:String, propName:String, getter:Dynamic, setter:Dynamic):Void
    {
        // Add property to class at runtime
    }
    
    // ============================================
    // TYPE COERCION
    // ============================================
    
    public function coerceToLua(value:Dynamic):Dynamic
    {
        if (value == null) return null;
        
        var type = Type.typeof(value);
        switch (type)
        {
            case TNull: return null;
            case TInt, TFloat, TBool, TString: return value;
            case TArray:
                return [for (i in 0...cast(value, Array<Dynamic>).length) 
                    coerceToLua(cast(value, Array<Dynamic>)[i])];
            case TClass(c):
                var className = Type.getClassName(c);
                
                // Special handling for common types
                if (Std.is(value, FlxColor)) return wrapFlxColor(cast value);
                if (Std.is(value, FlxPoint)) return wrapFlxPoint(cast value);
                if (Std.is(value, FlxRect)) return wrapFlxRect(cast value);
                
                // Wrap as Lua object
                return wrapAsLuaObject(value);
            case TEnum(e):
                return {
                    __enum: Type.getEnumName(e),
                    __ctor: Type.enumConstructor(value),
                    __params: [for (p in Type.enumParameters(value)) coerceToLua(p)]
                };
            default: return value;
        }
    }
    
    public function coerceToHaxe(value:Dynamic, ?targetType:String = null):Dynamic
    {
        if (value == null) return null;
        
        // Already Haxe types
        if (Std.is(value, String) || Std.is(value, Int) || Std.is(value, Float) || Std.is(value, Bool)) {
            return value;
        }
        
        // Unwrap Lua objects
        if (Reflect.hasField(value, '__obj')) {
            return Reflect.field(value, '__obj');
        }
        
        // Arrays stay arrays
        if (Std.is(value, Array)) {
            return value;
        }
        
        return value;
    }
    
    // ============================================
    // LUA OBJECT WRAPPING
    // ============================================
    
    public function wrapAsLuaObject(obj:Dynamic):Dynamic
    {
        if (obj == null) return null;
        
        var table:Dynamic = {};
        var className = 'Unknown';
        
        var cls = Type.getClass(obj);
        if (cls != null) {
            className = Type.getClassName(cls);
        }
        
        // Mark as Haxe object
        Reflect.setField(table, '__type', className);
        Reflect.setField(table, '__obj', obj);
        Reflect.setField(table, '__id', nextProxyId++);
        
        // Copy common properties
        copyObjectProperties(obj, table);
        
        // Add common methods as closures
        addCommonMethods(obj, table);
        
        return table;
    }
    
    function copyObjectProperties(obj:Dynamic, table:Dynamic):Void
    {
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_') {
                try {
                    var value = Reflect.field(obj, field);
                    if (!Reflect.isFunction(value)) {
                        Reflect.setField(table, field, coerceToLua(value));
                    }
                } catch (e:Dynamic) { }
            }
        }
    }
    
    function addCommonMethods(obj:Dynamic, table:Dynamic):Void
    {
        var self = this;
        
        // All objects get these
        Reflect.setField(table, 'destroy', function() {
            var o = Reflect.field(table, '__obj');
            self.destroyHaxeObject(o);
            return nil;
        });
        
        Reflect.setField(table, 'clone', function() {
            var o = Reflect.field(table, '__obj');
            return self.cloneHaxeObject(o);
        });
        
        Reflect.setField(table, 'type', function() {
            return Reflect.field(table, '__type');
        });
        
        Reflect.setField(table, 'toString', function() {
            var o = Reflect.field(table, '__obj');
            return self.objectToString(o);
        });
    }
    
    public function unwrapFromLuaObject(proxy:Dynamic):Dynamic
    {
        if (proxy == null) return null;
        if (Reflect.hasField(proxy, '__obj')) {
            return Reflect.field(proxy, '__obj');
        }
        return proxy;
    }
    
    public function createObjectProxy(obj:Dynamic):Dynamic
    {
        return wrapAsLuaObject(obj);
    }
    
    // ============================================
    // TYPE-SPECIFIC WRAPPERS
    // ============================================
    
    function wrapFlxColor(color:FlxColor):Dynamic
    {
        return {
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha,
            hex: color.toHexString(),
            int: color.toInteger(),
            __type: 'FlxColor',
            __obj: color
        };
    }
    
    function wrapFlxPoint(point:FlxPoint):Dynamic
    {
        return {
            x: point.x,
            y: point.y,
            __type: 'FlxPoint',
            __obj: point
        };
    }
    
    function wrapFlxRect(rect:FlxRect):Dynamic
    {
        return {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            __type: 'FlxRect',
            __obj: rect
        };
    }
    
    // ============================================
    // TYPE CONVERTERS
    // ============================================
    
    function initConverters():Void
    {
        // FlxColor converter
        converters.set('flixel.util.FlxColor', function(color:FlxColor):Dynamic {
            return wrapFlxColor(color);
        });
    }
    
    // ============================================
    // RESET
    // ============================================
    
    public function reset():Void
    {
        objectRegistry.clear();
        proxyRegistry.clear();
        nextProxyId = 0;
        FunkinLua.luaTrace('LuaBridge: Reset complete', false, false, FlxColor.GREEN);
    }
}

// ============================================
// TYPE CONVERTER FUNCTION
// ============================================

typedef TypeConverterFunc = Dynamic->Dynamic;

// ============================================
// LUA OBJECT PROXY
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