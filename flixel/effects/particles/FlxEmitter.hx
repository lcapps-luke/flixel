package flixel.effects.particles;

import flash.display.BitmapData;
import flash.display.BlendMode;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.particles.FlxParticle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRandom;
import flixel.math.FlxVelocity;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxStringUtil;
import flixel.util.helpers.FlxBounds;
import flixel.util.helpers.FlxRange;
import flixel.util.helpers.FlxRangeBounds;
import flixel.util.helpers.FlxPointRangeBounds;

typedef FlxEmitter = FlxTypedEmitter<FlxParticle>;

/**
 * FlxTypedEmitter is a lightweight particle emitter.
 * It can be used for one-time explosions or for
 * continuous fx like rain and fire.  FlxEmitter
 * is not optimized or anything; all it does is launch
 * FlxParticle objects out at set intervals
 * by setting their positions and velocities accordingly.
 * It is easy to use and relatively efficient,
 * relying on FlxGroup's RECYCLE POWERS.
 */
class FlxTypedEmitter<T:(FlxSprite, IFlxParticle)> extends FlxTypedGroup<T>
{
	/**
	 * Set your own particle class type here. The custom class must extend FlxParticle. Default is FlxParticle.
	 */
	public var particleClass:Class<T>;
	/**
	 * Determines whether the emitter is currently emitting particles. It is totally safe to directly toggle this.
	 */
	public var emitting:Bool = false;
	/**
	 * How often a particle is emitted (if emitter is started with Explode == false).
	 */
	public var frequency:Float = 0.1;
	/**
	 * Sets particle's blend mode. null by default. Warning: Expensive on flash target.
	 */
	public var blend:BlendMode;
	/**
	 * The x position of this emitter.
	 */
	public var x:Float = 0;
	/**
	 * The y position of this emitter.
	 */
	public var y:Float = 0;
	/**
	 * The width of this emitter. Particles can be randomly generated from anywhere within this box.
	 */
	public var width:Float = 0;
	/**
	 * The height of this emitter.  Particles can be randomly generated from anywhere within this box.
	 */
	public var height:Float = 0;
	/**
	 * How particles should be launched. If CIRCLE, particles will use launchAngle and velocity. Otherwise, particles will just use velocity.x and velocity.y.
	 */
	public var launchMode:FlxEmitterMode = FlxEmitterMode.CIRCLE;
	/**
	 * Sets the velocity range of particles launched from this emitter.
	 */
	public var velocity(default, null):FlxPointRangeBounds;
	/**
	 * The angular velocity range of particles launched from this emitter.
	 */
	public var angularVelocity(default, null):FlxRangeBounds<Float>;
	/**
	 * The angle range of particles launched from this emitter. angle.end is ignored unless ignoreAngularVelocity is set to true.
	 */
	public var angle(default, null):FlxRangeBounds<Float>;
	/**
	 * Set this if you want to specify the beginning and ending value of angle, instead of using angularVelocity.
	 */
	public var ignoreAngularVelocity:Bool = false;
	/**
	 * The angle range at which particles will be launched from this emitter. Ignored unless launchMode is set to FlxEmitterMode.CIRCLE
	 */
	public var launchAngle(default, null):FlxBounds<Float>;
	/**
	 * The life, or duration, range of particles launched from this emitter.
	 */
	public var lifespan(default, null):FlxBounds<Float>;
	/**
	 * Sets scale range of particles launched from this emitter.
	 */
	public var scale(default, null):FlxPointRangeBounds;
	/**
	 * Sets alpha range of particles launched from this emitter.
	 */
	public var alpha(default, null):FlxRangeBounds<Float>;
	/**
	 * Sets color range of particles launched from this emitter.
	 */
	public var color(default, null):FlxRangeBounds<FlxColor>;
	/**
	 * Sets X and Y drag component of particles launched from this emitter.
	 */
	public var drag(default, null):FlxPointRangeBounds;
	/**
	 * Sets the acceleration range of particles launched from this emitter. Set acceleration y-values to give particles gravity.
	 */
	public var acceleration(default, null):FlxPointRangeBounds;
	/**
	 * Sets the elasticity, or bounce, range of particles launched from this emitter.
	 */
	public var elasticity(default, null):FlxRangeBounds<Float>;
	/**
	 * Sets the immovable flag for particles launched from this emitter.
	 */
	public var immovable:Bool = false;
	/**
	 * Sets the autoUpdateHitbox flag for particles launched from this emitter. If true, the particles' hitbox will be updated to match scale.
	 */
	public var autoUpdateHitbox:Bool = false;
	/**
	 * Sets the allowCollisions value for particles launched from this emitter. Set to NONE by default. Don't forget to call FlxG.collide() in your update loop!
	 */
	public var allowCollisions:Int = FlxObject.NONE;
	/**
	 * Shorthand for toggling allowCollisions between ANY (if true) and NONE (if false). Don't forget to call FlxG.collide() in your update loop!
	 */
	public var solid(get, set):Bool;
	/**
	 * Internal helper for deciding how many particles to launch.
	 */
	private var _quantity:Int = 0;
	/**
	 * Internal helper for the style of particle emission (all at once, or one at a time).
	 */
	private var _explode:Bool = true;
	/**
	 * Internal helper for deciding when to launch particles or kill them.
	 */
	private var _timer:Float = 0;
	/**
	 * Internal counter for figuring out how many particles to launch.
	 */
	private var _counter:Int = 0;
	/**
	 * Internal point object, handy for reusing for memory management purposes.
	 */
	private var _point:FlxPoint;
	/**
	 * Internal helper for automatically calling the kill() method
	 */
	private var _waitForKill:Bool = false;
	
