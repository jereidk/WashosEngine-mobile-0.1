package psychlua;

#if LUA_ALLOWED
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
import sys.FileSystem;
import sys.io.File;

/**
 * Extended Lua Functions - Advanced scripting capabilities for WashosEngine
 * 
 * These functions provide additional utilities for modders that complement
 * the LuaBridge system. They focus on object manipulation, tweens, and utilities.
 */
class ExtendedLuaFunctions
{
    public static function implement(funk:FunkinLua):Void
    {
        var lua:State = funk.lua;
        
        // === OBJECT FACTORY ===
        // Create and manage game objects (uses LuaBridge.create internally)
        Lua_helper.add_callback(lua, "makeSprite", function(name:String, graphic:String, ?x:Float = 0, ?y:Float = 0) {
            var spr:FlxSprite = new FlxSprite(x, y);
            spr.loadGraphic(graphic);
            funk.setVar(name, spr);
            return spr;
        });
        
        Lua_helper.add_callback(lua, "makeAnimatedSprite", function(name:String, graphic:String, ?x:Float = 0, ?y:Float = 0, ?width:Int = 0, ?height:Int = 0, ?imageArrays:Array<Int> = null) {
            var spr:FlxSprite = new FlxSprite(x, y);
            if (imageArrays != null && imageArrays.length > 0) {
                spr.loadGraphic(graphic, true, width, height);
                spr.animation.add('idle', imageArrays, 12, true);
                spr.animation.play('idle');
            } else {
                spr.loadGraphic(graphic);
            }
            funk.setVar(name, spr);
            return spr;
        });
        
        Lua_helper.add_callback(lua, "getSprite", function(name:String):Dynamic {
            return funk.getVar(name);
        });
        
        Lua_helper.add_callback(lua, "removeSprite", function(name:String) {
            var obj:Dynamic = funk.getVar(name);
            if (obj != null && Std.is(obj, FlxBasic)) {
                obj.destroy();
            }
            funk.setVar(name, null);
        });
        
        // === ADVANCED TWEENING ===
        Lua_helper.add_callback(lua, "tweenSprite", function(objName:String, props:Dynamic, duration:Float, ?ease:String = 'linear', ?onComplete:Void->Void = null) {
            var obj:Dynamic = funk.getVar(objName);
            if (obj == null || !Std.is(obj, FlxSprite)) return;
            
            var propsMap:Map<String, Dynamic> = new Map();
            for (field in Reflect.fields(props)) {
                propsMap.set(field, Reflect.field(props, field));
            }
            
            var tween:FlxTween = FlxTween.tween(cast(obj, FlxSprite), propsMap, duration, {
                ease: getEaseFunction(ease),
                onComplete: function(_) {
                    if (onComplete != null) onComplete();
                }
            });
            
            return tween;
        });
        
        Lua_helper.add_callback(lua, "tweenCameraShake", function(intensity:Float, duration:Float, ?onComplete:Void->Void = null) {
            var cam:FlxCamera = FlxG.camera;
            var tween:FlxTween = FlxTween.tween(cam, {shake: intensity}, duration, {
                onComplete: function(_) {
                    cam.shake(0, 0);
                    if (onComplete != null) onComplete();
                }
            });
            cam.shake(intensity, duration);
            return tween;
        });
        
        Lua_helper.add_callback(lua, "tweenProperty", function(objName:String, propName:String, targetValue:Float, duration:Float, ?ease:String = 'linear', ?onUpdate:Float->Void = null, ?onComplete:Void->Void = null) {
            var obj:Dynamic = funk.getVar(objName);
            if (obj == null) return;
            
            var startValue:Float = 0;
            var getter:Dynamic = Reflect.field(obj, 'get_' + propName);
            if (getter != null && Reflect.isFunction(getter)) {
                startValue = Reflect.callMethod(obj, getter, []);
            } else {
                startValue = Reflect.field(obj, propName);
            }
            
            var tween:FlxTween = FlxTween.tween(obj, {propName: targetValue}, duration, {
                ease: getEaseFunction(ease),
                onUpdate: function(twn:FlxTween) {
                    if (onUpdate != null) {
                        var progress:Float = twn.percent;
                        onUpdate(startValue + (targetValue - startValue) * progress);
                    }
                },
                onComplete: function(_) {
                    if (onComplete != null) onComplete();
                }
            });
            
            return tween;
        });
        
        // === EVENT SYSTEM ===
        Lua_helper.add_callback(lua, "registerCallback", function(name:String, callback:Dynamic):Void {
            FunkinLua.customFunctions.set(name, callback);
        });
        
        Lua_helper.add_callback(lua, "fireCallback", function(name:String, ?args:Array<Dynamic> = null):Dynamic {
            var callback:Dynamic = FunkinLua.customFunctions.get(name);
            if (callback == null) return null;
            if (args == null) args = [];
            return Reflect.callMethod(callback, callback, args);
        });
        
        Lua_helper.add_callback(lua, "unregisterCallback", function(name:String):Void {
            FunkinLua.customFunctions.remove(name);
        });
        
        // === ARRAY/TABLE OPERATIONS ===
        Lua_helper.add_callback(lua, "arrayMap", function(tbl:Array<Dynamic>, func:Dynamic):Array<Dynamic> {
            var result:Array<Dynamic> = [];
            for (item in tbl) {
                result.push(Reflect.callMethod(func, func, [item]));
            }
            return result;
        });
        
        Lua_helper.add_callback(lua, "arrayFilter", function(tbl:Array<Dynamic>, func:Dynamic):Array<Dynamic> {
            var result:Array<Dynamic> = [];
            for (item in tbl) {
                if (Reflect.callMethod(func, func, [item]) == true) {
                    result.push(item);
                }
            }
            return result;
        });
        
        Lua_helper.add_callback(lua, "arrayReduce", function(tbl:Array<Dynamic>, func:Dynamic, initial:Dynamic):Dynamic {
            var accumulator:Dynamic = initial;
            for (item in tbl) {
                accumulator = Reflect.callMethod(func, func, [accumulator, item]);
            }
            return accumulator;
        });
        
        Lua_helper.add_callback(lua, "arrayFind", function(tbl:Array<Dynamic>, func:Dynamic):Dynamic {
            for (item in tbl) {
                if (Reflect.callMethod(func, func, [item]) == true) {
                    return item;
                }
            }
            return null;
        });
        
        Lua_helper.add_callback(lua, "arrayContains", function(tbl:Array<Dynamic>, value:Dynamic):Bool {
            return Lambda.has(tbl, value);
        });
        
        Lua_helper.add_callback(lua, "arrayClone", function(tbl:Array<Dynamic>):Array<Dynamic> {
            return tbl.copy();
        });
        
        Lua_helper.add_callback(lua, "arrayMerge", function(...tables:Array<Dynamic>):Array<Dynamic> {
            var result:Array<Dynamic> = [];
            for (tbl in tables) {
                if (Std.is(tbl, Array)) {
                    for (item in cast(tbl, Array<Dynamic>)) {
                        result.push(item);
                    }
                }
            }
            return result;
        });
        
        // === TYPE CHECKING ===
        Lua_helper.add_callback(lua, "isSprite", function(obj:Dynamic):Bool {
            return Std.is(obj, FlxSprite);
        });
        
        Lua_helper.add_callback(lua, "isText", function(obj:Dynamic):Bool {
            return Std.is(obj, FlxText);
        });
        
        Lua_helper.add_callback(lua, "isGroup", function(obj:Dynamic):Bool {
            return Std.is(obj, FlxGroup);
        });
        
        Lua_helper.add_callback(lua, "isCamera", function(obj:Dynamic):Bool {
            return Std.is(obj, FlxCamera);
        });
        
        Lua_helper.add_callback(lua, "isTween", function(obj:Dynamic):Bool {
            return Std.is(obj, FlxTween);
        });
        
        Lua_helper.add_callback(lua, "isString", function(obj:Dynamic):Bool {
            return Std.is(obj, String);
        });
        
        Lua_helper.add_callback(lua, "isNumber", function(obj:Dynamic):Bool {
            return Std.is(obj, Int) || Std.is(obj, Float);
        });
        
        Lua_helper.add_callback(lua, "isArray", function(obj:Dynamic):Bool {
            return Std.is(obj, Array);
        });
        
        Lua_helper.add_callback(lua, "isFunction", function(obj:Dynamic):Bool {
            return Reflect.isFunction(obj);
        });
        
        Lua_helper.add_callback(lua, "getTypeName", function(obj:Dynamic):String {
            if (obj == null) return 'nil';
            if (Std.is(obj, Bool)) return 'boolean';
            if (Std.is(obj, Int) || Std.is(obj, Float)) return 'number';
            if (Std.is(obj, String)) return 'string';
            if (Std.is(obj, Array)) return 'array';
            if (Reflect.isFunction(obj)) return 'function';
            if (Std.is(obj, FlxSprite)) return 'FlxSprite';
            if (Std.is(obj, FlxText)) return 'FlxText';
            if (Std.is(obj, FlxGroup)) return 'FlxGroup';
            if (Std.is(obj, FlxCamera)) return 'FlxCamera';
            if (Std.is(obj, FlxTween)) return 'FlxTween';
            return 'unknown';
        });
        
        // === UTILITY FUNCTIONS ===
        Lua_helper.add_callback(lua, "lerp", function(a:Float, b:Float, t:Float):Float {
            return a + (b - a) * t;
        });
        
        Lua_helper.add_callback(lua, "clampValue", function(value:Float, min:Float, max:Float):Float {
            return Math.max(min, Math.min(max, value));
        });
        
        Lua_helper.add_callback(lua, "randomFloat", function(min:Float, max:Float):Float {
            return Math.random() * (max - min) + min;
        });
        
        Lua_helper.add_callback(lua, "randomInt", function(min:Int, max:Int):Int {
            return Std.int(Math.random() * (max - min + 1)) + min;
        });
        
        Lua_helper.add_callback(lua, "randomPick", function(arr:Array<Dynamic>):Dynamic {
            return arr[Std.int(Math.random() * arr.length)];
        });
        
        Lua_helper.add_callback(lua, "shuffleArray", function(arr:Array<Dynamic>):Array<Dynamic> {
            var result = arr.copy();
            for (i in 0...result.length) {
                var j = Std.int(Math.random() * result.length);
                var temp = result[i];
                result[i] = result[j];
                result[j] = temp;
            }
            return result;
        });
        
        Lua_helper.add_callback(lua, "distance2D", function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
            return Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
        });
        
