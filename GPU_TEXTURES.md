# GPU Texture Support - WashosEngine

## Overview

This engine supports GPU-compressed textures (ASTC for Android, BC for Windows) for optimized performance. Based on [Shadow Engine](https://github.com/ShadowEngineTeam/FNF-Shadow-Engine) approach.

## How It Works

The system is **build-time configuration**, not runtime loading:

1. **Project.xml** defines asset paths for each format:
   - `assets/images-astc` → `assets/shared/images` (Android)
   - `assets/images-bc` → `assets/shared/images` (Windows)
   - `assets/images-png` → `assets/shared/images` (fallback)

2. **USING_GPU_TEXTURES haxedef** is set for Android builds

3. **OpenFL automatically** loads the correct format based on asset paths

## Quick Start

### 1. Generate GPU Textures

```bash
cd gpu_texture_generator
./build.sh
```

This converts all PNG images in `assets/` to ASTC format in `assets/images-astc/`.

### 2. Build for Android

```bash
lime build android -release
```

OpenFL automatically uses `.astc` files from `assets/images-astc/` when available.

## File Structure

```
WashosEngine/
├── Project.xml                    # Asset path configuration
├── project.hxp                    # Texture format settings
├── astc-compression-data.json     # Compression presets
├── assets/
│   └── shared/images/            # Source PNG images
├── assets/images-astc/            # Generated ASTC textures (Android)
├── assets/images-bc/             # Generated BC textures (Windows)
├── gpu_texture_generator/         # Conversion tools
│   ├── build.sh                  # Bash script for NDK
│   └── generate_gpu_textures.py  # Python converter
└── source/
    └── backend/
        └── gpu/
            └── GPUTextureLoader.hx  # Helper utilities
```

## Texture Formats

| Platform | Format | Extension | Asset Path |
|----------|--------|-----------|------------|
| Android | ASTC | .astc | assets/images-astc/ |
| Windows | BC/DXT | .dds | assets/images-bc/ |
| Other | PNG | .png | assets/images-png/ |

## Block Sizes (ASTC)

| Size | Ratio | Use Case |
|------|-------|----------|
| 4x4 | 8:1 | UI, icons |
| 5x5 | 12:1 | Characters |
| 6x6 | 16:1 | General (recommended) |
| 8x8 | 32:1 | Backgrounds |

## Code Usage

### Paths.hx

```haxe
// Check if GPU textures are enabled
if (Paths.shouldUseGPUTextures()) {
    trace('Using GPU compressed textures');
}

// Get current format
var format = Paths.GPU_TEXTURE_FORMAT; // "astc", "bc", or "png"
```

### GPUTextureLoader

```haxe
#if android
import backend.gpu.GPUTextureLoader;

// Check if enabled
if (GPUTextureLoader.isEnabled()) {
    var format = GPUTextureLoader.getCurrentFormat(); // "ASTC"
    var suffix = GPUTextureLoader.getAssetPathSuffix(); // "-astc"
}

// Preload texture
var tex = GPUTextureLoader.preload('assets/shared/images/note');
#end
```

## Asset Path Configuration

In **Project.xml**, asset paths are configured like this:

```xml
<!-- GPU Texture Format Assets -->
<assets path="assets/images-astc" rename="assets/shared/images" if="android"/>
<assets path="assets/images-bc"   rename="assets/shared/images" if="windows"/>
<assets path="assets/images-png"  rename="assets/shared/images" />
```

OpenFL checks paths in order - if `assets/images-astc/note.png.astc` exists, it's loaded instead of the PNG.

## Conversion Tool Usage

```bash
# Convert all textures to ASTC (6x6 blocks, medium quality)
python generate_gpu_textures.py -i ../assets -o ../assets/images-astc -f ASTC

# With custom settings
python generate_gpu_textures.py -i ../assets -o ../assets/images-astc -b 5x5 -q thorough
```

## Compression Configuration

Edit `astc-compression-data.json`:

```json
{
  "defaultSettings": {
    "blockSize": "6x6",
    "quality": "medium"
  },
  "textureCategories": {
    "notes": {
      "pattern": "**/noteSkins/**",
      "blockSize": "6x6"
    },
    "characters": {
      "pattern": "**/characters/**",
      "blockSize": "5x5"
    }
  }
}
```

## Troubleshooting

### Textures not loading as ASTC

1. Verify `assets/images-astc/` contains `.astc` files
2. Check that `USING_GPU_TEXTURES` haxedef is set in Project.xml
3. Ensure asset paths are correctly configured

### Build errors

Make sure Android NDK is installed for astcenc:
```bash
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/26.1.10909125
```

## References

- [Shadow Engine](https://github.com/ShadowEngineTeam/FNF-Shadow-Engine)
- [Funkin Crew](https://github.com/FunkinCrew/funkin)
- [ASTC Encoder](https://github.com/ARM-software/astc-encoder)