	/**
	 * Creates a new FlxTypedEmitter object at a specific position.
	 * Does NOT automatically generate or attach particles!
	 * 
	 * @param	X		The X position of the emitter.
	 * @param	Y		The Y position of the emitter.
	 * @param	Size	Optional, specifies a maximum capacity for this emitter.
	 */
	public function new(X:Float = 0, Y:Float = 0, Size:Int = 0)
	{
		super(Size);
		
		x = X;
		y = Y;
		
		velocity = new FlxPointRangeBounds(-100, -100, 100, 100);
		angularVelocity = new FlxRangeBounds<Float>(0, 0);
		angle = new FlxRangeBounds<Float>(0);
		launchAngle = new FlxBounds<Float>(-180, 180);
		lifespan = new FlxBounds<Float>(3);
		scale = new FlxPointRangeBounds(1, 1);
		alpha = new FlxRangeBounds<Float>(1);
		color = new FlxRangeBounds<FlxColor>(FlxColor.WHITE, FlxColor.WHITE);
		drag = new FlxPointRangeBounds(0, 0);
		acceleration = new FlxPointRangeBounds(0, 0);
		elasticity = new FlxRangeBounds<Float>(0);
		
		particleClass = cast FlxParticle;
		
		exists = false;
		_point = FlxPoint.get();
	}
	
	/**
	 * Clean up memory.
	 */
	override public function destroy():Void
	{
		velocity = FlxDestroyUtil.destroy(velocity);
		scale = FlxDestroyUtil.destroy(scale);
		drag = FlxDestroyUtil.destroy(drag);
		acceleration = FlxDestroyUtil.destroy(acceleration);
		_point = FlxDestroyUtil.put(_point);
		
		blend = null;
		angularVelocity = null;
		angle = null;
		launchAngle = null;
		lifespan = null;
		alpha = null;
		color = null;
		elasticity = null;
		
		super.destroy();
	}
	