        Lua_helper.add_callback(lua, "angle2D", function(x1:Float, y1:Float, x2:Float, y2:Float):Float {
            return Math.atan2(y2 - y1, x2 - x1) * (180 / Math.PI);
        });
        
        Lua_helper.add_callback(lua, "roundTo", function(value:Float, ?decimals:Int = 0):Float {
            var mult = Math.pow(10, decimals);
            return Math.round(value * mult) / mult;
        });
        
        Lua_helper.add_callback(lua, "formatTime", function(seconds:Float):String {
            var mins = Std.int(seconds / 60);
            var secs = Std.int(seconds % 60);
            var ms = Std.int((seconds % 1) * 100);
            return StringTools.lpad(Std.string(mins), '0', 2) + ':' + 
                   StringTools.lpad(Std.string(secs), '0', 2) + '.' + 
                   StringTools.lpad(Std.string(ms), '0', 2);
        });
        
        // === FILE OPERATIONS ===
        Lua_helper.add_callback(lua, "fileExists", function(path:String):Bool {
            return FileSystem.exists(path);
        });
        
        Lua_helper.add_callback(lua, "readTextFile", function(path:String):String {
            try {
                return File.getContent(path);
            } catch (e:Dynamic) {
                return null;
            }
        });
        
        Lua_helper.add_callback(lua, "writeTextFile", function(path:String, content:String):Bool {
            try {
                File.saveContent(path, content);
                return true;
            } catch (e:Dynamic) {
                return false;
            }
        });
        
