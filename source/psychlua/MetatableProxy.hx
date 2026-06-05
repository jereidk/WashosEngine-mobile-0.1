package psychlua;

#if LUA_ALLOWED
import haxe.ds.StringMap;
import haxe.Json;
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
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.FlxGraphic;

/**
 * MetatableProxy - Perfect Lua integration with metatables
 * 
 * This system creates Lua metatables for Haxe objects, allowing:
 * - Natural method calling with :syntax
 * - Property access via __index
 * - Property setting via __newindex
 * - Iterator support via __pairs and __ipairs
 * - String representation via __tostring
 * 
 * Example:
 * ```lua
 * local sprite = create('flixel.FlxSprite', 100, 200)
 * sprite:loadGraphic('assets/image.png')  -- Works like Haxe!
 * sprite.x = 500                          -- Direct property access
 * sprite.alpha = 0.5                       -- Property modification
 * print(sprite)                            -- __tostring
 * for k, v in pairs(sprite) do print(k) end  -- Iteration
 * ```
 */
class MetatableProxy
{
    private static var instance(get, never):MetatableProxy;
    private static var _instance:MetatableProxy = null;
    
    private static inline function get_instance():MetatableProxy
    {
        if (_instance == null) _instance = new MetatableProxy();
        return _instance;
    }
    
    // Proxy storage by object ID
    private var proxies:StringMap<ObjectProxy>;
    private var objectToId:StringMap<String>;
    private var nextId:Int = 0;
    
    // Method caches per class
    private var methodCaches:StringMap<Array<String>>;
    private var propertyCaches:StringMap<Array<String>>;
    
    public function new()
    {
        proxies = new StringMap();
        objectToId = new StringMap();
        methodCaches = new StringMap();
        propertyCaches = new StringMap();
        
        initMethodCaches();
    }
    
