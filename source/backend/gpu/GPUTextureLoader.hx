package backend.gpu;

#if android
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import sys.FileSystem;
import haxe.Json;

/**
 * GPU Texture Loader for ASTC compressed textures.
 * Based on hx-astcenc approach: https://github.com/rainyt/hx-astcenc
 * 
 * This class handles loading and caching of pre-compressed ASTC textures
 * for improved performance on Android devices.
 */
class GPUTextureLoader
{
	// Texture format constants (matching project.hxp)
	public static inline var FORMAT_ASTC:String = "ASTC";
	public static inline var FORMAT_BC:String = "BC";
	public static inline var FORMAT_DXT5:String = "DXT5";
	public static inline var FORMAT_ETC1:String = "ETC1";
	
	// Cache for loaded ASTC textures
	static var textureCache:Map<String, BitmapData> = [];
	static var astcManifest:Map<String, ASTCTextureInfo> = [];
	
	// Configuration
	static var config:Dynamic = null;
	static var enabled:Bool = true;
	static var useFallback:Bool = true;
	
	public static function init(?configPath:String):Void
	{
		#if android
		loadConfig(configPath);
		checkHardwareSupport();
		trace('GPUTextureLoader initialized. ASTC support: $enabled');
		#end
	}
	
	static function loadConfig(?configPath:String):Void
	{
		if (configPath == null)
			configPath = 'astc-compression-data.json';
		
		try {
			if (FileSystem.exists(configPath)) {
				var content:String = sys.io.File.getContent(configPath);
				config = Json.parse(content);
				
				// Load from project.hxp if exists
				if (FileSystem.exists('project.hxp')) {
					var hxpContent:String = sys.io.File.getContent('project.hxp');
					// Parse hxp format - simplified for now
				}
				
				enabled = config.enableGPUTextures != false;
				useFallback = config.fallbackToPNG != false;
				
				// Load manifest if exists
				loadManifest();
			}
		} catch (e:Dynamic) {
			trace('Warning: Could not load ASTC config: $e');
		}
	}
	
	static function loadManifest():Void
	{
		var manifestPath:String = 'assets-astc/astc_manifest.json';
		if (FileSystem.exists(manifestPath)) {
			try {
				var content:String = sys.io.File.getContent(manifestPath);
				var manifest:Dynamic = Json.parse(content);
				
				if (manifest.textures != null) {
					for (tex in cast(manifest.textures, Array<Dynamic>)) {
						var info:ASTCTextureInfo = {
							path: tex.path,
							size: tex.size,
							format: FORMAT_ASTC,
							loaded: false
						};
						astcManifest.set(tex.path, info);
					}
					trace('Loaded ${astcManifest.size} ASTC textures from manifest');
				}
			} catch (e:Dynamic) {
				trace('Warning: Could not load ASTC manifest: $e');
			}
		}
	}
	
	static function checkHardwareSupport():Void
	{
		#if android
		// Most modern Android devices support ASTC
		// Check for specific GPU capabilities if needed
		enabled = true;
		#end
	}
	
	/**
	 * Load a texture, preferring ASTC version if available.
	 * @param key The texture key/path
	 * @param parentFolder Optional parent folder
	 * @return BitmapData of the loaded texture
	 */
	public static function loadTexture(key:String, ?parentFolder:String = null):BitmapData
	{
		if (!enabled) return null;
		
		// Check cache first
		var cacheKey:String = key + (parentFolder != null ? '|$parentFolder' : '');
		if (textureCache.exists(cacheKey)) {
			return textureCache.get(cacheKey);
		}
		
		// Try to load ASTC version
		var astcPath:String = getASTCPath(key, parentFolder);
		if (astcPath != null && FileSystem.exists(astcPath)) {
			var texture:BitmapData = loadASTCTexture(astcPath);
			if (texture != null) {
				textureCache.set(cacheKey, texture);
				return texture;
			}
		}
		
		// Fallback to regular texture loading
		if (useFallback) {
			return loadFallbackTexture(key, parentFolder);
		}
		
		return null;
	}
	
