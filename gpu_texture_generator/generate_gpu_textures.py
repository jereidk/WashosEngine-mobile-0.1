#!/usr/bin/env python3
"""
GPU Texture Generator for WashosEngine
Generates compressed textures (ASTC, BC, DXT5, ETC1) for optimal GPU performance.

This tool processes all game textures and converts them to compressed formats
for use on mobile/desktop platforms.

Based on Shadow Engine approach: https://github.com/ShadowEngineTeam/FNF-Shadow-Engine

Usage:
    python generate_gpu_textures.py [--format ASTC] [--workers 4]
    
Required:
    - Android NDK (for astcenc on Linux/Mac/Windows)
    - Python 3.6+
"""

import os
import sys
import json
import argparse
import subprocess
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Supported formats
SUPPORTED_FORMATS = {
    "ASTC": {
        "extension": ".astc",
        "encoder": "astcenc",
        "block_sizes": ["4x4", "5x5", "6x6", "8x8"],
        "default_block": "6x6"
    },
    "BC": {
        "extension": ".dds",
        "encoder": "texconv",
        "default_block": "bc7"
    },
    "DXT5": {
        "extension": ".dds",
        "encoder": "texconv",
        "default_block": "dxt5"
    },
    "ETC1": {
        "extension": ".ktx",
        "encoder": "etcpack",
        "default_block": "etc1"
    }
}

DEFAULT_QUALITY = "medium"
QUALITY_FLAGS = {
    "fast": "-fast",
    "medium": "-medium",
    "thorough": "-thorough",
    "exhaustive": "-exhaustive"
}


