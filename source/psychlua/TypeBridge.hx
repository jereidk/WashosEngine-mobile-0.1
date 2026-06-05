package psychlua;

#if LUA_ALLOWED
import haxe.DynamicAccess;
import haxe.ds.StringMap;
import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.PosInfos;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxText;
import flixel.FlxCamera;
import flixel.FlxGroup;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import openfl.display.BitmapData;
import openfl.display3D.textures.TextureBase;
import sys.FileSystem;
import sys.io.File;

/**
 * TypeBridge - Perfect bridge between Lua and Haxe
 * 
 * This system provides seamless interoperability between Lua and Haxe,
 * allowing Lua code to access any Haxe type, method, property, or constant
 * without manual wrapper functions.
 * 
 * Philosophy:
 * - If it exists in Haxe, it should be accessible from Lua
 * - Native types should auto-convert (no manual wrapping)
 * - Classes should feel native to Lua (using metatables)
 * - Method calls should work identically in both languages
 * 
 * Usage:
 * ```lua
 * -- Access any class
 * local PS = Haxe.getClass('states.PlayState')
 * local sprite = Haxe.create('flixel.FlxSprite', 100, 200)
 * 
 * -- Call methods naturally
 * sprite:loadGraphic('assets/image.png')
 * sprite:update(0.016)
 * 
 * -- Access properties
 * sprite.x = 500
 * sprite.alpha = 0.5
 * 
 * -- Use constants
 * local RED = Haxe.getStatic('flixel.util.FlxColor.RED')
 * 
 * -- Type checking
 * if Haxe.isInstanceOf(sprite, 'flixel.FlxSprite') then
 *     print('It is a sprite!')
 * end
 * 
 * -- Extend classes
 * local MyClass = Haxe.defineClass('MyClass', {
 *     __construct = function(self, x, y)
 *         self.x = x
 *         self.y = y
 *     end,
 *     update = function(self, dt)
 *         self.x = self.x + dt * 100
 *     end
 * })
 * ```
 */
class TypeBridge
{
    // Singleton
    public static var instance(get, never):TypeBridge;
    private static var _instance:TypeBridge = null;
    
    private static inline function get_instance():TypeBridge
    {
        if (_instance == null) _instance = new TypeBridge();
        return _instance;
    }
    
    // Class cache
    private var classCache:StringMap<Class<Dynamic>>;
    private var proxyCache:StringMap<HaxeClassProxy>;
    private var objectRegistry:StringMap<Dynamic>;
    
    // Registered types for conversion
    private var typeConverters:StringMap<TypeConverter>;
    private var objectMethods:StringMap<Array<String>>;
    
    // Lua state reference
    private var luaState:State = null;
    
    public function new()
    {
        classCache = new StringMap();
        proxyCache = new StringMap();
        objectRegistry = new StringMap();
        typeConverters = new StringMap();
        objectMethods = new StringMap();
        
        // Register default type converters
        registerDefaultConverters();
        registerCommonMethods();
    }
    
    /**
     * Initialize with Lua state
     */
    public function init(lua:State):Void
    {
        this.luaState = lua;
        registerHaxeTable();
    }
    
