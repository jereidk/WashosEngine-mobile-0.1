# Compressed Texture Support - WashosEngine

## Overview

Mobile and desktop optimization through GPU texture compression. Reduces memory usage and improves loading times.

## How It Works

**Build-time asset configuration:**

1. **Project.xml** defines asset paths for each platform:
   - `assets/images-compressed` → `assets/shared/images` (Android/iOS)
   - `assets/images-compressed` → `assets/shared/images` (Windows)
   - `assets/images-base` → `assets/shared/images` (fallback)

2. **USING_GPU_TEXTURES** flag enabled for Android builds

3. **OpenFL automatically** loads compressed textures when available

## Quick Start

### 1. Generate Compressed Textures

```bash
cd gpu_texture_generator
./build.sh
```

This converts PNG images to compressed format in `assets/images-compressed/`.

### 2. Build for Android

```bash
lime build android -release
```

## File Structure

```
WashosEngine/
├── Project.xml                      # Asset path configuration
├── project.hxp                      # Compression settings
├── astc-compression-data.json       # Presets by texture type
├── assets/
│   └── shared/images/              # Source PNG images
├── assets/images-compressed/        # Compressed textures (.astc)
├── assets/images-base/            # Fallback PNGs
├── gpu_texture_generator/          # Conversion tools
│   ├── build.sh
│   └── generate_gpu_textures.py
└── source/
    └── backend/
        └── gpu/
            └── GPUTextureLoader.hx  # Helper utilities
```

## Supported Formats

| Platform | Format | Extension | Asset Folder |
|----------|--------|-----------|--------------|
| Android | ASTC | .astc | images-compressed |
| iOS | ASTC | .astc | images-compressed |
| Windows | BC/DXT | .dds | images-compressed |
| Other | PNG | .png | images-base |

## Block Sizes (ASTC)

| Size | Compression | Best For |
|------|-------------|----------|
| 4x4 | 8:1 | UI, icons |
| 5x5 | 12:1 | Characters |
| 6x6 | 16:1 | General (default) |
| 8x8 | 32:1 | Backgrounds |

## Code Usage

### Paths.hx

```haxe
// Check if compressed textures are enabled
if (Paths.isCompressedTexturesEnabled()) {
    trace('Using: ' + Paths.getCompressedTextureFormat());
}
```

### GPUTextureLoader

```haxe
#if android
import backend.gpu.GPUTextureLoader;

// Check status
if (GPUTextureLoader.isActive()) {
    var format = GPUTextureLoader.getActiveFormat(); // "ASTC"
    var suffix = GPUTextureLoader.getFolderSuffix(); // "-compressed"
}

// Pre-cache texture
var tex = GPUTextureLoader.preload('assets/shared/images/note');
#end
```

## Mods Support

Mods can include their own compressed textures. Place `.astc` files in:

```
mods/[mod-name]/images/[texture-name].astc
```

The engine checks mod directories first, then falls back to base assets.

## Conversion Tool Usage

```bash
# Convert all textures to ASTC
python generate_gpu_textures.py -i ../assets -o ../assets/images-compressed -f ASTC

# Custom settings
python generate_gpu_textures.py -i ../assets -o ../assets/images-compressed -b 5x5 -q thorough
```

## Configuration

Edit `astc-compression-data.json` for texture-specific settings:

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

### Compressed textures not loading

1. Verify `.astc` files exist in `assets/images-compressed/`
2. Check `USING_GPU_TEXTURES` flag in Project.xml
3. Ensure asset paths are correctly ordered (compressed before base)

### Mod textures not working

Place mod compressed textures in:
`mods/[mod-name]/images/[name].astc`