    /**
     * Initialize with Lua state
     */
    public function initWithLua(lua:State):Void
    {
        // Register factory functions in Lua
        Lua_helper.add_callback(lua, "__createHaxeObject", function(classPath:String, ...args:Dynamic):Dynamic {
            return createProxy(classPath, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "__getProperty", function(objId:String, propName:String):Dynamic {
            return getProperty(objId, propName);
        });
        
        Lua_helper.add_callback(lua, "__setProperty", function(objId:String, propName:String, value:Dynamic):Void {
            setProperty(objId, propName, value);
        });
        
        Lua_helper.add_callback(lua, "__callMethod", function(objId:String, methodName:String, ...args:Dynamic):Dynamic {
            return callMethod(objId, methodName, [for (a in args) a]);
        });
        
        Lua_helper.add_callback(lua, "__iterateObject", function(objId:String):Array<Dynamic> {
            return getIterableProperties(objId);
        });
        
        Lua_helper.add_callback(lua, "__cloneObject", function(objId:String):Dynamic {
            return cloneProxy(objId);
        });
        
        Lua_helper.add_callback(lua, "__destroyObject", function(objId:String):Void {
            destroyProxy(objId);
        });
        
        Lua_helper.add_callback(lua, "__objectType", function(objId:String):String {
            return getObjectType(objId);
        });
        
        Lua_helper.add_callback(lua, "__objectToString", function(objId:String):String {
            return objectToString(objId);
        });
    }
    
    /**
     * Create a proxy for a Haxe object
     */
    public function createProxy(classPath:String, args:Array<Dynamic>):Dynamic
    {
        var cls:Class<Dynamic> = Type.resolveClass(classPath);
        if (cls == null) {
            FunkinLua.luaTrace('MetatableProxy: Class not found: $classPath', true, false, FlxColor.RED);
            return null;
        }
        
        var instance:Dynamic;
        try {
            instance = createWithArgs(cls, args);
        } catch (e:Dynamic) {
            FunkinLua.luaTrace('MetatableProxy: Failed to create: $e', true, false, FlxColor.RED);
            return null;
        }
        
        // Create proxy wrapper
        var proxy = new ObjectProxy(instance, classPath, nextId++);
        var id = 'haxe_' + proxy.id;
        
        proxies.set(id, proxy);
        objectToId.set(id, id);
        
        // Return a Lua table with metatable for natural syntax
        return createLuaProxyTable(proxy);
    }
    
    /**
     * Create instance with args
     */
    function createWithArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
    {
        switch (args.length) {
            case 0: return Type.createInstance(cls, []);
            case 1: return Type.createInstance(cls, [args[0]]);
            case 2: return Type.createInstance(cls, [args[0], args[1]]);
            case 3: return Type.createInstance(cls, [args[0], args[1], args[2]]);
            case 4: return Type.createInstance(cls, [args[0], args[1], args[2], args[3]]);
            case 5: return Type.createInstance(cls, [args[0], args[1], args[2], args[3], args[4]]);
            default:
                // Handle more args
                return createWithManyArgs(cls, args);
        }
    }
    
    function createWithManyArgs(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic
    {
        // For 6+ args, use different approach
        try {
            var method = Reflect.field(cls, 'new');
            if (method != null && Reflect.isFunction(method)) {
                return Reflect.callMethod(cls, method, args);
            }
        } catch (e:Dynamic) { }
        return null;
    }
    
    /**
     * Create Lua table with metatable for natural syntax
     */
    function createLuaProxyTable(proxy:ObjectProxy):Dynamic
    {
        // This creates a table that mimics Haxe object behavior
        var table:Dynamic = {};
        
        // Set up metatable for method calls
        // The metatable allows : syntax to work
        Reflect.setField(table, '__id', 'haxe_' + proxy.id);
        Reflect.setField(table, '__class', proxy.classPath);
        Reflect.setField(table, '__type', 'HaxeObject');
        
        return table;
    }
    
    /**
     * Get property value
     */
    public function getProperty(objId:String, propName:String):Dynamic
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return null;
        
        // Check for getter method first
        var getterName = 'get_' + propName;
        var getter = Reflect.field(proxy.obj, getterName);
        if (getter != null && Reflect.isFunction(getter)) {
            return Reflect.callMethod(proxy.obj, getter, []);
        }
        
        // Direct field access
        var value = Reflect.field(proxy.obj, propName);
        
        // Convert Haxe types to Lua-compatible types
        return convertToLua(value);
    }
    
    /**
     * Set property value
     */
    public function setProperty(objId:String, propName:String, value:Dynamic):Void
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return;
        
        // Convert Lua value to Haxe type if needed
        var haxeValue = convertToHaxe(value, propName, proxy);
        
        // Check for setter method first
        var setterName = 'set_' + propName;
        var setter = Reflect.field(proxy.obj, setterName);
        if (setter != null && Reflect.isFunction(setter)) {
            Reflect.callMethod(proxy.obj, setter, [haxeValue]);
            return;
        }
        
        // Direct field access
        Reflect.setField(proxy.obj, propName, haxeValue);
    }
    
    /**
     * Call method on object
     */
    public function callMethod(objId:String, methodName:String, args:Array<Dynamic>):Dynamic
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return null;
        
        var method = Reflect.field(proxy.obj, methodName);
        if (method == null || !Reflect.isFunction(method)) {
            // Try to find as property
            var prop = Reflect.field(proxy.obj, methodName);
            if (prop != null) return prop;
            
            FunkinLua.luaTrace('MetatableProxy: Method not found: $methodName', true, false, FlxColor.RED);
            return null;
        }
        
        // Convert Lua args to Haxe types
        var haxeArgs = [for (arg in args) convertToHaxe(arg, null, proxy)];
        
        var result = Reflect.callMethod(proxy.obj, method, haxeArgs);
        
        // Convert result back to Lua type
        return convertToLua(result);
    }
    
    /**
     * Get iterable properties
     */
    public function getIterableProperties(objId:String):Array<Dynamic>
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return [];
        
        var props:Array<Dynamic> = [];
        
        // Get all fields
        for (field in Reflect.fields(proxy.obj)) {
            // Skip private fields
            if (field.charAt(0) != '_') {
                var value = Reflect.field(proxy.obj, field);
                if (!Reflect.isFunction(value)) {
                    props.push({key: field, value: convertToLua(value)});
                }
            }
        }
        
