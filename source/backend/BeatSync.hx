package backend;

import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxPoint;

/**
 * BeatSync - Sistema de animaciones sincronizadas con el beat
 * 
 * Permite crear efectos visuales que se sincronizan automáticamente
 * con el beat de la música, sin necesidad de cálculos manuales.
 * 
 * Características:
 * - Beat callbacks automáticos
 * - Tweens sincronizados con beat
 * - Beat-based animations
 * - Camera shake sincronizado
 * - Flash/alpha effects
 * 
 * Uso:
 * ```haxe
 * // Crear sincronizador
 * var beatSync = new BeatSync();
 * beatSync.beatCallback = myBeatFunction;
 * 
 * // Tween que sigue el beat
 * beatSync.beatTween(sprite, 'scale', 1.2, 0.5);
 * 
 * // Camera shake en beat
 * beatSync.beatCameraShake(0.5, 0.1);
 * ```
 */

typedef BeatTweenOptions = {
    ?interval:Int,        // Cada cuántos beats se repite
    ?beatOffset:Int,      // Offset del primer trigger
    ?ease:Dynamic,        // Función de easing
    ?pingPong:Bool,      // Si hace ping-pong
    ?onComplete:Void->Void // Callback al completar
}

typedef BeatTweenData = {
var sprite:FlxSprite;
var property:String;
var targetValue:Float;
var durationBeats:Float;
var durationSeconds:Float;
var interval:Int;
var beatOffset:Int;
var ease:Dynamic;
var isPingPong:Bool;
var isActive:Bool;
}

class BeatSync
{
    // ============================================
    // CALLBACKS
    // ============================================
    
    /** Callback al llegar a un beat */
    public var beatCallback:Float->Void = null;
    
    /** Callback al llegar a un step */
    public var stepCallback:Float->Void = null;
    
    /** Callback al llegar a un measure (4 beats) */
    public var measureCallback:Float->Void = null;
    
    /** Callback cada beat con el sprite a modificar */
    public var beatTweenCallback:FlxSprite->Float->Void = null;
    
    // ============================================
    // CONFIGURACIÓN
    // ============================================
    
    /** BPM de la canción */
    public var bpm:Float = 120;
    
    /** Crochet (duración de un beat en segundos) */
    public var crochet(get, never):Float;
    private inline function get_crochet():Float return 60 / bpm;
    
    /** Step crochet (duración de un step, 1/4 de beat) */
    public var stepCrochet(get, never):Float;
    private inline function get_stepCrochet():Float return crochet / 4;
    
    /** Conteo de beats */
    public var beatCount:Int = 0;
    public var stepCount:Int = 0;
    public var measureCount:Int = 0;
    
    /** Tiempo actual */
    public var currentTime:Float = 0;
    
    /** Beat actual (puede ser decimal) */
    public var currentBeat:Float = 0;
    
    // ============================================
    // TWEEN MANAGER
    // ============================================
    
    private var beatTweens:Array<BeatTweenData> = [];
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new(?Bpm:Float = 120)
    {
        bpm = Bpm;
    }
    
    // ============================================
    // UPDATE
    // ============================================
    
    /**
     * Update - debe llamarse cada frame con el tiempo actual
     */
    public function update(elapsed:Float):Void
    {
        currentTime += elapsed;
        currentBeat = currentTime / crochet;
        
    var newBeat = Math.floor(currentBeat);
    var newStep = Math.floor(currentTime / stepCrochet);
    var newMeasure = Math.floor(newBeat / 4);
        
        // Check beat
        if (newBeat > beatCount) {
        var missedBeats = newBeat - beatCount;
            for (i in 0...missedBeats) {
                onBeat(beatCount + i + 1);
            }
            beatCount = newBeat;
        }
        
        // Check step
        if (newStep > stepCount) {
        var missedSteps = newStep - stepCount;
            for (i in 0...missedSteps) {
                onStep(stepCount + i + 1);
            }
            stepCount = newStep;
        }
        
        // Check measure
        if (newMeasure > measureCount) {
            measureCount = newMeasure;
            if (measureCallback != null) {
                measureCallback(measureCount);
            }
        }
        
        // Process beat tweens
        processBeatTweens();
    }
    