	/**
	 * This function generates a new array of particle sprites to attach to the emitter.
	 * 
	 * @param	Graphics		If you opted to not pre-configure an array of FlxParticle objects, you can simply pass in a particle image or sprite sheet.
	 * @param	Quantity		The number of particles to generate when using the "create from image" option.
	 * @param	BakedRotations	How many frames of baked rotation to use (boosts performance).  Set to zero to not use baked rotations.
	 * @param	Multiple		Whether the image in the Graphics param is a single particle or a bunch of particles (if it's a bunch, they need to be square!).
	 * @param	AutoBuffer		Whether to automatically increase the image size to accomodate rotated corners.  Default is false.  Will create frames that are 150% larger on each axis than the original frame or graphic.
	 * @return	This FlxEmitter instance (nice for chaining stuff together).
	 */
	public function loadParticles(Graphics:FlxGraphicAsset, Quantity:Int = 50, bakedRotationAngles:Int = 16, Multiple:Bool = false, AutoBuffer:Bool = false):FlxTypedEmitter<T>
	{
		maxSize = Quantity;
		var totalFrames:Int = 1;
		
		if (Multiple)
		{ 
			var sprite = new FlxSprite();
			sprite.loadGraphic(Graphics, true);
			totalFrames = sprite.frames;
			sprite.destroy();
		}
		
		var randomFrame:Int;
		var i:Int = 0;
		
		while (i < Quantity)
		{
			var particle:T = Type.createInstance(particleClass, []);
			
			if (Multiple)
			{
				randomFrame = FlxRandom.int(0, totalFrames - 1);
				
				if (bakedRotationAngles > 0)
				{
					#if FLX_RENDER_BLIT
					particle.loadRotatedGraphic(Graphics, bakedRotationAngles, randomFrame, false, AutoBuffer);
					#else
					particle.loadGraphic(Graphics, true);
					#end
				}
				else
				{
					particle.loadGraphic(Graphics, true);
				}
				particle.animation.frameIndex = randomFrame;
			}
			else
			{
				if (bakedRotationAngles > 0)
				{
					#if FLX_RENDER_BLIT
					particle.loadRotatedGraphic(Graphics, bakedRotationAngles, -1, false, AutoBuffer);
					#else
					particle.loadGraphic(Graphics);
					#end
				}
				else
				{
					particle.loadGraphic(Graphics);
				}
			}
			
			add(particle);
			i++;
		}
		
		return this;
	}
	
	/**
	 * Similar to FlxSprite's makeGraphic, this function allows you to quickly make single-color particles.
	 * 
	 * @param	Width           The width of the generated particles. Default is 2 pixels.
	 * @param	Height          The height of the generated particles. Default is 2 pixels.
	 * @param	Color           The color of the generated particles. Default is white.
	 * @param	Quantity        How many particles to generate. Default is 50.
	 * @return  This FlxEmitter instance (nice for chaining stuff together).
	 */
	public function makeParticles(Width:Int = 2, Height:Int = 2, Color:FlxColor = FlxColor.WHITE, Quantity:Int = 50):FlxTypedEmitter<T>
	{
		var i:Int = 0;
		
		while (i < Quantity)
		{
			var particle:T = Type.createInstance(particleClass, []);
			particle.makeGraphic(Width, Height, Color);
			add(particle);
			
			i++;
		}
		
		return this;
	}
	
	/**
	 * Called automatically by the game loop, decides when to launch particles and when to "die".
	 */
	override public function update():Void
	{
		if (emitting)
		{
			if (_explode)
			{
				emitting = false;
				_waitForKill = true;
				
				var i:Int = 0;
				var l:Int = _quantity;
				
				if ((l <= 0) || (l > length))
				{
					l = length;
				}
				
				while (i < l)
				{
					emitParticle();
					i++;
				}
				
				_quantity = 0;
			}
			else
			{
				// Spawn a particle per frame
				if (frequency <= 0)
				{
					emitParticle();
					
					if ((_quantity > 0) && (++_counter >= _quantity))
					{
						emitting = false;
						_waitForKill = true;
						_quantity = 0;
					}
				}
				else
				{
					_timer += FlxG.elapsed;
					
					while (_timer > frequency)
					{
						_timer -= frequency;
						emitParticle();
						
						if ((_quantity > 0) && (++_counter >= _quantity))
						{
							emitting = false;
							_waitForKill = true;
							_quantity = 0;
						}
					}
				}
			}
		}
		else if (_waitForKill)
		{
			_timer += FlxG.elapsed;
			
			if ((lifespan.max > 0) && (_timer > lifespan.max))
			{
				kill();
				return;
			}
		}
		
		super.update();
	}
	
	/**
	 * Call this function to turn off all the particles and the emitter.
	 */
	override public function kill():Void
	{
		emitting = false;
		_waitForKill = false;
		
		super.kill();
	}
	