class GPUTextureGenerator:
    """Generator for GPU compressed textures."""
    
    def __init__(self, format="ASTC", config_path=None):
        self.format = format.upper()
        self.config = self._load_config(config_path)
        self.encoder_path = self._find_encoder()
        
        if self.format not in SUPPORTED_FORMATS:
            raise ValueError(f"Unsupported format: {format}. Choose from: {list(SUPPORTED_FORMATS.keys())}")
    
    def _load_config(self, config_path):
        """Load configuration from project.hxp or astc-compression-data.json."""
        if config_path is None:
            config_path = "astc-compression-data.json"
        
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                return json.load(f)
        
        return {}
    
    def _find_encoder(self):
        """Find the texture encoder executable."""
        if self.format == "ASTC":
            return self._find_astcenc()
        elif self.format in ["BC", "DXT5"]:
            return self._find_texconv()
        elif self.format == "ETC1":
            return self._find_etcpack()
        return None
    
    def _find_astcenc(self):
        """Find astcenc in common locations."""
        search_paths = [
            # NDK locations
            os.path.expanduser("~/android-sdk/ndk/latest/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"),
            os.path.expanduser("~/android-sdk/ndk/latest/toolchains/llvm/prebuilt/darwin-x86_64/bin/astcenc"),
            os.path.expanduser("~/android-sdk/ndk/latest/toolchains/llvm/prebuilt/windows-x86_64/bin/astcenc.exe"),
            os.path.expanduser("~/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"),
            "/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
            "/usr/local/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
            # Local
            os.path.join(os.path.dirname(__file__), "astcenc"),
            os.path.join(os.path.dirname(__file__), "astcenc.exe"),
        ]
        
        for path in search_paths:
            if os.path.exists(path):
                return path
        
        # Try PATH
        result = shutil.which("astcenc")
        if result:
            return result
        
        logger.warning("astcenc not found. Install Android NDK to enable ASTC compression.")
        return None
    
    def _find_texconv(self):
        """Find DirectX texture converter."""
        # texconv is part of DirectXTex toolkit
        search_paths = [
            os.path.join(os.path.dirname(__file__), "texconv.exe"),
            "C:\\Program Files\\DirectXTex\\texconv.exe",
            "/usr/local/bin/texconv",
        ]
        
        for path in search_paths:
            if os.path.exists(path):
                return path
        
        return shutil.which("texconv")
    
    def _find_etcpack(self):
        """Find etcpack for ETC1 compression."""
        search_paths = [
            os.path.join(os.path.dirname(__file__), "etcpack"),
            "/usr/local/bin/etcpack",
        ]
        
        for path in search_paths:
            if os.path.exists(path):
                return path
        
        return shutil.which("etcpack")
    
    def get_settings_for_texture(self, rel_path):
        """Get compression settings based on texture category."""
        categories = self.config.get("textureCategories", {})
        default_settings = self.config.get("defaultSettings", {})
        
        for category, settings in categories.items():
            pattern = settings.get("pattern", "")
            if self._match_pattern(rel_path, pattern):
                return {
                    "block_size": settings.get("blockSize", default_settings.get("blockSize", "6x6")),
                    "quality": settings.get("quality", default_settings.get("quality", "medium")),
                    "premultiply": settings.get("premultiply", default_settings.get("premultiplyAlpha", True))
                }
        
        return {
            "block_size": default_settings.get("blockSize", "6x6"),
            "quality": default_settings.get("quality", "medium"),
            "premultiply": default_settings.get("premultiplyAlpha", True)
        }
    
    def _match_pattern(self, path, pattern):
        """Simple glob pattern matching."""
        import fnmatch
        pattern = pattern.replace("**/", "*").replace("**", "*")
        return fnmatch.fnmatch(path, pattern)
    
    def convert_texture(self, input_path, output_path, settings=None):
        """Convert a single texture to the target format."""
        if self.encoder_path is None:
            logger.warning(f"Encoder not found, skipping {input_path}")
            return False
        
        if settings is None:
            settings = self.get_settings_for_texture(str(input_path))
        
        try:
            if self.format == "ASTC":
                return self._convert_astc(input_path, output_path, settings)
            elif self.format in ["BC", "DXT5"]:
                return self._convert_dds(input_path, output_path, settings)
            elif self.format == "ETC1":
                return self._convert_etc1(input_path, output_path, settings)
        except Exception as e:
            logger.error(f"Failed to convert {input_path}: {e}")
            return False
        
        return False
    
    def _convert_astc(self, input_path, output_path, settings):
        """Convert to ASTC format using astcenc."""
        block_size = settings.get("block_size", "6x6")
        quality = settings.get("quality", "medium")
        premultiply = settings.get("premultiply", True)
        
        quality_flag = QUALITY_FLAGS.get(quality, "-medium")
        
        cmd = [
            self.encoder_path,
            str(input_path),
            str(output_path),
            block_size,
            quality_flag
        ]
        
        if premultiply:
            cmd.append("-pp-premultiply")
        
        cmd.append("-quiet")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            orig_size = os.path.getsize(input_path)
            new_size = os.path.getsize(output_path)
            ratio = (1 - new_size / orig_size) * 100 if orig_size > 0 else 0
            logger.info(f"✓ {Path(input_path).name}: {orig_size/1024:.1f}KB → {new_size/1024:.1f}KB ({ratio:.1f}% reduction)")
            return True
        else:
            logger.error(f"✗ {input_path}: {result.stderr}")
            return False
    
    def _convert_dds(self, input_path, output_path, settings):
        """Convert to DDS format using texconv."""
        # texconv -f BC7_UNORM input.png -o output.dds
        cmd = [
            self.encoder_path,
            "-f", "BC7_UNORM",
            "-o", str(Path(output_path).parent),
            str(input_path)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0
    
    def _convert_etc1(self, input_path, output_path, settings):
        """Convert to ETC1 format using etcpack."""
        cmd = [
            self.encoder_path,
            str(input_path),
            str(output_path)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0
    
    def process_directory(self, input_dir, output_dir, workers=4, recursive=True):
        """Process all textures in a directory."""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Find all images
        image_extensions = ['.png', '.jpg', '.jpeg', '.bmp', '.tga']
        images = []
        
        for ext in image_extensions:
            if recursive:
                images.extend(input_path.rglob(f"*{ext}"))
            else:
                images.extend(input_path.glob(f"*{ext}"))
        
        images = list(set(images))
        
        if not images:
            logger.warning(f"No images found in {input_dir}")
            return 0, 0
        
        ext_info = SUPPORTED_FORMATS[self.format]
        success = 0
        failed = 0
        
        logger.info(f"Processing {len(images)} images to {self.format}...")
        
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {}
            
            for img in images:
                rel_path = img.relative_to(input_path)
                output_file = output_path / rel_path.parent / (rel_path.stem + ext_info["extension"])
                output_file.parent.mkdir(parents=True, exist_ok=True)
                
                future = executor.submit(self.convert_texture, str(img), str(output_file))
                futures[future] = str(img)
            
            for future in as_completed(futures):
                try:
                    if future.result():
                        success += 1
                    else:
                        failed += 1
                except Exception as e:
                    logger.error(f"Error: {futures[future]}: {e}")
                    failed += 1
        
        return success, failed
    
    def generate_manifest(self, output_dir):
        """Generate a manifest file for all converted textures."""
        ext_info = SUPPORTED_FORMATS[self.format]
        manifest = {
            "version": "1.0.0",
            "engine": "WashosEngine",
            "format": self.format,
            "textures": []
        }
        
        for file_path in Path(output_dir).rglob(f"*{ext_info['extension']}"):
            rel_path = str(file_path.relative_to(output_path))
            manifest["textures"].append({
                "path": rel_path,
                "size": os.path.getsize(file_path),
                "format": self.format
            })
        
        manifest_path = output_dir / f"{self.format.lower()}_manifest.json"
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        logger.info(f"Manifest generated: {manifest_path}")
        return manifest_path


def main():
    parser = argparse.ArgumentParser(
        description='GPU Texture Generator for WashosEngine',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Generate ASTC textures:
    python generate_gpu_textures.py -i assets/images -o assets-astc -f ASTC
    
  Generate with config:
    python generate_gpu_textures.py -i assets -o assets-gpu -f ASTC -c ../astc-compression-data.json
    
  High quality conversion:
    python generate_gpu_textures.py -i assets -o assets-gpu -f ASTC -q exhaustive
        """
    )
    
    parser.add_argument('-i', '--input', required=True, help='Input directory')
    parser.add_argument('-o', '--output', required=True, help='Output directory')
    parser.add_argument('-f', '--format', default='ASTC', 
                        choices=list(SUPPORTED_FORMATS.keys()),
                        help='Output format (default: ASTC)')
    parser.add_argument('-c', '--config', help='Configuration file')
    parser.add_argument('-q', '--quality', 
                        choices=['fast', 'medium', 'thorough', 'exhaustive'],
                        help='Compression quality')
    parser.add_argument('-b', '--block-size', help='Block size for ASTC (e.g., 6x6)')
    parser.add_argument('-w', '--workers', type=int, default=4, help='Parallel workers')
    parser.add_argument('--manifest', action='store_true', help='Generate manifest file')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.input):
        logger.error(f"Input directory not found: {args.input}")
        sys.exit(1)
    
    try:
        generator = GPUTextureGenerator(args.format, args.config)
        
        if generator.encoder_path:
            logger.info(f"Using encoder: {generator.encoder_path}")
        else:
            logger.warning(f"No encoder found for {args.format}. Install required tools.")
        
        success, failed = generator.process_directory(
            args.input,
            args.output,
            workers=args.workers
        )
        
        logger.info(f"\nCompleted: {success} success, {failed} failed")
        
        if args.manifest and success > 0:
            generator.generate_manifest(args.output)
        
        return 0 if failed == 0 else 1
        
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main() or 0)