        Lua_helper.add_callback(lua, "appendTextFile", function(path:String, content:String):Bool {
            try {
                File.saveContent(path, File.getContent(path) + content);
                return true;
            } catch (e:Dynamic) {
                return false;
            }
        });
        
        Lua_helper.add_callback(lua, "listDirectory", function(dir:String):Array<String> {
            try {
                if (!FileSystem.exists(dir)) return [];
                return FileSystem.readDirectory(dir);
            } catch (e:Dynamic) {
                return [];
            }
        });
        
        Lua_helper.add_callback(lua, "isDir", function(path:String):Bool {
            try {
                return FileSystem.isDirectory(path);
            } catch (e:Dynamic) {
                return false;
            }
        });
        
        // === DEBUG ===
        Lua_helper.add_callback(lua, "inspectValue", function(obj:Dynamic, ?depth:Int = 0):Dynamic {
            return inspectObject(obj, depth);
        });
        
        Lua_helper.add_callback(lua, "debugAllVars", function():Void {
            var vars = funk.getLocalVariables();
            for (key in vars.keys()) {
                FunkinLua.luaTrace('$key = ${vars.get(key)}', false, false, FlxColor.CYAN);
            }
        });
        
        Lua_helper.add_callback(lua, "printTable", function(obj:Dynamic):String {
            return inspectObject(obj, 0);
        });
    }
    
    // === HELPER FUNCTIONS ===
    
    static function getEaseFunction(easeName:String):FlxEase.EaseFunction
    {
        var ease:Dynamic = Reflect.field(FlxEase, easeName);
        if (ease != null && Reflect.isFunction(ease)) {
            return ease;
        }
        return FlxEase.linear;
    }
    
    static function inspectObject(obj:Dynamic, ?depth:Int = 0):Dynamic
    {
        if (depth == null) depth = 0;
        if (depth > 5) return '...';
        
        if (obj == null) return 'null';
        if (Std.is(obj, String) || Std.is(obj, Int) || Std.is(obj, Float) || Std.is(obj, Bool)) return obj;
        
        if (Std.is(obj, Array)) {
            var result:Array<Dynamic> = [];
            for (i in 0...cast(obj, Array<Dynamic>).length) {
                result.push(inspectObject(cast(obj, Array<Dynamic>)[i], depth + 1));
            }
            return result;
        }
        
        if (Std.is(obj, haxe.ds.StringMap)) {
            var result:Dynamic = {};
            for (key in cast(obj, haxe.ds.StringMap).keys()) {
                Reflect.setField(result, key, inspectObject(cast(obj, haxe.ds.StringMap).get(key), depth + 1));
            }
            return result;
        }
        
        var result:Dynamic = {};
        var fields:Array<String> = [];
        
        try {
            fields = Reflect.fields(obj);
        } catch (e:Dynamic) { }
        
        for (field in fields) {
            if (field.charAt(0) != '_') {
                try {
                    var value = Reflect.field(obj, field);
                    if (!Reflect.isFunction(value)) {
                        Reflect.setField(result, field, inspectObject(value, depth + 1));
                    }
                } catch (e:Dynamic) { }
            }
        }
        
        return result;
    }
}
#end