	/**
	 * Get the ASTC file path for a given texture key.
	 */
	public static function getASTCPath(key:String, ?parentFolder:String = null):String
	{
		// Check manifest first
		for (path => info in astcManifest) {
			if (path.indexOf(key) != -1 || key.indexOf(path) != -1) {
				return 'assets-astc/' + path;
			}
		}
		
		// Generate path based on key
		var basePath:String = parentFolder != null ? parentFolder : '';
		if (!basePath.endsWith('/') && basePath.length > 0) basePath += '/';
		
		// Common patterns for ASTC files
		var astcPath:String = 'assets-astc/' + basePath + key + '.astc';
		return astcPath;
	}
	
	/**
	 * Load an ASTC texture from file.
	 * This uses the native ASTC loading capability of OpenFL on Android.
	 */
	static function loadASTCTexture(path:String):BitmapData
	{
		#if android
		try {
			if (FileSystem.exists(path)) {
				var bytes:ByteArray = ByteArray.readFile(path);
				if (bytes != null && bytes.length > 0) {
					// OpenFL on Android can load ASTC directly via BitmapData
					var texture:BitmapData = BitmapData.loadFromFile(path);
					if (texture != null) {
						trace('Loaded ASTC texture: $path (${texture.width}x${texture.height})');
						return texture;
					}
				}
			}
		} catch (e:Dynamic) {
			trace('Failed to load ASTC texture: $path - $e');
		}
		#end
		
		return null;
	}
	
	/**
	 * Fallback to regular PNG/JPG loading.
	 */
	static function loadFallbackTexture(key:String, ?parentFolder:String = null):BitmapData
	{
		// Use the standard Paths.image() or similar
		// This will be handled by the existing texture loading system
		return null;
	}
	
	/**
	 * Preload textures for a category (e.g., all notes, all characters).
	 */
	public static function preloadCategory(category:String, basePath:String = 'assets'):Void
	{
		#if android
		if (!enabled || astcManifest.size == 0) return;
		
		trace('Preloading $category textures...');
		
		for (path => info in astcManifest) {
			if (path.indexOf(category) != -1 && !info.loaded) {
				var fullPath:String = 'assets-astc/' + path;
				var texture:BitmapData = loadASTCTexture(fullPath);
				if (texture != null) {
					info.loaded = true;
				}
			}
		}
		#end
	}
	
	/**
	 * Clear the texture cache to free memory.
	 */
	public static function clearCache():Void
	{
		for (texture in textureCache) {
			if (texture != null) {
				texture.dispose();
			}
		}
		textureCache.clear();
		trace('GPUTextureLoader cache cleared');
	}
	
	/**
	 * Get cache statistics.
	 */
	public static function getStats():{cached:Int, total:Int, memory:Float}
	{
		var memory:Float = 0;
		for (texture in textureCache) {
			if (texture != null) {
				memory += texture.width * texture.height * 4; // Approximate RGBA memory
			}
		}
		
		return {
			cached: textureCache.size,
			total: astcManifest.size,
			memory: memory / (1024 * 1024) // MB
		};
	}
	
	/**
	 * Check if a texture has an ASTC version available.
	 */
	public static function hasASTCVersion(key:String):Bool
	{
		// Check manifest
		for (path in astcManifest.keys()) {
			if (path.indexOf(key) != -1) return true;
		}
		
		// Check file system
		var astcPath:String = getASTCPath(key);
		return FileSystem.exists(astcPath);
	}
	
	/**
	 * Set the enabled state.
	 */
	public static function setEnabled(value:Bool):Void
	{
		enabled = value;
		if (!enabled) {
			clearCache();
		}
	}
}

/**
 * Information about a loaded ASTC texture.
 */
typedef ASTCTextureInfo = {
	var path:String;
	var size:Int;
	var format:String;
	var loaded:Bool;
}