	/**
	 * Call this function to start emitting particles.
	 * 
	 * @param	Explode			Whether the particles should all burst out at once.
	 * @param	Frequency		Ignored if Explode is set to true. Frequency is how often to emit a particle. 0 = never emit, 0.1 = 1 particle every 0.1 seconds, 5 = 1 particle every 5 seconds.
	 * @param	Quantity		Ignored if Explode is set to true. How many particles to launch. 0 = "all of the particles".
	 * @return	This FlxEmitter instance (nice for chaining stuff together).
	 */
	public function start(Explode:Bool = true, Frequency:Float = 0.1, Quantity:Int = 0):FlxTypedEmitter<T>
	{
		revive();
		visible = true;
		emitting = true;
		
		_explode = Explode;
		frequency = Frequency;
		_quantity += Quantity;
		
		_counter = 0;
		_timer = 0;
		
		_waitForKill = false;
		
		return this;
	}
	
	/**
	 * This function can be used both internally and externally to emit the next particle.
	 */
	public function emitParticle():Void
	{
		var particle:T = cast recycle(cast particleClass, function() return Type.createInstance(particleClass, []));
		
		particle.reset(FlxRandom.float(x, x + width), FlxRandom.float(y, y + height));
		
		// Particle blend settings
		
		particle.blend = blend;
		
		// Particle velocity/launch angle settings
		
		particle.velocityRange.active = !particle.velocityRange.start.equals(particle.velocityRange.end);
		
		if (launchAngle != null && launchMode == FlxEmitterMode.CIRCLE)
		{
			var particleAngle:Float = FlxRandom.float(launchAngle.min, launchAngle.max);
			// Calculate launch velocity
			_point = FlxVelocity.velocityFromAngle(particleAngle, FlxMath.vectorLength(FlxRandom.float(velocity.start.min.x, velocity.start.max.x), FlxRandom.float(velocity.start.min.y, velocity.start.max.y)));
			particle.velocity.x = _point.x;
			particle.velocity.y = _point.y;
			particle.velocityRange.start.set(_point.x, _point.y);
			// Calculate final velocity
			_point = FlxVelocity.velocityFromAngle(particleAngle, FlxMath.vectorLength(FlxRandom.float(velocity.end.min.x, velocity.end.max.x), FlxRandom.float(velocity.end.min.y, velocity.end.max.y)));
			particle.velocityRange.end.set(_point.x, _point.y);
		}
		else
		{
			particle.velocityRange.start.x = FlxRandom.float(velocity.start.min.x, velocity.start.max.x);
			particle.velocityRange.start.y = FlxRandom.float(velocity.start.min.y, velocity.start.max.y);
			particle.velocityRange.end.x = FlxRandom.float(velocity.end.min.x, velocity.end.max.x);
			particle.velocityRange.end.y = FlxRandom.float(velocity.end.min.y, velocity.end.max.y);
			particle.velocity.x = particle.velocityRange.start.x;
			particle.velocity.y = particle.velocityRange.start.y;
		}
		
		// Particle angular velocity settings
		
		particle.angularVelocityRange.active = angularVelocity.start != angularVelocity.end;
		
		if (!ignoreAngularVelocity)
		{
			particle.angularVelocityRange.start = FlxRandom.float(angularVelocity.start.min, angularVelocity.start.max);
			particle.angularVelocityRange.end = FlxRandom.float(angularVelocity.end.min, angularVelocity.end.max);
			particle.angularVelocity = particle.angularVelocityRange.start;
		}
		else
		{
			particle.angularVelocity = (FlxRandom.float(angle.end.min, angle.end.max) - FlxRandom.float(angle.start.min, angle.start.max)) / FlxRandom.float(lifespan.min, lifespan.max);
			particle.angularVelocityRange.active = false;
		}
		
		// Particle angle settings
		
		particle.angle = FlxRandom.float(angle.start.min, angle.start.max);
		
		// Particle lifespan settings
		
		particle.lifespan = FlxRandom.float(lifespan.min, lifespan.max);
		
		// Particle scale settings
		
		particle.scaleRange.start.x = FlxRandom.float(scale.start.min.x, scale.start.max.x);
		particle.scaleRange.start.y = FlxRandom.float(scale.start.min.y, scale.start.max.y);
		particle.scaleRange.end.x = FlxRandom.float(scale.end.min.x, scale.end.max.x);
		particle.scaleRange.end.y = FlxRandom.float(scale.end.min.y, scale.end.max.y);
		particle.scaleRange.active = particle.scaleRange.start != particle.scaleRange.end;
		particle.scale.x = particle.scaleRange.start.x;
		particle.scale.y = particle.scaleRange.start.y;
		
		// Particle alpha settings
		
		particle.alphaRange.start = FlxRandom.float(alpha.start.min, alpha.start.max);
		particle.alphaRange.end = FlxRandom.float(alpha.end.min, alpha.end.max);
		particle.alphaRange.active = particle.alphaRange.start != particle.alphaRange.end;
		particle.alpha = particle.alphaRange.start;
		
		// Particle color settings
		
		particle.colorRange.start = FlxRandom.color(color.start.min, color.start.max);
		particle.colorRange.end = FlxRandom.color(color.end.min, color.end.max);
		particle.colorRange.active = particle.colorRange.start != particle.colorRange.end;
		particle.color = particle.colorRange.start;
		
		// Particle drag settings
		
		particle.dragRange.start.x = FlxRandom.float(drag.start.min.x, drag.start.max.x);
		particle.dragRange.start.y = FlxRandom.float(drag.start.min.y, drag.start.max.y);
		particle.dragRange.end.x = FlxRandom.float(drag.end.min.x, drag.end.max.x);
		particle.dragRange.end.y = FlxRandom.float(drag.end.min.y, drag.end.max.y);
		particle.dragRange.active = !particle.dragRange.start.equals(particle.dragRange.end);
		particle.drag.x = particle.dragRange.start.x;
		particle.drag.y = particle.dragRange.start.y;
		
		// Particle acceleration settings
		
		particle.accelerationRange.start.x = FlxRandom.float(acceleration.start.min.x, acceleration.start.max.x);
		particle.accelerationRange.start.y = FlxRandom.float(acceleration.start.min.y, acceleration.start.max.y);
		particle.accelerationRange.end.x = FlxRandom.float(acceleration.end.min.x, acceleration.end.max.x);
		particle.accelerationRange.end.y = FlxRandom.float(acceleration.end.min.y, acceleration.end.max.y);
		particle.accelerationRange.active = !particle.accelerationRange.start.equals(particle.accelerationRange.end);
		particle.acceleration.x = particle.accelerationRange.start.x;
		particle.acceleration.y = particle.accelerationRange.start.y;
		
		// Particle elasticity settings
		
		particle.elasticityRange.start = FlxRandom.float(elasticity.start.min, elasticity.start.max);
		particle.elasticityRange.end = FlxRandom.float(elasticity.end.min, elasticity.end.max);
		particle.elasticityRange.active = particle.elasticityRange.start != particle.elasticityRange.end;
		particle.elasticity = particle.elasticityRange.start;
		
		// Particle collision settings
		
		particle.immovable = immovable;
		particle.solid = solid;
		particle.allowCollisions = allowCollisions;
		particle.autoUpdateHitbox = autoUpdateHitbox;
		
		particle.onEmit();
	}
	
	/**
	 * Change the emitter's midpoint to match the midpoint of a FlxObject.
	 * 
	 * @param	Object		The FlxObject that you want to sync up with.
	 */
	public function focusOn(Object:FlxObject):Void
	{
		Object.getMidpoint(_point);
		
		x = _point.x - (Std.int(width) >> 1);
		y = _point.y - (Std.int(height) >> 1);
	}
	
	private inline function get_solid():Bool
	{
		return (allowCollisions & FlxObject.ANY) > FlxObject.NONE;
	}
	
	private function set_solid(Solid:Bool):Bool
	{
		if (Solid)
		{
			allowCollisions = FlxObject.ANY;
		}
		else
		{
			allowCollisions = FlxObject.NONE;
		}
		return Solid;
	}
}

enum FlxEmitterMode
{
	SQUARE;
	CIRCLE;
}