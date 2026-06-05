package backend;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxRandom;

/**
 * Particle - Una partícula individual para el sistema de partículas
 * 
 * Optimizada para uso intensivo, soporta:
 * - Velocity y acceleration
 * - Color y alpha blending
 * - Rotation y scale animation
 * - Lifetime y fade
 * - Custom sprites
 */
class Particle extends FlxSprite
{
    // ============================================
    // PROPIEDADES
    // ============================================
    
    /** Velocidad inicial */
    public var velocityInitial:FlxPoint = FlxPoint.get();
    
    /** Aceleración */
    public var acceleration:FlxPoint = FlxPoint.get();
    
    /** Drag (fricción) */
    public var drag:FlxPoint = FlxPoint.get();
    
    /** Rotación speed */
    public var angularVelocity:Float = 0;
    public var angularAcceleration:Float = 0;
    
    /** Scale inicial y velocidad */
    public var scaleInitial:FlxPoint = FlxPoint.get(1, 1);
    public var scaleVelocity:FlxPoint = FlxPoint.get();
    
    /** Alpha inicial y velocidad */
    public var alphaInitial:Float = 1;
    public var alphaVelocity:Float = 0;
    
    /** Color inicial */
    public var colorInitial:FlxColor = FlxColor.WHITE;
    
    /** Lifetime en segundos (0 = infinito) */
    public var lifetime:Float = 0;
    
    /** Tiempo de vida actual */
    public var lifetimeRemaining:Float = 0;
    
    /** Delay antes de aparecer */
    public var delay:Float = 0;
    public var delayRemaining:Float = 0;
    
    /** Blend mode */
    public var blend:String = 'normal';
    
    /** Si está activa (no en delay ni muerta) */
    public var isActive:Bool = false;
    
    /** Callback al morir */
    public var onDeath:Void->Void = null;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new()
    {
        super();
        resetParticle();
    }
    
    // ============================================
    // METODOS
    // ============================================
    
    /**
     * Resetear partícula para pooling
     */
    public function resetParticle():Void
    {
        x = 0;
        y = 0;
        angle = 0;
        angularVelocity = 0;
        angularAcceleration = 0;
        alpha = 1;
        scale.set(1, 1);
        color = FlxColor.WHITE;
        blend = 'normal';
        
        velocityInitial.set(0, 0);
        velocity.set(0, 0);
        acceleration.set(0, 0);
        drag.set(0, 0);
        
        scaleInitial.set(1, 1);
        scaleVelocity.set(0, 0);
        
        alphaInitial = 1;
        alphaVelocity = 0;
        colorInitial = FlxColor.WHITE;
        
        lifetime = 0;
        lifetimeRemaining = 0;
        delay = 0;
        delayRemaining = 0;
        
        isActive = false;
        onDeath = null;
        
        exists = false;
        active = false;
    }
    
    /**
     * Configurar la partícula con parámetros
     */
    public function setup(?config:ParticleConfig):Void
    {
        if (config == null) config = {};
        
        // Position
        x = config.x ?? 0;
        y = config.y ?? 0;
        
        // Velocity
        velocityInitial.set(
            config.vx ?? 0, 
            config.vy ?? 0
        );
        velocity.set(velocityInitial.x, velocityInitial.y);
        
        // Acceleration
        acceleration.set(
            config.ax ?? 0, 
            config.ay ?? 0
        );
        
        // Drag
        drag.set(
            config.dragX ?? 0, 
            config.dragY ?? 0
        );
        
        // Angular
        angularVelocity = config.angularVelocity ?? 0;
        angularAcceleration = config.angularAcceleration ?? 0;
        
        // Scale
        var sx = config.scaleX ?? 1;
        var sy = config.scaleY ?? sx;
        scaleInitial.set(sx, sy);
        scale.set(sx, sy);
        scaleVelocity.set(
            config.scaleVelocityX ?? 0, 
            config.scaleVelocityY ?? 0
        );
        
        // Alpha
        alphaInitial = config.alpha ?? 1;
        alpha = alphaInitial;
        alphaVelocity = config.alphaVelocity ?? 0;
        
        // Color
        colorInitial = config.color ?? FlxColor.WHITE;
        color = colorInitial;
        
        // Lifetime
        lifetime = config.lifetime ?? 0;
        lifetimeRemaining = lifetime;
        
        // Delay
        delay = config.delay ?? 0;
        delayRemaining = delay;
        
        // Blend
        blend = config.blend ?? 'normal';
        updateBlendMode();
        
        // Sprite
        if (config.sprite != null) {
            loadGraphic(config.sprite);
        } else if (config.makeGraphic) {
            var size = config.size ?? 4;
            var color = config.color ?? FlxColor.WHITE;
            makeGraphic(size, size, color);
        }
        
        // Centrar origin
        centerOrigin();
        
        // Activar
        isActive = true;
        exists = true;
        active = true;
    }
    