    /**
     * Evento de beat
     */
    private function onBeat(beat:Int):Void
    {
        if (beatCallback != null) {
            beatCallback(beat);
        }
        
        // Process beat-based tweens
        for (tween in beatTweens) {
            if (tween.beatOffset == beat % tween.interval) {
                triggerBeatTween(tween);
            }
        }
    }
    
    /**
     * Evento de step
     */
    private function onStep(step:Int):Void
    {
        if (stepCallback != null) {
            stepCallback(step);
        }
    }
    
    // ============================================
    // TWEEN FUNCTIONS
    // ============================================
    
    /**
     * Crear un tween que se repite cada X beats
     */
    public function beatTween(
        sprite:FlxSprite,
        property:String,
        targetValue:Float,
        durationBeats:Float,
        ?options:BeatTweenOptions = null
    ):BeatTweenHandle
    {
        if (options == null) options = {};
        
    var tweenData:BeatTweenData = {
            sprite: sprite,
            property: property,
            targetValue: targetValue,
            durationBeats: durationBeats,
            durationSeconds: durationBeats * crochet,
            interval: options.interval ?? 4,
            beatOffset: options.beatOffset ?? 0,
            ease: options.ease ?? FlxEase.linear,
            isPingPong: options.pingPong ?? false,
            isActive: true
        };
        
        beatTweens.push(tweenData);
        
        return new BeatTweenHandle(tweenData, this);
    }
    
    /**
     * Trigger un beat tween
     */
    private function triggerBeatTween(tween:BeatTweenData):Void
    {
        if (!tween.isActive || tween.sprite == null) return;
        
        // Get current value
    var currentValue = getPropertyValue(tween.sprite, tween.property);
        
        // Tween de vuelta al original
        tween.sprite.tween(
            tween.sprite,
            {tween.property: tween.targetValue},
            tween.durationSeconds,
            {ease: tween.ease, type: FlxTweenType.ONESHOT}
        );
        
        // Callback
        if (beatTweenCallback != null) {
            beatTweenCallback(tween.sprite, tween.targetValue);
        }
    }
    
    /**
     * Procesar beat tweens activos
     */
    private function processBeatTweens():Void
    {
        // Limpiar tweens inactivos
        beatTweens = beatTweens.filter(t -> t.isActive && t.sprite != null && t.sprite.exists);
    }
    
    // ============================================
    // UTILITY FUNCTIONS
    // ============================================
    
    /**
     * Obtener valor de propiedad de un sprite
     */
    private function getPropertyValue(sprite:FlxSprite, property:String):Float
    {
        switch (property) {
            case 'x': return sprite.x;
            case 'y': return sprite.y;
            case 'scale.x', 'scaleX': return sprite.scale.x;
            case 'scale.y', 'scaleY': return sprite.scale.y;
            case 'alpha': return sprite.alpha;
            case 'angle': return sprite.angle;
            case 'offset.x', 'offsetX': return sprite.offset.x;
            case 'offset.y', 'offsetY': return sprite.offset.y;
            case 'origin.x', 'originX': return sprite.origin.x;
            case 'origin.y', 'originY': return sprite.origin.y;
            default: return 0;
        }
    }
    
    /**
     * Resetear contadores
     */
    public function reset():Void
    {
        currentTime = 0;
        currentBeat = 0;
        beatCount = 0;
        stepCount = 0;
        measureCount = 0;
    }
    
    /**
     * Set BPM y recalcular
     */
    public function setBpm(newBpm:Float):Void
    {
        bpm = newBpm;
    }
    
    /**
     * Saltar a un beat específico
     */
    public function seekTo(beat:Float):Void
    {
        currentTime = beat * crochet;
        currentBeat = beat;
        beatCount = Math.floor(beat);
    }
    
    /**
     * Saltar a un tiempo específico
     */
    public function seekToTime(time:Float):Void
    {
        currentTime = time;
        currentBeat = time / crochet;
        beatCount = Math.floor(currentBeat);
        stepCount = Math.floor(time / stepCrochet);
    }
    
    /**
     * Obtener beat actual con decimal
     */
    public function getCurrentBeat():Float
    {
        return currentTime / crochet;
    }
    
    /**
     * Verificar si estamos en un beat específico
     */
    public function isOnBeat(beat:Int, ?tolerance:Float = 0.1):Bool
    {
    var current = currentBeat;
    var diff = Math.abs(current - beat);
        return diff <= tolerance || (1 - diff) <= tolerance; // Handles wrapping
    }
    