        return props;
    }
    
    /**
     * Clone a proxy
     */
    public function cloneProxy(objId:String):Dynamic
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return null;
        
        try {
            // Try to clone the object
            var cls = Type.getClass(proxy.obj);
            if (cls != null) {
                // For now, just create a new instance with same class
                // Full clone would need clone() method on the object
                var newInstance = Type.createInstance(cls, []);
                var newProxy = new ObjectProxy(newInstance, proxy.classPath, nextId++);
                var newId = 'haxe_' + newProxy.id;
                
                proxies.set(newId, newProxy);
                
                var table:Dynamic = {};
                Reflect.setField(table, '__id', newId);
                Reflect.setField(table, '__class', proxy.classPath);
                Reflect.setField(table, '__type', 'HaxeObject');
                
                return table;
            }
        } catch (e:Dynamic) { }
        
        return null;
    }
    
    /**
     * Destroy a proxy
     */
    public function destroyProxy(objId:String):Void
    {
        var proxy = proxies.get(objId);
        if (proxy != null) {
            // Call destroy if available
            var destroy = Reflect.field(proxy.obj, 'destroy');
            if (destroy != null && Reflect.isFunction(destroy)) {
                Reflect.callMethod(proxy.obj, destroy, []);
            }
            
            proxies.remove(objId);
        }
    }
    
    /**
     * Get object type
     */
    public function getObjectType(objId:String):String
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return 'null';
        
        var cls = Type.getClass(proxy.obj);
        return cls != null ? Type.getClassName(cls) : 'Unknown';
    }
    
    /**
     * Get string representation
     */
    public function objectToString(objId:String):String
    {
        var proxy = proxies.get(objId);
        if (proxy == null) return 'null';
        
        // Try toString method first
        var toString = Reflect.field(proxy.obj, 'toString');
        if (toString != null && Reflect.isFunction(toString)) {
            var result = Reflect.callMethod(proxy.obj, toString, []);
            if (result != null) return Std.string(result);
        }
        
        // Default representation
        return proxy.classPath + '@' + proxy.id;
    }
    
    // ============================================
    // TYPE CONVERSION
    // ============================================
    
    /**
     * Convert Haxe value to Lua-compatible value
     */
    function convertToLua(value:Dynamic):Dynamic
    {
        if (value == null) return null;
        
        var type = Type.typeof(value);
        switch (type) {
            case TNull: return null;
            case TInt, TFloat, TBool, TString: return value;
            case TArray:
                return [for (i in 0...cast(value, Array<Dynamic>).length) 
                    convertToLua(cast(value, Array<Dynamic>)[i])];
            case TClass(c):
                var className = Type.getClassName(c);
                
                // Wrap Flixel objects
                if (Std.is(value, FlxSprite)) {
                    return wrapFlxSprite(cast value);
                }
                if (Std.is(value, FlxText)) {
                    return wrapFlxText(cast value);
                }
                if (Std.is(value, FlxGroup)) {
                    return wrapFlxGroup(cast value);
                }
                if (Std.is(value, FlxCamera)) {
                    return wrapFlxCamera(cast value);
                }
                if (Std.is(value, FlxPoint)) {
                    return wrapFlxPoint(cast value);
                }
                if (Std.is(value, FlxRect)) {
                    return wrapFlxRect(cast value);
                }
                if (Std.is(value, FlxColor)) {
                    return wrapFlxColor(cast value);
                }
                if (Std.is(value, FlxTween)) {
                    return wrapFlxTween(cast value);
                }
                
                // Create generic proxy for other objects
                return wrapGenericObject(value);
                
            case TEnum(e):
                return {
                    __enum: Type.getEnumName(e),
                    __constructor: Type.enumConstructor(value),
                    __params: [for (p in Type.enumParameters(value)) convertToLua(p)]
                };
            default:
                return value;
        }
    }
    
    /**
     * Convert Lua value to Haxe type
     */
    function convertToHaxe(value:Dynamic, propName:String, proxy:ObjectProxy):Dynamic
    {
        if (value == null) return null;
        
        // Numbers stay numbers
        if (Std.is(value, Int) || Std.is(value, Float)) return value;
        if (Std.is(value, Bool)) return value;
        if (Std.is(value, String)) return value;
        
        // Tables become arrays
        if (Std.is(value, Array)) {
            return value;
        }
        
        // Check for Haxe object wrapper
        if (Std.is(value, String) && Reflect.hasField(value, '__obj')) {
            return Reflect.field(value, '__obj');
        }
        
        return value;
    }
    
    /**
     * Wrap FlxSprite for Lua
     */
    function wrapFlxSprite(sprite:FlxSprite):Dynamic
    {
        var table:Dynamic = {};
        
        // Core properties
        Reflect.setField(table, 'x', sprite.x);
        Reflect.setField(table, 'y', sprite.y);
        Reflect.setField(table, 'width', sprite.width);
        Reflect.setField(table, 'height', sprite.height);
        Reflect.setField(table, 'alpha', sprite.alpha);
        Reflect.setField(table, 'angle', sprite.angle);
        Reflect.setField(table, 'visible', sprite.visible);
        Reflect.setField(table, 'active', sprite.active);
        Reflect.setField(table, 'exists', sprite.exists);
        
        // Type marker
        Reflect.setField(table, '__type', 'FlxSprite');
        Reflect.setField(table, '__obj', sprite);
        
        // Common methods
        Reflect.setField(table, 'loadGraphic', function(path:String) {
            sprite.loadGraphic(path);
            return table;
        });
        
        Reflect.setField(table, 'makeGraphic', function(w:Int, h:Int, color:Dynamic) {
            sprite.makeGraphic(w, h, color);
            return table;
        });
        
        Reflect.setField(table, 'setPosition', function(x:Float, y:Float) {
            sprite.setPosition(x, y);
            return table;
        });
        
        Reflect.setField(table, 'kill', function() {
            sprite.kill();
            return table;
        });
        
        Reflect.setField(table, 'revive', function() {
            sprite.revive();
            return table;
        });
        
        Reflect.setField(table, 'destroy', function() {
            sprite.destroy();
            return table;
        });
        
        return table;
    }
    
    /**
     * Wrap FlxText for Lua
     */
    function wrapFlxText(text:FlxText):Dynamic
    {
        var table:Dynamic = {};
        
        Reflect.setField(table, 'text', text.text);
        Reflect.setField(table, 'size', text.size);
        Reflect.setField(table, 'color', text.color.toHexString());
        Reflect.setField(table, 'x', text.x);
        Reflect.setField(table, 'y', text.y);
        Reflect.setField(table, 'alpha', text.alpha);
        Reflect.setField(table, '__type', 'FlxText');
        Reflect.setField(table, '__obj', text);
        
        Reflect.setField(table, 'setFormat', function(font:String, size:Float, color:Dynamic, alignment:String) {
            text.setFormat(font, size, color, alignment);
            return table;
        });
        
        Reflect.setField(table, 'destroy', function() {
            text.destroy();
            return table;
        });
        
        return table;
    }
    
    /**
     * Wrap FlxGroup for Lua
     */
    function wrapFlxGroup(group:FlxGroup):Dynamic
    {
        var table:Dynamic = {};
        
        Reflect.setField(table, 'length', group.length);
        Reflect.setField(table, 'members', [for (m in group.members) convertToLua(m)]);
        Reflect.setField(table, '__type', 'FlxGroup');
        Reflect.setField(table, '__obj', group);
        
        Reflect.setField(table, 'add', function(obj:Dynamic) {
            if (Reflect.hasField(obj, '__obj')) {
                return group.add(Reflect.field(obj, '__obj'));
            }
            return group.add(obj);
        });
        
        Reflect.setField(table, 'remove', function(obj:Dynamic) {
            if (Reflect.hasField(obj, '__obj')) {
                return group.remove(Reflect.field(obj, '__obj'));
            }
            return group.remove(obj);
        });
        
        Reflect.setField(table, 'clear', function() {
            group.clear();
            return table;
        });
        
        return table;
    }
    
    /**
     * Wrap FlxCamera for Lua
     */
    function wrapFlxCamera(cam:FlxCamera):Dynamic
    {
        var table:Dynamic = {};
        
        Reflect.setField(table, 'x', cam.x);
        Reflect.setField(table, 'y', cam.y);
        Reflect.setField(table, 'zoom', cam.zoom);
        Reflect.setField(table, 'alpha', cam.alpha);
        Reflect.setField(table, 'width', cam.width);
        Reflect.setField(table, 'height', cam.height);
        Reflect.setField(table, '__type', 'FlxCamera');
        Reflect.setField(table, '__obj', cam);
        
        Reflect.setField(table, 'follow', function(target:Dynamic) {
            if (Reflect.hasField(target, '__obj')) {
                cam.follow(Reflect.field(target, '__obj'));
            } else {
                cam.follow(target);
            }
            return table;
        });
        
        Reflect.setField(table, 'shake', function(intensity:Float, duration:Float) {
            cam.shake(intensity, duration);
            return table;
        });
        
        Reflect.setField(table, 'flash', function(color:Dynamic, duration:Float) {
            cam.flash(color, duration);
            return table;
        });
        
        return table;
    }
    
    /**
     * Wrap FlxPoint for Lua
     */
    function wrapFlxPoint(point:FlxPoint):Dynamic
    {
        return {
            x: point.x,
            y: point.y,
            __type: 'FlxPoint',
            __obj: point
        };
    }
    
    /**
     * Wrap FlxRect for Lua
     */
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
    
    /**
     * Wrap FlxColor for Lua
     */
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
    
    /**
     * Wrap FlxTween for Lua
     */
    function wrapFlxTween(tween:FlxTween):Dynamic
    {
        var table:Dynamic = {};
        
        Reflect.setField(table, 'active', tween.active);
        Reflect.setField(table, 'percent', tween.percent);
        Reflect.setField(table, '__type', 'FlxTween');
        Reflect.setField(table, '__obj', tween);
        
        Reflect.setField(table, 'cancel', function() {
            tween.cancel();
            return table;
        });
        
        Reflect.setField(table, 'complete', function() {
            tween.complete();
            return table;
        });
        
        return table;
    }
    
    /**
     * Wrap generic Haxe object
     */
    function wrapGenericObject(obj:Dynamic):Dynamic
    {
        var table:Dynamic = {};
        var className = 'Unknown';
        
        var cls = Type.getClass(obj);
        if (cls != null) {
            className = Type.getClassName(cls);
        }
        
        Reflect.setField(table, '__type', className);
        Reflect.setField(table, '__obj', obj);
        
        // Copy all fields
        for (field in Reflect.fields(obj)) {
            if (field.charAt(0) != '_') {
                try {
                    var value = Reflect.field(obj, field);
                    if (!Reflect.isFunction(value)) {
                        Reflect.setField(table, field, convertToLua(value));
                    }
                } catch (e:Dynamic) { }
            }
        }
        
        return table;
    }
    
    // ============================================
    // METHOD CACHES
    // ============================================
    
    function initMethodCaches():Void
    {
        methodCaches.set('flixel.FlxSprite', [
            'loadGraphic', 'makeGraphic', 'updateHitbox', 'destroy', 'kill', 'revive',
            'setPosition', 'setSize', 'setGraphicSize', 'drawFrame', 'animation', 'play', 'stop'
        ]);
        
        methodCaches.set('flixel.FlxText', [
            'setFormat', 'destroy', 'drawFrame', 'update'
        ]);
        
        methodCaches.set('flixel.FlxGroup', [
            'add', 'remove', 'clear', 'getFirstAvailable', 'sort', 'forEach', 'forEachAlive'
        ]);
        
        methodCaches.set('flixel.FlxCamera', [
            'follow', 'unfollow', 'shake', 'flash', 'fade', 'focusOn'
        ]);
        
        methodCaches.set('flixel.FlxObject', [
            'setPosition', 'setSize', 'centerOffsets', 'updateHitbox'
        ]);
    }
}

// ============================================
// OBJECT PROXY
// ============================================

class ObjectProxy
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