package backend;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxRandom;

/**
 * ParticleEmitter - Sistema de emisión de partículas
 * 
 * Permite crear efectos visuales con partículas como:
 * - Explosiones
 * - Fuegos
 * - Humo
 * - Chispas
 * - Nieve
 * - Lluvia
 * - etc.
 * 
 * Uso:
 * ```haxe
 * // Crear emisor
 * var emitter = new ParticleEmitter();
 * emitter.x = 100;
 * emitter.y = 100;
 * add(emitter);
 * 
 * // Configurar
 * emitter.setColors([0xFF0000, 0xFFFF00]);
 * emitter.setQuantity(10);
 * emitter.setLifetime(1.5);
 * 
 * // Emitir
 * emitter.explode();
 * // o
 * emitter.start();
 * ```
 */
class ParticleEmitter extends FlxBasic
{
    // ============================================
    // PROPIEDADES DEL EMISOR
    // ============================================
    
    /** Posición del emisor */
    public var x:Float = 0;
    public var y:Float = 0;
    
    /** Área de emisión */
    public var width:Float = 0;
    public var height:Float = 0;
    
    /** Pool de partículas */
    private var particles:FlxTypedGroup<Particle>;
    
    /** Pool de partículas disponibles */
    private var pool:FlxTypedGroup<Particle>;
    
    /** Máxima cantidad de partículas */
    public var maxParticles:Int = 200;
    
    // ============================================
    // CONFIGURACIÓN DE EMISIÓN
    // ============================================
    
    /** Cantidad de partículas por ráfaga */
    public var quantity:Int = 10;
    
    /** Frecuencia de emisión (0 = manual) */
    public var frequency:Float = 0;
    private var timer:Float = 0;
    
    /** Si está activo */
    public var emitting:Bool = false;
    
    // ============================================
    // CONFIGURACIÓN DE PARTÍCULAS
    // ============================================
    
    /** Velocidad inicial */
    public var speedMin:Float = 50;
    public var speedMax:Float = 100;
    public var angleMin:Float = 0;
    public var angleMax:Float = 360;
    
    /** Acceleración */
    public var accelerationX:Float = 0;
    public var accelerationY:Float = 100;
    
    /** Drag */
    public var dragX:Float = 0;
    public var dragY:Float = 0;
    
    /** Angular */
    public var angularVelocityMin:Float = 0;
    public var angularVelocityMax:Float = 0;
    public var angularAcceleration:Float = 0;
    
    /** Scale */
    public var scaleStartMin:Float = 1;
    public var scaleStartMax:Float = 1;
    public var scaleEndMin:Float = 0;
    public var scaleEndMax:Float = 0;
    
    /** Alpha */
    public var alphaStart:Float = 1;
    public var alphaEnd:Float = 0;
    
    /** Color */
    public var colors:Array<FlxColor> = [FlxColor.WHITE];
    
    /** Lifetime */
    public var lifetimeMin:Float = 1;
    public var lifetimeMax:Float = 1;
    
    /** Blend mode */
    public var blend:String = 'normal';
    
    // ============================================
    // SPRITE DE PARTÍCULA
    // ============================================
    
    /** Sprite custom para las partículas */
    public var particleSprite:String = null;
    public var makeGraphic:Bool = false;
    public var graphicSize:Int = 4;
    
    // ============================================
    // CALLBACKS
    // ============================================
    
    public var onParticleSpawn:Particle->Void = null;
    public var onParticleDeath:Particle->Void = null;
    
    // ============================================
    // STATS
    // ============================================
    
    public var totalEmitted:Int = 0;
    public var totalAlive:Int = 0;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    public function new(X:Float = 0, Y:Float = 0, ?MaxParticles:Int = 200)
    {
        super();
        
        x = X;
        y = Y;
        maxParticles = MaxParticles;
        
        particles = new FlxTypedGroup<Particle>();
        pool = new FlxTypedGroup<Particle>();
        
        // Pre-allocate particles
        for (i in 0...maxParticles) {
            var p = new Particle();
            p.exists = false;
            p.active = false;
            pool.add(p);
        }
    }
    
    // ============================================
    // CONFIGURACIÓN
    // ============================================
    
    /**
     * Setter posición
     */
    public function setPosition(X:Float, Y:Float):ParticleEmitter
    {
        x = X;
        y = Y;
        return this;
    }
    
    /**
     * Setter área de emisión
     */
    public function setSize(Width:Float, Height:Float):ParticleEmitter
    {
        width = Width;
        height = Height;
        return this;
    }
    
    /**
     * Setter velocidad
     */
    public function setSpeed(Min:Float, Max:Float):ParticleEmitter
    {
        speedMin = Min;
        speedMax = Max;
        return this;
    }
    
    /**
     * Setter ángulo
     */
    public function setAngle(Min:Float, Max:Float):ParticleEmitter
    {
        angleMin = Min;
        angleMax = Max;
        return this;
    }
    