    /**
     * Verificar si estamos en un beat fuerte (1, 3 de 4/4)
     */
    public function isOnStrongBeat():Bool
    {
        return isOnBeat(Math.floor(currentBeat / 2) * 2 + 1, 0.15);
    }
    
    /**
     * Verificar si estamos en el beat 0 (inicio)
     */
    public function isOnDownbeat():Bool
    {
        return isOnBeat(Math.floor(currentBeat / 4) * 4, 0.15);
    }
    
    // ============================================
    // PRESET ANIMATIONS
    // ============================================
    
    /**
     * Bounce animation (scale up and down)
     */
    public function beatBounce(sprite:FlxSprite, amount:Float = 0.1, ?interval:Int = 1):BeatTweenHandle
    {
    var baseScale = sprite.scale.x;
        return beatTween(sprite, 'scale.x', baseScale * (1 + amount), 0.5, {interval: interval})
            .onUpdate(() -> {
                sprite.scale.y = sprite.scale.x;
            });
    }
    
    /**
     * Shake animation (offset left/right)
     */
    public function beatShake(sprite:FlxSprite, amount:Float = 5, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'offset.x', amount, 0.25, {interval: interval, pingPong: true})
            .onComplete(() -> {
                sprite.offset.x = 0;
            });
    }
    
    /**
     * Pulse animation (scale con ease)
     */
    public function beatPulse(sprite:FlxSprite, maxScale:Float = 1.2, ?interval:Int = 1):BeatTweenHandle
    {
    var baseScale = sprite.scale.x;
        return beatTween(sprite, 'scale.x', maxScale, 0.5, {interval: interval, ease: FlxEase.elasticOut})
            .onUpdate(() -> {
                sprite.scale.y = sprite.scale.x;
            });
    }
    
    /**
     * Flash animation (alpha blink)
     */
    public function beatFlash(sprite:FlxSprite, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'alpha', 0, 0.25, {interval: interval, pingPong: true})
            .onComplete(() -> {
                sprite.alpha = 1;
            });
    }
    
    /**
     * Rotate animation (360 cada X beats)
     */
    public function beatRotate(sprite:FlxSprite, beatsPerRotation:Float = 4, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'angle', 360, beatsPerRotation, {interval: interval});
    }
    
    /**
     * Beat bounce simple (alternating up/down)
     */
class BeatSync
{
    // ============================================
    // CALLBACKS
    // ============================================
    
    /** Callback al llegar a un beat */
    public var beatCallback:Float->Void = null;
    
    /** Callback al llegar a un step */
    public var stepCallback:Float->Void = null;
    
    /** Callback al llegar a un measure (4 beats) */
    public var measureCallback:Float->Void = null;
    
    /** Callback cada beat con el sprite a modificar */
    public var beatTweenCallback:FlxSprite->Float->Void = null;
    
    // ============================================
    // CONFIGURACIÓN
    // ============================================
    
    /** BPM de la canción */
    public var bpm:Float = 120;
    
    /** Crochet (duración de un beat en segundos) */
    public var crochet(get, never):Float;
    private inline function get_crochet():Float return 60 / bpm;
    
    /** Step crochet (duración de un step, 1/4 de beat) */
    public var stepCrochet(get, never):Float;
    private inline function get_stepCrochet():Float return crochet / 4;
    
    /** Conteo de beats */
    public var beatCount:Int = 0;
    public var stepCount:Int = 0;
    public var measureCount:Int = 0;
    
    /** Tiempo actual */
    public var currentTime:Float = 0;
    
    /** Beat actual (puede ser decimal) */
    public var currentBeat:Float = 0;
    
    // ============================================
    // TWEEN MANAGER
    // ============================================
    
    private var beatTweens:Array<BeatTweenData> = [];
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new(?Bpm:Float = 120)
    {
        bpm = Bpm;
    }
    
    // ============================================
    // UPDATE
    // ============================================
    