    /**
     * Update blend mode basado en string
     */
    private function updateBlendMode():Void
    {
        switch (blend.toLowerCase()) {
            case 'additive', 'add':
                blendMode = ADD;
            case 'multiply', 'mult':
                blendMode = MULTIPLY;
            case 'screen':
                blendMode = SCREEN;
            case 'subtract':
                blendMode = SUBTRACT;
            default:
                blendMode = NORMAL;
        }
    }
    
    // ============================================
    // UPDATE
    // ============================================
    
    override public function update(elapsed:Float):Void
    {
        if (!exists || !active) return;
        
        // Handle delay
        if (delayRemaining > 0) {
            delayRemaining -= elapsed;
            if (delayRemaining <= 0) {
                delayRemaining = 0;
            }
            return;
        }
        
        // Update lifetime
        if (lifetime > 0) {
            lifetimeRemaining -= elapsed;
            
            // Fade out basado en lifetime
            if (alphaVelocity == 0 && lifetimeRemaining > 0) {
                alpha = alphaInitial * (lifetimeRemaining / lifetime);
            }
            
            // Morir si se acabó el lifetime
            if (lifetimeRemaining <= 0) {
                kill();
                return;
            }
        }
        
        // Apply acceleration
        velocity.x += acceleration.x * elapsed;
        velocity.y += acceleration.y * elapsed;
        
        // Apply drag
        velocity.x -= velocity.x * drag.x * elapsed;
        velocity.y -= velocity.y * drag.y * elapsed;
        
        // Update position
        x += velocity.x * elapsed;
        y += velocity.y * elapsed;
        
        // Update angular
        angularVelocity += angularAcceleration * elapsed;
        angle += angularVelocity * elapsed;
        
        // Update scale
        scale.x += scaleVelocity.x * elapsed;
        scale.y += scaleVelocity.y * elapsed;
        
        // Update alpha
        alpha += alphaVelocity * elapsed;
        alpha = FlxMath.bound(alpha, 0, 1);
        
        super.update(elapsed);
    }
    
    // ============================================
    // KILL / DEATH
    // ============================================
    
    override public function kill():Void
    {
        if (onDeath != null) {
            onDeath();
        }
        super.kill();
    }
}

// ============================================
// CONFIG TYPEDEF
// ============================================

typedef ParticleConfig = {
    ?x:Float,
    ?y:Float,
    ?vx:Float,
    ?vy:Float,
    ?ax:Float,
    ?ay:Float,
    ?dragX:Float,
    ?dragY:Float,
    ?angularVelocity:Float,
    ?angularAcceleration:Float,
    ?scaleX:Float,
    ?scaleY:Float,
    ?scaleVelocityX:Float,
    ?scaleVelocityY:Float,
    ?alpha:Float,
    ?alphaVelocity:Float,
    ?color:FlxColor,
    ?lifetime:Float,
    ?delay:Float,
    ?blend:String,
    ?sprite:String,
    ?makeGraphic:Bool,
    ?size:Int
}