    /**
     * Setter aceleración
     */
    public function setAcceleration(X:Float, Y:Float):ParticleEmitter
    {
        accelerationX = X;
        accelerationY = Y;
        return this;
    }
    
    /**
     * Setter drag
     */
    public function setDrag(X:Float, Y:Float):ParticleEmitter
    {
        dragX = X;
        dragY = Y;
        return this;
    }
    
    /**
     * Setter rotación
     */
    public function setAngularVelocity(Min:Float, Max:Float):ParticleEmitter
    {
        angularVelocityMin = Min;
        angularVelocityMax = Max;
        return this;
    }
    
    /**
     * Setter colors
     */
    public function setColors(Colors:Array<FlxColor>):ParticleEmitter
    {
        colors = Colors;
        return this;
    }
    
    /**
     * Setter lifetime
     */
    public function setLifetime(Min:Float, Max:Float):ParticleEmitter
    {
        lifetimeMin = Min;
        lifetimeMax = Max;
        return this;
    }
    
    /**
     * Setter scale
     */
    public function setScale(StartMin:Float, StartMax:Float, EndMin:Float, EndMax:Float):ParticleEmitter
    {
        scaleStartMin = StartMin;
        scaleStartMax = StartMax;
        scaleEndMin = EndMin;
        scaleEndMax = EndMax;
        return this;
    }
    
    /**
     * Setter alpha
     */
    public function setAlpha(Start:Float, End:Float):ParticleEmitter
    {
        alphaStart = Start;
        alphaEnd = End;
        return this;
    }
    
    /**
     * Setter blend
     */
    public function setBlend(Blend:String):ParticleEmitter
    {
        blend = Blend;
        return this;
    }
    
    /**
     * Setter quantity
     */
    public function setQuantity(Qty:Int):ParticleEmitter
    {
        quantity = Qty;
        return this;
    }
    
    /**
     * Setter sprite
     */
    public function setParticleSprite(Sprite:String):ParticleEmitter
    {
        particleSprite = Sprite;
        makeGraphic = false;
        return this;
    }
    
    /**
     * Setter graphic (genera un círculo)
     */
    public function setParticleGraphic(Size:Int, Color:FlxColor = FlxColor.WHITE):ParticleEmitter
    {
        graphicSize = Size;
        makeGraphic = true;
        particleSprite = null;
        return this;
    }
    
    // ============================================
    // EMISIÓN
    // ============================================
    
    /**
     * Emitir una ráfaga de partículas
     */
    public function emit(?Qty:Int = -1):Void
    {
        if (Qty < 0) Qty = quantity;
        
        for (i in 0...Qty) {
            emitParticle();
        }
    }
    
    /**
     * Emitir una partícula individual
     */
    private function emitParticle():Void
    {
        var particle = pool.getFirstAvailable();
        
        if (particle == null) {
            // Auto-expand si hay espacio
            if (particles.length < maxParticles) {
                particle = new Particle();
                pool.add(particle);
            } else {
                return; // Pool lleno
            }
        }
        
        // Configurar partícula
        configureParticle(particle);
        
        // Mover de pool a active
        pool.remove(particle);
        particles.add(particle);
        
        // Callback
        if (onParticleSpawn != null) {
            onParticleSpawn(particle);
        }
        
        totalEmitted++;
    }
    
    /**
     * Configurar una partícula con los parámetros del emisor
     */
    private function configureParticle(p:Particle):Void
    {
        // Position (con área)
        var px = x + FlxRandom.floatRanged(0, width);
        var py = y + FlxRandom.floatRanged(0, height);
        
        // Velocity
        var speed = FlxRandom.floatRanged(speedMin, speedMax);
        var angle = FlxRandom.floatRanged(angleMin, angleMax);
        var vx = Math.cos(angle * Math.PI / 180) * speed;
        var vy = Math.sin(angle * Math.PI / 180) * speed;
        
        // Scale
        var scaleStart = FlxRandom.floatRanged(scaleStartMin, scaleStartMax);
        var scaleEnd = FlxRandom.floatRanged(scaleEndMin, scaleEndMax);
        
        // Color
        var color = colors[FlxRandom.intRanged(0, colors.length - 1)];
        
        // Lifetime
        var lifetime = FlxRandom.floatRanged(lifetimeMin, lifetimeMax);
        
        // Angular
        var angularVel = FlxRandom.floatRanged(angularVelocityMin, angularVelocityMax);
        
        // Crear config
        var config:ParticleConfig = {
            x: px,
            y: py,
            vx: vx,
            vy: vy,
            ax: accelerationX,
            ay: accelerationY,
            dragX: dragX,
            dragY: dragY,
            angularVelocity: angularVel,
            angularAcceleration: angularAcceleration,
            scaleX: scaleStart,
            scaleY: scaleStart,
            scaleVelocityX: (scaleEnd - scaleStart) / lifetime,
            scaleVelocityY: (scaleEnd - scaleStart) / lifetime,
            alpha: alphaStart,
            alphaVelocity: (alphaEnd - alphaStart) / lifetime,
            color: color,
            lifetime: lifetime,
            blend: blend,
            sprite: particleSprite,
            makeGraphic: makeGraphic,
            size: graphicSize
        };
        
        // Setup
        p.setup(config);
        
        // Callback de muerte
        p.onDeath = () -> {
            particles.remove(p);
            pool.add(p);
            if (onParticleDeath != null) {
                onParticleDeath(p);
            }
        };
    }
    