    /**
     * Update - debe llamarse cada frame con el tiempo actual
     */
    public function update(elapsed:Float):Void
    {
        currentTime += elapsed;
        currentBeat = currentTime / crochet;
        
    var newBeat = Math.floor(currentBeat);
    var newStep = Math.floor(currentTime / stepCrochet);
    var newMeasure = Math.floor(newBeat / 4);
        
        // Check beat
        if (newBeat > beatCount) {
        var missedBeats = newBeat - beatCount;
            for (i in 0...missedBeats) {
                onBeat(beatCount + i + 1);
            }
            beatCount = newBeat;
        }
        
        // Check step
        if (newStep > stepCount) {
        var missedSteps = newStep - stepCount;
            for (i in 0...missedSteps) {
                onStep(stepCount + i + 1);
            }
            stepCount = newStep;
        }
        
        // Check measure
        if (newMeasure > measureCount) {
            measureCount = newMeasure;
            if (measureCallback != null) {
                measureCallback(measureCount);
            }
        }
        
        // Process beat tweens
        processBeatTweens();
    }
    
    /**
     * Evento de beat
     */
    private function onBeat(beat:Int):Void
    {
        if (beatCallback != null) {
            beatCallback(beat);
        }
        
        // Process beat-based tweens
        for (tween in beatTweens) {
            if (tween.beatOffset == beat % tween.interval) {
                triggerBeatTween(tween);
            }
        }
    }
    
    /**
     * Evento de step
     */
    private function onStep(step:Int):Void
    {
        if (stepCallback != null) {
            stepCallback(step);
        }
    }
    
    // ============================================
    // TWEEN FUNCTIONS
    // ============================================
    
    /**
     * Crear un tween que se repite cada X beats
     */
    public function beatTween(
        sprite:FlxSprite,
        property:String,
        targetValue:Float,
        durationBeats:Float,
        ?options:BeatTweenOptions = null
    ):BeatTweenHandle
    {
        if (options == null) options = {};
        
    var tweenData:BeatTweenData = {
            sprite: sprite,
            property: property,
            targetValue: targetValue,
            durationBeats: durationBeats,
            durationSeconds: durationBeats * crochet,
            interval: options.interval ?? 4,
            beatOffset: options.beatOffset ?? 0,
            ease: options.ease ?? FlxEase.linear,
            isPingPong: options.pingPong ?? false,
            isActive: true
        };
        
        beatTweens.push(tweenData);
        
        return new BeatTweenHandle(tweenData, this);
    }
    
    /**
     * Trigger un beat tween
     */
    private function triggerBeatTween(tween:BeatTweenData):Void
    {
        if (!tween.isActive || tween.sprite == null) return;
        
        // Get current value
    var currentValue = getPropertyValue(tween.sprite, tween.property);
        
        // Tween de vuelta al original
        tween.sprite.tween(
            tween.sprite,
            {tween.property: tween.targetValue},
            tween.durationSeconds,
            {ease: tween.ease, type: FlxTweenType.ONESHOT}
        );
        
        // Callback
        if (beatTweenCallback != null) {
            beatTweenCallback(tween.sprite, tween.targetValue);
        }
    }
    
    /**
     * Procesar beat tweens activos
     */
    private function processBeatTweens():Void
    {
        // Limpiar tweens inactivos
        beatTweens = beatTweens.filter(t -> t.isActive && t.sprite != null && t.sprite.exists);
    }
    
    // ============================================
    // UTILITY FUNCTIONS
    // ============================================
    
    /**
     * Obtener valor de propiedad de un sprite
     */
    private function getPropertyValue(sprite:FlxSprite, property:String):Float
    {
        switch (property) {
            case 'x': return sprite.x;
            case 'y': return sprite.y;
            case 'scale.x', 'scaleX': return sprite.scale.x;
            case 'scale.y', 'scaleY': return sprite.scale.y;
            case 'alpha': return sprite.alpha;
            case 'angle': return sprite.angle;
            case 'offset.x', 'offsetX': return sprite.offset.x;
            case 'offset.y', 'offsetY': return sprite.offset.y;
            case 'origin.x', 'originX': return sprite.origin.x;
            case 'origin.y', 'originY': return sprite.origin.y;
            default: return 0;
        }
    }
    
    /**
     * Resetear contadores
     */
    public function reset():Void
    {
        currentTime = 0;
        currentBeat = 0;
        beatCount = 0;
        stepCount = 0;
        measureCount = 0;
    }
    
    /**
     * Set BPM y recalcular
     */
    public function setBpm(newBpm:Float):Void
    {
        bpm = newBpm;
    }
    
