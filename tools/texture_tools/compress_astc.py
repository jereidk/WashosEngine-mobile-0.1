#!/usr/bin/env python3
"""
ASTC Texture Converter for WashosEngine
Converts PNG/JPG images to ASTC compressed format for Android.

Based on hx-astcenc approach: https://github.com/rainyt/hx-astcenc

Usage:
    python compress_astc.py [--input <folder>] [--output <folder>] [--block-size <WxH>] [--quality <preset>]

Requirements:
    - Android NDK installed (for astcenc tool)
    - Python 3.6+

Example:
    python compress_astc.py -i assets/images -o assets-astc -b 6x6 -q medium
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

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Default settings matching hx-astcenc style
DEFAULT_BLOCK_SIZE = "6x6"
QUALITY_FLAGS = {
    "fast": "-fast",
    "medium": "-medium", 
    "thorough": "-thorough",
    "exhaustive": "-exhaustive"
}
SUPPORTED_FORMATS = ['.png', '.jpg', '.jpeg', '.bmp', '.tga']


class ASTCConverter:
    """ASTC texture converter with hx-astcenc compatibility."""
    
    def __init__(self, config_path=None):
        self.config = self._load_config(config_path)
        self.astcenc_path = self._find_astcenc()
        
    def _load_config(self, config_path):
        """Load ASTC compression configuration from JSON."""
        if config_path and os.path.exists(config_path):
            with open(config_path, 'r') as f:
                return json.load(f)
        # Default config
        return {
            "defaultSettings": {
                "blockSize": "6x6",
                "quality": "medium",
                "premultiplyAlpha": True
            },
            "textureCategories": {}
        }
    
    def _find_astcenc(self):
        """Find astcenc executable in common locations."""
        possible_paths = [
            # NDK toolchains
            os.path.expanduser("~/android-sdk/ndk/latest/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"),
            os.path.expanduser("~/android-sdk/ndk/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"),
            os.path.expanduser("~/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"),
            "/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
            "/usr/local/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
            # Standalone
            "/usr/local/bin/astcenc",
            os.path.join(os.path.dirname(__file__), "astcenc"),
            os.path.join(os.path.dirname(__file__), "astcenc.exe"),
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Try PATH
        result = shutil.which("astcenc")
        if result:
            return result
            
        return None
    
    def get_block_size_for_category(self, rel_path):
        """Get block size based on texture category."""
        default = self.config.get("defaultSettings", {}).get("blockSize", "6x6")
        categories = self.config.get("textureCategories", {})
        
        for category, settings in categories.items():
            pattern = settings.get("pattern", "")
            if self._match_pattern(rel_path, pattern):
                return settings.get("blockSize", default)
        
        return default
    
    def get_quality_flag(self, quality=None):
        """Get astcenc quality flag."""
        if quality is None:
            quality = self.config.get("defaultSettings", {}).get("quality", "medium")
        return QUALITY_FLAGS.get(quality, "-medium")
    
    def _match_pattern(self, path, pattern):
        """Simple glob pattern matching."""
        import fnmatch
        return fnmatch.fnmatch(path, pattern.replace("**/", "*").replace("**", "*"))
    
    def convert_image(self, input_path, output_path, block_size=None, quality=None, premultiply=True):
        """Convert a single image to ASTC format."""
        if not self.astcenc_path:
            logger.warning(f"astcenc not found, skipping {input_path}")
            return False
        
        try:
            # Determine block size from category if not specified
            if block_size is None:
                rel_path = str(input_path)
                block_size = self.get_block_size_for_category(rel_path)
            
            quality_flag = self.get_quality_flag(quality)
            
            # Build command (hx-astcenc style)
            cmd = [
                self.astcenc_path,
                str(input_path),
                str(output_path),
                block_size,
                quality_flag
            ]
            
            # Add premultiply if supported
            if premultiply and self.config.get("defaultSettings", {}).get("premultiplyAlpha", True):
                cmd.append("-pp-premultiply")
            
            cmd.append("-quiet")
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                size_orig = os.path.getsize(input_path)
                size_astc = os.path.getsize(output_path)
                ratio = (1 - size_astc / size_orig) * 100 if size_orig > 0 else 0
                logger.info(f"✓ {Path(input_path).name}: {size_orig/1024:.1f}KB → {size_astc/1024:.1f}KB ({ratio:.1f}% smaller)")
                return True
            else:
                logger.error(f"✗ {input_path}: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"✗ {input_path}: {str(e)}")
            return False
    
    def convert_directory(self, input_dir, output_dir, workers=4, skip_patterns=None):
        """Convert all images in a directory."""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        if skip_patterns is None:
            skip_patterns = self.config.get("defaultSettings", {}).get("ignorePatterns", [])
        
        # Find all images
        images = []
        for fmt in SUPPORTED_FORMATS:
            for img in input_path.rglob(f"*{fmt}"):
                rel = str(img.relative_to(input_path))
                if not any(self._match_pattern(rel, p) for p in skip_patterns):
                    images.append(img)
        
        images = list(set(images))
        
        if not images:
            logger.warning(f"No images found in {input_dir}")
            return 0, 0
        
        logger.info(f"Found {len(images)} images to convert")
        
        success = 0
        failed = 0
        
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {}
            
            for img_path in images:
                rel_path = img_path.relative_to(input_path)
                astc_path = output_path / rel_path.parent / (rel_path.stem + '.astc')
                astc_path.parent.mkdir(parents=True, exist_ok=True)
                
                future = executor.submit(self.convert_image, str(img_path), str(astc_path))
                futures[future] = str(img_path)
            
            for future in as_completed(futures):
                try:
                    if future.result():
                        success += 1
                    else:
                        failed += 1
                except Exception as e:
                    logger.error(f"Error: {futures[future]}: {str(e)}")
                    failed += 1
        
        return success, failed
    
    def generate_manifest(self, output_dir, manifest_path=None):
        """Generate a manifest of converted textures."""
        if manifest_path is None:
            manifest_path = Path(output_dir) / "astc_manifest.json"
        
        manifest = {
            "version": "1.0.0",
            "engine": "WashosEngine",
            "format": "ASTC",
            "textures": []
        }
        
        astc_dir = Path(output_dir)
        for astc_file in astc_dir.rglob("*.astc"):
            manifest["textures"].append({
                "path": str(astc_file.relative_to(astc_dir)),
                "size": os.path.getsize(astc_file),
                "format": "ASTC"
            })
        
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        logger.info(f"Manifest generated: {manifest_path}")


def main():
    parser = argparse.ArgumentParser(
        description='ASTC Texture Converter for WashosEngine',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Basic conversion:
    python compress_astc.py -i assets/images -o assets-astc
    
  With config:
    python compress_astc.py -i assets -o assets-astc -c ../astc-compression-data.json
    
  High quality (like hx-astcenc exhaustive):
    python compress_astc.py -i assets -o assets-astc -b 4x4 -q exhaustive
    
  Custom block size:
    python compress_astc.py -i assets -o assets-astc -b 5x5 -q thorough
        """
    )
    
    parser.add_argument('-i', '--input', required=True, help='Input directory')
    parser.add_argument('-o', '--output', required=True, help='Output directory for ASTC files')
    parser.add_argument('-c', '--config', default='astc-compression-data.json', 
                        help='Configuration JSON file')
    parser.add_argument('-b', '--block-size', help='Block size (4x4, 5x5, 6x6, 8x8)')
    parser.add_argument('-q', '--quality', choices=['fast', 'medium', 'thorough', 'exhaustive'],
                        help='Compression quality')
    parser.add_argument('-w', '--workers', type=int, default=4, help='Parallel workers')
    parser.add_argument('--manifest', action='store_true', help='Generate manifest file')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.input):
        logger.error(f"Input directory not found: {args.input}")
        sys.exit(1)
    
    # Create converter
    config_path = args.config if os.path.exists(args.config) else None
    converter = ASTCConverter(config_path)
    
    if not converter.astcenc_path:
        logger.error("astcenc not found! Please install Android NDK.")
        logger.error("Download: https://developer.android.com/ndk/downloads")
        sys.exit(1)
    
    logger.info(f"Using astcenc: {converter.astcenc_path}")
    
    # Convert
    success, failed = converter.convert_directory(
        args.input, 
        args.output, 
        workers=args.workers
    )
    
    logger.info(f"\nConversion complete: {success} success, {failed} failed")
    
    # Generate manifest if requested
    if args.manifest and success > 0:
        converter.generate_manifest(args.output)
    
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main() or 0)