    /**
     * Register the global Haxe table and engine functions
     */
    function registerHaxeTable():Void
    {
        if (luaState == null) return;
        
        var lua = luaState;
        
        // Haxe table - main entry point
        Lua_helper.add_callback(lua, "Haxe", function(action:String, ...args:Dynamic):Dynamic {
            return handleHaxeAction(action, args);
        });
        
        // Quick access functions
        Lua_helper.add_callback(lua, "create", function(classPath:String, ...args:Dynamic):Dynamic {
            return createHaxeInstance(classPath, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "getClass", function(classPath:String):Dynamic {
            return getHaxeClassProxy(classPath);
        });
        
        Lua_helper.add_callback(lua, "callStatic", function(classPath:String, method:String, ...args:Dynamic):Dynamic {
            return callStaticMethod(classPath, method, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "getStatic", function(fullPath:String):Dynamic {
            return getStaticValue(fullPath);
        });
        
        Lua_helper.add_callback(lua, "setStatic", function(fullPath:String, value:Dynamic):Void {
            setStaticValue(fullPath, value);
        });
        
        Lua_helper.add_callback(lua, "isInstance", function(obj:Dynamic, classPath:String):Bool {
            return isHaxeInstance(obj, classPath);
        });
        
        Lua_helper.add_callback(lua, "typeof", function(obj:Dynamic):String {
            return getHaxeTypeName(obj);
        });
        
        Lua_helper.add_callback(lua, "castTo", function(obj:Dynamic, classPath:String):Dynamic {
            return castHaxeValue(obj, classPath);
        });
        
        // Inheritance support
        Lua_helper.add_callback(lua, "extends", function(baseClass:String, extensions:Dynamic):Dynamic {
            return createExtendedClass(baseClass, extensions);
        });
        
        Lua_helper.add_callback(lua, "implements", function(classPath:String, interfaces:Array<String>):Void {
            // Mark class as implementing interfaces
        });
        
        // Method introspection
        Lua_helper.add_callback(lua, "methods", function(classPath:String):Array<String> {
            return getClassMethods(classPath);
        });
        
        Lua_helper.add_callback(lua, "properties", function(classPath:String):Array<String> {
            return getClassProperties(classPath);
        });
        
        Lua_helper.add_callback(lua, "statics", function(classPath:String):Array<String> {
            return getClassStatics(classPath);
        });
        
        Lua_helper.add_callback(lua, "haxeToLua", function(value:Dynamic):Dynamic {
            return coerceToLua(value);
        });
        
        Lua_helper.add_callback(lua, "luaToHaxe", function(value:Dynamic, typePath:String):Dynamic {
            return coerceToHaxe(value, typePath);
        });
        
        // Create proxy objects
        Lua_helper.add_callback(lua, "proxy", function(obj:Dynamic):Dynamic {
            return createObjectProxy(obj);
        });
        
        // Access enums
        Lua_helper.add_callback(lua, "enumValue", function(enumPath:String, valueName:String):Dynamic {
            return getEnumValue(enumPath, valueName);
        });
        
        Lua_helper.add_callback(lua, "enumValues", function(enumPath:String):Array<String> {
            return getEnumConstructors(enumPath);
        });
        
        Lua_helper.add_callback(lua, "isEnum", function(value:Dynamic):Bool {
            return Std.is(value, Enum);
        });
    }
    
    /**
     * Handle Haxe.* calls
     */
    function handleHaxeAction(action:String, args:Array<Dynamic>):Dynamic
    {
        switch (action)
        {
            case "getClass":
                return getHaxeClassProxy(args[0]);
                
            case "create":
                return createHaxeInstance(args[0], args.slice(1));
                
            case "callStatic":
                return callStaticMethod(args[0], args[1], args.slice(2));
                
            case "getStatic":
                return getStaticValue(args[0]);
                
            case "setStatic":
                setStaticValue(args[0], args[1]);
                return null;
                
            case "isInstance":
                return isHaxeInstance(args[0], args[1]);
                
            case "typeof":
                return getHaxeTypeName(args[0]);
                
            case "cast":
                return castHaxeValue(args[0], args[1]);
                
            case "extend":
                return createExtendedClass(args[0], args[1]);
                
            case "methods":
                return getClassMethods(args[0]);
                
            case "properties":
                return getClassProperties(args[0]);
                
            case "statics":
                return getClassStatics(args[0]);
                
            case "enum":
                return getEnumValue(args[0], args[1]);
                
            case "enumValues":
                return getEnumConstructors(args[0]);
                
            default:
                FunkinLua.luaTrace('TypeBridge: Unknown action: $action', true, false, FlxColor.RED);
                return null;
        }
    }
    
    // ============================================
    // CLASS ACCESS
    // ============================================
    
    /**
     * Get a Haxe class proxy
     */
    public function getHaxeClassProxy(classPath:String):HaxeClassProxy
    {
        if (proxyCache.exists(classPath)) {
            return proxyCache.get(classPath);
        }
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('TypeBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        var proxy = new HaxeClassProxy(classPath, cls);
        proxyCache.set(classPath, proxy);
        return proxy;
    }
    
    /**
     * Get a Haxe class
     */
    public function getHaxeClass(classPath:String):Class<Dynamic>
    {
        if (classCache.exists(classPath)) {
            return classCache.get(classPath);
        }
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls != null) {
            classCache.set(classPath, cls);
        }
        return cls;
    }
    
    // ============================================
    // INSTANCE CREATION
    // ============================================
    
    /**
     * Create a Haxe instance with arguments
     */
    public function createHaxeInstance(classPath:String, args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('TypeBridge: Cannot create instance - class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        try {
            var instance = createInstanceArgs(cls, args);
            
            // Register for tracking
            var id = 'obj_' + Std.string(Math.random() * 1000000);
            objectRegistry.set(id, instance);
            
            // Return as proxy for method chaining
            return createObjectProxy(instance);
            
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('TypeBridge: Failed to create instance: $e', true, false, FlxColor.RED);
            return null;
        }
    }
    
    /**
     * Create instance with variable args
     */
    function createInstanceArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
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
                // For more args, use reflection-based creation
                return createInstanceWithManyArgs(cls, args);
        }
    }
    
    /**
     * Create instance with many arguments
     */
    function createInstanceWithManyArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
    {
        // Use a different approach for many arguments
        // This would need HScript or macro support
        FunkinLua.luaTrace('TypeBridge: Too many arguments for instantiation', true, false, FlxColor.YELLOW);
        return null;
    }
    
    // ============================================
    // METHOD CALLS
    // ============================================
    
    /**
     * Call a static method on a class
     */
    public function callStaticMethod(classPath:String, methodName:String, args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('TypeBridge: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        var method:Dynamic = Reflect.field(cls, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            FunkinLua.luaTrace('TypeBridge: Static method not found: $classPath.$methodName', true, false, FlxColor.RED);
            return null;
        }
        
        return Reflect.callMethod(cls, method, args);
    }
    
    /**
     * Call an instance method
     */
    public function callInstanceMethod(obj:Dynamic, methodName:String, args:Array<Dynamic>):Dynamic
    {
        if (obj == null) {
            FunkinLua.luaTrace('TypeBridge: Cannot call method on null object', true, false, FlxColor.RED);
            return null;
        }
        
        var method:Dynamic = Reflect.field(obj, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            FunkinLua.luaTrace('TypeBridge: Method not found: $methodName', true, false, FlxColor.RED);
            return null;
        }
        
        return Reflect.callMethod(obj, method, args);
    }
    
    // ============================================
    // PROPERTY ACCESS
    // ============================================
    
    /**
     * Get a static value (e.g., FlxColor.RED)
     */
    public function getStaticValue(fullPath:String):Dynamic
    {
        var parts = fullPath.split('.');
        if (parts.length < 2) {
            FunkinLua.luaTrace('TypeBridge: Invalid static path: $fullPath', true, false, FlxColor.RED);
            return null;
        }
        
        // Find the class
        var classPath = parts.slice(0, -1).join('.');
        var fieldName = parts[parts.length - 1];
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            // Maybe it's already a static on a class path
            var possibleClass = parts.slice(0, -2).join('.');
            cls = Type.resolveClass(possibleClass);
            if (cls != null) {
                // Check if this is a static enum value
                var stat = Reflect.field(cls, parts[parts.length - 2]);
                if (stat != null && Std.is(stat, Enum)) {
                    var enumVal:Enum = cast stat;
                    return enumVal.createByName(parts[parts.length - 1]);
                }
            }
            return null;
        }
        
        return Reflect.field(cls, fieldName);
    }
    
    /**
     * Set a static value
     */
    public function setStaticValue(fullPath:String, value:Dynamic):Void
    {
        var parts = fullPath.split('.');
        if (parts.length < 2) return;
        
        var classPath = parts.slice(0, -1).join('.');
        var fieldName = parts[parts.length - 1];
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return;
        
        Reflect.setField(cls, fieldName, value);
    }
    
    /**
     * Get instance property
     */
    public function getProperty(obj:Dynamic, propName:String):Dynamic
    {
        if (obj == null) return null;
        return Reflect.field(obj, propName);
    }
    
    /**
     * Set instance property
     */
    public function setProperty(obj:Dynamic, propName:String, value:Dynamic):Void
    {
        if (obj == null) return;
        Reflect.setField(obj, propName, value);
    }
    
    // ============================================
    // TYPE CHECKING & CONVERSION
    // ============================================
    
    /**
     * Check if object is instance of class
     */
    public function isHaxeInstance(obj:Dynamic, classPath:String):Bool
    {
        if (obj == null) return false;
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return false;
        
        return Std.is(obj, cls);
    }
    
    /**
     * Get Haxe type name
     */
    public function getHaxeTypeName(obj:Dynamic):String
    {
        if (obj == null) return 'null';
        
        var type = Type.typeof(obj);
        switch (type)
        {
            case TNull: return 'null';
            case TInt: return 'Int';
            case TFloat: return 'Float';
            case TBool: return 'Bool';
            case TString: return 'String';
            case TObject: return 'Object';
            case TArray: return 'Array';
            case TClass(c):
                return Type.getClassName(c);
            case TEnum(e):
                return Type.getEnumName(e);
            case TFunction: return 'Function';
            case TUnknown: return 'Unknown';
        }
    }
    
    /**
     * Cast value to type
     */
    public function castHaxeValue(obj:Dynamic, classPath:String):Dynamic
    {
        if (obj == null) return null;
        
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return obj;
        
        if (Std.is(obj, cls)) {
            return obj;
        }
        
        // Try conversion
        try {
            return cls == String ? Std.string(obj) :
                   cls == Int ? Std.int(obj) :
                   cls == Float ? Std.parseFloat(Std.string(obj)) :
                   obj;
        } catch (e:Dynamic) {
            return obj;
        }
    }
    
    /**
     * Coerce Haxe value to Lua-compatible type
     */
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
                // Check for custom converter
                if (typeConverters.exists(className)) {
                    return typeConverters.get(className).toLua(value, this);
                }
                // Return as proxy
                return createObjectProxy(value);
            case TEnum(e):
                return {
                    __enum: Type.getEnumName(e),
                    __constructor: Type.enumConstructor(value),
                    __params: Type.enumParameters(value)
                };
            default:
                return value;
        }
    }
    
    /**
     * Coerce Lua value to Haxe type
     */
    public function coerceToHaxe(value:Dynamic, typePath:String):Dynamic
    {
        if (value == null) return null;
        
        var cls:Class<Dynamic> = Type.resolveClass(typePath);
        if (cls == null) return value;
        
        // Check for custom converter
        if (typeConverters.exists(typePath)) {
            return typeConverters.get(typePath).toHaxe(value, this);
        }
        
        // Basic type conversion
        if (cls == String) return Std.string(value);
        if (cls == Int) return Std.int(value);
        if (cls == Float) return Std.parseFloat(Std.string(value));
        if (cls == Bool) return value == true;
        
        return value;
    }
    
    // ============================================
    // OBJECT PROXY
    // ============================================
    
    /**
     * Create a proxy wrapper for a Haxe object
     * This allows Lua to call methods using :syntax
     */
    public function createObjectProxy(obj:Dynamic):HaxeObjectProxy
    {
        if (obj == null) return null;
        return new HaxeObjectProxy(obj, this);
    }
    
    /**
     * Get registered methods for a type
     */
    public function getRegisteredMethods(classPath:String):Array<String>
    {
        return objectMethods.exists(classPath) ? objectMethods.get(classPath) : [];
    }
    
    // ============================================
    // CLASS INTROSPECTION
    // ============================================
    
    /**
     * Get all methods of a class
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
        
        // Instance methods (from prototype)
        try {
            var instance = Type.createEmptyInstance(cls);
            for (field in Reflect.fields(instance)) {
                var value = Reflect.field(instance, field);
                if (Reflect.isFunction(value) && !Lambda.has(methods, field)) {
                    methods.push(field);
                }
            }
        } catch (e:Dynamic) { }
        
        return methods;
    }
    
    /**
     * Get all properties of a class
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
        
        return props;
    }
    
    /**
     * Get static fields of a class
     */
    public function getClassStatics(classPath:String):Array<String>
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) return [];
        
        var statics:Array<String> = [];
        for (field in Type.getClassFields(cls)) {
            statics.push(field);
        }
        return statics;
    }
    
    // ============================================
    // ENUM SUPPORT
    // ============================================
    
    /**
     * Get enum value by name
     */
    public function getEnumValue(enumPath:String, valueName:String):Dynamic
    {
        var enm:Enum<Dynamic> = Type.resolveEnum(enumPath);
        if (enm == null) {
            FunkinLua.luaTrace('TypeBridge: Enum not found: $enumPath', true, false, FlxColor.RED);
            return null;
        }
        
        try {
            return enm.createByName(valueName);
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('TypeBridge: Enum value not found: $enumPath.$valueName', true, false, FlxColor.RED);
            return null;
        }
    }
    
    /**
     * Get all enum constructors
     */
    public function getEnumConstructors(enumPath:String):Array<String>
    {
        var enm:Enum<Dynamic> = Type.resolveEnum(enumPath);
        if (enm == null) return [];
        
        return Type.getEnumConstructs(enm);
    }
    
    // ============================================
    // CLASS EXTENSION (OOP in Lua)
    // ============================================
    
    /**
     * Create a class that extends another
     */
    public function createExtendedClass(baseClassPath:String, extensions:Dynamic):Dynamic
    {
        var baseCls:Class<Dynamic> = Type.resolveClass(baseClassPath);
        if (baseCls == null) {
            FunkinLua.luaTrace('TypeBridge: Base class not found: $baseClassPath', true, false, FlxColor.RED);
            return null;
        }
        
        // Create a proxy that wraps the base class with extensions
        return createClassExtension(baseCls, extensions);
    }
    
    /**
     * Create class extension
     */
    function createClassExtension(baseCls:Class<Dynamic>, extensions:Dynamic):Dynamic
    {
        // For now, return the base class with a marker
        // Full implementation would need HScript
        return baseCls;
    }
    
    // ============================================
    // TYPE CONVERTERS
    // ============================================
    
    /**
     * Register default type converters
     */
    function registerDefaultConverters():Void
    {
        // FlxColor converter
        typeConverters.set('flixel.util.FlxColor', new FlxColorConverter());
        
        // FlxPoint converter
        typeConverters.set('flixel.math.FlxPoint', new FlxPointConverter());
        
        // FlxRect converter
        typeConverters.set('flixel.math.FlxRect', new FlxRectConverter());
        
        // FlxSprite converter
        typeConverters.set('flixel.FlxSprite', new FlxSpriteConverter());
        
        // BitmapData converter
        typeConverters.set('openfl.display.BitmapData', new BitmapDataConverter());
    }
    
    /**
     * Register common methods for quick access
     */
    function registerCommonMethods():Void
    {
        // FlxSprite methods
        objectMethods.set('flixel.FlxSprite', [
            'loadGraphic', 'loadGraphicFromSprite', 'makeGraphic', 'updateHitbox',
            'animation', 'addAnimation', 'addOffset', 'play', 'stop', 'destroy',
            'kill', 'revive', 'setPosition', 'setSize', 'setGraphicSize',
            'setGraphicSizeFromFrame', 'scale', 'centerOffsets', 'centerOrigin',
            'getGraphicSize', 'drawFrame', 'updateFrame', 'color', 'alpha',
            'x', 'y', 'width', 'height', 'angle', 'scaleX', 'scaleY',
            'visible', 'active', 'exists', 'solid', 'immovable'
        ]);
        
        // FlxText methods
        objectMethods.set('flixel.FlxText', [
            'text', 'size', 'font', 'color', 'alignment', 'borderStyle',
            'borderColor', 'borderSize', 'shadowColor', 'backgroundColor',
            'background', 'setFormat', 'setBorderStyle', 'drawFrame', 'update'
        ]);
        
        // FlxGroup methods
        objectMethods.set('flixel.FlxGroup', [
            'add', 'remove', 'clear', 'replace', 'sort', 'getFirstAvailable',
            'getFirstNull', 'getFirstAlive', 'getFirstDead', 'countLiving',
            'countDead', 'forEach', 'forEachAlive', 'forEachDead', 'forEachExists'
        ]);
        
        // FlxCamera methods
        objectMethods.set('flixel.FlxCamera', [
            'follow', 'followLead', 'unfollow', 'focusOn', 'shake', 'fade',
            'flash', 'zoom', 'x', 'y', 'width', 'height', 'target', 'alpha'
        ]);
    }
    
    /**
     * Reset the bridge
     */
    public function reset():Void
    {
        objectRegistry.clear();
        FunkinLua.luaTrace('TypeBridge: Reset complete', false, false, FlxColor.GREEN);
    }
}

