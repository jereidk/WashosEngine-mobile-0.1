package backend.gpu;

#if android
import openfl.display.BitmapData;
import openfl.utils.Assets;

/**
 * Helper utilities for compressed texture operations on mobile.
 */
class GPUTextureLoader
{
	// Texture format identifiers
	public static inline var FMT_ASTC:String = "ASTC";
	public static inline var FMT_BC:String = "BC";
	public static inline var FMT_PNG:String = "PNG";
	
	/**
	 * Check if compressed textures are active.
	 */
	public static inline function isActive():Bool {
		#if USING_GPU_TEXTURES
		return true;
		#else
		return false;
		#end
	}
	
	/**
	 * Get the active texture format name.
	 */
	public static inline function getActiveFormat():String {
		#if android
		return FMT_ASTC;
		#elseif windows
		return FMT_BC;
		#else
		return FMT_PNG;
		#end
	}
	
	/**
	 * Get the folder suffix for the current format.
	 */
	public static inline function getFolderSuffix():String {
		#if android
		return "-compressed";
		#elseif windows
		return "-compressed";
		#else
		return "";
		#end
	}
	
	/**
	 * Pre-cache a texture.
	 */
	public static function preload(key:String):BitmapData {
		var texture:BitmapData = null;
		try {
			texture = Assets.getBitmapData(key);
		} catch (e:Dynamic) {
			// Ignore preload errors
		}
		return texture;
	}
	
	/**
	 * Check if a texture asset exists.
	 */
	public static function exists(key:String):Bool {
		return Assets.exists(key);
	}
	
	/**
	 * Estimate memory usage of a texture.
	 */
	public static function getMemorySize(texture:BitmapData):Float {
		if (texture == null) return 0;
		return (texture.width * texture.height * 4) / (1024 * 1024);
	}
}