    // ============================================
    // MODOS DE EMISIÓN
    // ============================================
    
    /**
     * Explósión - una ráfaga
     */
    public function explode(?Qty:Int = -1):Void
    {
        emit(Qty);
    }
    
    /**
     * Iniciar emisión continua
     */
    public function start(?Frequency:Float = 0.1):Void
    {
        frequency = Frequency;
        emitting = true;
        timer = 0;
    }
    
    /**
     * Detener emisión continua
     */
    public function stop():Void
    {
        emitting = false;
        frequency = 0;
    }
    
    /**
     * ráfaga continua (on/off rápido)
     */
    public function burst(Count:Int = 10):Void
    {
        for (i in 0...Count) {
            emitParticle();
        }
    }
    
    /**
     * Spray - emite en una dirección
     */
    public function spray(Angle:Float, Spread:Float = 30, Count:Int = 10):Void
    {
        var startAngle = Angle - Spread / 2;
        var endAngle = Angle + Spread / 2;
        
        for (i in 0...Count) {
            var a = FlxRandom.floatRanged(startAngle, endAngle);
            var speed = FlxRandom.floatRanged(speedMin, speedMax);
            
            var p = pool.getFirstAvailable();
            if (p == null) {
                if (particles.length < maxParticles) {
                    p = new Particle();
                    pool.add(p);
                } else continue;
            }
            
            pool.remove(p);
            particles.add(p);
            
            var vx = Math.cos(a * Math.PI / 180) * speed;
            var vy = Math.sin(a * Math.PI / 180) * speed;
            
            var config:ParticleConfig = {
                x: x + FlxRandom.floatRanged(0, width),
                y: y + FlxRandom.floatRanged(0, height),
                vx: vx,
                vy: vy,
                ax: accelerationX,
                ay: accelerationY,
                lifetime: FlxRandom.floatRanged(lifetimeMin, lifetimeMax),
                scaleX: FlxRandom.floatRanged(scaleStartMin, scaleStartMax),
                scaleY: FlxRandom.floatRanged(scaleStartMin, scaleStartMax),
                alpha: alphaStart,
                alphaVelocity: (alphaEnd - alphaStart) / lifetimeMax,
                color: colors[FlxRandom.intRanged(0, colors.length - 1)],
                blend: blend
            };
            
            p.setup(config);
            totalEmitted++;
        }
    }
    
    // ============================================
    // UPDATE
    // ============================================
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        // Emisión continua
        if (emitting && frequency > 0) {
            timer += elapsed;
            if (timer >= frequency) {
                emit();
                timer = 0;
            }
        }
        
        // Update partículas
        totalAlive = particles.countLiving();
    }
    
    // ============================================
    // UTILIDADES
    // ============================================
    
    /**
     * Matar todas las partículas activas
     */
    public function killAll():Void
    {
        for (p in particles) {
            p.kill();
        }
    }
    
    /**
     * Hacer que todas las partículas cambien de dirección
     */
    public function bounceAll(Bounce:Float = 0.5):Void
    {
        for (p in particles) {
            p.velocity.x *= -Bounce;
            p.velocity.y *= -Bounce;
        }
    }
    
    /**
     * Aplicar gravedad a todas las partículas
     */
    public function applyGravity(Gravity:Float):Void
    {
        for (p in particles) {
            p.acceleration.y = Gravity;
        }
    }
    
    /**
     * Follow a sprite/object
     */
    public function followTarget(Target:FlxSprite, OffsetX:Float = 0, OffsetY:Float = 0):Void
    {
        x = Target.x + OffsetX;
        y = Target.y + OffsetY;
    }
    
    /**
     * Obtener grupo de partículas (para agregar a un state)
     */
    public function getGroup():FlxTypedGroup<Particle>
    {
        return particles;
    }
    
    /**
     * Estadísticas
     */
    public function getStats():Dynamic
    {
        return {
            totalEmitted: totalEmitted,
            totalAlive: totalAlive,
            totalPooled: pool.length,
            maxParticles: maxParticles,
            emitting: emitting,
            frequency: frequency
        };
    }
    
    /**
     * Debug
     */
    public function debug():Void
    {
        #if debug
        var s = getStats();
        trace('[ParticleEmitter] Alive: ' + s.totalAlive + ' | Pooled: ' + s.totalPooled + ' | Emitted: ' + s.totalEmitted);
        #end
    }
}