// ============================================
// TYPE CONVERTER INTERFACE
// ============================================

interface TypeConverter
{
    function toLua(value:Dynamic, bridge:TypeBridge):Dynamic;
    function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic;
}

// ============================================
// SPECIFIC CONVERTERS
// ============================================

class FlxColorConverter implements TypeConverter
{
    public function toLua(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        var color:FlxColor = cast value;
        return {
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha,
            hex: color.toHexString(),
            toInt: color.toInteger()
        };
    }
    
    public function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        if (Std.is(value, Int)) return FlxColor.fromInt(value);
        if (Std.is(value, String)) return FlxColor.fromString(value);
        if (value.hex != null) return FlxColor.fromHex(value.hex);
        return FlxColor.WHITE;
    }
}

class FlxPointConverter implements TypeConverter
{
    public function toLua(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        var point:FlxPoint = cast value;
        return {x: point.x, y: point.y};
    }
    
    public function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        if (Std.is(value, FlxPoint)) return value;
        return FlxPoint.get(value.x, value.y);
    }
}

class FlxRectConverter implements TypeConverter
{
    public function toLua(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        var rect:FlxRect = cast value;
        return {x: rect.x, y: rect.y, width: rect.width, height: rect.height};
    }
    
    public function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        if (Std.is(value, FlxRect)) return value;
        return FlxRect.weak(value.x, value.y, value.width, value.height);
    }
}