    /**
     * Saltar a un beat específico
     */
    public function seekTo(beat:Float):Void
    {
        currentTime = beat * crochet;
        currentBeat = beat;
        beatCount = Math.floor(beat);
    }
    
    /**
     * Saltar a un tiempo específico
     */
    public function seekToTime(time:Float):Void
    {
        currentTime = time;
        currentBeat = time / crochet;
        beatCount = Math.floor(currentBeat);
        stepCount = Math.floor(time / stepCrochet);
    }
    
    /**
     * Obtener beat actual con decimal
     */
    public function getCurrentBeat():Float
    {
        return currentTime / crochet;
    }
    
    /**
     * Verificar si estamos en un beat específico
     */
    public function isOnBeat(beat:Int, ?tolerance:Float = 0.1):Bool
    {
    var current = currentBeat;
    var diff = Math.abs(current - beat);
        return diff <= tolerance || (1 - diff) <= tolerance; // Handles wrapping
    }
    
    /**
     * Verificar si estamos en un beat fuerte (1, 3 de 4/4)
     */
    public function isOnStrongBeat():Bool
    {
        return isOnBeat(Math.floor(currentBeat / 2) * 2 + 1, 0.15);
    }
    
    /**
     * Verificar si estamos en el beat 0 (inicio)
     */
    public function isOnDownbeat():Bool
    {
        return isOnBeat(Math.floor(currentBeat / 4) * 4, 0.15);
    }
    
    // ============================================
    // PRESET ANIMATIONS
    // ============================================
    
    /**
     * Bounce animation (scale up and down)
     */
    public function beatBounce(sprite:FlxSprite, amount:Float = 0.1, ?interval:Int = 1):BeatTweenHandle
    {
    var baseScale = sprite.scale.x;
        return beatTween(sprite, 'scale.x', baseScale * (1 + amount), 0.5, {interval: interval})
            .onUpdate(() -> {
                sprite.scale.y = sprite.scale.x;
            });
    }
    
    /**
     * Shake animation (offset left/right)
     */
    public function beatShake(sprite:FlxSprite, amount:Float = 5, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'offset.x', amount, 0.25, {interval: interval, pingPong: true})
            .onComplete(() -> {
                sprite.offset.x = 0;
            });
    }
    
    /**
     * Pulse animation (scale con ease)
     */
    public function beatPulse(sprite:FlxSprite, maxScale:Float = 1.2, ?interval:Int = 1):BeatTweenHandle
    {
    var baseScale = sprite.scale.x;
        return beatTween(sprite, 'scale.x', maxScale, 0.5, {interval: interval, ease: FlxEase.elasticOut})
            .onUpdate(() -> {
                sprite.scale.y = sprite.scale.x;
            });
    }
    
    /**
     * Flash animation (alpha blink)
     */
    public function beatFlash(sprite:FlxSprite, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'alpha', 0, 0.25, {interval: interval, pingPong: true})
            .onComplete(() -> {
                sprite.alpha = 1;
            });
    }
    
    /**
     * Rotate animation (360 cada X beats)
     */
    public function beatRotate(sprite:FlxSprite, beatsPerRotation:Float = 4, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'angle', 360, beatsPerRotation, {interval: interval});
    }
    
    /**
     * Beat bounce simple (alternating up/down)
     */
    public function beatBounceSimple(sprite:FlxSprite, amount:Float = 10, ?interval:Int = 1):BeatTweenHandle
    {
        return beatTween(sprite, 'y', sprite.y - amount, 0.5, {interval: interval, pingPong: true});
    }
}

// ============================================
// TIPOS
// ============================================

// ============================================
// BEAT TWEEN HANDLE
// ============================================

class BeatTweenHandle
{
    private var data:BeatTweenData;
    private var parent:BeatSync;
    
    public var onUpdateCallback:Void->Void = null;
    public var onCompleteCallback:Void->Void = null;
    
    public function new(data:BeatTweenData, parent:BeatSync)
    {
        this.data = data;
        this.parent = parent;
    }
    
    public function onUpdate(callback:Void->Void):BeatTweenHandle
    {
        onUpdateCallback = callback;
        return this;
    }
    
    public function onComplete(callback:Void->Void):BeatTweenHandle
    {
        onCompleteCallback = callback;
        return this;
    }
    
    public function cancel():Void
    {
        data.isActive = false;
    }
}