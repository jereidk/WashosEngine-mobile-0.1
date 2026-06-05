# GPU Texture Support - WashosEngine

## Overview

This engine supports GPU-compressed textures (ASTC, BC, DXT5, ETC1) for optimized performance on mobile and desktop platforms. This is based on the approach used by [Shadow Engine](https://github.com/ShadowEngineTeam/FNF-Shadow-Engine) and [Funkin Crew](https://github.com/FunkinCrew/funkin).

## Quick Start

### 1. Generate GPU Textures

```bash
# Navigate to the GPU texture generator
cd gpu_texture_generator

# Run the build script
./build.sh
```

Or use the Python script directly:

```bash
python generate_gpu_textures.py -i ../assets -o ../assets-gpu -f ASTC
```

### 2. Configure Compression

Edit `astc-compression-data.json` to customize compression settings:

```json
{
  "defaultSettings": {
    "blockSize": "6x6",
    "quality": "medium",
    "premultiplyAlpha": true
  },
  "textureCategories": {
    "notes": {
      "pattern": "**/noteSkins/**",
      "blockSize": "6x6",
      "quality": "thorough"
    },
    "characters": {
      "pattern": "**/characters/**",
      "blockSize": "5x5",
      "quality": "thorough"
    }
  }
}
```

## File Structure

```
WashosEngine/
├── project.hxp                    # Texture format configuration
├── astc-compression-data.json     # Compression settings
├── assets-gpu/                    # Generated GPU textures
│   └── astc/                      # ASTC format textures
│       └── astc_manifest.json     # Texture manifest
├── gpu_texture_generator/         # Texture conversion tools
│   ├── build.sh                  # Bash script for NDK
│   ├── generate_gpu_textures.py  # Python converter
│   └── compress_astc.py          # ASTC compressor
└── source/
    └── backend/
        └── gpu/
            └── GPUTextureLoader.hx  # Haxe texture loader
```

## Texture Formats

| Format | Extension | Platform | Quality |
|--------|-----------|----------|---------|
| ASTC | .astc | Android (all), iOS | Best |
| BC | .dds | Windows, Xbox | High |
| DXT5 | .dds | Windows, macOS | High |
| ETC1 | .ktx | Android (legacy) | Medium |

## Block Sizes

| Block Size | Compression Ratio | Use Case |
|------------|-------------------|----------|
| 4x4 | 8:1 | UI, icons (highest quality) |
| 5x5 | 12:1 | Characters |
| 6x6 | 16:1 | General textures (recommended) |
| 8x8 | 32:1 | Large backgrounds |

## Quality Presets

| Preset | Speed | Quality |
|--------|-------|---------|
| fast | Very fast | Lower |
| medium | Fast | Balanced (default) |
| thorough | Slow | High |
| exhaustive | Very slow | Best |

## Using in Code

### Paths.hx Integration

```haxe
// Check if GPU textures should be used
if (Paths.shouldUseGPUTextures()) {
    var astcPath = Paths.getASTCPath('images/character');
    // Load ASTC texture...
}

// Format constants
var format = Paths.FORMAT_ASTC; // "ASTC"
```

### GPUTextureLoader

```haxe
#if android
import backend.gpu.GPUTextureLoader;

// Initialize
GPUTextureLoader.init('astc-compression-data.json');

// Load texture (prefers ASTC if available)
var texture = GPUTextureLoader.loadTexture('images/note');

// Preload category
GPUTextureLoader.preloadCategory('noteSkins');

// Get stats
var stats = GPUTextureLoader.getStats();
trace('Cached: ${stats.cached}, Total: ${stats.total}, Memory: ${stats.memory}MB');

// Clear cache when needed
GPUTextureLoader.clearCache();
#end
```

## Build Integration

### GitHub Actions

Add to your workflow to auto-generate textures before build:

```yaml
- name: Generate GPU Textures
  run: |
    cd gpu_texture_generator
    chmod +x build.sh
    ./build.sh
```

### Gradle (Android)

The build system automatically detects `.astc` files in assets and loads them when available.

## Configuration (project.hxp)

```json
{
  "textureFormats": ["ASTC", "BC", "DXT5", "ETC1"],
  "enableGPUTextures": true,
  "fallbackToPNG": true
}
```

## Troubleshooting

### astcenc not found

Install Android NDK:
```bash
# Linux/macOS
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/26.1.10909125

# Windows - download from:
# https://developer.android.com/ndk/downloads
```

### Textures not loading

1. Check that `.astc` files exist in `assets-gpu/astc/`
2. Verify `astc_manifest.json` is present
3. Ensure `ASTC_ENABLED` is `true` in Paths.hx
4. Check log output for texture loading errors

### Performance issues

1. Use smaller block sizes (4x4 or 5x5) for critical textures
2. Increase quality preset for important sprites
3. Use texture pooling in hot paths
4. Clear cache periodically to free memory

## References

- [Shadow Engine](https://github.com/ShadowEngineTeam/FNF-Shadow-Engine)
- [hx-astcenc](https://github.com/rainyt/hx-astcenc)
- [Funkin Crew](https://github.com/FunkinCrew/funkin)
- [ASTC Encoder](https://github.com/ARM-software/astc-encoder)
- [Android NDK](https://developer.android.com/ndk/downloads)