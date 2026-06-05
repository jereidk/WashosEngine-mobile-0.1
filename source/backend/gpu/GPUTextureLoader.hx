package backend.gpu;

#if android
import openfl.display.BitmapData;
import openfl.utils.Assets;

/**
 * GPU Texture Helper for ASTC compressed textures.
 * Based on Shadow Engine approach: https://github.com/ShadowEngineTeam/FNF-Shadow-Engine
 * 
 * Note: OpenFL automatically loads .astc files when available in the asset paths
 * configured in Project.xml. This class provides utility functions for GPU texture operations.
 */
class GPUTextureLoader
{
	// GPU texture format constants
	public static inline var FORMAT_ASTC:String = "ASTC";
	public static inline var FORMAT_BC:String = "BC";
	public static inline var FORMAT_PNG:String = "PNG";
	
	/**
	 * Check if GPU compressed textures are enabled.
	 * This reflects the USING_GPU_TEXTURES haxedef from Project.xml
	 */
	public static inline function isEnabled():Bool {
		#if USING_GPU_TEXTURES
		return true;
		#else
		return false;
		#end
	}
	
	/**
	 * Get the current GPU texture format string.
	 */
	public static inline function getCurrentFormat():String {
		#if android
		return FORMAT_ASTC;
		#elseif windows
		return FORMAT_BC;
		#else
		return FORMAT_PNG;
		#end
	}
	
	/**
	 * Get the asset path suffix for the current format.
	 * Returns "-astc", "-bc", or "" for PNG.
	 */
	public static inline function getAssetPathSuffix():String {
		#if android
		return "-astc";
		#elseif windows
		return "-bc";
		#else
		return "-png";
		#end
	}
	
	/**
	 * Preload a texture by key.
	 * This triggers OpenFL to cache the texture.
	 */
	public static function preload(key:String):BitmapData {
		var texture:BitmapData = null;
		try {
			texture = Assets.getBitmapData(key);
		} catch (e:Dynamic) {
			// Texture not found or load error
		}
		return texture;
	}
	
	/**
	 * Check if a texture exists (ASTC version if available).
	 */
	public static function exists(key:String):Bool {
		return Assets.exists(key);
	}
	
	/**
	 * Get memory usage estimate for a texture.
	 */
	public static function getTextureMemorySize(texture:BitmapData):Float {
		if (texture == null) return 0;
		// Approximate memory: width * height * 4 bytes (RGBA)
		return (texture.width * texture.height * 4) / (1024 * 1024); // MB
	}
}