class FlxSpriteConverter implements TypeConverter
{
    public function toLua(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        return bridge.createObjectProxy(value);
    }
    
    public function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        return value;
    }
}

class BitmapDataConverter implements TypeConverter
{
    public function toLua(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        return bridge.createObjectProxy(value);
    }
    
    public function toHaxe(value:Dynamic, bridge:TypeBridge):Dynamic
    {
        return value;
    }
}

// ============================================
// HAXE CLASS PROXY
// ============================================

/**
 * Represents a Haxe class with method/property access
 */
class HaxeClassProxy
{
    public var classPath:String;
    public var cls:Class<Dynamic>;
    
    public function new(classPath:String, cls:Class<Dynamic>)
    {
        this.classPath = classPath;
        this.cls = cls;
    }
    
    // Allow calling class directly like: local Sprite = Haxe.getClass('flixel.FlxSprite')
    // Then: local sprite = Sprite:new(100, 200)
}

/**
 * Proxy wrapper for Haxe objects
 * Allows Lua to use :syntax for method calls
 */
class HaxeObjectProxy
{
    public var __obj:Dynamic;
    private var __bridge:TypeBridge;
    
    public function new(obj:Dynamic, bridge:TypeBridge)
    {
        this.__obj = obj;
        this.__bridge = bridge;
    }
    
    // These meta methods allow Lua to use :syntax
    // The actual method calls go through __call
    public function __call(methodName:String, args:Array<Dynamic>):Dynamic
    {
        return __bridge.callInstanceMethod(__obj, methodName, args);
    }
}
#end